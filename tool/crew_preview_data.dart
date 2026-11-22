// Made-up Crew mates for tool/crew_preview.dart and tool/store_preview.dart.
// Not part of the app.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/models/track.dart';
import 'package:setlist_tracker/models/venue_details.dart';

Tour? _tour(DateTime today, DateTime race, RaceDistance distance) =>
    TourBuilder()
        .build(
          TourSetup(
            raceDate: race,
            raceDistance: distance,
            goal: TourGoal.finish,
            currentWeeklyMiles: 24,
            longestRecentRunMiles: 10,
            daysPerWeek: 4,
            headlinerWeekday: DateTime.sunday,
            venuePreference: VenuePreference.mix,
            easyPaceSecondsPerMile: 600,
          ),
          today: today,
        )
        .tour;

Show _show(
  String id,
  DateTime date, {
  required Venue venue,
  required WorkoutType workout,
  required double miles,
  required int seconds,
  int effort = 5,
  Feel feel = Feel.good,
  String? notes,
  SongOfTheShow? song,
  StudioDetails? studio,
  LiveDetails? live,
  bool crewPrivate = false,
}) => Show(
  id: id,
  date: date,
  venue: venue,
  workoutType: workout,
  distanceMiles: miles,
  durationSeconds: seconds,
  effort: effort,
  feel: feel,
  notes: notes,
  song: song,
  studio: studio,
  live: live,
  crewPrivate: crewPrivate,
  createdAt: date.toUtc(),
  updatedAt: date.toUtc(),
);

/// Ryan's Crew: Maya (a half marathon Tour you can book featuring her, and
/// her Tour invite onto it),
/// Jordan (no Tour) and Priya (racing [coHeadlineRace] when given, so the
/// Tour tab shows "Featuring Priya").
MemoryCrewService previewCrew(DateTime now, {DateTime? coHeadlineRace}) {
  final today = DateTime(now.year, now.month, now.day);
  final crew = MemoryCrewService(me: 'me')
    ..profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan')
    ..addMate(
      // A badge.
      const CrewProfile(
        userId: 'maya',
        stageName: 'Maya',
        color: 2,
        avatarBadge: 'vinyl',
      ),
      since: DateTime(2026, 11, 2),
    )
    ..addMate(
      const CrewProfile(userId: 'jordan', stageName: 'Jordan', color: 1),
      since: DateTime(2026, 11, 9),
    )
    ..addMate(
      const CrewProfile(userId: 'priya', stageName: 'Priya', color: 3),
      since: DateTime(2026, 11, 15),
    );

  // A photo (a made-up placeholder, not a real person).
  crew.addPhoto('jordan', placeholderPhoto());
  // Ryan picked the headphones badge.
  crew.profiles['me'] = crew.profiles['me']!.copyWith(
    avatarBadge: 'headphones',
  );

  final maya = _tour(
    today,
    today.add(const Duration(days: 7 * 12 + 6)),
    RaceDistance.half,
  );
  if (maya != null) {
    crew.addTour('maya', maya);
    // Maya asks Ryan onto her Tour: a "Tour invites" card on The Crew tab.
    crew.addTourInvite(
      'maya',
      maya,
      at: now.subtract(const Duration(hours: 5)),
    );
  }
  final priya = _tour(
    today,
    coHeadlineRace ?? today.add(const Duration(days: 7 * 18 + 6)),
    RaceDistance.marathon,
  );
  if (priya != null) crew.addTour('priya', priya);

  // An invite from someone not in the Crew yet: open #/crew/join/P4TR8WHN.
  crew.profiles['sam'] = const CrewProfile(
    userId: 'sam',
    stageName: 'Sam',
    color: 1,
  );
  crew.invites['P4TR8WHN'] = 'sam';

  final twoHours = now.subtract(const Duration(hours: 2));
  crew.addShow(
    'maya',
    _show(
      'm1',
      twoHours,
      venue: Venue.studio,
      workout: WorkoutType.tempo,
      miles: 6.2,
      seconds: 2950,
      effort: 8,
      feel: Feel.encore,
      song: const SongOfTheShow(
        title: 'Midnight City',
        artist: 'M83',
        note: 'last two Tracks',
      ),
      studio: const StudioDetails(
        gymName: 'Eastside Y',
        tracks: [
          Track(
            startSeconds: 0,
            endSeconds: 600,
            speedMph: 6,
            inclinePercent: 1,
          ),
          Track(
            startSeconds: 600,
            endSeconds: 2400,
            speedMph: 7.8,
            inclinePercent: 1,
          ),
          Track(
            startSeconds: 2400,
            endSeconds: 2950,
            speedMph: 6.2,
            inclinePercent: 2,
          ),
        ],
      ),
    ),
    gearName: 'Saucony Endorphin Speed 4',
    at: twoHours,
    encoreCount: 3,
  );
  crew.addShow(
    'maya',
    _show(
      'm2',
      now.subtract(const Duration(days: 3)),
      venue: Venue.live,
      workout: WorkoutType.easy,
      miles: 4,
      seconds: 2520,
      effort: 3,
      live: const LiveDetails(routeName: 'Lakefront loop'),
    ),
    at: now.subtract(const Duration(days: 3)),
  );
  // Kept off the Crew: never shows up.
  crew.addShow(
    'maya',
    _show(
      'm3',
      now.subtract(const Duration(days: 1)),
      venue: Venue.live,
      workout: WorkoutType.easy,
      miles: 2,
      seconds: 1500,
      crewPrivate: true,
    ),
  );
  final jordan = crew.addShow(
    'jordan',
    _show(
      'j1',
      now.subtract(const Duration(days: 1)),
      venue: Venue.live,
      workout: WorkoutType.long,
      miles: 16,
      seconds: 8400,
      effort: 7,
      feel: Feel.good,
      song: const SongOfTheShow(
        title: 'Dog Days Are Over',
        artist: 'Florence + The Machine',
        note: 'mile 13 second wind',
      ),
      notes: 'Rolling hills along the river. Felt strong after the turnaround.',
      live: const LiveDetails(
        routeName: 'River Trail',
        surface: Surface.trail,
        elevationGainFt: 640,
        weather: Weather(tempF: 48, windMph: 6, conditions: Conditions.cloudy),
      ),
    ),
    gearName: 'Hoka Speedgoat 6',
    at: now.subtract(const Duration(days: 1, hours: 3)),
    encoreCount: 4,
  );
  crew.encores[jordan]!.add('me');
  crew.addShow(
    'priya',
    _show(
      'p1',
      now.subtract(const Duration(days: 2)),
      venue: Venue.live,
      workout: WorkoutType.intervals,
      miles: 5.5,
      seconds: 2900,
      effort: 9,
      feel: Feel.offKey,
      notes: '6 × 800 m. The last two hurt.',
      live: const LiveDetails(
        routeName: 'High school track',
        surface: Surface.track,
      ),
    ),
    at: now.subtract(const Duration(days: 2)),
    encoreCount: 1,
  );
  return crew;
}

/// A stand-in profile photo: a soft violet-to-teal ground with a pale head
/// and shoulders, drawn in code. 256 px JPEG, like the app makes.
Uint8List placeholderPhoto() {
  const size = 256;
  final image = img.Image(width: size, height: size);
  for (final p in image) {
    final t = (p.x + p.y) / (2 * size);
    var r = 109 + (14 - 109) * t;
    var g = 40 + (116 - 40) * t;
    var b = 217 + (144 - 217) * t;
    // Head and shoulders.
    final head = math.sqrt(math.pow(p.x - 128, 2) + math.pow(p.y - 104, 2));
    final shoulders = math.sqrt(
      math.pow((p.x - 128) / 1.5, 2) + math.pow(p.y - 262, 2),
    );
    if (head < 46 || shoulders < 86) {
      r = 236;
      g = 231;
      b = 218;
    }
    p
      ..r = r
      ..g = g
      ..b = b;
  }
  return img.encodeJpg(image, quality: 85);
}
