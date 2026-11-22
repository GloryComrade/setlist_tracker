import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/crew_screen.dart';
import 'package:setlist_tracker/ui/crew/shoutouts_sheet.dart';

import 'fakes/fake_backend.dart';

const me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@example.com');
const maya = CrewProfile(userId: 'maya', stageName: 'Maya', color: 2);
const sam = CrewProfile(userId: 'sam', stageName: 'Sam', color: 1);

Show mateShow(String id) => Show(
  id: id,
  date: DateTime(2026, 11, 21, 7),
  venue: Venue.live,
  workoutType: WorkoutType.easy,
  distanceMiles: 5,
  durationSeconds: 2700,
  effort: 5,
  feel: Feel.good,
  createdAt: DateTime.utc(2026, 11, 21),
  updatedAt: DateTime.utc(2026, 11, 21),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  test('the button label counts Shout-outs', () {
    expect(shoutoutsLabel(0), 'Shout-out');
    expect(shoutoutsLabel(1), '1 Shout-out');
    expect(shoutoutsLabel(3), '3 Shout-outs');
  });

  group('Shout-outs on screen', () {
    late MemoryCrewService crew;

    Future<void> pump(
      WidgetTester tester, {
      Size size = const Size(400, 1400),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = await tester.runAsync(
        () => newDatabaseFactoryMemory().openDatabase(
          'so${DateTime.now().microsecondsSinceEpoch}.db',
        ),
      );
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const CrewScreen())],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db!),
            authServiceProvider.overrideWithValue(FakeAuth(me)),
            remoteStoreProvider.overrideWithValue(FakeRemote()),
            crewServiceProvider.overrideWithValue(crew),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
    }

    setUp(() {
      crew = MemoryCrewService(me: 'me')
        ..profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan')
        ..addMate(maya)
        ..addMate(sam)
        // Sam and Maya are Crew too, so Sam can cheer Maya's Shows.
        ..links['maya|sam'] = DateTime.utc(2026, 10);
    });

    testWidgets('open, empty, post one, the card counts it, then delete', (
      tester,
    ) async {
      final id = crew.addShow('maya', mateShow('m1'));
      await pump(tester);

      expect(find.text('Shout-out'), findsOneWidget);
      await tester.tap(find.text('Shout-out'));
      await settle(tester);
      expect(find.text('SHOUT-OUTS'), findsOneWidget);
      expect(find.text('Only Maya and their Crew see these.'), findsOneWidget);
      expect(find.text('No Shout-outs yet. Be the first.'), findsOneWidget);
      // Opening it counts as seeing the Show.
      expect(crew.views[id], contains('me'));

      // Send waits for words.
      final send = find.widgetWithIcon(IconButton, Icons.send);
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      // Near the limit a counter shows; over it, Send turns off.
      await tester.enterText(find.byType(TextField), 'a' * 250);
      await tester.pump();
      expect(find.text('30'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'a' * 285);
      await tester.pump();
      expect(find.text('-5'), findsOneWidget);
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Huge hills, nice work!');
      await tester.pump();
      await tester.tap(send);
      await settle(tester);
      expect(find.text('Huge hills, nice work!'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(crew.shoutoutRows.single.body, 'Huge hills, nice work!');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      // The card behind the sheet counts it.
      Navigator.of(tester.element(find.text('SHOUT-OUTS'))).pop();
      await settle(tester);
      expect(find.text('1 Shout-out'), findsOneWidget);

      await tester.tap(find.text('1 Shout-out'));
      await settle(tester);
      await tester.tap(find.byTooltip('Shout-out options'));
      await settle(tester);
      // Your own: Delete, no Report.
      expect(find.text('Report Shout-out'), findsNothing);
      await tester.tap(find.text('Delete Shout-out'));
      await settle(tester);
      expect(find.text('Delete this Shout-out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(crew.shoutoutRows, isEmpty);
      expect(find.text('Huge hills, nice work!'), findsNothing);
      expect(find.text('No Shout-outs yet. Be the first.'), findsOneWidget);
    });

    testWidgets('oldest first; report hides one and keeps the count right', (
      tester,
    ) async {
      final id = crew.addShow('maya', mateShow('m1'));
      crew.addShoutoutFrom('maya', id, 'Thanks for the pace!');
      crew.addShoutoutFrom('sam', id, 'See you Saturday.');
      await pump(tester);
      expect(find.text('2 Shout-outs'), findsOneWidget);

      await tester.tap(find.text('2 Shout-outs'));
      await settle(tester);
      final first = tester.getTopLeft(find.text('Thanks for the pace!'));
      final second = tester.getTopLeft(find.text('See you Saturday.'));
      expect(first.dy, lessThan(second.dy));

      // Someone else's on someone else's Show: Report, no Delete.
      await tester.longPress(find.text('See you Saturday.'));
      await settle(tester);
      expect(find.text('Delete Shout-out'), findsNothing);
      await tester.tap(find.text('Report Shout-out'));
      await settle(tester);
      expect(find.text('REPORT THIS SHOUT-OUT'), findsOneWidget);
      expect(find.text('Also block Sam'), findsOneWidget);
      await tester.tap(find.text('Rude or hurtful'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await settle(tester);
      expect(crew.shoutoutReports.single.reason, 'Rude or hurtful');
      expect(find.text('See you Saturday.'), findsNothing);
      expect(find.text('Thanks for the pace!'), findsOneWidget);

      Navigator.of(tester.element(find.text('SHOUT-OUTS'))).pop();
      await settle(tester);
      expect(find.text('1 Shout-out'), findsOneWidget);
    });

    testWidgets('on your own Show you can delete a Crew mate’s', (
      tester,
    ) async {
      final saved = mateShow('s1');
      final id = crew.addShow('me', saved);
      crew.addShoutoutFrom('maya', id, 'Strong finish.');
      await pump(tester);
      await tester.tap(find.text('1 Shout-out'));
      await settle(tester);
      expect(find.text('Only you and your Crew see these.'), findsOneWidget);
      await tester.tap(find.byTooltip('Shout-out options'));
      await settle(tester);
      expect(find.text('Delete Shout-out'), findsOneWidget);
      expect(find.text('Report Shout-out'), findsOneWidget);
    });

    testWidgets('fits a phone at 150% text', (tester) async {
      crew.addShow('maya', mateShow('m1'), encoreCount: 12);
      final id = crew.addShow('maya', mateShow('m2'));
      for (var i = 0; i < 3; i++) {
        crew.addShoutoutFrom('sam', id, 'Shout-out number $i');
      }
      await pump(tester, size: const Size(390, 2400), textScale: 1.5);
      expect(tester.takeException(), isNull);
      expect(find.text('3 Shout-outs'), findsOneWidget);
      await tester.tap(find.text('3 Shout-outs'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Shout-out number 2'), findsOneWidget);
      // The composer stays on screen.
      final box = find.byType(TextField);
      expect(tester.getBottomLeft(box).dy, lessThanOrEqualTo(2400));
      expect(find.byTooltip('Send Shout-out'), findsOneWidget);
    });

    testWidgets('the button speaks its count', (tester) async {
      final id = crew.addShow('maya', mateShow('m1'));
      crew.addShoutoutFrom('sam', id, 'Nice.');
      final semantics = tester.ensureSemantics();
      await pump(tester);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Shout-outs').first,
      );
      expect(node.value, '1 Shout-out');
      semantics.dispose();
      // Keeps the controller in the tree for the test's teardown.
      expect(
        ProviderScope.containerOf(tester.element(find.byType(CrewScreen)))
            .read(crewControllerProvider)
            .posts,
        isNotEmpty,
      );
    });
  });
}
