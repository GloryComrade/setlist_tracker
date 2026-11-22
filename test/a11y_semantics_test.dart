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
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/crew_post_card.dart';
import 'package:setlist_tracker/ui/setlist/show_card.dart';
import 'package:setlist_tracker/ui/tour/tour_widgets.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';

import 'fakes/fake_backend.dart';

const _showLabel =
    'Sunday 22. Headliner, Live Show. 15 miles, 9 minutes 20 seconds per '
    'mile, 2 hours 20 minutes. Effort 6 of 10, felt Fine. Song: Lose '
    'Yourself by Eminem.';

final _headliner = Show(
  id: 'h1',
  date: DateTime(2026, 11, 22, 7),
  venue: Venue.live,
  workoutType: WorkoutType.long,
  distanceMiles: 15,
  durationSeconds: 8400,
  effort: 6,
  feel: Feel.fine,
  song: const SongOfTheShow(title: 'Lose Yourself', artist: 'Eminem'),
  createdAt: DateTime.utc(2026, 11, 22),
  updatedAt: DateTime.utc(2026, 11, 22),
);

Future<void> _pumpRouted(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [child]),
        ),
      ),
      GoRoute(
        path: '/show/:id',
        builder: (_, s) => Text('SHOW PAGE ${s.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

/// Lets the Crew controller's async loads finish, as crew_test does.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('Show card', () {
    testWidgets('speaks the whole ticket in words', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(tester, ShowCard(show: _headliner));

      expect(find.bySemanticsLabel(_showLabel), findsOneWidget);
      // The ticket still looks the same.
      expect(find.text('15 mi'), findsOneWidget);
      expect(find.text('9:20 /mi'), findsOneWidget);
      expect(find.text('2:20:00'), findsOneWidget);
      // Nothing says "mi" on its own.
      expect(find.bySemanticsLabel(RegExp(r'\bmi\b')), findsNothing);

      final node = tester.getSemantics(find.bySemanticsLabel(_showLabel));
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('a screen reader tap opens the Show', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(tester, ShowCard(show: _headliner));
      tester.semantics.tap(find.semantics.byLabel(_showLabel));
      await tester.pumpAndSettle();
      expect(find.text('SHOW PAGE h1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a Studio Session with no song leaves the song out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final easy = Show(
        id: 'e1',
        date: DateTime(2026, 11, 18, 6),
        venue: Venue.studio,
        workoutType: WorkoutType.easy,
        distanceMiles: 1,
        durationSeconds: 600,
        effort: 3,
        feel: Feel.good,
        createdAt: DateTime.utc(2026, 11, 18),
        updatedAt: DateTime.utc(2026, 11, 18),
      );
      await _pumpRouted(tester, ShowCard(show: easy));
      expect(
        find.bySemanticsLabel(
          'Wednesday 18. Easy, Studio Session. 1 mile, 10 minutes per mile, '
          '10 minutes. Effort 3 of 10, felt Good set.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  testWidgets('Stat tiles say their units', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpRouted(
      tester,
      const Wrap(
        children: [
          StatTile(label: 'Pace', value: '8:42 /mi'),
          StatTile(label: 'Longest so far', value: '18 mi'),
          StatTile(label: 'Time', value: '1:05:30'),
          StatTile(label: 'Gear', value: 'Road Racers'),
        ],
      ),
    );
    expect(
      find.bySemanticsLabel('Pace: 8 minutes 42 seconds per mile'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Longest so far: 18 miles'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Time: 1 hour 5 minutes 30 seconds'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Gear: Road Racers'), findsOneWidget);
    expect(find.text('8:42 /mi'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the Gradient Button is a button in its own case', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pumpRouted(
      tester,
      GradientButton(label: 'Join the Crew', onPressed: () => taps++),
    );
    expect(find.text('JOIN THE CREW'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('Join the Crew'));
    expect(node.flagsCollection.isButton, isTrue);
    tester.semantics.tap(find.semantics.byLabel('Join the Crew'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('Tour tags are at least 11 pt and fit at phone width', (
    tester,
  ) async {
    await _pumpRouted(
      tester,
      const Wrap(
        spacing: 8,
        children: [
          TourTag('Rest Stop'),
          TourTag('This week', color: Colors.white),
        ],
      ),
    );
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.fontSize ?? 14, greaterThanOrEqualTo(11));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a Crew post speaks its numbers, effort, Gear, song and Gold Records',
    (tester) async {
      final handle = tester.ensureSemantics();
      final db = await newDatabaseFactoryMemory().openDatabase(
        'a11y${DateTime.now().microsecondsSinceEpoch}.db',
      );
      const me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@x.com');
      final post = CrewPost(
        id: 'p1',
        ownerId: 'maya',
        stageName: 'Maya',
        color: 1,
        sharedAt: DateTime(2026, 11, 22, 10),
        show: Show(
          id: 'h1',
          date: DateTime(2026, 11, 22, 7),
          venue: Venue.live,
          workoutType: WorkoutType.long,
          distanceMiles: 15,
          durationSeconds: 8400,
          effort: 6,
          feel: Feel.fine,
          song: const SongOfTheShow(
            title: 'Lose Yourself',
            artist: 'Eminem',
            note: 'mile 12',
            spotifyUrl: 'https://open.spotify.com/track/x',
          ),
          createdAt: DateTime.utc(2026, 11, 22),
          updatedAt: DateTime.utc(2026, 11, 22),
        ),
        gearName: 'Pegasus 41',
      );
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            authServiceProvider.overrideWithValue(FakeAuth(me)),
            remoteStoreProvider.overrideWithValue(FakeRemote()),
            crewServiceProvider.overrideWithValue(MemoryCrewService(me: 'me')),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CrewPostCard(
                    post: post,
                    now: DateTime(2026, 11, 22, 12),
                    goldRecords: const ['Longest Headliner'],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        find.bySemanticsLabel(
          'Sunday 22. Headliner, Live Show. 15 miles, 9 minutes 20 seconds '
          'per mile, 2 hours 20 minutes.',
        ),
        findsOneWidget,
      );
      final song = tester.getSemantics(
        find.bySemanticsLabel('Song: Lose Yourself by Eminem. “mile 12”'),
      );
      expect(song.flagsCollection.isLink, isTrue);
      expect(song.hint, 'Opens in Spotify');
      expect(
        find.bySemanticsLabel('Gold Record: Longest Headliner'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Effort 6 of 10, felt Fine.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Gear: Pegasus 41.'), findsOneWidget);
      expect(find.text('15 mi'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      await tester.runAsync(db.close);
    },
  );
}
