/// The Calendar: a month of Shows and Tour dates, worked out from the
/// Setlist and the active Tour. Pure Dart, nothing here is stored.
library;

import '../models/enums.dart';
import '../models/show.dart';
import '../models/tour.dart';
import 'gold_records.dart';
import 'show_math.dart';
import 'spoken.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The day each calendar week starts on. Tour weeks end on Opening Night, so
/// with a Tour the grid follows its weeks (Monday for a Sunday race);
/// without one, weeks start on Monday like the Setlist.
int calendarFirstWeekday(Tour? tour) => tour == null || tour.weeks.isEmpty
    ? DateTime.monday
    : tour.weeks.first.startDate.weekday;

/// The first day of the calendar week [d] falls in.
DateTime calendarWeekStart(DateTime d, int firstWeekday) {
  final back = (d.weekday - firstWeekday + 7) % 7;
  return DateTime(d.year, d.month, d.day - back);
}

/// The first day of [d]'s month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// Every month the Calendar can show, oldest first: from the first Show's
/// month through Opening Night's month (or today's month with no Tour).
/// Today's month is always in range, so "Today" always has a page.
List<DateTime> calendarMonths({
  required Iterable<Show> shows,
  required Tour? tour,
  required DateTime today,
}) {
  var first = monthOf(today);
  for (final s in shows) {
    if (s.isDeleted) continue;
    final m = monthOf(s.date);
    if (m.isBefore(first)) first = m;
  }
  var last = monthOf(today);
  if (tour != null) {
    final race = monthOf(tour.raceDate);
    if (race.isAfter(last)) last = race;
  }
  return [
    for (var m = first; !m.isAfter(last); m = DateTime(m.year, m.month + 1)) m,
  ];
}

/// A run on the Tour Schedule as it stands on the Calendar.
class CalendarPlan {
  const CalendarPlan({required this.plan, this.logged});

  final PlannedShow plan;

  /// The Show logged for it, by the same rule as the Tour tab's checkmarks.
  final Show? logged;

  bool get done => logged != null;

  /// Dropped from the week and never run.
  bool get skipped => plan.skipped && logged == null;
}

/// One square of the grid.
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isPast,
    required this.shows,
    required this.plans,
    required this.goldRecord,
    required this.openingNight,
  });

  final DateTime date;

  /// False for the leading and trailing days of the neighboring months.
  final bool inMonth;
  final bool isToday;

  /// Before today: a planned run not logged by now was missed.
  final bool isPast;

  /// Shows logged this day, earliest first.
  final List<Show> shows;

  /// Tour runs planned for this day, skipped ones included.
  final List<CalendarPlan> plans;

  /// A Gold Record was set by a Show this day.
  final bool goldRecord;
  final bool openingNight;

  double get loggedMiles => shows.fold(0.0, (a, s) => a + s.distanceMiles);

  /// Planned runs still to do (not done, not skipped).
  List<CalendarPlan> get pending =>
      plans.where((p) => !p.done && !p.skipped).toList();

  bool get isEmpty => shows.isEmpty && plans.isEmpty;
}

/// One row of the grid: seven days, and the Tour week it is, if any.
class CalendarWeek {
  const CalendarWeek({required this.days, this.tourWeek});

  final List<CalendarDay> days;
  final TourWeek? tourWeek;

  DateTime get start => days.first.date;

  /// Every Show logged in the seven days, planned or not.
  double get doneMiles => days.fold(0.0, (a, d) => a + d.loggedMiles);

  /// The Tour's planned miles, or null outside the Tour.
  double? get plannedMiles => tourWeek?.plannedMiles;
}

class CalendarMonth {
  const CalendarMonth({required this.month, required this.weeks});

  /// The first of the month.
  final DateTime month;
  final List<CalendarWeek> weeks;
}

/// Days on which a Show set a Gold Record that still stands. Week and month
/// records belong to no single day, so they're left out.
Set<DateTime> goldRecordDays(List<Show> shows) => {
  for (final r in computeGoldRecords(shows).values)
    if (r.show != null) _day(r.show!.date),
};

/// Builds [month]'s grid. [done] maps a Planned Show id to the Show logged
/// for it (`tourProgressProvider`); [goldDays] comes from [goldRecordDays].
CalendarMonth buildCalendarMonth(
  DateTime month, {
  required Iterable<Show> shows,
  required Tour? tour,
  required Map<String, Show> done,
  required DateTime today,
  Set<DateTime> goldDays = const {},
}) {
  final first = monthOf(month);
  final firstWeekday = calendarFirstWeekday(tour);
  final gridStart = calendarWeekStart(first, firstWeekday);
  final nextMonth = DateTime(first.year, first.month + 1);

  final byDay = <DateTime, List<Show>>{};
  for (final s in shows) {
    if (s.isDeleted) continue;
    byDay.putIfAbsent(_day(s.date), () => []).add(s);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }
  final plansByDay = <DateTime, List<CalendarPlan>>{};
  if (tour != null) {
    for (final p in tour.allShows) {
      plansByDay
          .putIfAbsent(_day(p.date), () => [])
          .add(CalendarPlan(plan: p, logged: done[p.id]));
    }
  }
  final todayDay = _day(today);

  final weeks = <CalendarWeek>[];
  for (
    var start = gridStart;
    start.isBefore(nextMonth);
    start = _addDays(start, 7)
  ) {
    final days = [
      for (var i = 0; i < 7; i++)
        () {
          final d = _addDays(start, i);
          return CalendarDay(
            date: d,
            inMonth: d.month == first.month && d.year == first.year,
            isToday: d == todayDay,
            isPast: d.isBefore(todayDay),
            shows: byDay[d] ?? const [],
            plans: plansByDay[d] ?? const [],
            goldRecord: goldDays.contains(d),
            openingNight: tour != null && _sameDay(tour.raceDate, d),
          );
        }(),
    ];
    TourWeek? tourWeek;
    if (tour != null) {
      for (final w in tour.weeks) {
        if (_sameDay(w.startDate, start)) tourWeek = w;
      }
    }
    weeks.add(CalendarWeek(days: days, tourWeek: tourWeek));
  }
  return CalendarMonth(month: first, weeks: weeks);
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The square for [date], built the same way as the month grid.
CalendarDay calendarDayFor(
  DateTime date, {
  required Iterable<Show> shows,
  required Tour? tour,
  required Map<String, Show> done,
  required DateTime today,
  Set<DateTime> goldDays = const {},
}) {
  final d = _day(date);
  final month = buildCalendarMonth(
    d,
    shows: shows,
    tour: tour,
    done: done,
    today: today,
    goldDays: goldDays,
  );
  return month.weeks.expand((w) => w.days).firstWhere((x) => x.date == d);
}

/// "Tuesday, March 3".
String spokenCalendarDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// "March 2027".
String calendarMonthTitle(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';

/// What a screen reader says for a day square, e.g. "Tuesday, March 3:
/// Tempo 6 miles planned, done." Logged Shows that weren't on the plan
/// are read too, so nothing on the square is only visual.
String spokenCalendarDay(CalendarDay day) {
  final parts = <String>[];
  if (day.isToday) parts.add('today');
  if (day.openingNight) parts.add('Opening Night');
  final linked = <String>{};
  for (final p in day.plans) {
    final status = p.done
        ? 'done'
        : p.skipped
        ? 'skipped'
        : day.isPast
        ? 'not logged'
        : p.plan.rescheduledFrom != null
        ? 'moved from ${_weekdays[p.plan.rescheduledFrom!.weekday - 1]}'
        : null;
    parts.add(
      '${p.plan.title} ${spokenMiles(p.plan.distanceMiles)} planned'
      '${status == null ? '' : ', $status'}',
    );
    if (p.logged != null) linked.add(p.logged!.id);
  }
  for (final s in day.shows) {
    if (linked.contains(s.id)) continue;
    parts.add(
      '${s.workoutType.label}, ${s.venue.label}, ${spokenMiles(s.distanceMiles)}',
    );
  }
  if (day.goldRecord) parts.add('Gold Record');
  if (parts.isEmpty) parts.add('nothing booked');
  return '${spokenCalendarDate(day.date)}: ${parts.join('. ')}';
}

/// "12.4" and "18 mi" for a Tour week ("12.4 / 18 mi"), "12.4 mi" outside
/// the Tour. A Tour week with nothing logged yet is just its plan: no "0".
/// Planned miles round to the half mile like the Tour tab: they're a target.
({String? done, String? planned}) weekMilesText(CalendarWeek w) {
  final planned = w.plannedMiles;
  return (
    done: planned != null && w.doneMiles == 0
        ? null
        : formatMiles(w.doneMiles, withUnit: planned == null),
    planned: planned == null ? null : formatMiles((planned * 2).round() / 2),
  );
}

/// Spoken week total: "12.4 miles of 18 miles planned".
String spokenWeekMiles(CalendarWeek w) {
  final planned = w.plannedMiles;
  final done = spokenMiles(w.doneMiles);
  if (planned == null) return done;
  if (w.doneMiles == 0) {
    return '${spokenMiles((planned * 2).round() / 2)} planned';
  }
  return '$done of ${spokenMiles((planned * 2).round() / 2)} planned';
}

/// A short word for a planned run that fits under a day square.
String calendarShortLabel(WorkoutType t) => switch (t) {
  WorkoutType.easy => 'Easy',
  WorkoutType.recovery => 'Recovery',
  WorkoutType.tempo => 'Tempo',
  WorkoutType.intervals => 'Intervals',
  WorkoutType.long => 'Headliner',
  WorkoutType.race => 'Opening Night',
};

/// "84 days to Opening Night", "Opening Night is tomorrow", ... or null once
/// it has been played.
String? openingNightCountdown(Tour tour, DateTime today) {
  final days = DateTime.utc(
    tour.raceDate.year,
    tour.raceDate.month,
    tour.raceDate.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days < 0) return null;
  if (days == 0) return 'Opening Night is today';
  if (days == 1) return '1 day to Opening Night';
  return '$days days to Opening Night';
}
