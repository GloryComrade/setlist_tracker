import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/models/track.dart';
import 'package:setlist_tracker/models/venue_details.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/crew_screen.dart';
import 'package:setlist_tracker/ui/crew/crew_widgets.dart';
import 'package:setlist_tracker/ui/crew/join_crew_screen.dart';
import 'package:setlist_tracker/ui/tour/tour_screen.dart';
import 'package:setlist_tracker/ui/crew/crew_mate_screen.dart';
import 'package:setlist_tracker/ui/crew/crew_post_card.dart';
import 'package:setlist_tracker/ui/tour/featuring_strip.dart';
import 'package:setlist_tracker/logic/gold_records.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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

/// A Crew mate's Show: a Studio Session with Tracks.
Show mateShow(
  String id, {
  double miles = 6.2,
  bool crewPrivate = false,
  DateTime? date,
  String? notes,
}) => Show(
  id: id,
  date: date ?? DateTime(2026, 11, 21, 6, 30),
  venue: Venue.studio,
  workoutType: WorkoutType.easy,
  distanceMiles: miles,
  durationSeconds: 3300,
  effort: 4,
  feel: Feel.fine,
  notes: notes,
  crewPrivate: crewPrivate,
  studio: const StudioDetails(
    tracks: [
      Track(
        startSeconds: 0,
        endSeconds: 1800,
        speedMph: 6.5,
        inclinePercent: 1,
      ),
      Track(
        startSeconds: 1800,
        endSeconds: 3300,
        speedMph: 7.2,
        inclinePercent: 2,
      ),
    ],
  ),
  createdAt: DateTime.utc(2026, 11, 21),
  updatedAt: DateTime.utc(2026, 11, 21),
);

Tour tourFor(DateTime race, {DateTime? today}) => TourBuilder()
    .build(
      TourSetup(
        raceDate: race,
        goal: TourGoal.finish,
        currentWeeklyMiles: 25,
        longestRecentRunMiles: 10,
        daysPerWeek: 4,
        headlinerWeekday: DateTime.sunday,
        venuePreference: VenuePreference.mix,
        easyPaceSecondsPerMile: 600,
      ),
      today: today,
    )
    .tour!;

/// A race date whose Tour, built today, has a week running now.
DateTime raceInProgress() {
  final n = DateTime.now();
  final day = DateTime(n.year, n.month, n.day);
  for (var d = 7 * 12; d < 7 * 24; d++) {
    final race = day.add(Duration(days: d));
    if (tourFor(race).weekContaining(day) != null) return race;
  }
  throw StateError('no Tour covers today');
}

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

      mayaView.addShow('maya', mateShow('s1'));
      mayaView.addShow('maya', mateShow('s2', crewPrivate: true));
      final post = (await mayaView.feed()).single;
      expect(post.mine, isTrue);
      expect(post.id, 'maya:s1');
      await mayaView.block('me');
      expect(await mayaView.crew(), hasLength(1));
      expect((await mayaView.crew()).single.blocked, isTrue);
      expect(await mayaView.previewInvite(code), isNull);
    });

    test('a stranger sees nothing and can’t cheer', () async {
      final s = MemoryCrewService(me: 'me');
      s.profiles['x'] = const CrewProfile(userId: 'x', stageName: 'X');
      final post = s.addShow('x', mateShow('s9'));
      expect(await s.feed(), isEmpty);
      expect(await s.mate('x'), isNull);
      await s.encore(post, on: true);
      expect(s.encores[post], isEmpty);
    });
  });

  group('Show.crewPrivate', () {
    test('round-trips through JSON; absent means false', () {
      final kept = show('a').copyWith(crewPrivate: true);
      expect(kept.crewPrivate, isTrue);
      final json = kept.toJson();
      expect(json['crewPrivate'], isTrue);
      expect(Show.fromJson(json).crewPrivate, isTrue);

      final open = show('b').toJson();
      expect(open.containsKey('crewPrivate'), isFalse);
      expect(Show.fromJson(open).crewPrivate, isFalse);
      expect(
        Show.fromJson({...open, 'crewPrivate': false}).crewPrivate,
        isFalse,
      );
      // copyWith keeps it unless told otherwise.
      expect(kept.copyWith(updatedAt: DateTime.utc(2027)).crewPrivate, isTrue);
    });
  });

  group('Crew JSON', () {
    test('a feed post carries the whole Show and its Gear', () {
      final s = show('s1', notes: 'felt strong');
      final post = CrewPost.fromJson({
        'id': 'u2:s1',
        'ownerId': 'u2',
        'stageName': 'Sam',
        'color': 1,
        'showId': 's1',
        'show': s.toJson(),
        'gearName': 'Pegasus 41',
        'sharedAt': '2026-11-21T08:00:00.000Z',
        'encores': 2,
        'encoredByMe': true,
        'mine': false,
      });
      expect(post.id, 'u2:s1');
      expect(post.showId, 's1');
      expect(post.show.effort, 8);
      expect(post.show.feel, Feel.good);
      expect(post.show.notes, 'felt strong');
      expect(post.show.song?.note, 'mile 3');
      expect(post.gearName, 'Pegasus 41');
      expect(post.withEncore(false).encores, 1);
    });

    test('a mate’s Tour summary and page', () {
      final mate = CrewMate.fromJson({
        'userId': 'u2',
        'stageName': 'Sam',
        'color': 1,
        'since': '2026-11-01T00:00:00.000Z',
        'tour': {
          'id': 't1',
          'name': 'Spring Tour',
          'raceDate': '2027-04-18',
          'raceDistance': 'half',
          'featuring': {'userId': 'me', 'stageName': 'Ryan'},
        },
        'blocked': false,
      });
      expect(mate.tour?.raceDate, DateTime(2027, 4, 18));
      expect(mate.tour?.raceDistance, RaceDistance.half);
      expect(mate.tour?.featuring?.stageName, 'Ryan');
      final noDistance = CrewTourSummary.fromJson({
        'id': 't2',
        'name': 'Fall Tour',
        'raceDate': '2027-10-10',
      });
      expect(noDistance?.raceDistance, RaceDistance.marathon);
      expect(CrewTourSummary.fromJson(null), isNull);

      final tour = tourFor(DateTime(2027, 4, 18), today: DateTime(2026, 12, 1));
      final detail = CrewMateDetail.fromJson({
        'mate': {'userId': 'u2', 'stageName': 'Sam', 'color': 1},
        'tour': tour.toJson(),
        'shows': [
          {
            'id': 'u2:s1',
            'ownerId': 'u2',
            'showId': 's1',
            'show': show('s1').toJson(),
          },
        ],
      });
      expect(detail.mate.stageName, 'Sam');
      expect(detail.tour?.weeks.length, tour.weeks.length);
      expect(detail.shows.single.show.distanceMiles, 5);
    });

    test('a mate’s current week: Shows done of planned, miles so far', () {
      final start = DateTime(2026, 12, 1);
      final tour = tourFor(DateTime(2027, 4, 18), today: start);
      final week = tour.weeks[2];
      final planned = week.shows.where((p) => !p.skipped).toList();
      final day = planned.first.date;
      final shows = [
        // On a planned day: counts.
        mateShow('a', date: DateTime(day.year, day.month, day.day, 7)),
        // Another run that week, not on a planned day: miles only.
        mateShow(
          'b',
          miles: 3,
          date: week.startDate.add(const Duration(hours: 30)),
        ),
        // The week before: not counted.
        mateShow('c', date: week.startDate.subtract(const Duration(days: 1))),
      ];
      final today = week.startDate.add(const Duration(days: 3));
      final p = CrewWeekProgress.of(tour, shows, today)!;
      expect(p.week.number, week.number);
      expect(p.showsPlanned, planned.length);
      final bDay = DateTime(
        week.startDate.year,
        week.startDate.month,
        week.startDate.day + 1,
      );
      final bCounts = planned.skip(1).any((x) => x.date == bDay);
      expect(p.showsDone, bCounts ? 2 : 1);
      expect(p.miles, closeTo(9.2, 0.001));
      expect(
        CrewWeekProgress.of(tour, shows, DateTime(2030)),
        isNull,
        reason: 'after the Tour',
      );
    });
  });

  test('a friend’s Gold Records: no repeats, one row per Show, 3 at most', () {
    final shows = [
      for (var i = 0; i < 6; i++)
        mateShow('s$i', miles: 3.5 + i, date: DateTime(2026, 11, 1 + i * 3, 7)),
    ];
    final rows = mateRecordRows(computeGoldRecords(shows));
    expect(rows.length, lessThanOrEqualTo(3));
    // Every row is a different Show or period.
    expect(rows.map((r) => r.date).toSet().length, rows.length);
    expect(rows.first.titles.first, 'Longest Show');
    // A week or month that only repeats the Longest Show is left off.
    final one = mateRecordRows(computeGoldRecords([mateShow('only')]));
    expect(one, hasLength(1));
    expect(one.single.titles, isNot(contains('Biggest week')));
    expect(one.single.titles, isNot(contains('Biggest month')));
    expect(one.single.titles, contains('Longest Show'));
  });

  test('the featuring strip says something new about the friend', () {
    final mate = CrewMate(
      userId: 'maya',
      stageName: 'Maya',
      color: 2,
      since: DateTime(2026, 10, 1),
    );
    final detail = CrewMateDetail(
      mate: mate,
      shows: [
        CrewPost(
          id: 'maya:m1',
          ownerId: 'maya',
          stageName: 'Maya',
          color: 2,
          show: mateShow('m1', date: DateTime(2026, 11, 20, 7), miles: 5.5),
          sharedAt: DateTime(2026, 11, 20),
        ),
      ],
    );
    final news = featuringNews(detail, DateTime(2026, 11, 22));
    expect(news.text, startsWith('Fri · 5.5 mi Easy'));
    expect(news.spoken, startsWith('Latest Show: Friday, 5.5 miles'));
    expect(
      featuringNews(CrewMateDetail(mate: mate), DateTime(2026, 11, 22)).text,
      'No Shows yet',
    );
  });

  test('the effort line says one stop after “Encore!”', () {
    expect(spokenEffortLine(8, Feel.encore), 'Effort 8 of 10, felt Encore!');
    expect(spokenEffortLine(6, Feel.fine), 'Effort 6 of 10, felt Fine.');
  });

  test('saving a stage name keeps a pending OK; accepting ends it', () async {
    final s = MemoryCrewService(me: 'me')
      ..profiles['me'] = const CrewProfile(
        userId: 'me',
        stageName: 'Ryan',
        allActivityPending: true,
      );
    final renamed = await s.saveProfile(
      const CrewProfile(userId: 'me', stageName: 'Ry'),
    );
    expect(renamed.allActivityPending, isTrue);
    final ok = await s.acceptAllActivity(renamed);
    expect(ok.allActivityPending, isFalse);
    expect(ok.stageName, 'Ry');
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
    // Tests run as the app, not the website: the public site.
    expect(
      crewInviteLink('K7Q9MX4P'),
      'https://setlisttracker.com/#/crew/join/K7Q9MX4P',
    );
  });

  group('on screen', () {
    late Database db;
    late MemoryCrewService crew;
    late FakeAuth auth;
    TourFeaturing? booked;

    setUp(() async {
      booked = null;
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
      Size size = const Size(400, 1600),
    }) async {
      tester.view.physicalSize = size;
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
          GoRoute(
            path: '/crew/mate/:userId',
            builder: (_, s) =>
                CrewMateScreen(userId: s.pathParameters['userId']!),
          ),
          GoRoute(
            path: '/tour/book',
            builder: (_, s) {
              booked = s.extra as TourFeaturing?;
              return const Scaffold(body: Text('BOOK THE TOUR'));
            },
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
      expect(find.text('PICK YOUR STAGE NAME'), findsOneWidget);
      // Suggested from the sign-in name.
      expect(find.widgetWithText(TextField, 'Ryan'), findsOneWidget);
      await tester.tap(find.text('JOIN THE CREW'));
      await settle(tester);
      expect(crew.profiles['me']?.stageName, 'Ryan');
      expect(find.text('YOUR CREW'), findsOneWidget);
      expect(find.text('NO SHOWS YET'), findsOneWidget);

      await tester.tap(find.text('INVITE A FRIEND'));
      await settle(tester);
      expect(find.text('K7Q9 MX4P'), findsOneWidget);
    });

    testWidgets('the feed: every detail, Encore one Show, report another', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      crew.addShow(
        'maya',
        Show(
          id: 'm1',
          date: DateTime(2026, 11, 21, 7),
          venue: Venue.live,
          workoutType: WorkoutType.long,
          distanceMiles: 12,
          durationSeconds: 6600,
          effort: 7,
          feel: Feel.good,
          notes: 'Hills after mile 8.',
          song: const SongOfTheShow(
            title: 'Run',
            artist: 'Band',
            note: 'mile 3',
          ),
          live: const LiveDetails(
            routeName: 'River Trail',
            surface: Surface.trail,
            elevationGainFt: 420,
            weather: Weather(tempF: 48, conditions: Conditions.cloudy),
          ),
          createdAt: DateTime.utc(2026, 11, 21),
          updatedAt: DateTime.utc(2026, 11, 21),
        ),
        gearName: 'Speedgoat 6',
        encoreCount: 2,
      );
      crew.addShow('maya', mateShow('m2', miles: 3.1));
      crew.addShow('maya', mateShow('m3', miles: 9.9, crewPrivate: true));
      await pump(tester, const CrewScreen());

      expect(find.text('Maya'), findsWidgets);
      // The whole Show: effort and feel, route, weather, Gear, notes, song.
      expect(find.text('Effort 7/10 · Good set'), findsOneWidget);
      expect(find.text('River Trail · Trail'), findsOneWidget);
      expect(find.text('420 ft'), findsOneWidget);
      expect(find.text('48°F · Cloudy'), findsOneWidget);
      expect(find.text('Speedgoat 6'), findsOneWidget);
      expect(find.text('Hills after mile 8.'), findsOneWidget);
      expect(find.text('Run'), findsOneWidget);
      // A Studio Session sums up its Tracks.
      expect(
        find.text('2 Tracks · up to 7.2 mph · 1.5% incline'),
        findsOneWidget,
      );
      // Kept off the Crew: not on the feed.
      expect(find.text('9.90 mi'), findsNothing);

      // The toggle and the count are separate: the count lists who.
      const count = ValueKey('encore-count-maya:m1');
      expect(
        find.descendant(of: find.byKey(count), matching: find.text('2')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('encore-maya:m1')));
      await settle(tester);
      expect(
        find.descendant(of: find.byKey(count), matching: find.text('3')),
        findsOneWidget,
      );
      expect(crew.encores['maya:m1'], contains('me'));

      await tester.tap(find.byTooltip('Show options').last);
      await settle(tester);
      await tester.tap(find.text('Report this Show'));
      await settle(tester);
      await tester.tap(find.text('Spam or fake'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await settle(tester);
      expect(crew.reports.single.reason, 'Spam or fake');
      expect(crew.reports.single.postId, 'maya:m2');
      expect(find.text('3.10 mi'), findsNothing);
    });

    testWidgets('a friend’s Tour: book one featuring them', (tester) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      final race = DateTime.now().add(const Duration(days: 7 * 16));
      final tour = tourFor(race);
      crew.addTour('maya', tour);
      await pump(tester, const CrewScreen());

      await tester.tap(find.text('Maya').first);
      await settle(tester);
      expect(find.text(tour.name.toUpperCase()), findsOneWidget);
      await tester.tap(find.text('Book a Tour featuring Maya'));
      await settle(tester);
      expect(find.text('BOOK THE TOUR'), findsOneWidget);
      expect(booked?.userId, 'maya');
      expect(booked?.stageName, 'Maya');
      expect(booked?.raceDistance, RaceDistance.marathon);
      expect(booked?.tourName, tour.name);
      expect(
        sameRace(
          booked!.raceDate,
          booked!.raceDistance,
          race,
          RaceDistance.marathon,
        ),
        isTrue,
      );
    });

    testWidgets('co-headlining: no button, and a friend page with their week', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      final race = DateTime.now().add(const Duration(days: 7 * 16));
      crew.addTour('maya', tourFor(race));
      final mine = tourFor(race);
      await tester.runAsync(() => SembastTourRepository(db).save(mine));
      crew.addShow('maya', mateShow('m1', date: DateTime.now()));
      await pump(tester, const CrewScreen());

      await tester.tap(find.text('Maya').first);
      await settle(tester);
      expect(find.text('Book a Tour featuring Maya'), findsNothing);
      expect(find.text('Co-headlining ${mine.name}'), findsOneWidget);

      await tester.tap(find.text('See Maya’s Setlist'));
      await settle(tester);
      expect(find.text('MAYA'), findsOneWidget);
      expect(find.text('THE TOUR'), findsOneWidget);
      // One Show would make every record the same Show: no card yet.
      expect(find.text('GOLD RECORDS'), findsNothing);
      expect(find.text('CREW MATE'), findsOneWidget);
      expect(find.textContaining(' mi'), findsWidgets);
      expect(find.text('Co-headlining ${mine.name}'), findsOneWidget);
    });

    testWidgets('an invite link: see who sent it, join', (tester) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.profiles['maya'] = maya;
      crew.invites['P4TR8WHN'] = 'maya';
      await pump(tester, const SizedBox(), initial: '/crew/join/p4tr-8whn');
      expect(find.text('MAYA INVITES YOU TO THE CREW'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(StageButton),
          matching: find.text('JOIN THE CREW'),
        ),
      );
      await settle(tester);
      expect(crew.isCrew('me', 'maya'), isTrue);
      expect(find.text('YOUR CREW'), findsOneWidget);
    });

    testWidgets('an expired invite says so', (tester) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      await pump(tester, const SizedBox(), initial: '/crew/join/ZZZZZZZZ');
      expect(find.text('THIS INVITE HAS EXPIRED'), findsOneWidget);
    });

    testWidgets('the Tour tab features a co-headlining friend’s week', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      crew.addMate(const CrewProfile(userId: 'jo', stageName: 'Jo', color: 1));
      final race = raceInProgress();
      crew.addTour('maya', tourFor(race));
      // Jo races a week later: not co-headlining.
      crew.addTour('jo', tourFor(race.add(const Duration(days: 7))));
      // Logged on a planned day of this week, so it counts as done whatever
      // weekday the test runs on (today may be a rest day).
      final now = DateTime.now();
      final week = tourFor(race)
          .weekContaining(DateTime(now.year, now.month, now.day))!;
      final planned = week.shows.firstWhere((p) => !p.skipped).date;
      crew.addShow(
        'maya',
        mateShow('m1', miles: 4, date: planned.add(const Duration(hours: 7))),
      );
      await tester.runAsync(
        () => SembastTourRepository(db).save(tourFor(race)),
      );
      await pump(tester, const TourScreen());
      // The name is the title, under a FEATURING micro label.
      expect(find.text('FEATURING'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Jo'), findsNothing);
      expect(find.text('Co-headlining Opening Night'), findsNothing);
      expect(find.textContaining('4.0 mi so far'), findsOneWidget);
    });

    testWidgets('no Crew, no strip on the Tour tab', (tester) async {
      auth = FakeAuth();
      final race = DateTime.now().add(const Duration(days: 7 * 16));
      await tester.runAsync(
        () => SembastTourRepository(db).save(tourFor(race)),
      );
      await pump(tester, const TourScreen());
      expect(find.textContaining('FEATURING'), findsNothing);
    });

    testWidgets('your own Show: keep it off the Crew from the feed', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      final repo = SembastShowRepository(db);
      await tester.runAsync(() => repo.save(show('s1', notes: 'mine')));
      final saved = (await tester.runAsync(() => repo.getById('s1')))!;
      crew.addShow('me', saved);
      await pump(tester, const CrewScreen());
      expect(find.text('You'), findsOneWidget);
      expect(find.text('No Encores yet'), findsOneWidget);

      await tester.tap(find.byTooltip('Show options'));
      await settle(tester);
      await tester.tap(find.text('Keep off the Crew'));
      await settle(tester);
      expect(find.text('You'), findsNothing);
      final after = (await tester.runAsync(() => repo.getById('s1')))!;
      expect(after.crewPrivate, isTrue);
    });

    testWidgets('a friend page holds Gold Records once, at most 3 rows', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      for (var i = 0; i < 6; i++) {
        crew.addShow(
          'maya',
          mateShow(
            'm$i',
            miles: 3.5 + i,
            date: DateTime(2026, 11, 1 + i * 3, 7),
          ),
        );
      }
      await pump(tester, const SizedBox(), initial: '/crew/mate/maya');
      expect(find.text('GOLD RECORDS'), findsOneWidget);
      // The longest Show holds several records: one row names them all.
      expect(find.textContaining('Longest Show, '), findsOneWidget);
      final rows = find.descendant(
        of: find.ancestor(
          of: find.text('GOLD RECORDS'),
          matching: find.byType(SectionCard),
        ),
        matching: find.byIcon(Icons.album),
      );
      expect(rows.evaluate().length, lessThanOrEqualTo(3));
    });

    testWidgets('pending: one card to OK every Show, and honest copy', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(
        userId: 'me',
        stageName: 'Ryan',
        allActivityPending: true,
      );
      crew.addMate(maya);
      await pump(tester, const CrewScreen());
      expect(find.text('YOUR CREW SEES MORE NOW'), findsOneWidget);
      expect(find.textContaining('They see the Shows you shared.'), findsOne);
      expect(find.textContaining('They see every Show you log.'), findsNothing);

      await tester.tap(find.text('Sounds good'));
      await settle(tester);
      expect(crew.profiles['me']?.allActivityPending, isFalse);
      expect(crew.profiles['me']?.stageName, 'Ryan');
      expect(find.text('YOUR CREW SEES MORE NOW'), findsNothing);
      expect(find.textContaining('They see every Show you log.'), findsOne);
    });

    testWidgets('pending: Not now hides the card and changes nothing', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(
        userId: 'me',
        stageName: 'Ryan',
        allActivityPending: true,
      );
      crew.addMate(maya);
      await pump(tester, const CrewScreen());
      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(find.text('YOUR CREW SEES MORE NOW'), findsNothing);
      expect(crew.profiles['me']?.allActivityPending, isTrue);
      expect(find.textContaining('They see the Shows you shared.'), findsOne);
    });

    testWidgets('a long note opens in place with More', (tester) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      final long = List.filled(30, 'Rolling hills along the river.').join(' ');
      crew.addShow('maya', mateShow('m1', notes: long));
      await pump(tester, const CrewScreen());
      Text notes() => tester.widget<Text>(find.text(long));
      expect(notes().maxLines, 4);
      await tester.tap(find.text('More'));
      await tester.pump();
      expect(notes().maxLines, isNull);
      expect(find.text('Less'), findsOneWidget);
    });

    testWidgets('at 150% text the name keeps its whole width', (tester) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.addMate(maya);
      crew.addShow('maya', mateShow('m1'));
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, const CrewScreen(), size: const Size(390, 1600));
      expect(tester.takeException(), isNull);
      final name = find.descendant(
        of: find.byType(CrewPostCard),
        matching: find.text('Maya'),
      );
      expect(name, findsOneWidget);
      final p = tester.renderObject<RenderParagraph>(name);
      expect(p.didExceedMaxLines, isFalse);
      // Laid out at its full width: nothing was cut off.
      final full = TextPainter(
        text: p.text,
        textDirection: TextDirection.ltr,
        textScaler: p.textScaler,
      )..layout();
      expect(p.size.width, greaterThanOrEqualTo(full.width - 0.5));
      full.dispose();
      // The workout line wraps instead of ending in an ellipsis.
      final line = tester.widget<Text>(find.text('EASY · STUDIO SESSION'));
      expect(line.overflow, isNot(TextOverflow.ellipsis));
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
