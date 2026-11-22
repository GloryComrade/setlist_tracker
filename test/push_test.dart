import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/push/push_api.dart';
import 'package:setlist_tracker/data/push/push_bridge.dart';
import 'package:setlist_tracker/data/push/push_controller.dart';
import 'package:setlist_tracker/data/settings/app_settings.dart';
import 'package:setlist_tracker/data/sync/sync_controller.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/crew_screen.dart';
import 'package:setlist_tracker/ui/settings/settings_screen.dart';

import 'fakes/fake_backend.dart';

const me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@example.com');
const title = 'Tell me when my Crew plays a Show';

class FakeBridge implements PushBridge {
  FakeBridge({this.status = PushPermission.notDetermined, this.grant = true});
  PushPermission status;
  bool grant;
  int prompts = 0;
  int registers = 0;
  final tokenCtl = StreamController<PushToken>.broadcast();
  final openCtl = StreamController<String>.broadcast();

  @override
  bool get supported => true;
  @override
  Future<PushPermission> permission() async => status;
  @override
  Future<bool> requestPermission() async {
    prompts++;
    status = grant ? PushPermission.authorized : PushPermission.denied;
    return grant;
  }

  @override
  Future<void> register() async {
    registers++;
    tokenCtl.add(PushToken('ab' * 32));
  }

  @override
  Stream<PushToken> get tokens => tokenCtl.stream;
  @override
  Stream<String> get opens => openCtl.stream;
}

class FakePushApi implements PushApi {
  final registered = <String>[];
  final forgotten = <String>[];
  @override
  Future<void> registerDevice(String token, {required bool sandbox}) async =>
      registered.add(token);
  @override
  Future<void> forgetDevice(String token) async => forgotten.add(token);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  test('profile reads notifyShows, on by default', () {
    expect(
      CrewProfile.fromJson({'userId': 'a', 'stageName': 'A'}).notifyShows,
      isTrue,
    );
    expect(
      CrewProfile.fromJson({
        'userId': 'a',
        'stageName': 'A',
        'notifyShows': false,
      }).notifyShows,
      isFalse,
    );
  });

  group('push', () {
    late MemoryCrewService crew;
    late FakeBridge bridge;
    late FakePushApi api;
    late ProviderContainer container;

    setUp(() {
      crew = MemoryCrewService(me: 'me')
        ..profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      bridge = FakeBridge();
      api = FakePushApi();
    });

    Future<void> pump(
      WidgetTester tester,
      String location, {
      bool push = true,
    }) async {
      tester.view.physicalSize = const Size(400, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = await tester.runAsync(
        () => newDatabaseFactoryMemory().openDatabase(
          'push${DateTime.now().microsecondsSinceEpoch}.db',
        ),
      );
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db!),
            authServiceProvider.overrideWithValue(FakeAuth(me)),
            remoteStoreProvider.overrideWithValue(FakeRemote()),
            crewServiceProvider.overrideWithValue(crew),
            settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
            if (push) pushBridgeProvider.overrideWithValue(bridge),
            if (push) pushApiProvider.overrideWithValue(api),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              ref.listen(pushControllerProvider, (_, _) {});
              return MaterialApp.router(
                theme: AppTheme.dark(),
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('no switch where notifications aren’t supported', (
      tester,
    ) async {
      await pump(tester, '/settings', push: false);
      expect(find.text('THE CREW'), findsOneWidget);
      expect(find.text(title), findsNothing);
    });

    testWidgets('the switch asks iOS, registers the phone and saves', (
      tester,
    ) async {
      await pump(tester, '/settings');
      final tile = find.widgetWithText(SwitchListTile, title);
      await tester.ensureVisible(tile);
      // Not allowed yet, so it shows off.
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await settle(tester);
      expect(bridge.prompts, 1);
      expect(api.registered, ['ab' * 32]);
      expect(crew.profiles['me']!.notifyShows, isTrue);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.tap(tile);
      await settle(tester);
      expect(crew.profiles['me']!.notifyShows, isFalse);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      // Signing out forgets this phone on the server.
      await tester.runAsync(
        () => container
            .read(syncControllerProvider.notifier)
            .signOut(force: true),
      );
      expect(api.forgotten, ['ab' * 32]);
    });

    testWidgets(
      'a denied prompt leaves the switch off and says where to fix it',
      (tester) async {
        bridge.grant = false;
        await pump(tester, '/settings');
        final tile = find.widgetWithText(SwitchListTile, title);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await settle(tester);
        expect(
          find.textContaining('in the iPhone’s Settings app'),
          findsWidgets,
        );
        expect(tester.widget<SwitchListTile>(tile).value, isFalse);
        expect(api.registered, isEmpty);
      },
    );

    testWidgets('already allowed: registers at start, no card on the Crew', (
      tester,
    ) async {
      bridge.status = PushPermission.authorized;
      crew.addMate(const CrewProfile(userId: 'maya', stageName: 'Maya'));
      await pump(tester, '/crew');
      expect(bridge.registers, 1);
      expect(api.registered, ['ab' * 32]);
      expect(find.text('KNOW WHEN YOUR CREW PLAYS'), findsNothing);
    });

    testWidgets('the Crew card asks once there’s a Crew; Not now hides it', (
      tester,
    ) async {
      crew.addMate(const CrewProfile(userId: 'maya', stageName: 'Maya'));
      await pump(tester, '/crew');
      expect(find.text('KNOW WHEN YOUR CREW PLAYS'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(find.text('KNOW WHEN YOUR CREW PLAYS'), findsNothing);
      expect(bridge.prompts, 0);
    });

    testWidgets('Turn on asks iOS and registers', (tester) async {
      crew.addMate(const CrewProfile(userId: 'maya', stageName: 'Maya'));
      await pump(tester, '/crew');
      await tester.tap(find.text('Turn on'));
      await settle(tester);
      expect(bridge.prompts, 1);
      expect(api.registered, ['ab' * 32]);
      expect(find.text('KNOW WHEN YOUR CREW PLAYS'), findsNothing);
      expect(find.textContaining('You’ll hear when your Crew'), findsWidgets);
    });
  });
}
