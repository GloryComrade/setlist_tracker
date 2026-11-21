import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/music/music_search.dart';
import 'package:setlist_tracker/data/providers.dart';

/// Books a Live Show through the real screens and checks it lands on the
/// Setlist and its detail page. Uses an in-memory database and a plain theme
/// (the real theme downloads fonts, which tests can't do).
class _FakeMusicSearch implements MusicSearch {
  @override
  Future<List<SongResult>> search(String query) async => const [
        SongResult(
            title: 'Dancing in the Dark',
            artist: 'Bruce Springsteen',
            album: 'Born in the U.S.A.'),
        SongResult(title: 'Born to Run', artist: 'Bruce Springsteen'),
      ];
}

void main() {
  testWidgets('book a Live Show and see it on the Setlist', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final db = await tester.runAsync(
        () => newDatabaseFactoryMemory().openDatabase('flow.db'));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db!),
        musicSearchProvider.overrideWithValue(_FakeMusicSearch()),
      ],
      child: MaterialApp.router(
        theme: ThemeData.dark(),
        routerConfig: appRouter,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('NO SHOWS YET'), findsOneWidget);

    await tester.tap(find.text('Book a Show'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LIVE SHOW'));
    await tester.pumpAndSettle();

    Future<void> type(String label, String text) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      await tester.pump();
    }

    await tester.tap(find.text('Headliner'));
    await type('Route', 'River Loop');
    await type('Elevation gain', '820');
    await type('Temperature', '41');
    await type('Wind', '8');
    await type('Distance', '16');
    await type('Duration', '2:20:00');

    // Pick the Song of the Show from search results.
    final pick = find.text('Pick a song');
    await tester.ensureVisible(pick);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'springsteen');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dancing in the Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Bruce Springsteen'), findsOneWidget);
    await type('Note (optional)', 'mile 14 second wind');

    // Pace preview: 140 min / 16 mi = 8:45 /mi
    expect(find.text('8:45 /mi'), findsOneWidget);

    final bookIt = find.text('BOOK IT');
    await tester.ensureVisible(bookIt);
    await tester.runAsync(() async {
      await tester.tap(bookIt);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('16 mi'), findsWidgets);
    expect(find.textContaining('Dancing in the Dark'), findsOneWidget);

    await tester.tap(find.textContaining('Dancing in the Dark'));
    await tester.pumpAndSettle();
    expect(find.text('River Loop'), findsOneWidget);
    expect(find.text('41°F'), findsOneWidget);
    expect(find.text('820 ft'), findsOneWidget);

    await tester.runAsync(() => db.close());
  });
}
