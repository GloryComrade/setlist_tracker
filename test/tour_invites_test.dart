import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/crew_service.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/crew/tour_invites_controller.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/remote/api_client.dart';
import 'package:setlist_tracker/data/remote/cloudflare_crew_service.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/crew_screen.dart';
import 'package:setlist_tracker/ui/crew/tour_invite_picker.dart';
import 'package:setlist_tracker/ui/tour/book_tour_screen.dart';
import 'package:setlist_tracker/ui/tour/tour_screen.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';

import 'fakes/fake_backend.dart';

const _me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@example.com');
const _ryan = CrewProfile(userId: 'me', stageName: 'Ryan');
const _maya = CrewProfile(userId: 'maya', stageName: 'Maya', color: 2);
const _jo = CrewProfile(userId: 'jo', stageName: 'Jo', color: 1);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

Tour _tour(
  DateTime race, {
  RaceDistance distance = RaceDistance.half,
  String? name,
}) {
  final t = TourBuilder()
      .build(
        TourSetup(
          raceDate: race,
          raceDistance: distance,
          goal: TourGoal.finish,
          currentWeeklyMiles: 25,
          longestRecentRunMiles: 10,
          daysPerWeek: 4,
          headlinerWeekday: DateTime.sunday,
          venuePreference: VenuePreference.mix,
          easyPaceSecondsPerMile: 600,
        ),
      )
      .tour!;
  return name == null ? t : Tour.fromJson({...t.toJson(), 'name': name});
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('MemoryCrewService Tour invites follow the server rules', () {
    late MemoryCrewService ryan;
    late Tour spring;

    setUp(() {
      spring = _tour(_today().add(const Duration(days: 90)));
      ryan = MemoryCrewService(me: 'me')
        ..profiles['me'] = _ryan
        ..addMate(_maya)
        ..addMate(_jo)
        ..addTour('me', spring);
      ryan.profiles['sam'] = const CrewProfile(userId: 'sam', stageName: 'Sam');
    });

    MemoryCrewService viewOf(String who) => MemoryCrewService(me: who)
      ..profiles.addAll(ryan.profiles)
      ..links.addAll(ryan.links)
      ..blocks.addAll(ryan.blocks)
      ..tours.addAll(ryan.tours)
      ..tourInviteRows.addAll(ryan.tourInviteRows);

    test(
      'Crew mates only; strangers, blocked runners and you are skipped',
      () async {
        await ryan.block('jo');
        final invited = await ryan.inviteToTour(spring.id, [
          'maya',
          'jo',
          'sam',
          'me',
          'maya',
        ]);
        expect(invited, ['maya']);
        final maya = viewOf('maya');
        final got = await maya.tourInvites();
        expect(got, hasLength(1));
        expect(got.single.fromStageName, 'Ryan');
        expect(got.single.tourName, spring.name);
        expect(got.single.raceDistance, RaceDistance.half);
        expect(got.single.sameRaceAs(spring), isTrue);
        expect(await viewOf('jo').tourInvites(), isEmpty);
        expect(await ryan.tourInvites(), isEmpty);
      },
    );

    test('a Tour that is not backstage yet throws TourNotSynced', () async {
      expect(
        () => ryan.inviteToTour('nope', ['maya']),
        throwsA(isA<TourNotSyncedException>()),
      );
      ryan.myTour = (id) async => id == 'later' ? spring : null;
      expect(await ryan.inviteToTour('later', ['maya']), ['maya']);
    });

    test('dismissed, past and cancelled invites are gone', () async {
      await ryan.inviteToTour(spring.id, ['maya', 'jo']);
      final maya = viewOf('maya');
      final [invite] = await maya.tourInvites();
      await maya.dismissTourInvite(invite.id);
      expect(await maya.tourInvites(), isEmpty);
      // Asking again doesn't bring it back.
      await ryan.inviteToTour(spring.id, ['maya']);
      expect(ryan.tourInviteRows.where((r) => r.to == 'maya'), hasLength(1));

      final jo = viewOf('jo');
      expect(await jo.tourInvites(), hasLength(1));
      jo.today = spring.raceDate.add(const Duration(days: 1));
      expect(await jo.tourInvites(), isEmpty);
      jo.today = null;
      jo.tours['me'] = [spring.copyWith(deletedAt: DateTime.now())];
      expect(await jo.tourInvites(), isEmpty);
    });
  });

  test('sending syncs and tries again until the Tour is backstage', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('send.db');
    final spring = _tour(_today().add(const Duration(days: 90)));
    var asked = 0;
    final crew = MemoryCrewService(me: 'me')
      ..profiles['me'] = _ryan
      ..addMate(_maya)
      ..myTour = (id) async => ++asked < 3 ? null : spring;
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(FakeAuth(_me)),
        remoteStoreProvider.overrideWithValue(FakeRemote()),
        crewServiceProvider.overrideWithValue(crew),
      ],
    );
    addTearDown(c.dispose);
    final invites = c.read(tourInvitesProvider.notifier);
    expect(await invites.send(spring.id, ['maya']), ['maya']);
    expect(asked, 3);

    crew.myTour = (_) async => null;
    await expectLater(
      invites.send('never', ['maya']),
      throwsA(isA<TourNotSyncedException>()),
    );
  });

  group('CrewTourInvite JSON and the Worker', () {
    final json = {
      'id': 'inv1',
      'from': {'userId': 'u2', 'stageName': 'Ryan', 'color': 3},
      'tourId': 't1',
      'tourName': 'Spring 2027 Half Tour',
      'raceDate': '2027-02-20',
      'raceDistance': 'half',
      'createdAt': '2026-11-22T03:04:05.678Z',
    };

    test('fromJson reads the contract', () {
      final i = CrewTourInvite.fromJson(json)!;
      expect(i.fromUserId, 'u2');
      expect(i.fromStageName, 'Ryan');
      expect(i.fromColor, 3);
      expect(i.raceDate, DateTime(2027, 2, 20));
      expect(i.raceDistance, RaceDistance.half);
      expect(i.featuring.userId, 'u2');
      expect(i.featuring.tourName, 'Spring 2027 Half Tour');
      expect(
        tourRaceLine(i.raceDistance, i.raceDate),
        'Half Marathon · Sat, Feb 20',
      );
      expect(CrewTourInvite.fromJson({...json, 'raceDate': null}), isNull);
    });

    test('words for who was invited', () {
      expect(tourInvitesSentLine(['Maya']), 'Invite sent to Maya.');
      expect(
        tourInvitesSentLine(['Maya', 'Jo']),
        'Invites sent to Maya and Jo.',
      );
      expect(
        tourInvitesSentLine(['Maya', 'Jo', 'Sam']),
        'Invites sent to Maya, Jo and Sam.',
      );
      expect(
        tourInvitesSentLine(['a', 'b', 'c', 'd']),
        'Invites sent to 4 Crew mates.',
      );
    });

    test('CloudflareCrewService calls the routes', () async {
      final sent = <http.Request>[];
      var status = 200;
      final db = await newDatabaseFactoryMemory().openDatabase('ti.db');
      final api = ApiClient(
        baseUrl: 'https://api.test',
        db: db,
        client: MockClient((req) async {
          sent.add(req);
          if (status != 200) {
            return http.Response(
              jsonEncode({'error': 'not_found', 'message': 'x'}),
              status,
              headers: {'content-type': 'application/json'},
            );
          }
          final body = switch ((req.method, req.url.path)) {
            ('POST', _) => {
              'invited': ['u2'],
            },
            ('GET', _) => {
              'invites': [
                json,
                {...json, 'raceDate': 'nope'},
              ],
            },
            _ => null,
          };
          return body == null
              ? http.Response('', 204)
              : http.Response(
                  jsonEncode(body),
                  200,
                  headers: {'content-type': 'application/json'},
                );
        }),
      );
      await api.setSession(
        ApiSession.fromJson({
          'accessToken': 'a1',
          'refreshToken': 'r1',
          'expiresAt': apiTime(DateTime.now().add(const Duration(hours: 1))),
          'user': {'id': 'u1', 'name': 'Ryan', 'email': 'r@example.com'},
        }),
      );
      final s = CloudflareCrewService(api);

      expect(await s.inviteToTour('t1', ['u2', 'u3']), ['u2']);
      expect(sent.last.method, 'POST');
      expect(sent.last.url.path, '/api/crew/tour-invites');
      expect(jsonDecode(sent.last.body), {
        'tourId': 't1',
        'to': ['u2', 'u3'],
      });

      final list = await s.tourInvites();
      expect(sent.last.method, 'GET');
      expect(list.map((i) => i.id), ['inv1']);

      await s.dismissTourInvite('a/b');
      expect(sent.last.method, 'DELETE');
      expect(
        sent.last.url.toString(),
        endsWith('/api/crew/tour-invites/a%2Fb'),
      );

      status = 404;
      expect(
        () => s.inviteToTour('t9', ['u2']),
        throwsA(isA<TourNotSyncedException>()),
      );
      // Already gone is fine.
      await s.dismissTourInvite('gone');
    });
  });

  group('on screen', () {
    late Database db;
    late MemoryCrewService crew;
    TourFeaturing? booked;

    setUp(() async {
      booked = null;
      db = await newDatabaseFactoryMemory().openDatabase(
        'ti${DateTime.now().microsecondsSinceEpoch}.db',
      );
      crew = MemoryCrewService(me: 'me')
        ..profiles['me'] = _ryan
        ..myTour = SembastTourRepository(db).getById;
    });

    Future<void> pump(
      WidgetTester tester, {
      String initial = '/crew',
      TourFeaturing? featuring,
      bool realBooking = false,
    }) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
          GoRoute(
            path: '/tour',
            builder: (_, _) => const TourScreen(),
            routes: [
              GoRoute(
                path: 'book',
                builder: (_, s) {
                  booked = s.extra as TourFeaturing?;
                  return realBooking
                      ? BookTourScreen(featuring: featuring ?? booked)
                      : const Scaffold(body: Text('BOOKING'));
                },
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            authServiceProvider.overrideWithValue(FakeAuth(_me)),
            remoteStoreProvider.overrideWithValue(FakeRemote()),
            crewServiceProvider.overrideWithValue(crew),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('a received invite: Join the Tour books featuring them', (
      tester,
    ) async {
      crew.addMate(_maya);
      final race = _today().add(const Duration(days: 90));
      final mayas = _tour(race, name: 'Spring 2027 Half Tour');
      crew.addTourInvite('maya', mayas);
      await pump(tester);

      expect(find.text('TOUR INVITES'), findsOneWidget);
      expect(
        find.textContaining('Maya invited you on the Spring 2027 Half Tour'),
        findsOneWidget,
      );
      expect(find.text(tourRaceLine(RaceDistance.half, race)), findsOneWidget);
      expect(find.text('90 days to Opening Night'), findsOneWidget);

      await tester.tap(find.text('Join the Tour'));
      await _settle(tester);
      expect(find.text('BOOKING'), findsOneWidget);
      expect(booked?.userId, 'maya');
      expect(booked?.stageName, 'Maya');
      expect(booked?.tourName, 'Spring 2027 Half Tour');
      expect(booked?.raceDistance, RaceDistance.half);
      expect(booked?.raceDate, race);
    });

    testWidgets('Not this time dismisses the invite', (tester) async {
      crew.addMate(_maya);
      final row = crew.addTourInvite(
        'maya',
        _tour(_today().add(const Duration(days: 60))),
      );
      await pump(tester);
      await tester.tap(find.text('Not this time'));
      await _settle(tester);
      expect(row.dismissed, isTrue);
      expect(find.text('TOUR INVITES'), findsNothing);
    });

    testWidgets('no card for a race you already co-headline', (tester) async {
      crew.addMate(_maya);
      final race = _today().add(const Duration(days: 60));
      crew.addTourInvite('maya', _tour(race));
      await tester.runAsync(() => SembastTourRepository(db).save(_tour(race)));
      await pump(tester);
      expect(find.text('TOUR INVITES'), findsNothing);
    });

    testWidgets('the Tour tab: Invite to this Tour', (tester) async {
      final race = _today().add(const Duration(days: 80));
      final mine = _tour(race);
      await tester.runAsync(() => SembastTourRepository(db).save(mine));
      crew.addMate(_maya);
      crew.addMate(_jo);
      // Maya already races the same Opening Night.
      crew.addTour('maya', _tour(race));
      await pump(tester, initial: '/tour');

      await tester.tap(find.byTooltip('Tour options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite to this Tour'));
      await _settle(tester);
      expect(find.text('INVITE TO THIS TOUR'), findsOneWidget);
      expect(find.text('Co-headlining'), findsOneWidget);
      final send = find.widgetWithText(FilledButton, 'Send invite');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.tap(find.text('Jo'));
      await tester.pump();
      await tester.tap(send);
      await _settle(tester);
      expect(find.text('INVITE TO THIS TOUR'), findsNothing);
      expect(find.text('Invite sent to Jo.'), findsOneWidget);
      expect(crew.tourInviteRows.map((r) => (r.to, r.tour.id)), [
        ('jo', mine.id),
      ]);
    });

    testWidgets('no Invite to this Tour without a stage name', (tester) async {
      crew.profiles.remove('me');
      await tester.runAsync(
        () =>
            SembastTourRepository(db)
                .save(_tour(_today().add(const Duration(days: 80)))),
      );
      await pump(tester, initial: '/tour');
      await tester.tap(find.byTooltip('Tour options'));
      await tester.pumpAndSettle();
      expect(find.text('Rebook The Tour'), findsOneWidget);
      expect(find.text('Invite to this Tour'), findsNothing);
    });

    Future<void> finishQuiz(WidgetTester tester) async {
      Future<void> tap(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      Future<void> next() async {
        await tester.tap(find.byType(StageButton));
        await tester.pumpAndSettle();
      }

      await tap('Finish strong');
      await next();
      await tester.enterText(find.byType(TextField), '15');
      await tester.pump();
      await next();
      await tester.enterText(find.byType(TextField), '5');
      await tester.pump();
      await next();
      await tap('No recent race');
      await next();
      await next();
      await next();
      await tap(VenuePreference.live.label);
      await next();
      expect(find.text('YOUR TOUR'), findsOneWidget);
    }

    testWidgets('Book The Tour: Bring your Crew, sent once it is booked', (
      tester,
    ) async {
      crew.addMate(_maya);
      crew.addMate(_jo);
      final race = _today().add(const Duration(days: 7 * 14));
      crew.addTour('maya', _tour(race));
      await pump(
        tester,
        initial: '/tour/book',
        realBooking: true,
        featuring: TourFeaturing(
          userId: 'maya',
          stageName: 'Maya',
          raceDate: race,
          raceDistance: RaceDistance.half,
          tourName: 'Maya’s Half',
        ),
      );
      await finishQuiz(tester);

      await tester.ensureVisible(find.text('BRING YOUR CREW'));
      expect(find.text('Featuring'), findsOneWidget);
      await tester.tap(find.text('Jo'));
      await tester.pump();
      await tester.tap(find.byType(StageButton));
      await _settle(tester);

      final saved = (await tester.runAsync(
        () => SembastTourRepository(db).watchAll().first,
      ))!;
      expect(saved, hasLength(1));
      expect(crew.tourInviteRows.map((r) => (r.to, r.tour.id)), [
        ('jo', saved.single.id),
      ]);
      // After the "booked" line.
      expect(find.textContaining('booked.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Invite sent to Jo.'), findsOneWidget);
    });

    testWidgets('Book The Tour with no Crew offers Invite a friend', (
      tester,
    ) async {
      await pump(tester, initial: '/tour/book', realBooking: true);
      await tester.tap(find.text('Half Marathon'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StageButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help me pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StageButton));
      await tester.pumpAndSettle();
      await finishQuiz(tester);
      await tester.ensureVisible(find.text('BRING YOUR CREW'));
      await tester.tap(find.text('Invite a friend'));
      await _settle(tester);
      expect(find.text('INVITE TO THE CREW'), findsOneWidget);
    });
  });
}
