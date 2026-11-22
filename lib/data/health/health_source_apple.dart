import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:health/health.dart';

import 'health_source.dart';

/// Native builds. Only iPhone has Apple Health.
HealthSource createHealthSource() =>
    Platform.isIOS ? AppleHealthSource() : const UnavailableHealthSource();

const _metersPerMile = 1609.344;
const _feetPerMeter = 3.28084;

/// Reads running workouts through the `health` plugin (HealthKit). Asks for
/// read access to workouts only, and never writes.
class AppleHealthSource implements HealthSource {
  final _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.WORKOUT];
  static const _readOnly = [HealthDataAccess.READ];

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
      return await _health.requestAuthorization(_types, permissions: _readOnly);
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
    return runs;
  }
}
