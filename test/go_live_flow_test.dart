import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/gps/live_recorder.dart';
import 'package:setlist_tracker/data/gps/location_source.dart';
import 'package:setlist_tracker/data/health/health_source.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/gps_track.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/setlist/show_card.dart';

class FakeLocation implements LocationSource {
  FakeLocation({this.access = LocationAccess.granted});
  final LocationAccess access;
  final controller = StreamController<GpsPoint>.broadcast();

  @override
  bool get available => true;

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Stream<GpsPoint> fixes() => controller.stream;

  @override
  Future<void> openSettings() async {}
}

class FakeHealth implements HealthSource {
  final saved = <HealthRunToSave>[];

  @override
  bool get available => true;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<List<HealthRun>> fetchRuns(DateTime from, DateTime to) async =>
      const [];

  @override
  Future<String?> saveRun(HealthRunToSave run) async {
    saved.add(run);
    return 'HK-${saved.length}';
  }

  @override
  Future<HeartRateSummary?> heartRate(DateTime from, DateTime to) async =>
      const HeartRateSummary(average: 151, max: 172, samples: 40);
}

const _degPerM = 1 / 111195.0;

void main() {
  testWidgets('go Live, run a mile, book it, and it goes to Apple Health', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final db = await tester.runAsync(
      () => newDatabaseFactoryMemory().openDatabase('live.db'),
    );
    final location = FakeLocation();
    final health = FakeHealth();
    final start = DateTime.utc(2026, 11, 22, 14);
    var now = start;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db!),
          locationSourceProvider.overrideWithValue(location),
          recordingStoreProvider.overrideWithValue(MemoryRecordingStore()),
          healthSourceProvider.overrideWithValue(health),
          recorderClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go Live'));
    await tester.pumpAndSettle();
    expect(find.text('ON STAGE'), findsOneWidget);
    expect(find.text('DOORS OPEN'), findsOneWidget);

    await tester.tap(find.text('GO LIVE'));
    await tester.pump();
    await tester.pump();
    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    // 1.2 miles due north at 3 m/s, one fix a second, climbing 1 m every
    // 5 s.
    const seconds = 644;
    for (var i = 0; i <= seconds; i++) {
      now = start.add(Duration(seconds: i));
      location.controller.add(
        GpsPoint(
          lat: 40 + i * 3 * _degPerM,
          lng: -105,
          time: now,
          accuracyM: 4,
          altitudeM: 1600 + i / 5,
        ),
      );
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('10:44'), findsOneWidget);
    expect(find.text('1.20'), findsOneWidget);
    // Pace now, average pace and the mile 1 split.
    expect(find.text('8:56 /mi'), findsNWidgets(3));
    expect(find.text('6.7'), findsOneWidget); // mph
    expect(find.text('MILE 1'), findsOneWidget);
    expect(find.textContaining('GPS locked'), findsOneWidget);

    // Hold End Show: no question, straight to booking.
    await tester.longPress(find.text('End Show'));
    await tester.pumpAndSettle();
    expect(find.text('BOOK A SHOW'), findsOneWidget);
    // Distance, time and elevation gain from the GPS.
    expect(find.text('1.2'), findsOneWidget);
    expect(find.text('10:44'), findsOneWidget);
    expect(find.text('413'), findsOneWidget);
    expect(find.text('THE ROUTE'), findsNothing);

    final book = find.text('BOOK IT');
    await tester.ensureVisible(book);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(book);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    // The Health save runs after the form closes.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    final shows = (await tester.runAsync(
      () => SembastShowRepository(db).watchAll().first,
    ))!;
    expect(shows, hasLength(1));
    final show = shows.single;
    expect(show.distanceMiles, 1.2);
    expect(show.durationSeconds, seconds);
    expect(show.live!.gps!.splits, hasLength(1));
    expect(show.live!.elevationGainFt, 413);
    // Saved to Health with the route, and Health's id kept so an import
    // won't bring it back.
    expect(health.saved, hasLength(1));
    expect(health.saved.single.route, hasLength(seconds + 1));
    expect(health.saved.single.indoor, isFalse);
    expect(show.healthWorkoutId, 'HK-1');

    // The Show page draws the route and reads heart rate.
    await tester.tap(find.byType(ShowCard));
    await tester.pumpAndSettle();
    expect(find.text('THE ROUTE'), findsOneWidget);
    expect(find.text('HEART RATE'), findsOneWidget);
    expect(find.text('151 bpm'), findsOneWidget);
    expect(find.text('172 bpm'), findsOneWidget);

    await location.controller.close();
  });

  testWidgets('a refused location prompt explains the fix', (tester) async {
    final db = await tester.runAsync(
      () => newDatabaseFactoryMemory().openDatabase('denied.db'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db!),
          locationSourceProvider.overrideWithValue(
            FakeLocation(access: LocationAccess.denied),
          ),
          recordingStoreProvider.overrideWithValue(MemoryRecordingStore()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go('/live');
    await tester.pumpAndSettle();
    await tester.tap(find.text('GO LIVE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Location is off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('GO LIVE'), findsOneWidget);
    appRouter.go('/setlist');
    await tester.pumpAndSettle();
  });
}
