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
import 'package:setlist_tracker/ui/crew/audience_sheet.dart';
import 'package:setlist_tracker/ui/crew/crew_screen.dart';

import 'fakes/fake_backend.dart';

const me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@example.com');
const maya = CrewProfile(userId: 'maya', stageName: 'Maya', color: 2);
const sam = CrewProfile(userId: 'sam', stageName: 'Sam', color: 1);
const jo = CrewProfile(userId: 'jo', stageName: 'Jo', color: 3);
const lee = CrewProfile(userId: 'lee', stageName: 'Lee');

Show aShow(String id, {double miles = 5, int day = 20}) => Show(
  id: id,
  date: DateTime(2026, 11, day, 7),
  venue: Venue.studio,
  workoutType: WorkoutType.easy,
  distanceMiles: miles,
  durationSeconds: 2700,
  effort: 5,
  feel: Feel.fine,
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: DateTime.utc(2026, 11, 20),
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
  test('the Seen by line names a few, then counts the rest', () {
    expect(
      seenByText(const CrewSeenSummary(count: 4, names: ['Maya', 'Sam'])),
      'Seen by Maya, Sam +2',
    );
    expect(
      seenByText(const CrewSeenSummary(count: 1, names: ['Maya'])),
      'Seen by Maya',
    );
  });

  late MemoryCrewService crew;

  setUp(() {
    crew = MemoryCrewService(me: 'me')
      ..profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan')
      ..addMate(maya)
      ..addMate(sam)
      ..addMate(jo)
      ..addMate(lee);
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = await tester.runAsync(
      () => newDatabaseFactoryMemory().openDatabase(
        'aud${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const CrewScreen()),
        GoRoute(
          path: '/crew/mate/:userId',
          builder: (_, s) =>
              Scaffold(body: Text('PAGE OF ${s.pathParameters['userId']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db!),
          authServiceProvider.overrideWithValue(FakeAuth(me)),
          remoteStoreProvider.overrideWithValue(FakeRemote()),
          crewServiceProvider.overrideWithValue(crew),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await settle(tester);
  }

  testWidgets('your Show: who saw it, and who gave Encores', (tester) async {
    final id = crew.addShow('me', aShow('s1'));
    crew.views[id] = {
      'lee': DateTime.utc(2026, 11, 20, 8),
      'jo': DateTime.utc(2026, 11, 20, 9),
      'sam': DateTime.utc(2026, 11, 20, 10),
      'maya': DateTime.utc(2026, 11, 20, 11),
    };
    crew.encores[id] = {'sam', 'fan0'};
    await pump(tester);

    // Newest first, three names, then the rest counted.
    expect(find.text('Seen by Maya, Sam, Jo +1'), findsOneWidget);
    expect(find.text('2 Encores'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Seen by Maya, Sam, Jo and 1 more. See who.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Seen by Maya, Sam, Jo +1'));
    await settle(tester);
    expect(find.text('THE AUDIENCE'), findsOneWidget);
    expect(find.text('Seen by · 4'), findsOneWidget);
    for (final n in ['Maya', 'Sam', 'Jo', 'Lee']) {
      expect(
        find.descendant(of: find.byType(AudienceSheet), matching: find.text(n)),
        findsOneWidget,
      );
    }
    // Sam gave an Encore too: the one amber mark on the list.
    expect(
      find.descendant(
        of: find.byType(AudienceSheet),
        matching: find.byIcon(Icons.celebration),
      ),
      findsOneWidget,
    );
    expect(find.text('Only you see who saw your Show.'), findsOneWidget);

    await tester.tap(find.text('Encores · 2'));
    await settle(tester);
    final sheet = find.byType(AudienceSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Sam')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Maya')),
      findsNothing,
    );
    expect(find.text('and 1 more outside your Crew'), findsOneWidget);

    // A Crew mate on the list opens their page.
    await tester.tap(find.descendant(of: sheet, matching: find.text('Sam')));
    await settle(tester);
    expect(find.text('PAGE OF sam'), findsOneWidget);
  });

  testWidgets('nobody has seen it yet: no line', (tester) async {
    crew.addShow('me', aShow('s1'));
    await pump(tester);
    expect(find.textContaining('Seen by'), findsNothing);
    expect(find.text('No Encores yet'), findsOneWidget);
  });

  testWidgets('a Crew mate’s Show: Encores only, never Seen by', (
    tester,
  ) async {
    final id = crew.addShow('maya', aShow('m1'), encoreCount: 2);
    crew.encores[id]!.add('sam');
    crew.views[id] = {'jo': DateTime.utc(2026, 11, 20, 9)};
    await pump(tester);
    expect(find.textContaining('Seen by'), findsNothing);

    await tester.tap(find.byKey(ValueKey('encore-count-$id')));
    await settle(tester);
    expect(find.text('ENCORES'), findsOneWidget);
    expect(find.text('THE AUDIENCE'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    final sheet = find.byType(AudienceSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Sam')),
      findsOneWidget,
    );
    expect(find.descendant(of: sheet, matching: find.text('Jo')), findsNothing);
    expect(find.text('and 2 more outside your Crew'), findsOneWidget);
  });

  testWidgets('a Show with no Encores says so in the sheet', (tester) async {
    final id = crew.addShow('me', aShow('s1'));
    crew.views[id] = {'maya': DateTime.utc(2026, 11, 20, 9)};
    await pump(tester);
    await tester.tap(find.text('Seen by Maya'));
    await settle(tester);
    await tester.tap(find.text('Encores · 0'));
    await settle(tester);
    expect(find.text('NO ENCORES YET'), findsOneWidget);
  });

  testWidgets('a Crew mate’s Show is marked seen once, after a beat', (
    tester,
  ) async {
    final id = crew.addShow('maya', aShow('m1'));
    await pump(tester);
    // On screen, but not for long enough yet.
    expect(crew.views[id], isNull);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(crew.views[id]?.keys, ['me']);

    // Never again this session, however long it stays.
    crew.views.remove(id);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(crew.views[id], isNull);
  });

  testWidgets('a Show below the fold isn’t marked seen', (tester) async {
    final ids = [
      for (var i = 0; i < 8; i++)
        crew.addShow('maya', aShow('m$i', miles: 3.0 + i, day: 10 + i)),
    ];
    await pump(tester, size: const Size(400, 700));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    // The feed is newest first: the oldest Show is far down the list.
    expect(crew.views[ids.first], isNull);
    expect(crew.views.isNotEmpty, isTrue);
  });

  testWidgets('switch off: nothing is recorded', (tester) async {
    crew.profiles['me'] = crew.profiles['me']!.copyWith(shareViews: false);
    final id = crew.addShow('maya', aShow('m1'));
    await pump(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(crew.views[id], isNull);
  });

  testWidgets('at 150% text on a phone, nothing overflows', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final mine = crew.addShow('me', aShow('s1', day: 21));
    crew.views[mine] = {
      'maya': DateTime.utc(2026, 11, 20, 11),
      'sam': DateTime.utc(2026, 11, 20, 10),
      'jo': DateTime.utc(2026, 11, 20, 9),
      'lee': DateTime.utc(2026, 11, 20, 8),
    };
    crew.encores[mine] = {'maya', 'sam'};
    crew.addShow('maya', aShow('m1'), encoreCount: 12);
    await pump(tester, size: const Size(390, 1600));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Seen by Maya, Sam, Jo +1'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
