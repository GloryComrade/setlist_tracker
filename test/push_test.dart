import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/push/push_controller.dart';
import 'package:setlist_tracker/data/push/push_service.dart';
import 'package:setlist_tracker/data/push/push_service_native.dart';
import 'package:setlist_tracker/data/settings/app_settings.dart';
import 'package:setlist_tracker/data/sync/sync_controller.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/crew_screen.dart';
import 'package:setlist_tracker/ui/crew/push_opens.dart';
import 'package:setlist_tracker/ui/settings/settings_screen.dart';

import 'fakes/fake_backend.dart';

const me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@example.com');
const token = PushToken('a1b2c3d4e5f60718293a4b5c6d7e8f90', 'sandbox');

/// iOS's side, by hand.
class FakePushService implements PushService {
  FakePushService({this.permission = PushPermission.notDetermined});

  PushPermission permission;
  var asks = 0;
  var registers = 0;
  var settingsOpened = 0;
  Map<String, Object?>? launchedFrom;
  final tokenCtl = StreamController<PushToken>.broadcast();
  final openCtl = StreamController<Map<String, Object?>>.broadcast();

  @override
  bool get available => true;

  @override
  Future<PushPermission> status() async => permission;

  @override
  Future<bool> requestPermission() async {
    asks++;
    permission = PushPermission.authorized;
    tokenCtl.add(token);
    return true;
  }

  @override
  Future<void> register() async {
    registers++;
    if (permission.allowed) tokenCtl.add(token);
  }

  @override
  Stream<PushToken> get tokens => tokenCtl.stream;

  @override
  Stream<Map<String, Object?>> get opened => openCtl.stream;

  @override
  Future<Map<String, Object?>?> initialMessage() async {
    final m = launchedFrom;
    launchedFrom = null;
    return m;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class FakePushDevices implements PushDevices {
  final calls = <String>[];

  @override
  Future<void> register(PushToken t) async =>
      calls.add('PUT ${t.token} ${t.environment}');

  @override
  Future<void> unregister(String t) async => calls.add('DELETE $t');
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
  late Database db;
  late MemoryCrewService crew;
  late FakeAuth auth;
  late FakePushService push;
  late FakePushDevices devices;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase(
      'push${DateTime.now().microsecondsSinceEpoch}.db',
    );
    crew = MemoryCrewService(me: 'me');
    crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
    auth = FakeAuth(me);
    push = FakePushService();
    devices = FakePushDevices();
  });

  List<Override> overrides({bool withPush = true}) => [
    databaseProvider.overrideWithValue(db),
    authServiceProvider.overrideWithValue(auth),
    remoteStoreProvider.overrideWithValue(FakeRemote()),
    crewServiceProvider.overrideWithValue(crew),
    settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
    if (withPush) pushServiceProvider.overrideWithValue(push),
    pushDevicesProvider.overrideWithValue(devices),
  ];

  Future<GoRouter> pump(
    WidgetTester tester, {
    String initial = '/crew',
    bool withPush = true,
  }) async {
    tester.view.physicalSize = const Size(400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(withPush: withPush),
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: router,
          builder: (_, child) => PushOpens(router: router, child: child!),
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  testWidgets('first Crew visit asks iOS once, then sends the token', (
    tester,
  ) async {
    await pump(tester);
    expect(push.asks, 1);
    expect(devices.calls, ['PUT ${token.token} sandbox']);

    // A later launch: remembered on the device, never asked again, but the
    // token is sent again.
    push.permission = PushPermission.denied;
    await tester.pumpWidget(const SizedBox());
    devices.calls.clear();
    await pump(tester);
    expect(push.asks, 1);
    expect(devices.calls, isEmpty);
  });

  testWidgets('no stage name yet: no prompt', (tester) async {
    crew.profiles.clear();
    await pump(tester);
    expect(push.asks, 0);
    expect(devices.calls, isEmpty);
  });

  testWidgets('already allowed: registers at launch, no prompt', (
    tester,
  ) async {
    push.permission = PushPermission.authorized;
    await pump(tester, initial: '/');
    expect(push.asks, 0);
    expect(devices.calls, ['PUT ${token.token} sandbox']);
  });

  testWidgets('a tapped notification opens The Crew, also at cold start', (
    tester,
  ) async {
    push.permission = PushPermission.authorized;
    push.launchedFrom = {'type': 'show', 'postId': 'sam:s1'};
    final router = await pump(tester, initial: '/');
    expect(find.byType(CrewScreen), findsOneWidget);

    router.go('/');
    await settle(tester);
    expect(find.text('HOME'), findsOneWidget);
    push.openCtl.add({'type': 'shoutout', 'postId': 'me:s2'});
    await settle(tester);
    expect(find.byType(CrewScreen), findsOneWidget);
  });

  testWidgets('Settings: both switches, both off takes the token back', (
    tester,
  ) async {
    push.permission = PushPermission.authorized;
    await pump(tester, initial: '/settings');
    expect(devices.calls, ['PUT ${token.token} sandbox']);
    final shows = find.widgetWithText(
      SwitchListTile,
      'When my Crew logs a Show',
    );
    final shoutouts = find.widgetWithText(
      SwitchListTile,
      'Shout-outs on my Shows',
    );
    expect(tester.widget<SwitchListTile>(shows).value, isTrue);
    expect(tester.widget<SwitchListTile>(shoutouts).value, isTrue);
    expect(find.text('Open iOS Settings'), findsNothing);

    await tester.ensureVisible(shows);
    await tester.tap(shows);
    await settle(tester);
    expect(crew.profiles['me']!.pushShows, isFalse);
    expect(crew.profiles['me']!.pushShoutouts, isTrue);
    expect(tester.widget<SwitchListTile>(shows).value, isFalse);
    expect(devices.calls, hasLength(1)); // One switch is still on.

    await tester.tap(shoutouts);
    await settle(tester);
    expect(crew.profiles['me']!.pushShoutouts, isFalse);
    expect(devices.calls.last, 'DELETE ${token.token}');

    await tester.tap(shoutouts);
    await settle(tester);
    expect(devices.calls.last, 'PUT ${token.token} sandbox');
  });

  testWidgets('Settings: denied in iOS shows the way to iOS Settings', (
    tester,
  ) async {
    push.permission = PushPermission.denied;
    await pump(tester, initial: '/settings');
    expect(
      find.text('Notifications are off for Setlist Tracker in iOS Settings.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Open iOS Settings'));
    await tester.tap(find.text('Open iOS Settings'));
    await settle(tester);
    expect(push.settingsOpened, 1);
  });

  testWidgets('Settings on web: no notification switches', (tester) async {
    await pump(tester, initial: '/settings', withPush: false);
    expect(find.text('THE CREW'), findsOneWidget);
    expect(find.text('When my Crew logs a Show'), findsNothing);
    expect(find.text('Shout-outs on my Shows'), findsNothing);
  });

  testWidgets('signing out takes the token back first', (tester) async {
    push.permission = PushPermission.authorized;
    await pump(tester, initial: '/settings');
    expect(devices.calls, ['PUT ${token.token} sandbox']);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    var done = false;
    unawaited(
      container
          .read(syncControllerProvider.notifier)
          .signOut()
          .then((_) => done = true),
    );
    await settle(tester);
    expect(done, isTrue);
    expect(devices.calls.last, 'DELETE ${token.token}');
    expect(auth.current, isNull);
  });

  group('NativePushService', () {
    const channel = MethodChannel('setlist/push');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('calls iOS and reads what it sends back', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final asked = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked.add(call.method);
        return switch (call.method) {
          'status' => 'denied',
          'requestPermission' => true,
          'initialMessage' => {'type': 'show', 'postId': 'sam:s1'},
          _ => null,
        };
      });
      final s = NativePushService(channel);
      expect(await s.status(), PushPermission.denied);
      expect(await s.requestPermission(), isTrue);
      expect(await s.initialMessage(), {'type': 'show', 'postId': 'sam:s1'});
      await s.openSettings();
      expect(asked, [
        'status',
        'requestPermission',
        'initialMessage',
        'openSettings',
      ]);

      final tokens = <PushToken>[];
      final opened = <Map<String, Object?>>[];
      s.tokens.listen(tokens.add);
      s.opened.listen(opened.add);
      Future<void> fromIos(String method, Object? args) =>
          messenger.handlePlatformMessage(
            'setlist/push',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, args),
            ),
            (_) {},
          );
      await fromIos('token', {'token': 'abcd' * 8, 'environment': 'sandbox'});
      await fromIos('token', {'token': 'ef01' * 8, 'environment': 'x'});
      await fromIos('opened', {'type': 'shoutout', 'postId': 'me:s2'});
      await Future<void>.delayed(Duration.zero);
      expect(tokens, [
        PushToken('abcd' * 8, 'sandbox'),
        PushToken('ef01' * 8, 'production'),
      ]);
      expect(opened.single['postId'], 'me:s2');
    });

    test('unknown status reads as not asked yet', () {
      expect(PushPermission.fromName('nope'), PushPermission.notDetermined);
      expect(PushPermission.provisional.allowed, isTrue);
      expect(PushPermission.denied.allowed, isFalse);
    });
  });

  test('profile JSON carries both switches, on unless false', () {
    final p = CrewProfile.fromJson(const {
      'userId': 'me',
      'stageName': 'Ryan',
      'pushShows': false,
    });
    expect(p.pushShows, isFalse);
    expect(p.pushShoutouts, isTrue);
    expect(p.copyWith(pushShoutouts: false).pushShoutouts, isFalse);
  });
}
