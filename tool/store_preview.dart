// The App Store screenshot build: The Crew with made-up friends, plus six
// weeks of training, Gear and a booked Tour. Not part of the app.
//
//   flutter run -d chrome -t tool/store_preview.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/local/open_database.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/sync/remote_store.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/gear.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/models/track.dart';
import 'package:setlist_tracker/models/venue_details.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';

const _me = PassHolder(id: 'me', name: 'Ryan Cheng', email: 'ryan@example.com');

class _PreviewAuth implements AuthService {
  @override
  bool get available => true;
  @override
  PassHolder? get current => _me;
  @override
  Stream<PassHolder?> changes() => const Stream.empty();
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {}
}

class _NoRemote implements RemoteStore {
  @override
  Future<void> upsert(String table, List<RemoteRow> rows) async {}
  @override
  Future<List<RemoteRow>> pullSince(
    String table,
    DateTime? since, {
    int offset = 0,
    int limit = 500,
  }) async => const [];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  final now = DateTime.now();
  final crew = MemoryCrewService(me: 'me')
    ..profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan')
    ..addMate(
      CrewProfile(
        userId: 'maya',
        stageName: 'Maya',
        color: 2,
        showOpeningNight: true,
        openingNight: now.add(const Duration(days: 34)),
        tourName: 'Spring Marathon Tour',
      ),
      since: DateTime(2026, 11, 2),
    )
    ..addMate(
      const CrewProfile(userId: 'jordan', stageName: 'Jordan', color: 1),
      since: DateTime(2026, 11, 9),
    )
    ..addMate(
      CrewProfile(
        userId: 'priya',
        stageName: 'Priya',
        color: 3,
        showOpeningNight: true,
        openingNight: now.add(const Duration(days: 61)),
      ),
      since: DateTime(2026, 11, 15),
    );

  // An invite from someone not in the Crew yet: open #/crew/join/P4TR8WHN.
  crew.profiles['sam'] = const CrewProfile(
    userId: 'sam',
    stageName: 'Sam',
    color: 1,
  );
  crew.invites['P4TR8WHN'] = 'sam';

  crew.addPost(
    'maya',
    'm1',
    SharedShow(
      date: now.subtract(const Duration(hours: 2)),
      venue: Venue.studio,
      workoutType: WorkoutType.tempo,
      distanceMiles: 6.2,
      durationSeconds: 2950,
      song: const SongOfTheShow(
        title: 'Midnight City',
        artist: 'M83',
        note: 'last two Tracks',
      ),
      goldRecords: const ['Fastest 10K'],
    ),
    at: now.subtract(const Duration(hours: 2)),
    encoreCount: 3,
  );
  final jordan = crew.addPost(
    'jordan',
    'j1',
    SharedShow(
      date: now.subtract(const Duration(days: 1)),
      venue: Venue.live,
      workoutType: WorkoutType.long,
      distanceMiles: 16,
      durationSeconds: 8400,
      song: const SongOfTheShow(
        title: 'Dog Days Are Over',
        artist: 'Florence + The Machine',
        note: 'mile 13 second wind',
      ),
      goldRecords: const ['Longest Headliner'],
      notes: 'Rolling hills along the river. Felt strong after the turnaround.',
    ),
    at: now.subtract(const Duration(days: 1, hours: 3)),
    encoreCount: 4,
  );
  crew.encores[jordan]!.add('me');

  // One of Ryan's own Shows, already shared.
  final shows = SembastShowRepository(db);
  final mine = Show(
    id: '6f3c1f0e-0000-4000-8000-000000000001',
    date: DateTime(
      now.year,
      now.month,
      now.day,
      6,
      40,
    ).subtract(const Duration(days: 2)),
    venue: Venue.live,
    workoutType: WorkoutType.easy,
    distanceMiles: 5,
    durationSeconds: 2820,
    effort: 4,
    feel: Feel.good,
    song: const SongOfTheShow(title: 'Run', artist: 'Snow Patrol'),
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
  await shows.save(mine);
  final saved = (await shows.getById(mine.id))!;
  crew.addPost(
    'me',
    saved.id,
    SharedShow.fromShow(saved, allShows: [saved]),
    at: now.subtract(const Duration(days: 2)),
    encoreCount: 2,
  );

  await _seedTraining(db, now);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(_PreviewAuth()),
        remoteStoreProvider.overrideWithValue(_NoRemote()),
        crewServiceProvider.overrideWithValue(crew),
      ],
      child: const SetlistApp(),
    ),
  );
}

Future<void> _seedTraining(Database db, DateTime now) async {
  final stamp = now.toUtc();
  final shoes = Gear(
    id: 'gear-0001',
    name: 'Endorphin Speed 4',
    brand: 'Saucony',
    startingMiles: 42,
    createdAt: stamp,
    updatedAt: stamp,
  );
  await SembastGearRepository(db).save(shoes);

  final today = DateTime(now.year, now.month, now.day);
  final build = TourBuilder().build(
    TourSetup(
      raceDate: today.add(const Duration(days: 7 * 16 + 4)),
      goal: TourGoal.targetTime,
      goalTimeSeconds: 3 * 3600 + 45 * 60,
      currentWeeklyMiles: 28,
      longestRecentRunMiles: 12,
      daysPerWeek: 5,
      headlinerWeekday: DateTime.sunday,
      venuePreference: VenuePreference.mix,
      recentRace: const RaceResult(distanceMiles: 13.1, timeSeconds: 6420),
    ),
    today: today,
  );
  if (build.tour != null) await SembastTourRepository(db).save(build.tour!);

  const songs = [
    SongOfTheShow(title: 'Midnight City', artist: 'M83', note: 'last mile'),
    SongOfTheShow(title: 'Dog Days Are Over', artist: 'Florence + The Machine'),
    SongOfTheShow(title: 'Lose Yourself', artist: 'Eminem', note: 'the hill'),
    SongOfTheShow(title: 'Mr. Brightside', artist: 'The Killers'),
    SongOfTheShow(title: 'Titanium', artist: 'David Guetta, Sia'),
    SongOfTheShow(title: 'Born to Run', artist: 'Bruce Springsteen'),
    SongOfTheShow(title: 'Levitating', artist: 'Dua Lipa'),
  ];
  // The last six weeks, ending today: Tue easy, Wed studio tempo, Thu easy, Sat recovery,
  // Sun Headliner growing from 10 to 15 miles.
  final repo = SembastShowRepository(db);
  var n = 0;
  for (var week = 5; week >= 0; week--) {
    final monday = today.subtract(Duration(days: today.weekday - 1 + 7 * week));
    final plan = <(int, WorkoutType, double, int)>[
      (1, WorkoutType.easy, 5, 545),
      (2, WorkoutType.tempo, 6 + (5 - week) * 0.2, 490),
      (3, WorkoutType.easy, 5, 540),
      (5, WorkoutType.recovery, 3, 600),
      (6, WorkoutType.long, 10.0 + (5 - week), 560),
    ];
    for (final (offset, type, miles, pace) in plan) {
      final day = monday.add(Duration(days: offset));
      final studio = type == WorkoutType.tempo;
      final seconds = (miles * pace).round();
      n++;
      await repo.save(
        Show(
          id: 'demo-show-${n.toString().padLeft(4, '0')}',
          date: DateTime(day.year, day.month, day.day, 6, 30),
          venue: studio ? Venue.studio : Venue.live,
          workoutType: type,
          distanceMiles: double.parse(miles.toStringAsFixed(1)),
          durationSeconds: seconds,
          effort: switch (type) {
            WorkoutType.tempo => 7,
            WorkoutType.long => 6,
            WorkoutType.recovery => 2,
            _ => 4,
          },
          feel: n % 4 == 0 ? Feel.encore : (n % 3 == 0 ? Feel.fine : Feel.good),
          gearId: shoes.id,
          song: songs[n % songs.length],
          studio: studio
              ? StudioDetails(
                  gymName: 'Downtown Y',
                  useTrackTotals: false,
                  tracks: [
                    const Track(
                      startSeconds: 0,
                      endSeconds: 600,
                      speedMph: 6.0,
                      inclinePercent: 1,
                    ),
                    Track(
                      startSeconds: 600,
                      endSeconds: seconds - 300,
                      speedMph: 7.6,
                      inclinePercent: 1,
                    ),
                    Track(
                      startSeconds: seconds - 300,
                      endSeconds: seconds,
                      speedMph: 5.8,
                      inclinePercent: 0,
                    ),
                  ],
                )
              : null,
          live: studio
              ? null
              : LiveDetails(
                  routeName: type == WorkoutType.long
                      ? 'River Loop'
                      : 'Neighborhood 5',
                  elevationGainFt: type == WorkoutType.long ? 410 : 120,
                  weather: const Weather(tempF: 48, windMph: 6),
                ),
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    }
  }
}
