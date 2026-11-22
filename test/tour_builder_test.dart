import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/tour.dart';

final _today = DateTime(2026, 11, 22); // a Sunday

TourSetup _setup({
  DateTime? race,
  TourGoal goal = TourGoal.targetTime,
  int? goalTime = 4 * 3600,
  double weekly = 25,
  double longest = 10,
  int days = 5,
  int headlinerDay = DateTime.sunday,
  VenuePreference venue = VenuePreference.mix,
  RaceResult? recent = const RaceResult(distanceMiles: 13.1, timeSeconds: 6600),
  double? easyPace,
}) => TourSetup(
  raceDate: race ?? DateTime(2027, 4, 18),
  goal: goal,
  goalTimeSeconds: goalTime,
  currentWeeklyMiles: weekly,
  longestRecentRunMiles: longest,
  daysPerWeek: days,
  headlinerWeekday: headlinerDay,
  venuePreference: venue,
  recentRace: recent,
  easyPaceSecondsPerMile: easyPace,
);

var _n = 0;
Tour _tour(TourSetup s) =>
    TourBuilder(newId: () => 'id${_n++}').build(s, today: _today).tour!;

void main() {
  group('paces', () {
    test("Riegel's formula predicts a marathon from a half", () {
      // 1:50:00 half → about 3:49:21.
      final t = predictMarathonSeconds(
        const RaceResult(distanceMiles: 13.1, timeSeconds: 6600),
      );
      expect(t, closeTo(13761, 5));
    });

    test('training paces are ordered fastest to slowest', () {
      final p = pacesFromMarathon(4 * 3600, 'goalTime');
      expect(p.marathon, closeTo(549.6, 0.1)); // 9:10 /mi
      expect(p.interval, lessThan(p.tempo));
      expect(p.tempo, lessThan(p.marathon));
      expect(p.easyFast, p.marathon + 60);
      expect(p.easySlow, p.marathon + 90);
    });

    test('a recent race wins over the goal time', () {
      expect(pacesFor(_setup())!.source, 'recentRace');
      expect(pacesFor(_setup(recent: null))!.source, 'goalTime');
    });

    test('finish goal with no race uses the easy pace, or runs by feel', () {
      final s = _setup(goal: TourGoal.finish, goalTime: null, recent: null);
      expect(pacesFor(s), isNull);
      final withEasy = _setup(
        goal: TourGoal.finish,
        goalTime: null,
        recent: null,
        easyPace: 660,
      );
      expect(pacesFor(withEasy)!.marathon, 585);
    });

    test('treadmill speed rounds to a tenth of a mph', () {
      expect(studioMphFor(600), 6.0); // 10:00 /mi
      expect(studioMphFor(480), 7.5); // 8:00 /mi
      expect(studioMphFor(549.6), 6.6);
    });
  });

  group('dates', () {
    test('help-me-pick suggests a Sunday at least 18 weeks out', () {
      final d = suggestedRaceDate(_today);
      expect(d.weekday, DateTime.sunday);
      expect(daysBetween(_today, d), greaterThanOrEqualTo(18 * 7));
      expect(daysBetween(_today, d), lessThan(19 * 7));
    });

    test('Tour names follow the race season', () {
      expect(tourNameFor(DateTime(2027, 4, 18)), 'Spring 2027 Tour');
      expect(tourNameFor(DateTime(2027, 10, 10)), 'Fall 2027 Tour');
      expect(tourNameFor(DateTime(2027, 12, 5)), 'Winter 2028 Tour');
    });
  });

  group('length and warnings', () {
    test('more than 20 weeks out: 20 weeks, ending on Opening Night', () {
      final b = TourBuilder().build(_setup(), today: _today);
      final tour = b.tour!;
      expect(tour.weeks, hasLength(20));
      expect(tour.weeks.last.endDate, DateTime(2027, 4, 18));
      expect(tour.allShows.last.isRace, isTrue);
      expect(tour.allShows.last.date, DateTime(2027, 4, 18));
      expect(b.checks.map((c) => c.title), contains('The Tour starts later'));
    });

    test('under 6 weeks: no Tour, suggest a later race', () {
      final b = TourBuilder().build(
        _setup(race: DateTime(2026, 12, 27)),
        today: _today,
      );
      expect(b.canBook, isFalse);
      expect(b.suggestedDate, isNotNull);
      expect(b.checks.single.serious, isTrue);
    });

    test('under 12 weeks: serious warning with a later date', () {
      final b = TourBuilder().build(
        _setup(race: DateTime(2027, 2, 7)),
        today: _today,
      );
      expect(b.canBook, isTrue);
      expect(b.tour!.weeks.length, lessThan(12));
      final c = b.checks.firstWhere((c) => c.title == 'Race may be too soon');
      expect(c.serious, isTrue);
      expect(c.message, contains('finish-only'));
    });

    test('12 to 15 weeks: short Tour note', () {
      final b = TourBuilder().build(
        _setup(race: DateTime(2027, 3, 7)),
        today: _today,
      );
      expect(b.checks.map((c) => c.title), contains('Short Tour'));
    });

    test('goal much faster than the race predicts gets a note', () {
      final b = TourBuilder().build(
        _setup(goalTime: 3 * 3600 + 30 * 60),
        today: _today,
      );
      expect(b.checks.map((c) => c.title), contains('Ambitious goal'));
    });
  });

  group('plan rules', () {
    final setups = {
      '20 wk, 5 days, mix': _setup(),
      '18 wk, 3 days, studio, low base': _setup(
        race: DateTime(2027, 3, 28),
        goal: TourGoal.finish,
        goalTime: null,
        recent: null,
        easyPace: 660,
        weekly: 12,
        longest: 5,
        days: 3,
        headlinerDay: DateTime.saturday,
        venue: VenuePreference.studio,
      ),
      '16 wk, 6 days, BQ': _setup(
        race: DateTime(2027, 3, 14),
        goal: TourGoal.bq,
        goalTime: 3 * 3600 + 25 * 60,
        recent: const RaceResult(distanceMiles: 6.2137, timeSeconds: 2700),
        weekly: 35,
        longest: 13,
        days: 6,
        venue: VenuePreference.live,
      ),
    };

    setups.forEach((name, setup) {
      group(name, () {
        late Tour tour;
        setUp(() => tour = _tour(setup));

        test('phases run in order and end with a 2–3 week Soundcheck', () {
          final phases = tour.weeks.map((w) => w.phase).toList();
          for (var i = 1; i < phases.length; i++) {
            expect(phases[i].index, greaterThanOrEqualTo(phases[i - 1].index));
          }
          expect(phases.first, TourPhase.rehearsals);
          expect(phases, contains(TourPhase.onTheRoad));
          expect(phases, contains(TourPhase.headlineLeg));
          final sc = phases.where((p) => p == TourPhase.soundcheck).length;
          expect(sc, inInclusiveRange(2, 3));
        });

        test('weekly miles rise about 10% at most', () {
          double? last;
          for (final w in tour.weeks) {
            if (w.isRestStop || w.phase == TourPhase.soundcheck) continue;
            if (last != null) {
              // Half-mile rounding on each run allows a little slack.
              expect(
                w.plannedMiles,
                lessThanOrEqualTo(last * 1.10 + 1.0),
                reason: 'week ${w.number}',
              );
            }
            last = w.plannedMiles;
          }
        });

        test(
          'a Rest Stop every 3rd–4th week, lighter than the week before',
          () {
            final build = tour.weeks
                .where((w) => w.phase != TourPhase.soundcheck)
                .toList();
            var gap = 0;
            for (var i = 0; i < build.length; i++) {
              final w = build[i];
              if (w.isRestStop) {
                expect(w.plannedMiles, lessThan(build[i - 1].plannedMiles));
                gap = 0;
              } else {
                gap++;
                // The peak block may run one extra week before the taper.
                expect(gap, lessThanOrEqualTo(5), reason: 'week ${w.number}');
              }
            }
            expect(build.where((w) => w.isRestStop), isNotEmpty);
          },
        );

        test('Headliner peaks at 18–20 mi, 3 weeks before race week', () {
          final longs = [
            for (final w in tour.weeks) w.headliner?.distanceMiles ?? 0.0,
          ];
          final peak = longs.reduce((a, b) => a > b ? a : b);
          expect(peak, inInclusiveRange(18, 20));
          expect(longs.indexOf(peak), tour.weeks.length - 4);
        });

        test(
          'no quality in Rehearsals or Rest Stops; one a week otherwise',
          () {
            for (final w in tour.weeks) {
              final q = w.shows.where(
                (s) =>
                    s.workoutType == WorkoutType.tempo ||
                    s.workoutType == WorkoutType.intervals,
              );
              if (w.phase == TourPhase.rehearsals || w.isRestStop) {
                expect(q, isEmpty, reason: 'week ${w.number}');
              } else {
                expect(q.length, lessThanOrEqualTo(1));
              }
            }
          },
        );

        test('runs fit the days available, Headliner on its day', () {
          for (final w in tour.weeks) {
            expect(w.shows.length, lessThanOrEqualTo(setup.daysPerWeek + 1));
            expect(w.shows.map((s) => s.date).toSet().length, w.shows.length);
            final h = w.headliner;
            if (h != null) expect(h.date.weekday, setup.headlinerWeekday);
            for (final s in w.shows) {
              expect(w.contains(s.date), isTrue);
            }
          }
        });

        test('Studio Sessions carry a matching Track list', () {
          for (final s in tour.allShows) {
            if (s.venue != Venue.studio) continue;
            if (tour.paces == null) continue;
            expect(s.tracks, isNotEmpty);
            expect(s.tracks.first.startSeconds, 0);
            for (var i = 1; i < s.tracks.length; i++) {
              expect(s.tracks[i].startSeconds, s.tracks[i - 1].endSeconds);
            }
            final miles = s.tracks.fold(0.0, (a, t) => a + t.distanceMiles);
            expect(miles, closeTo(s.distanceMiles, 0.15));
            expect(s.plannedDurationSeconds, s.tracks.last.endSeconds);
          }
        });
      });
    });

    test('mix: workouts in the Studio, Headliners and race Live', () {
      final tour = _tour(_setup());
      for (final s in tour.allShows) {
        if (s.workoutType == WorkoutType.tempo ||
            s.workoutType == WorkoutType.intervals) {
          expect(s.venue, Venue.studio);
        }
        if (s.workoutType == WorkoutType.long || s.isRace) {
          expect(s.venue, Venue.live);
        }
      }
    });
  });

  test('a Tour survives a save and load', () {
    final tour = _tour(_setup());
    final back = Tour.fromJson(tour.toJson());
    expect(back.toJson(), tour.toJson());
    expect(back.raceDate, DateTime(2027, 4, 18));
    expect(back.weeks.first.shows.first.date.hour, 0);
  });
}
