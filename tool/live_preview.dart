// Go Live preview: the On Stage recorder on a made-up loop (sped up 30x), a
// booked Live Show with its route, splits and heart rate, and the Apple
// Health settings. Fake GPS and a fake Apple Health, so it runs in a browser.
// Not part of the app.
//
//   flutter run -d chrome -t tool/live_preview.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/gps/live_recorder.dart';
import 'package:setlist_tracker/data/gps/location_source.dart';
import 'package:setlist_tracker/data/health/health_source.dart';
import 'package:setlist_tracker/data/local/open_database.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/logic/gps_math.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/gps_track.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/models/venue_details.dart';

const _speedUp = 30;
final _realStart = DateTime.now().toUtc();
DateTime _clock() => _realStart.add(
  DateTime.now().toUtc().difference(_realStart) * _speedUp,
);

/// A made-up park loop (about 2.3 miles), as (lat, lng) corners.
const _loop = [
  (39.6990, -104.9700),
  (39.7000, -104.9655),
  (39.6985, -104.9600),
  (39.6950, -104.9590),
  (39.6905, -104.9612),
  (39.6880, -104.9650),
  (39.6890, -104.9705),
  (39.6925, -104.9730),
  (39.6962, -104.9722),
];

/// Where you are [meters] into laps of [_loop].
(double, double) _along(double meters) {
  final legs = <double>[];
  for (var i = 0; i < _loop.length; i++) {
    final a = _loop[i], b = _loop[(i + 1) % _loop.length];
    legs.add(haversineMeters(a.$1, a.$2, b.$1, b.$2));
  }
  final lap = legs.fold<double>(0, (s, l) => s + l);
  var d = meters % lap;
  for (var i = 0; i < legs.length; i++) {
    if (d <= legs[i]) {
      final a = _loop[i], b = _loop[(i + 1) % _loop.length];
      final f = d / legs[i];
      return (a.$1 + (b.$1 - a.$1) * f, a.$2 + (b.$2 - a.$2) * f);
    }
    d -= legs[i];
  }
  return _loop.first;
}

/// Pace wobbles a little, like a real run (about 8:40 to 9:20 /mi).
double _speedAt(double seconds) => 2.95 + 0.12 * math.sin(seconds / 90);

GpsPoint _fix(DateTime t, double meters, double seconds) {
  final (lat, lng) = _along(meters);
  return GpsPoint(
    lat: lat,
    lng: lng,
    time: t,
    accuracyM: 4,
    altitudeM: 1610 + 6 * math.sin(meters / 400),
  );
}

class _FakeGps implements LocationSource {
  @override
  bool get available => true;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.granted;

  @override
  Stream<GpsPoint> fixes() {
    DateTime? first;
    var meters = 0.0;
    DateTime? last;
    return Stream.periodic(const Duration(milliseconds: 100), (_) {
      final t = _clock();
      first ??= t;
      final s = t.difference(first!).inMilliseconds / 1000;
      if (last != null) {
        meters += _speedAt(s) * t.difference(last!).inMilliseconds / 1000;
      }
      last = t;
      return _fix(t, meters, s);
    });
  }

  @override
  Future<void> openSettings() async {}
}

class _FakeHealth implements HealthSource {
  @override
  bool get available => true;
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<HealthRun>> fetchRuns(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<String?> saveRun(HealthRunToSave run) async => 'preview';
  @override
  Future<HeartRateSummary?> heartRate(DateTime from, DateTime to) async =>
      const HeartRateSummary(average: 148, max: 167, samples: 120);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();

  // A booked Live Show from yesterday morning: 4.6 miles, two laps.
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, 6, 30)
      .subtract(const Duration(days: 1))
      .toUtc();
  final rec = LiveRecording.start(start);
  var meters = 0.0;
  for (var s = 0; s <= 2500; s++) {
    if (s > 0) meters += _speedAt(s.toDouble());
    rec.addFix(_fix(start.add(Duration(seconds: s)), meters, s.toDouble()));
  }
  rec.end(start.add(const Duration(seconds: 2500)));
  final stamp = DateTime.now().toUtc();
  await SembastShowRepository(db).save(
    Show(
      id: 'live-preview-0001',
      date: start.toLocal(),
      venue: Venue.live,
      workoutType: WorkoutType.easy,
      distanceMiles: double.parse(rec.distanceMiles.toStringAsFixed(2)),
      durationSeconds: 2500,
      effort: 4,
      feel: Feel.good,
      song: const SongOfTheShow(title: 'Run', artist: 'Snow Patrol'),
      live: LiveDetails(
        routeName: 'Park loop',
        elevationGainFt: rec.elevationGainFt.roundToDouble(),
        gps: rec.toTrack(),
      ),
      healthWorkoutId: 'preview',
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        locationSourceProvider.overrideWithValue(_FakeGps()),
        recordingStoreProvider.overrideWithValue(MemoryRecordingStore()),
        recorderClockProvider.overrideWithValue(_clock),
        healthSourceProvider.overrideWithValue(_FakeHealth()),
      ],
      child: const SetlistApp(),
    ),
  );
}
