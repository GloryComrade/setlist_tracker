import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/calendar.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/tour.dart';

Show _show(
  String id,
  DateTime date,
  double miles, {
  Venue venue = Venue.live,
  WorkoutType type = WorkoutType.easy,
  String? plannedShowId,
}) => Show(
  id: id,
  date: date,
  venue: venue,
  workoutType: type,
  distanceMiles: miles,
  durationSeconds: (miles * 560).round(),
  effort: 5,
  feel: Feel.good,
  plannedShowId: plannedShowId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Tour _tour(DateTime race, {DateTime? today}) {
  var n = 0;
  return TourBuilder(newId: () => 'p${n++}')
      .build(
        TourSetup(
          raceDate: race,
          goal: TourGoal.finish,
          currentWeeklyMiles: 20,
          longestRecentRunMiles: 10,
          daysPerWeek: 4,
          headlinerWeekday: DateTime.sunday,
          venuePreference: VenuePreference.mix,
          easyPaceSecondsPerMile: 600,
        ),
        today: today ?? DateTime(2026, 11, 1),
      )
      .tour!;
}

final _today = DateTime(2026, 11, 22);

void main() {
  group('weeks', () {
    test('start on Monday without a Tour', () {
      expect(calendarFirstWeekday(null), DateTime.monday);
      // Sun 22 Nov 2026 belongs to the week of Mon 16 Nov.
      expect(
        calendarWeekStart(DateTime(2026, 11, 22), DateTime.monday),
        DateTime(2026, 11, 16),
      );
    });

    test('follow the Tour, whose weeks end on Opening Night', () {
      // A Sunday race: Tour weeks run Monday to Sunday.
      final sunday = _tour(DateTime(2027, 3, 21));
      expect(calendarFirstWeekday(sunday), DateTime.monday);
      // A Saturday race: they run Sunday to Saturday.
      final saturday = _tour(DateTime(2027, 3, 20));
      expect(calendarFirstWeekday(saturday), DateTime.sunday);
      final month = buildCalendarMonth(
        DateTime(2027, 3),
        shows: const [],
        tour: saturday,
        done: const {},
        today: _today,
      );
      for (final w in month.weeks) {
        expect(w.start.weekday, DateTime.sunday);
      }
      // Every week inside the Tour lines up with its Tour week.
      expect(month.weeks.where((w) => w.tourWeek != null), isNotEmpty);
      for (final w in month.weeks.where((w) => w.tourWeek != null)) {
        expect(w.tourWeek!.startDate, w.start);
      }
    });
  });

  group('months', () {
    test('run from the first Show to Opening Night', () {
      final shows = [_show('a', DateTime(2026, 9, 3, 7), 4)];
      final months = calendarMonths(
        shows: shows,
        tour: _tour(DateTime(2027, 3, 21)),
        today: _today,
      );
      expect(months.first, DateTime(2026, 9));
      expect(months.last, DateTime(2027, 3));
      expect(months, hasLength(7));
    });

    test('end today with no Tour, and always include today', () {
      expect(calendarMonths(shows: const [], tour: null, today: _today), [
        DateTime(2026, 11),
      ]);
      final shows = [_show('a', DateTime(2026, 10, 3, 7), 4)];
      expect(calendarMonths(shows: shows, tour: null, today: _today), [
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
    });

    test('November 2026 is six Monday rows with its neighbors dimmed', () {
      final m = buildCalendarMonth(
        DateTime(2026, 11, 14),
        shows: const [],
        tour: null,
        done: const {},
        today: _today,
      );
      expect(m.month, DateTime(2026, 11));
      expect(m.weeks, hasLength(6));
      expect(m.weeks.first.start, DateTime(2026, 10, 26));
      expect(m.weeks.last.days.last.date, DateTime(2026, 12, 6));
      expect(m.weeks.first.days.first.inMonth, isFalse);
      expect(m.weeks.first.days.last.inMonth, isTrue); // Sun 1 Nov
      final today = m.weeks.expand((w) => w.days).where((d) => d.isToday);
      expect(today.single.date, _today);
    });
  });

  group('days', () {
    final tour = _tour(DateTime(2027, 3, 21));
    final plans = tour.allShows.toList();
    // Tue 3 Nov: Easy 3.5 mi. The first run after today is Tue 24 Nov.
    final ranPlan = plans.firstWhere((p) => p.date.isBefore(_today));
    final later = plans.firstWhere((p) => p.date.isAfter(_today));
    final ran = _show(
      'r',
      DateTime(ranPlan.date.year, ranPlan.date.month, ranPlan.date.day, 7),
      6.2,
      venue: ranPlan.venue,
      type: ranPlan.workoutType,
      plannedShowId: ranPlan.id,
    );
    final extra = _show(
      'x',
      DateTime(ranPlan.date.year, ranPlan.date.month, ranPlan.date.day, 18),
      2,
    );

    CalendarDay dayOf(DateTime d, {Tour? t, Set<DateTime> gold = const {}}) =>
        calendarDayFor(
          d,
          shows: [ran, extra],
          tour: t ?? tour,
          done: {ranPlan.id: ran},
          today: _today,
          goldDays: gold,
        );

    test('a planned run is checked once it is logged', () {
      final d = dayOf(ranPlan.date);
      expect(d.shows.map((s) => s.id), ['r', 'x']);
      expect(d.loggedMiles, closeTo(8.2, 1e-9));
      final p = d.plans.singleWhere((p) => p.plan.id == ranPlan.id);
      expect(p.done, isTrue);
      expect(d.pending, isEmpty);
    });

    test('a skipped run stays on the day but is not pending', () {
      final skippedTour = tour.copyWith(
        weeks: [
          for (final w in tour.weeks)
            w.copyWith(
              shows: [
                for (final s in w.shows)
                  s.id == later.id ? s.copyWith(skipped: true) : s,
              ],
            ),
        ],
      );
      final d = dayOf(later.date, t: skippedTour);
      final p = d.plans.singleWhere((p) => p.plan.id == later.id);
      expect(p.skipped, isTrue);
      expect(d.pending, isEmpty);
      expect(spokenCalendarDay(d), contains('planned, skipped'));
    });

    test('Opening Night and Gold Record days are marked', () {
      final race = dayOf(tour.raceDate);
      expect(race.openingNight, isTrue);
      expect(race.plans.single.plan.isRace, isTrue);
      final gold = dayOf(ranPlan.date, gold: goldRecordDays([ran, extra]));
      expect(gold.goldRecord, isTrue);
    });

    test('goldRecordDays only counts days a Show set a record', () {
      final days = goldRecordDays([
        _show('a', DateTime(2026, 11, 2, 7), 3),
        _show('b', DateTime(2026, 11, 9, 7), 10, type: WorkoutType.long),
      ]);
      expect(days, contains(DateTime(2026, 11, 9)));
    });

    test('the spoken label says the day in words', () {
      final d = dayOf(ranPlan.date);
      final label = spokenCalendarDay(d);
      expect(label, startsWith('${spokenCalendarDate(ranPlan.date)}: '));
      expect(label, contains('${ranPlan.title} '));
      expect(label, contains('planned, done'));
      // The unplanned evening Show is read too; the planned one isn't read
      // twice.
      expect(label, contains('Easy, Live Show, 2 miles'));
      expect(label, isNot(contains('6.2 miles')));
      expect(label, isNot(contains(' mi ')));
    });

    test('an empty day says so', () {
      final d = calendarDayFor(
        DateTime(2026, 3, 3),
        shows: const [],
        tour: null,
        done: const {},
        today: _today,
      );
      expect(spokenCalendarDay(d), 'Tuesday, March 3: nothing booked');
    });

    test('a Tour week shows done against planned miles', () {
      final week = buildCalendarMonth(
        ranPlan.date,
        shows: [ran, extra],
        tour: tour,
        done: {ranPlan.id: ran},
        today: _today,
      ).weeks.firstWhere((w) => w.days.any((d) => d.date == ranPlan.date));
      expect(week.tourWeek, isNotNull);
      expect(week.doneMiles, closeTo(8.2, 1e-9));
      final text = weekMilesText(week);
      expect(text.done, '8.2');
      expect(text.planned, endsWith(' mi'));
      final next = buildCalendarMonth(
        DateTime(2027, 2),
        shows: [ran, extra],
        tour: tour,
        done: {ranPlan.id: ran},
        today: _today,
      ).weeks.firstWhere((w) => w.tourWeek != null);
      expect(weekMilesText(next).done, isNull);
      expect(spokenWeekMiles(next), endsWith(' miles planned'));
      expect(spokenWeekMiles(week), startsWith('8.2 miles of '));
    });
  });

  test('the countdown names Opening Night', () {
    final tour = _tour(DateTime(2027, 3, 21));
    expect(openingNightCountdown(tour, _today), '119 days to Opening Night');
    expect(
      openingNightCountdown(tour, DateTime(2027, 3, 20)),
      '1 day to Opening Night',
    );
    expect(
      openingNightCountdown(tour, DateTime(2027, 3, 21)),
      'Opening Night is today',
    );
    expect(openingNightCountdown(tour, DateTime(2027, 3, 22)), isNull);
  });
}
