// A preview of The Crew with made-up friends, for screenshots and trying the
// screens without a backend. Not part of the app.
//
//   flutter run -d chrome -t tool/crew_preview.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/local/open_database.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/sync/remote_store.dart';
import 'package:setlist_tracker/models/crew.dart';
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
