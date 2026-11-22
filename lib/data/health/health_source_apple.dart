import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../../models/gps_track.dart';
import 'health_source.dart';

/// Native builds. Only iPhone has Apple Health.
HealthSource createHealthSource() =>
    Platform.isIOS ? AppleHealthSource() : const UnavailableHealthSource();

const _metersPerMile = 1609.344;
const _feetPerMeter = 3.28084;

/// Apple Health through the `health` plugin (HealthKit): reads running
/// workouts and heart rate, saves Shows as running workouts with routes.
class AppleHealthSource implements HealthSource {
  final _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.WORKOUT];

  /// Everything the app asks for, in one Apple permission sheet.
  static const _askTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT_ROUTE,
  ];
  static const _askAccess = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ,
    // Read: imported runs bring their route. Write: Go Live routes.
    HealthDataAccess.READ_WRITE,
  ];

  @override
  bool get available => true;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> requestAccess() async {
    await _configure();
    try {
      return await _health.requestAuthorization(
        _askTypes,
        permissions: _askAccess,
      );
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<List<HealthRun>> fetchRuns(DateTime from, DateTime to) async {
    await _configure();
    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: from,
        endTime: to,
      );
    } on HealthPlatformException catch (e) {
      if (e.errorCode == HealthErrorCode.permissionDenied) {
        throw const HealthAccessDenied();
      }
      rethrow;
    }
    final runs = <HealthRun>[];
    for (final p in points) {
      final w = p.value;
      if (w is! WorkoutHealthValue) continue;
      final type = w.workoutActivityType;
      final treadmill = type == HealthWorkoutActivityType.RUNNING_TREADMILL;
      if (type != HealthWorkoutActivityType.RUNNING && !treadmill) continue;
      final meters = w.totalDistance;
      final active = w.duration;
      final elevationM = w.elevationAscended;
      final tempC = w.weatherTemperature;
      runs.add(
        HealthRun(
          uuid: p.uuid,
          start: p.dateFrom.toLocal(),
          end: p.dateTo.toLocal(),
          distanceMiles: meters == null ? 0 : meters / _metersPerMile,
          durationSeconds: active != null && active > 0
              ? active.round()
              : p.dateTo.difference(p.dateFrom).inSeconds,
          indoor: w.indoorWorkout ?? (treadmill ? true : null),
          elevationGainFt: elevationM == null
              ? null
              : elevationM.toDouble() * _feetPerMeter,
          tempF: tempC == null ? null : tempC.toDouble() * 9 / 5 + 32,
          sourceName: p.sourceName.isEmpty ? null : p.sourceName,
        ),
      );
    }
    if (runs.every((r) => r.indoor == true)) return runs;
    // Routes end with their run, so look a little past [to].
    final routes = await _routes(from, to.add(const Duration(hours: 12)));
    if (routes.isEmpty) return runs;
    return [
      for (final r in runs)
        if (r.indoor != true)
          switch (matchRoute(r.start.toUtc(), r.end.toUtc(), [
            for (final x in routes)
              (start: x.start.toUtc(), end: x.end.toUtc(), fixes: x.fixes),
          ])) {
            final fixes? => r.withRoute(fixes),
            null => r,
          }
        else
          r,
    ];
  }

  /// Health's routes between [from] and [to]: start, end and fixes.
  /// Routes from other apps aren't tied to their workout by id, so they are
  /// matched to runs by time. Empty if routes can't be read.
  Future<List<({DateTime start, DateTime end, List<GpsPoint> fixes})>> _routes(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT_ROUTE],
        startTime: from,
        endTime: to,
      );
      return [
        for (final p in points)
          if (p.value case WorkoutRouteHealthValue(:final locations)
              when locations.length >= 2)
            (
              start: p.dateFrom,
              end: p.dateTo,
              fixes: [
                for (final l in locations)
                  GpsPoint(
                    lat: l.latitude,
                    lng: l.longitude,
                    time: l.timestamp.toUtc(),
                    altitudeM: l.altitude,
                    accuracyM: l.horizontalAccuracy,
                  ),
              ]..sort((a, b) => a.time.compareTo(b.time)),
            ),
      ];
    } on HealthPlatformException catch (e) {
      debugPrint('Apple Health routes: $e');
      return const [];
    } on PlatformException catch (e) {
      debugPrint('Apple Health routes: $e');
      return const [];
    }
  }

  @override
  Future<String?> saveRun(HealthRunToSave run) async {
    await _configure();
    try {
      final uuid = await _health.writeWorkoutDataUUID(
        activityType: run.indoor
            ? HealthWorkoutActivityType.RUNNING_TREADMILL
            : HealthWorkoutActivityType.RUNNING,
        start: run.start,
        end: run.end,
        totalDistance: (run.distanceMiles * _metersPerMile).round(),
        metadata: WorkoutMetadata(indoorWorkout: run.indoor),
        recordingMethod: run.route.isEmpty
            ? RecordingMethod.manual
            : RecordingMethod.automatic,
      );
      if (uuid == null || uuid.isEmpty || uuid == 'null') return null;
      if (run.route.length >= 2) await _saveRoute(uuid, run.route);
      return uuid;
    } on PlatformException catch (e) {
      debugPrint('Apple Health save: $e');
      return null;
    }
  }

  Future<void> _saveRoute(String workoutUuid, List<GpsPoint> route) async {
    String? builder;
    try {
      builder = await _health.startWorkoutRoute();
      // HealthKit takes routes in batches.
      for (var i = 0; i < route.length; i += 500) {
        final batch = route.skip(i).take(500);
        await _health.insertWorkoutRouteData(
          builderId: builder,
          locations: [
            for (final p in batch)
              WorkoutRouteLocation(
                latitude: p.lat,
                longitude: p.lng,
                timestamp: p.time,
                altitude: p.altitudeM,
                horizontalAccuracy: p.accuracyM,
              ),
          ],
        );
      }
      await _health.finishWorkoutRoute(
        builderId: builder,
        workoutUuid: workoutUuid,
      );
    } on PlatformException catch (e) {
      // The workout is saved either way; only the map is missing.
      debugPrint('Apple Health route: $e');
      if (builder != null) {
        try {
          await _health.discardWorkoutRoute(builder);
        } on PlatformException {
          // Nothing more to do.
        }
      }
    }
  }

  @override
  Future<HeartRateSummary?> heartRate(DateTime from, DateTime to) async {
    await _configure();
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: from,
        endTime: to,
      );
      return summarizeHeartRate([
        for (final p in points)
          if (p.value case NumericHealthValue(:final numericValue))
            numericValue,
      ]);
    } on HealthPlatformException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
