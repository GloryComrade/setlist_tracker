import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/logic/tour_logging.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/tour.dart';

void main() {
  final tour = TourBuilder()
      .build(
        TourSetup(
          raceDate: DateTime(2027, 4, 18),
          goal: TourGoal.targetTime,
          goalTimeSeconds: 4 * 3600,
          currentWeeklyMiles: 25,
          longestRecentRunMiles: 10,
          daysPerWeek: 5,
          headlinerWeekday: DateTime.sunday,
          venuePreference: VenuePreference.mix,
        ),
        today: DateTime(2026, 11, 22),
      )
      .tour!;

  test('Done as planned: a Studio Session copies its Tracks', () {
    final plan = tour.allShows.firstWhere((s) => s.venue == Venue.studio);
    final now = DateTime(2027, 1, 1, 18, 30);
    final show = showFromPlan(plan, id: 's1', now: now);
    expect(show.plannedShowId, plan.id);
    expect(show.venue, Venue.studio);
    expect(show.studio!.tracks, plan.tracks);
    expect(show.studio!.useTrackTotals, isTrue);
    expect(show.durationSeconds, plan.tracks.last.endSeconds);
    expect(show.distanceMiles, closeTo(plan.distanceMiles, 0.15));
    expect(show.effort, plannedEffortFor(plan.workoutType));
    // Not today, so it's logged at 7 AM on the planned day.
    expect(
      show.date,
      DateTime(plan.date.year, plan.date.month, plan.date.day, 7),
    );
  });

  test('Done as planned: a Live Show uses planned miles and time', () {
    final plan = tour.allShows.firstWhere(
      (s) => s.venue == Venue.live && s.workoutType == WorkoutType.long,
    );
    final now = DateTime(plan.date.year, plan.date.month, plan.date.day, 9, 15);
    final show = showFromPlan(plan, id: 's2', now: now);
    expect(show.distanceMiles, plan.distanceMiles);
    expect(show.durationSeconds, plan.plannedDurationSeconds);
    expect(show.date, now);
    expect(show.live, isNotNull);
  });

  test('a logged Show keeps its plan link through save and load', () {
    final plan = tour.allShows.first;
    final show = showFromPlan(plan, id: 's3', now: DateTime(2027));
    expect(show.toJson()['plannedShowId'], plan.id);
  });
}
