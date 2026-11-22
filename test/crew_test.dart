import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/crew_screen.dart';
import 'package:setlist_tracker/ui/crew/crew_widgets.dart';
import 'package:setlist_tracker/ui/crew/join_crew_screen.dart';
import 'package:setlist_tracker/ui/crew/share_with_crew_card.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';

import 'fakes/fake_backend.dart';

const me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@example.com');

Show show(
  String id, {
  double miles = 5,
  int seconds = 2700,
  String? notes,
  DateTime? updatedAt,
}) => Show(
  id: id,
  date: DateTime(2026, 11, 20, 7),
  venue: Venue.live,
  workoutType: WorkoutType.tempo,
  distanceMiles: miles,
  durationSeconds: seconds,
  effort: 8,
  feel: Feel.good,
  notes: notes,
  gearId: 'shoe',
  song: const SongOfTheShow(title: 'Run', artist: 'Band', note: 'mile 3'),
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: updatedAt ?? DateTime.utc(2026, 11, 20),
);

SharedShow shared({double miles = 6.2, List<String> records = const []}) =>
    SharedShow(
      date: DateTime(2026, 11, 21, 6, 30),
      venue: Venue.studio,
      workoutType: WorkoutType.easy,
      distanceMiles: miles,
      durationSeconds: 3300,
      goldRecords: records,
    );

const maya = CrewProfile(userId: 'maya', stageName: 'Maya', color: 2);

void main() {
  group('MemoryCrewService follows the server rules', () {
    test('invite, join, share, block', () async {
      final ryan = MemoryCrewService(me: 'me');
      await ryan.saveProfile(
        const CrewProfile(userId: 'me', stageName: 'Ryan'),
      );
      final code = await ryan.inviteCode();
      expect(await ryan.inviteCode(), code, reason: 'one code at a time');

      // Maya's view of the same world.
      final mayaView = MemoryCrewService(me: 'maya')
        ..profiles.addAll(ryan.profiles)
        ..invites.addAll(ryan.invites);
      await mayaView.saveProfile(maya);
      final preview = await mayaView.previewInvite(code.toLowerCase());
      expect(preview?.stageName, 'Ryan');
      expect(preview?.alreadyCrew, isFalse);
      await mayaView.join(code);
      expect((await mayaView.crew()).single.stageName, 'Ryan');

      await mayaView.share('s1', shared(), DateTime.utc(2026));
      expect((await mayaView.feed()).single.mine, isTrue);
      await mayaView.block('me');
      expect(await mayaView.crew(), hasLength(1));
      expect((await mayaView.crew()).single.blocked, isTrue);
      expect(await mayaView.previewInvite(code), isNull);
    });

    test('a stranger sees nothing and can’t cheer', () async {
      final s = MemoryCrewService(me: 'me');
      s.profiles['x'] = const CrewProfile(userId: 'x', stageName: 'X');
      final post = s.addPost('x', 's9', shared());
      expect(await s.feed(), isEmpty);
      await s.encore(post, on: true);
      expect(s.encores[post], isEmpty);
    });
  });

  group('SharedShow', () {
    test('leaves effort, feel and Gear behind; notes only when ticked', () {
      final s = show('a', notes: 'felt strong');
      final plain = SharedShow.fromShow(s, allShows: [s]);
      final json = plain.toJson();
      expect(json.containsKey('effort'), isFalse);
      expect(json.containsKey('gearId'), isFalse);
      expect(json['notes'], isNull);
      expect(plain.goldRecords, contains('Longest Show'));
      final withNotes = SharedShow.fromShow(
        s,
        allShows: [s],
        includeNotes: true,
      );
      expect(withNotes.notes, 'felt strong');

      final back = SharedShow.fromJson(withNotes.toJson());
      expect(back.distanceMiles, 5);
      expect(back.venue, Venue.live);
      expect(back.song?.note, 'mile 3');
      expect(back.date, DateTime(2026, 11, 20, 7));
    });
  });

  test('words for time', () {
    final now = DateTime(2026, 11, 21, 18);
    expect(sharedAgo(now, now: now), 'Just now');
    expect(
      sharedAgo(now.subtract(const Duration(hours: 3)), now: now),
      '3 hr ago',
    );
    expect(sharedAgo(DateTime(2026, 11, 20, 9), now: now), 'Yesterday');
    expect(sharedAgo(DateTime(2026, 11, 2), now: now), 'Nov 2');
    expect(
      openingNightLine(DateTime(2026, 12, 21), now: now),
      '30 days to Opening Night',
    );
    expect(openingNightLine(DateTime(2026, 11, 1), now: now), isNull);
    expect(spacedCode('K7Q9MX4P'), 'K7Q9 MX4P');
    expect(
      crewInviteLink('K7Q9MX', base: Uri.parse('https://x.dev/app/#/crew')),
      'https://x.dev/app/#/crew/join/K7Q9MX',
    );
  });

  group('on screen', () {
    late Database db;
    late MemoryCrewService crew;
    late FakeAuth auth;

    setUp(() async {
      db = await newDatabaseFactoryMemory().openDatabase(
        'crew${DateTime.now().microsecondsSinceEpoch}.db',
      );
      crew = MemoryCrewService(me: 'me');
      auth = FakeAuth(me);
    });

    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      String initial = '/',
    }) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/', builder: (_, _) => home),
          GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
          GoRoute(
            path: '/crew/join/:code',
            builder: (_, s) => JoinCrewScreen(code: s.pathParameters['code']!),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            authServiceProvider.overrideWithValue(auth),
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

    testWidgets('first visit: pick a stage name, then invite', (tester) async {
      await pump(tester, const CrewScreen());
      expect(find.text('Pick your stage name'), findsOneWidget);
      // Suggested from the sign-in name.
      expect(find.widgetWithText(TextField, 'Ryan'), findsOneWidget);
      await tester.tap(find.text('JOIN THE CREW'));
      await settle(tester);
      expect(crew.profiles['me']?.stageName, 'Ryan');
      expect(find.text('Your Crew'), findsOneWidget);
      expect(find.text('NO SHOWS YET'), findsOneWidget);

      await tester.tap(find.text('INVITE A FRIEND'));
      await settle(tester);
      expect(find.text('K7Q9 MX4P'), findsOneWidget);
    });

    testWidgets('the feed: Encore a friend’s Show, report another', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      crew.addPost(
        'maya',
        'm1',
        shared(records: ['Fastest 10K']),
        encoreCount: 2,
      );
      crew.addPost('maya', 'm2', shared(miles: 3.1));
      await pump(tester, const CrewScreen());

      expect(find.text('Maya'), findsWidgets);
      expect(find.text('Fastest 10K'), findsOneWidget);
      expect(find.text('Encore · 2'), findsOneWidget);
      await tester.tap(find.text('Encore · 2'));
      await settle(tester);
      expect(find.text('Encore · 3'), findsOneWidget);
      expect(crew.encores.values.any((s) => s.contains('me')), isTrue);

      await tester.tap(find.byTooltip('Show options').first);
      await settle(tester);
      await tester.tap(find.text('Report this Show'));
      await settle(tester);
      await tester.tap(find.text('Spam or fake'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await settle(tester);
      expect(crew.reports.single.reason, 'Spam or fake');
      expect(find.text('3.10 mi'), findsNothing);
    });

    testWidgets('an invite link: see who sent it, join', (tester) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.profiles['maya'] = maya;
      crew.invites['P4TR8WHN'] = 'maya';
      await pump(tester, const SizedBox(), initial: '/crew/join/p4tr-8whn');
      expect(find.text('MAYA INVITES YOU TO THE CREW'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(GradientButton),
          matching: find.text('JOIN THE CREW'),
        ),
      );
      await settle(tester);
      expect(crew.isCrew('me', 'maya'), isTrue);
      expect(find.text('Your Crew'), findsOneWidget);
    });

    testWidgets('an expired invite says so', (tester) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      await pump(tester, const SizedBox(), initial: '/crew/join/ZZZZZZZZ');
      expect(find.text('THIS INVITE HAS EXPIRED'), findsOneWidget);
    });

    testWidgets('share a Show; edit it and the Crew gets the new version', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      final repo = SembastShowRepository(db);
      await tester.runAsync(() => repo.save(show('s1', notes: 'secret')));
      final saved = (await tester.runAsync(() => repo.getById('s1')))!;
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(showsProvider).value?.firstOrNull;
            return Scaffold(
              body: s == null ? const SizedBox() : ShareWithCrewCard(show: s),
            );
          },
        ),
      );
      expect(find.text('Only you can see this Show.'), findsOneWidget);
      await tester.tap(find.text('Share with your Crew'));
      await settle(tester);
      expect(crew.posts.values.single.show.notes, isNull);
      expect(find.text('Include my notes'), findsOneWidget);

      // Edit the Show (a longer run): the shared copy follows.
      await tester.runAsync(
        () => repo.save(
          show('s1', miles: 7, notes: 'secret', updatedAt: saved.updatedAt),
        ),
      );
      await settle(tester);
      expect(crew.posts.values.single.show.distanceMiles, 7);

      // Delete it: it leaves the feed.
      await tester.runAsync(() => repo.delete('s1'));
      await settle(tester);
      expect(crew.posts, isEmpty);
    });

    testWidgets('guests are asked to get a Backstage Pass', (tester) async {
      auth = FakeAuth();
      await pump(tester, const CrewScreen());
      expect(find.text('JOIN THE CREW'), findsOneWidget);
      expect(find.text('GO BACKSTAGE'), findsOneWidget);
    });
  });
}

/// Lets the in-memory database and services finish, then the frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}
