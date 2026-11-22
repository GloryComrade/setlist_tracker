/// Turns a Planned Show into a logged Show ("Done as planned").
library;

import '../models/enums.dart';
import '../models/show.dart';
import '../models/tour.dart';
import '../models/track.dart';
import '../models/venue_details.dart';

/// The effort a run done as planned usually feels like.
int plannedEffortFor(WorkoutType t) => switch (t) {
  WorkoutType.recovery => 3,
  WorkoutType.easy => 4,
  WorkoutType.long => 6,
  WorkoutType.tempo => 7,
  WorkoutType.intervals => 8,
  WorkoutType.race => 9,
};

/// Whether "Done as planned" has enough to log: a distance and a time.
bool canLogAsPlanned(PlannedShow p) =>
    p.distanceMiles > 0 && (p.plannedDurationSeconds ?? 0) > 0;

/// When the logged Show happened: now if it's today, else 7 AM that day.
DateTime plannedShowTime(PlannedShow p, DateTime now) {
  final sameDay =
      p.date.year == now.year &&
      p.date.month == now.month &&
      p.date.day == now.day;
  return sameDay ? now : DateTime(p.date.year, p.date.month, p.date.day, 7);
}

/// A Show filled in from the plan. Studio Sessions copy the Track list, so
/// their totals come from the Tracks just like a hand-logged one.
Show showFromPlan(PlannedShow p, {required String id, required DateTime now}) {
  final studio = p.venue == Venue.studio;
  final tracks = studio ? p.tracks : const <Track>[];
  final fromTracks = studio && tracks.isNotEmpty;
  final totalsSeconds = fromTracks ? tracks.last.endSeconds : null;
  final totalsMiles = fromTracks
      ? tracks.fold(0.0, (sum, t) => sum + t.distanceMiles)
      : null;
  return Show(
    id: id,
    date: plannedShowTime(p, now),
    venue: p.venue,
    workoutType: p.workoutType,
    distanceMiles: totalsMiles ?? p.distanceMiles,
    durationSeconds: totalsSeconds ?? p.plannedDurationSeconds ?? 0,
    effort: plannedEffortFor(p.workoutType),
    feel: Feel.good,
    notes: 'Done as planned: ${p.title}.',
    plannedShowId: p.id,
    studio: studio
        ? StudioDetails(tracks: tracks, useTrackTotals: fromTracks)
        : null,
    live: studio ? null : const LiveDetails(),
    createdAt: now,
    updatedAt: now,
  );
}
