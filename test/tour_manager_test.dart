import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/logic/tour_manager.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/models/track.dart';
import 'package:setlist_tracker/models/venue_details.dart';

const _paces = TourPaces(
  predictedMarathonSeconds: 4 * 3600,
  marathon: 549,
  easySlow: 690,
  easyFast: 630,
  tempo: 510,
  interval: 470,
  source: 'goalTime',
);

PlannedShow _p(
  String id,
  DateTime date,
  WorkoutType type, {
  double miles = 5,
  Venue venue = Venue.live,
  List<Track> tracks = const [],
}) => PlannedShow(
  id: id,
  date: date,
  workoutType: type,
  distanceMiles: miles,
  venue: venue,
  title: type.label,
  targetPaceSecondsPerMile: type == WorkoutType.tempo ? 510 : 660,
  plannedDurationSeconds: (miles * 660).round(),
  tracks: tracks,
);

Show _log(
  String id,
  DateTime date, {
  WorkoutType type = WorkoutType.easy,
  int effort = 5,
  double miles = 5,
  int? seconds,
  String? planned,
}) => Show(
  id: id,
  date: date,
  venue: Venue.live,
  workoutType: type,
  distanceMiles: miles,
  durationSeconds: seconds ?? (miles * 660).round(),
  effort: effort,
  feel: Feel.fine,
  live: const LiveDetails(),
  plannedShowId: planned,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// Week 1: Mon 16 – Sun 22 Nov 2026. Week 2: 23 – 29 Nov.
Tour _tour({List<PlannedShow>? week1, List<PlannedShow>? week2}) => Tour(
  id: 't',
  name: 'Test Tour',
  setup: TourSetup(
    raceDate: DateTime(2027, 3, 14),
    goal: TourGoal.finish,
    currentWeeklyMiles: 20,
    longestRecentRunMiles: 8,
    daysPerWeek: 4,
    headlinerWeekday: DateTime.sunday,
    venuePreference: VenuePreference.live,
  ),
  paces: _paces,
  weeks: [
    TourWeek(
      number: 1,
      startDate: DateTime(2026, 11, 16),
      phase: TourPhase.rehearsals,
      isRestStop: false,
      shows:
          week1 ??
          [
            _p('tue', DateTime(2026, 11, 17), WorkoutType.easy),
            _p('wed', DateTime(2026, 11, 18), WorkoutType.tempo, miles: 6),
            _p('fri', DateTime(2026, 11, 20), WorkoutType.easy),
            _p('sun', DateTime(2026, 11, 22), WorkoutType.long, miles: 10),
          ],
    ),
    TourWeek(
      number: 2,
      startDate: DateTime(2026, 11, 23),
      phase: TourPhase.rehearsals,
      isRestStop: false,
      shows:
          week2 ??
          [
            _p('tue2', DateTime(2026, 11, 24), WorkoutType.easy, miles: 6),
            _p('wed2', DateTime(2026, 11, 25), WorkoutType.tempo, miles: 6),
            _p('sun2', DateTime(2026, 11, 29), WorkoutType.long, miles: 12),
          ],
    ),
  ],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('missed Show', () {
    test('an easy run moves to the next open day, not the day before the '
        'Headliner', () {
      final tour = _tour();
      // Thursday 19 Nov. Tue easy missed; Wed tempo done.
      final now = DateTime(2026, 11, 19, 8);
      final s = missedShowSuggestion(
        tour,
        done: {'wed': _log('w', DateTime(2026, 11, 18))},
        now: now,
      )!;
      expect(s.applyLabel, 'Move to Thu');
      final after = s.apply(now);
      final moved = after.showById('tue')!;
      expect(moved.date, DateTime(2026, 11, 19));
      expect(moved.rescheduledFrom, DateTime(2026, 11, 17));
      expect(after.adjustments.single.kind, AdjustmentKind.rescheduled);
      // Week stays in date order.
      final dates = after.weeks.first.shows.map((p) => p.date).toList();
      expect(dates, [...dates]..sort());
    });

    test('a missed workout never lands next to another hard day', () {
      final tour = _tour();
      // Thursday. Tempo (Wed) missed. Thu is open but Sat is next to the
      // Sunday Headliner, so it goes on Thu.
      final now = DateTime(2026, 11, 19, 8);
      final s = missedShowSuggestion(
        tour,
        done: {'tue': _log('t', DateTime(2026, 11, 17))},
        now: now,
      )!;
      expect(s.apply(now).showById('wed')!.date, DateTime(2026, 11, 19));
    });

    test('a missed Headliner with no open day swaps with an easy run', () {
      // Headliner on Sat; easy runs Sun and every other day busy.
      final tour = _tour(
        week1: [
          _p('mon', DateTime(2026, 11, 16), WorkoutType.easy),
          _p('tue', DateTime(2026, 11, 17), WorkoutType.easy),
          _p('wed', DateTime(2026, 11, 18), WorkoutType.easy),
          _p('thu', DateTime(2026, 11, 19), WorkoutType.easy),
          _p('fri', DateTime(2026, 11, 20), WorkoutType.easy),
          _p('sat', DateTime(2026, 11, 21), WorkoutType.long, miles: 12),
          _p('sun', DateTime(2026, 11, 22), WorkoutType.easy),
        ],
      );
      final now = DateTime(2026, 11, 22, 7);
      final done = {
        for (final id in ['mon', 'tue', 'wed', 'thu', 'fri'])
          id: _log(id, DateTime(2026, 11, 16)),
      };
      final s = missedShowSuggestion(tour, done: done, now: now)!;
      expect(s.applyLabel, 'Swap with Sun');
      final after = s.apply(now);
      expect(after.showById('sat')!.date, DateTime(2026, 11, 22));
      expect(after.showById('sun')!.skipped, isTrue);
      expect(after.weeks.first.plannedMiles, 5 * 5 + 12);
    });

    test('no room means skip, and it never spills into next week', () {
      final tour = _tour(
        week1: [
          _p('sat', DateTime(2026, 11, 21), WorkoutType.easy),
          _p('sun', DateTime(2026, 11, 22), WorkoutType.long, miles: 10),
        ],
      );
      final now = DateTime(2026, 11, 22, 7);
      final s = missedShowSuggestion(tour, done: const {}, now: now)!;
      expect(s.applyLabel, 'Skip it');
      final after = s.apply(now);
      expect(after.showById('sat')!.skipped, isTrue);
      expect(after.weeks[1].shows.length, 3);
    });

    test('Not now keeps the card away', () {
      final now = DateTime(2026, 11, 19, 8);
      var tour = _tour();
      final done = {'wed': _log('w', DateTime(2026, 11, 18))};
      final s = tourSuggestions(tour, shows: const [], done: done, now: now);
      expect(s.single.kind, SuggestionKind.missedShow);
      tour = dismissSuggestion(tour, s.single.key);
      expect(
        tourSuggestions(tour, shows: const [], done: done, now: now),
        isEmpty,
      );
    });
  });

  group('lighter week', () {
    test('three hard-feeling easy runs suggest a Rest Stop next week', () {
      final now = DateTime(2026, 11, 20, 8);
      final shows = [
        _log('a', DateTime(2026, 11, 16), effort: 8),
        _log('b', DateTime(2026, 11, 17), effort: 9),
        _log('c', DateTime(2026, 11, 19), effort: 8),
      ];
      final s = lighterWeekSuggestion(_tour(), shows: shows, now: now)!;
      final after = s.apply(now);
      final w2 = after.weeks[1];
      expect(w2.isRestStop, isTrue);
      expect(w2.shows.any((p) => p.workoutType == WorkoutType.tempo), isFalse);
      expect(w2.plannedMiles, lessThan(_tour().weeks[1].plannedMiles * 0.8));
      expect(after.adjustments.single.kind, AdjustmentKind.lighterWeek);
    });

    test('one easy run at a normal effort keeps the plan', () {
      final now = DateTime(2026, 11, 20, 8);
      final shows = [
        _log('a', DateTime(2026, 11, 16), effort: 8),
        _log('b', DateTime(2026, 11, 17), effort: 5),
        _log('c', DateTime(2026, 11, 19), effort: 9),
      ];
      expect(lighterWeekSuggestion(_tour(), shows: shows, now: now), isNull);
    });
  });

  group('faster paces', () {
    test('three comfortable fast easy runs offer a capped update', () {
      final now = DateTime(2026, 11, 22, 6);
      // Planned easy target 660 s/mi; ran 630, 625, 600 (30–60 s faster).
      final done = {
        'tue': _log('a', DateTime(2026, 11, 17), seconds: 5 * 630),
        'wed': _log('x', DateTime(2026, 11, 18)), // tempo: ignored
        'fri': _log('b', DateTime(2026, 11, 20), seconds: 5 * 625),
        'sun': _log(
          'c',
          DateTime(2026, 11, 21),
          type: WorkoutType.long,
          miles: 10,
          seconds: 10 * 600,
        ),
      };
      final s = fasterPacesSuggestion(_tour(), done: done, now: now)!;
      final after = applySuggestion(_tour(), s, now);
      expect(after.paces!.easy, _paces.easy - kMaxPaceShift);
      expect(after.showById('tue2')!.targetPaceSecondsPerMile, 645);
      // Past and logged runs keep their plan.
      expect(after.showById('tue')!.targetPaceSecondsPerMile, 660);
      // The same runs can't offer it again.
      expect(fasterPacesSuggestion(after, done: done, now: now), isNull);
    });

    test('hard efforts or small gaps do not count', () {
      final now = DateTime(2026, 11, 22, 6);
      final done = {
        'tue': _log('a', DateTime(2026, 11, 17), seconds: 5 * 630, effort: 8),
        'fri': _log('b', DateTime(2026, 11, 20), seconds: 5 * 625),
        'sun': _log(
          'c',
          DateTime(2026, 11, 21),
          type: WorkoutType.long,
          miles: 10,
          seconds: 10 * 650,
        ),
      };
      expect(fasterPacesSuggestion(_tour(), done: done, now: now), isNull);
    });

    test('Studio Tracks get faster speeds over the same distance', () {
      final p = _p(
        's',
        DateTime(2026, 11, 24),
        WorkoutType.easy,
        venue: Venue.studio,
        tracks: const [
          Track(
            startSeconds: 0,
            endSeconds: 3300,
            speedMph: 5.5,
            inclinePercent: 1,
          ),
        ],
      );
      final fast = speedUpShow(p, 15);
      expect(fast.tracks.single.speedMph, greaterThan(5.5));
      expect(fast.tracks.single.distanceMiles, closeTo(5.04, 0.05));
      expect(fast.plannedDurationSeconds, lessThan(3300));
    });
  });

  test('new fields survive a JSON round trip and old saves still load', () {
    final now = DateTime(2026, 11, 19, 8);
    final s = missedShowSuggestion(
      _tour(),
      done: {'wed': _log('w', DateTime(2026, 11, 18))},
      now: now,
    )!;
    final after = applySuggestion(_tour(), s, now.toUtc());
    final back = Tour.fromJson(after.toJson());
    expect(back.showById('tue')!.rescheduledFrom, DateTime(2026, 11, 17));
    expect(back.adjustments.single.note, contains('Tue 11/17'));
    expect(back.dismissed, [s.key]);
    final old = after.toJson()
      ..remove('adjustments')
      ..remove('dismissed');
    expect(Tour.fromJson(old).adjustments, isEmpty);
  });

  test('replanShow rebuilds a tempo as an easy Studio Session', () {
    final p = _p(
      'x',
      DateTime(2026, 11, 24),
      WorkoutType.tempo,
      miles: 6,
      venue: Venue.studio,
    );
    final r = replanShow(p, type: WorkoutType.easy, miles: 4.5, paces: _paces);
    expect(r.workoutType, WorkoutType.easy);
    expect(r.distanceMiles, 4.5);
    expect(r.tracks, isNotEmpty);
    expect(r.id, 'x');
  });
}
