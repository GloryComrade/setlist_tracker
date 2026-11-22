import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/tour_stats.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/venue_details.dart';

Show _show(
  String id,
  DateTime date, {
  double miles = 5,
  Venue venue = Venue.live,
  WorkoutType type = WorkoutType.easy,
  DateTime? deletedAt,
}) => Show(
  id: id,
  date: date,
  venue: venue,
  workoutType: type,
  distanceMiles: miles,
  durationSeconds: (miles * 600).round(),
  effort: 5,
  feel: Feel.fine,
  live: venue == Venue.live ? const LiveDetails() : null,
  studio: venue == Venue.studio ? const StudioDetails() : null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  deletedAt: deletedAt,
);

void main() {
  // Sunday 22 Nov 2026; its week starts Monday 16 Nov.
  final now = DateTime(2026, 11, 22, 9);

  test('weekly mileage splits Studio and Live and skips deleted Shows', () {
    final weeks = weeklyMileage(
      [
        _show('a', DateTime(2026, 11, 16, 7), miles: 4, venue: Venue.studio),
        _show('b', DateTime(2026, 11, 21, 7), miles: 10),
        _show('c', DateTime(2026, 11, 10, 7), miles: 6),
        _show('d', DateTime(2026, 11, 18, 7), deletedAt: DateTime.utc(2026)),
      ],
      now: now,
      weeks: 3,
    );
    expect(weeks.length, 3);
    expect(weeks.last.weekStart, DateTime(2026, 11, 16));
    expect(weeks.last.studioMiles, 4);
    expect(weeks.last.liveMiles, 10);
    expect(weeks.last.showCount, 2);
    expect(weeks[1].totalMiles, 6);
    expect(weeks.first.totalMiles, 0);
  });

  test('Headliner progression keeps only long runs, oldest first', () {
    final points = headlinerProgression([
      _show('a', DateTime(2026, 11, 15), miles: 12, type: WorkoutType.long),
      _show('b', DateTime(2026, 11, 8), miles: 10, type: WorkoutType.long),
      _show('c', DateTime(2026, 11, 9), miles: 4),
    ], now: now);
    expect(points.map((p) => p.miles), [10, 12]);
    expect(points.every((p) => !p.planned), isTrue);
  });

  test('venue split shares', () {
    final split = venueSplit([
      _show('a', now, miles: 3, venue: Venue.studio),
      _show('b', now, miles: 9),
    ]);
    expect(split.studioMilesShare, 0.25);
    expect(split.studioShowsShare, 0.5);
    expect(venueSplit(const []).studioMilesShare, 0);
  });

  test('week streak counts weeks with 3+ Shows; this week never breaks it', () {
    final shows = [
      // Week of 26 Oct: 3 Shows.
      for (var d = 26; d <= 28; d++) _show('o$d', DateTime(2026, 10, d)),
      // Week of 2 Nov: only 1. Breaks the streak.
      _show('n2', DateTime(2026, 11, 2)),
      // Weeks of 9 Nov: 3, then 16 Nov (this week): 1 so far.
      for (var d = 9; d <= 11; d++) _show('n$d', DateTime(2026, 11, d)),
      _show('n16', DateTime(2026, 11, 16)),
    ];
    final streak = weekStreak(shows, now: now);
    expect(streak.current, 1);
    expect(streak.longest, 1);
    final withThisWeek = weekStreak([
      ...shows,
      _show('n17', DateTime(2026, 11, 17)),
      _show('n18', DateTime(2026, 11, 18)),
    ], now: now);
    expect(withThisWeek.current, 2);
    expect(withThisWeek.longest, 2);
  });

  test('longest daily streak', () {
    expect(longestDailyStreak(const []), 0);
    expect(
      longestDailyStreak([
        _show('a', DateTime(2026, 11, 1, 7)),
        _show('b', DateTime(2026, 11, 2, 18)),
        _show('b2', DateTime(2026, 11, 2, 7)),
        _show('c', DateTime(2026, 11, 3, 7)),
        _show('d', DateTime(2026, 11, 5, 7)),
      ]),
      3,
    );
  });
}
