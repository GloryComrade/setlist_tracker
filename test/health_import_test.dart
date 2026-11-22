import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/data/health/health_source.dart';
import 'package:setlist_tracker/logic/health_import.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';

HealthRun run(
  String uuid,
  DateTime start, {
  double miles = 5,
  int seconds = 2700,
  bool? indoor,
  double? elevation,
  double? tempF,
}) => HealthRun(
  uuid: uuid,
  start: start,
  end: start.add(Duration(seconds: seconds)),
  distanceMiles: miles,
  durationSeconds: seconds,
  indoor: indoor,
  elevationGainFt: elevation,
  tempF: tempF,
  sourceName: 'Apple Watch',
);

Show handLogged(String id, DateTime date, double miles, {String? healthId}) =>
    Show(
      id: id,
      date: date,
      venue: Venue.live,
      workoutType: WorkoutType.easy,
      distanceMiles: miles,
      durationSeconds: 2700,
      effort: 5,
      feel: Feel.good,
      healthWorkoutId: healthId,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  final now = DateTime(2026, 11, 22, 9);

  group('showFromHealthRun', () {
    test('an outdoor run becomes a Live Show with elevation and temp', () {
      final s = showFromHealthRun(
        run(
          'A',
          DateTime(2026, 11, 21, 6, 15),
          miles: 6.2137,
          seconds: 3300,
          indoor: false,
          elevation: 212.4,
          tempF: 41.7,
        ),
        now: now,
        id: 's1',
      );
      expect(s.id, 's1');
      expect(s.date, DateTime(2026, 11, 21, 6, 15));
      expect(s.venue, Venue.live);
      expect(s.workoutType, WorkoutType.easy);
      expect(s.distanceMiles, 6.21);
      expect(s.durationSeconds, 3300);
      expect(s.notes, isNull);
      expect(s.live!.elevationGainFt, 212);
      expect(s.live!.weather!.tempF, 42);
      expect(s.studio, isNull);
      expect(s.healthWorkoutId, 'A');
      expect(s.createdAt, now);
    });

    test('no indoor flag means a Live Show; no extras stay empty', () {
      final s = showFromHealthRun(run('B', now), now: now);
      expect(s.venue, Venue.live);
      expect(s.live!.elevationGainFt, isNull);
      expect(s.live!.weather, isNull);
    });

    test('an indoor run becomes a Studio Session', () {
      final s = showFromHealthRun(
        run('C', now, indoor: true, elevation: 50),
        now: now,
      );
      expect(s.venue, Venue.studio);
      expect(s.studio, isNotNull);
      expect(s.studio!.tracks, isEmpty);
      expect(s.live, isNull);
    });

    test('the Show round-trips through JSON with its Health link', () {
      final s = showFromHealthRun(run('D', now), now: now);
      expect(Show.fromJson(s.toJson()).healthWorkoutId, 'D');
    });
  });

  group('newHealthRuns', () {
    test('skips runs already imported', () {
      final fresh = newHealthRuns(
        [run('A', DateTime(2026, 11, 20)), run('B', DateTime(2026, 11, 21))],
        [handLogged('s', DateTime(2026, 11, 2), 3, healthId: 'A')],
      );
      expect(fresh.map((r) => r.uuid), ['B']);
    });

    test('skips a run logged by hand the same day at about that distance', () {
      final day = DateTime(2026, 11, 21, 6);
      final fresh = newHealthRuns(
        [
          run('close', day, miles: 5.2),
          run('farther', day.add(const Duration(hours: 10)), miles: 3),
          run('next day', day.add(const Duration(days: 1)), miles: 5),
        ],
        [handLogged('s', DateTime(2026, 11, 21, 7), 5)],
      );
      expect(fresh.map((r) => r.uuid), ['next day', 'farther']);
    });

    test('the 5% window is two-sided', () {
      final d = DateTime(2026, 11, 21);
      expect(
        looksLikeSameRun(run('a', d, miles: 10), handLogged('s', d, 10.5)),
        isTrue,
      );
      expect(
        looksLikeSameRun(run('a', d, miles: 10), handLogged('s', d, 9.4)),
        isFalse,
      );
      // Short runs get a small floor so rounding doesn't matter.
      expect(
        looksLikeSameRun(run('a', d, miles: 1), handLogged('s', d, 1.04)),
        isTrue,
      );
    });

    test('an imported Show never blocks a different run by distance', () {
      final d = DateTime(2026, 11, 21, 6);
      final fresh = newHealthRuns(
        [run('second', d.add(const Duration(hours: 9)))],
        [handLogged('s', d, 5, healthId: 'first')],
      );
      expect(fresh.map((r) => r.uuid), ['second']);
    });

    test('drops runs with no distance and repeats, newest first', () {
      final fresh = newHealthRuns([
        run('old', DateTime(2026, 11, 1)),
        run('zero', DateTime(2026, 11, 5), miles: 0),
        run('new', DateTime(2026, 11, 20)),
        run('new', DateTime(2026, 11, 20)),
      ], const []);
      expect(fresh.map((r) => r.uuid), ['new', 'old']);
    });
  });

  test('healthImportStart looks back 30 days, then from the last import', () {
    expect(
      healthImportStart(null, now),
      now.subtract(const Duration(days: 30)),
    );
    final last = DateTime(2026, 11, 15, 20);
    expect(healthImportStart(last, now), DateTime(2026, 11, 14, 20));
  });

  test('the default source is unavailable off iPhone', () {
    expect(createHealthSource().available, isFalse);
  });
}
