// A preview of The Crew with made-up friends, for screenshots and trying the
// screens without a backend. Not part of the app.
//
//   flutter run -d chrome -t tool/crew_preview.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/local/open_database.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/sync/remote_store.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';

import 'crew_preview_data.dart';

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
  final crew = previewCrew(now);

  // One of Ryan's own Shows: the Crew sees it too.
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
  crew.addShow(
    'me',
    saved,
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
