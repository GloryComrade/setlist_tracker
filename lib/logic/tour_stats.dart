/// The numbers behind The Charts tab. Computed from Shows (and the active
/// Tour, when there is one); nothing here is stored.
library;

import '../models/enums.dart';
import '../models/show.dart';
import '../models/tour.dart';
import 'show_math.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

List<Show> _live(Iterable<Show> shows) =>
    shows.where((s) => !s.isDeleted).toList();

/// Miles for one Monday-to-Sunday week.
class WeekMiles {
  const WeekMiles({
    required this.weekStart,
    required this.studioMiles,
    required this.liveMiles,
    required this.showCount,
    this.plannedMiles,
  });

  final DateTime weekStart;
  final double studioMiles;
  final double liveMiles;
  final int showCount;

  /// The Tour's planned miles for this week, or null with no Tour that week.
  final double? plannedMiles;

  double get totalMiles => studioMiles + liveMiles;
}

/// The last [weeks] calendar weeks, oldest first, ending with this week.
List<WeekMiles> weeklyMileage(
  Iterable<Show> shows, {
  required DateTime now,
  Tour? tour,
  int weeks = 12,
}) {
  final thisWeek = weekStart(now);
  final starts = [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i),
  ];
  final studio = {for (final s in starts) s: 0.0};
  final live = {for (final s in starts) s: 0.0};
  final count = {for (final s in starts) s: 0};
  for (final s in _live(shows)) {
    final w = weekStart(s.date);
    if (!count.containsKey(w)) continue;
    count[w] = count[w]! + 1;
    if (s.venue == Venue.studio) {
      studio[w] = studio[w]! + s.distanceMiles;
    } else {
      live[w] = live[w]! + s.distanceMiles;
    }
  }
  final planned = <DateTime, double>{};
  if (tour != null) {
    for (final p in tour.allShows) {
      if (p.skipped) continue;
      final w = weekStart(p.date);
      planned[w] = (planned[w] ?? 0) + p.distanceMiles;
    }
  }
  return [
    for (final w in starts)
      WeekMiles(
        weekStart: w,
        studioMiles: studio[w]!,
        liveMiles: live[w]!,
        showCount: count[w]!,
        plannedMiles: planned[w],
      ),
  ];
}

/// One dot on the Headliner progression chart.
class HeadlinerPoint {
  const HeadlinerPoint({
    required this.date,
    required this.miles,
    required this.planned,
  });

  final DateTime date;
  final double miles;

  /// True for a Tour Headliner that hasn't been run yet.
  final bool planned;
}

/// Every logged Headliner, oldest first, then the Tour's upcoming ones.
///
/// Logged ones are limited to [since] onward (the Tour's start when there is
/// a Tour) so the chart tells the story of this training cycle.
List<HeadlinerPoint> headlinerProgression(
  Iterable<Show> shows, {
  required DateTime now,
  Tour? tour,
  DateTime? since,
}) {
  final from = since ?? tour?.startDate;
  final today = _day(now);
  final logged = [
    for (final s in _live(shows))
      if (s.workoutType == WorkoutType.long &&
          (from == null || !_day(s.date).isBefore(from)))
        HeadlinerPoint(date: _day(s.date), miles: s.distanceMiles, planned: false),
  ]..sort((a, b) => a.date.compareTo(b.date));
  final upcoming = <HeadlinerPoint>[
    if (tour != null)
      for (final p in tour.allShows)
        if (p.workoutType == WorkoutType.long &&
            !p.skipped &&
            !p.date.isBefore(today))
          HeadlinerPoint(date: p.date, miles: p.distanceMiles, planned: true),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return [...logged, ...upcoming];
}

/// Studio Sessions vs. Live Shows, by miles and by count.
class VenueSplit {
  const VenueSplit({
    required this.studioMiles,
    required this.liveMiles,
    required this.studioShows,
    required this.liveShows,
  });

  final double studioMiles;
  final double liveMiles;
  final int studioShows;
  final int liveShows;

  double get totalMiles => studioMiles + liveMiles;
  int get totalShows => studioShows + liveShows;

  /// 0 to 1. Zero when nothing is logged.
  double get studioMilesShare =>
      totalMiles == 0 ? 0 : studioMiles / totalMiles;
  double get studioShowsShare =>
      totalShows == 0 ? 0 : studioShows / totalShows;
}

VenueSplit venueSplit(Iterable<Show> shows, {DateTime? since}) {
  var sm = 0.0, lm = 0.0;
  var sc = 0, lc = 0;
  for (final s in _live(shows)) {
    if (since != null && _day(s.date).isBefore(since)) continue;
    if (s.venue == Venue.studio) {
      sm += s.distanceMiles;
      sc++;
    } else {
      lm += s.distanceMiles;
      lc++;
    }
  }
  return VenueSplit(
    studioMiles: sm,
    liveMiles: lm,
    studioShows: sc,
    liveShows: lc,
  );
}

/// Weeks in a row that "count": at least [minShows] Shows, or every planned
/// Tour run that week done.
class WeekStreak {
  const WeekStreak({required this.current, required this.longest});

  /// Includes this week once it counts; an unfinished week never breaks it.
  final int current;
  final int longest;
}

WeekStreak weekStreak(
  Iterable<Show> shows, {
  required DateTime now,
  Tour? tour,
  Set<String> doneIds = const {},
  int minShows = 3,
}) {
  final counts = <DateTime, int>{};
  for (final s in _live(shows)) {
    final w = weekStart(s.date);
    counts[w] = (counts[w] ?? 0) + 1;
  }
  final plannedIds = <DateTime, List<String>>{};
  if (tour != null) {
    for (final p in tour.allShows) {
      if (p.skipped) continue;
      plannedIds.putIfAbsent(weekStart(p.date), () => []).add(p.id);
    }
  }
  bool counts_(DateTime w) {
    if ((counts[w] ?? 0) >= minShows) return true;
    final ids = plannedIds[w];
    return ids != null && ids.isNotEmpty && ids.every(doneIds.contains);
  }

  final thisWeek = weekStart(now);
  if (counts.isEmpty) return const WeekStreak(current: 0, longest: 0);
  final first = counts.keys.reduce((a, b) => a.isBefore(b) ? a : b);

  var longest = 0, run = 0;
  for (var w = first;
      !w.isAfter(thisWeek);
      w = DateTime(w.year, w.month, w.day + 7)) {
    if (counts_(w)) {
      run++;
      if (run > longest) longest = run;
    } else if (w != thisWeek) {
      run = 0;
    }
  }
  return WeekStreak(current: run, longest: longest);
}

/// Most calendar days in a row with at least one Show.
int longestDailyStreak(Iterable<Show> shows) {
  final days = _live(shows).map((s) => _day(s.date)).toSet().toList()..sort();
  var longest = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    final next = prev == null
        ? null
        : DateTime(prev.year, prev.month, prev.day + 1);
    run = (next != null && d == next) ? run + 1 : 1;
    if (run > longest) longest = run;
    prev = d;
  }
  return longest;
}

/// Days until Opening Night: 0 on race day, negative after it.
int daysToOpeningNight(Tour tour, DateTime now) =>
    // Built from dates, not Durations, so daylight saving can't shave a day.
    DateTime.utc(tour.raceDate.year, tour.raceDate.month, tour.raceDate.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
