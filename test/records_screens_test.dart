import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/theme/app_theme.dart';

Show _show(String id, int day, double miles, SongOfTheShow song) => Show(
  id: id,
  date: DateTime(2026, 11, day, 7),
  venue: Venue.live,
  workoutType: WorkoutType.easy,
  distanceMiles: miles,
  durationSeconds: (miles * 540).round(),
  effort: 5,
  feel: Feel.fine,
  song: song,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  testWidgets('Backstage opens Gold Records and The Record Wall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final db = await tester.runAsync(() async {
      final db = await newDatabaseFactoryMemory().openDatabase('rec.db');
      final repo = SembastShowRepository(db);
      const song = SongOfTheShow(
        title: 'Born to Run',
        artist: 'Bruce Springsteen',
      );
      await repo.save(_show('a', 2, 4, song));
      await repo.save(_show('b', 9, 6.2, song));
      return db;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db!)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go('/backstage');
    await tester.pumpAndSettle();
    expect(find.text('1 song'), findsOneWidget);

    await tester.tap(find.text('Gold Records'));
    await tester.pumpAndSettle();
    expect(find.text('GOLD RECORDS'), findsOneWidget);
    expect(find.text('6.2 mi'), findsWidgets);
    expect(find.text('Fastest 10K'), findsOneWidget);

    appRouter.go('/backstage/record-wall');
    await tester.pumpAndSettle();
    expect(find.text('THE RECORD WALL'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Born to Run by')));
    await tester.pumpAndSettle();
    expect(find.text('Song of 2 Shows'), findsOneWidget);
  });
}
