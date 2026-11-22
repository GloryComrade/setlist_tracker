import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/app_version.dart';
import 'package:setlist_tracker/data/crew/crew_controller.dart';
import 'package:setlist_tracker/data/crew/crew_service.dart';
import 'package:setlist_tracker/data/crew/memory_crew_service.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/settings/app_settings.dart';
import 'package:setlist_tracker/logic/avatar_photo.dart';
import 'package:setlist_tracker/logic/spotify_links.dart';
import 'package:setlist_tracker/models/avatar_badge.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/crew/avatar_badges.dart';
import 'package:setlist_tracker/ui/crew/crew_widgets.dart';
import 'package:setlist_tracker/ui/settings/profile_picture.dart';
import 'package:setlist_tracker/ui/settings/settings_button.dart';
import 'package:setlist_tracker/ui/settings/settings_screen.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';

import 'fakes/fake_backend.dart';

const me = PassHolder(id: 'me', name: 'Ryan Runner', email: 'r@example.com');

/// A real JPEG, [w] × [h], left half magenta and right half teal.
Uint8List photo(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p
      ..r = p.x < w / 2 ? 224 : 14
      ..g = p.x < w / 2 ? 21 : 116
      ..b = p.x < w / 2 ? 122 : 144;
  }
  return img.encodeJpg(image);
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
  group('AppSettings', () {
    test('defaults, JSON round trip, and bad values fall back', () {
      const d = AppSettings();
      expect(d.newShowsOffCrew, isFalse);
      expect(d.headlinerWeekday, DateTime.sunday);
      expect(d.tourVenue, isNull);
      expect(d.musicApp, MusicApp.spotify);
      expect(d.healthImport, isTrue);

      final s = d.copyWith(
        newShowsOffCrew: true,
        headlinerWeekday: DateTime.saturday,
        tourVenue: VenuePreference.studio,
        musicApp: MusicApp.appleMusic,
        healthImport: false,
      );
      expect(AppSettings.fromJson(s.toJson()), s);
      expect(s.copyWith(clearTourVenue: true).tourVenue, isNull);
      expect(AppSettings.fromJson(const {}), d);
      expect(
        AppSettings.fromJson(const {
          'headlinerWeekday': 9,
          'tourVenue': 'moon',
          'musicApp': 'tape',
        }),
        d,
      );
    });

    test('kept in Sembast, and loaded by the controller', () async {
      final db = await newDatabaseFactoryMemory().openDatabase('s.db');
      final store = SembastSettingsStore(db);
      expect(await store.load(), const AppSettings());
      const saved = AppSettings(headlinerWeekday: DateTime.saturday);
      await store.save(saved);
      expect(await store.load(), saved);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appSettingsProvider), saved);
      expect(
        container.read(tourQuizDefaultsProvider).headlinerWeekday,
        DateTime.saturday,
      );
      await container
          .read(appSettingsProvider.notifier)
          .update((s) => s.copyWith(tourVenue: VenuePreference.mix));
      expect((await store.load()).tourVenue, VenuePreference.mix);
      expect(
        container.read(tourQuizDefaultsProvider).venue,
        VenuePreference.mix,
      );
    });
  });

  group('profile pictures', () {
    test('a photo becomes a 256 px square JPEG under 64 KB', () {
      final out = squareAvatarJpeg(photo(600, 300))!;
      expect(out.length, lessThanOrEqualTo(kAvatarPhotoMaxBytes));
      expect(out.sublist(0, 3), [0xff, 0xd8, 0xff]);
      final back = img.decodeJpg(out)!;
      expect(back.width, 256);
      expect(back.height, 256);
      // The middle square: the seam between the halves stays centered.
      final left = back.getPixel(64, 128);
      final right = back.getPixel(192, 128);
      expect(left.r, greaterThan(150));
      expect(right.g, greaterThan(80));
      expect(squareAvatarJpeg(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });

    test('the badge list matches the server, and every badge has art', () {
      final ts = File('backend/src/avatars.ts').readAsStringSync();
      final list = RegExp(r'AVATAR_BADGES = \[([^\]]*)\]')
          .firstMatch(ts)!
          .group(1)!;
      final server = RegExp(r'"([a-z-]+)"')
          .allMatches(list)
          .map((m) => m.group(1))
          .toList();
      expect(server, kAvatarBadges.keys.toList());
      expect(kAvatarBadges, hasLength(24));
      for (final id in kAvatarBadges.keys) {
        expect(hasBadgeArt(id), isTrue, reason: id);
      }
    });

    test('the app version matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final v = RegExp(
        r'^version: (\S+)$',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);
      expect(kAppVersion, v);
    });

    test('Apple Music search link', () {
      expect(
        appleMusicSearchUri('Lose Yourself', 'Eminem').toString(),
        'https://music.apple.com/us/search?term=Lose+Yourself+Eminem',
      );
    });

    testWidgets('CrewAvatar: photo over badge over initial', (tester) async {
      final crew = MemoryCrewService(me: 'me')
        ..profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan')
        ..addPhoto('me', photo(64, 64));
      final url = crew.profiles['me']!.avatarUrl!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [crewServiceProvider.overrideWithValue(crew)],
          child: const MaterialApp(
            home: Column(
              children: [
                CrewAvatar(name: 'Ryan', color: 1),
                CrewAvatar(name: 'Ryan', color: 1, badge: 'crown'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('R'), findsOneWidget);
      expect(find.byType(BadgeGlyph), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [crewServiceProvider.overrideWithValue(crew)],
          child: MaterialApp(
            home: CrewAvatar(
              name: 'Ryan',
              color: 1,
              badge: 'crown',
              photoUrl: url,
            ),
          ),
        ),
      );
      // The badge shows until the photo arrives, then the photo covers it.
      expect(find.byType(BadgeGlyph), findsOneWidget);
      await settle(tester);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('Settings screen', () {
    late MemoryCrewService crew;
    late FakeAuth auth;
    late MemorySettingsStore store;
    late GoRouter router;

    setUp(() {
      crew = MemoryCrewService(me: 'me');
      auth = FakeAuth(me);
      store = MemorySettingsStore();
    });

    Future<void> pump(
      WidgetTester tester, {
      Widget? home,
      bool signedIn = true,
      PickPhoto? pick,
    }) async {
      tester.view.physicalSize = const Size(400, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (!signedIn) auth = FakeAuth();
      final db = await tester.runAsync(
        () => newDatabaseFactoryMemory().openDatabase(
          'settings${DateTime.now().microsecondsSinceEpoch}.db',
        ),
      );
      router = GoRouter(
        initialLocation: home == null ? '/settings' : '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PosterCornerAction(
              action: const SettingsAvatarButton(),
              child: Scaffold(body: home ?? const SizedBox()),
            ),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db!),
            authServiceProvider.overrideWithValue(auth),
            remoteStoreProvider.overrideWithValue(FakeRemote()),
            crewServiceProvider.overrideWithValue(crew),
            settingsStoreProvider.overrideWithValue(store),
            if (pick != null) pickPhotoProvider.overrideWithValue(pick),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('signed out: a nudge, the Backstage Pass and About', (
      tester,
    ) async {
      await pump(tester, signedIn: false);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.textContaining('to pick a stage name'), findsOneWidget);
      expect(find.text('THE CREW'), findsNothing);
      expect(find.text('BACKSTAGE PASS'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('THE TOUR'), findsOneWidget);
      expect(find.text('SONG OF THE SHOW'), findsOneWidget);
      // Not an iPhone: no Apple Health.
      expect(find.text('APPLE HEALTH'), findsNothing);
      expect(find.text('Setlist Tracker $kAppVersion'), findsOneWidget);
    });

    testWidgets('every tab poster opens Settings from its corner', (
      tester,
    ) async {
      await pump(
        tester,
        signedIn: false,
        home: const PosterHeader(title: 'THE SETLIST'),
      );
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('pick a badge, then upload a photo, then remove it', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(
        userId: 'me',
        stageName: 'Ryan',
        color: 2,
      );
      await pump(tester, pick: () async => photo(800, 600));
      expect(find.text('YOUR PROFILE'), findsOneWidget);
      expect(find.text('Ryan'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Crown badge'));
      await settle(tester);
      expect(crew.profiles['me']!.avatarBadge, 'crown');
      expect(find.text('Picture saved.'), findsOneWidget);

      await tester.tap(find.text('Upload a photo'));
      await settle(tester);
      expect(find.text('Use this photo?'), findsOneWidget);
      await tester.tap(find.text('Use photo'));
      await settle(tester);
      final uploaded = crew.photos['me']!;
      expect(img.decodeJpg(uploaded)!.width, 256);
      expect(crew.profiles['me']!.avatarUrl, isNotNull);
      // The badge stays saved underneath the photo.
      expect(crew.profiles['me']!.avatarBadge, 'crown');
      expect(find.text('Change photo'), findsOneWidget);

      await tester.tap(find.text('Remove photo'));
      await settle(tester);
      expect(find.textContaining('Crown badge instead'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(crew.profiles['me']!.avatarUrl, isNull);
      expect(find.text('Upload a photo'), findsOneWidget);
    });

    testWidgets('The Crew: new Shows off by default, unblock a runner', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.profiles['sam'] = const CrewProfile(userId: 'sam', stageName: 'Sam');
      crew.blocks['me'] = {'sam'};
      await pump(tester);
      expect(find.text('THE CREW'), findsOneWidget);
      await tester.tap(find.text('Keep new Shows off the Crew'));
      await settle(tester);
      expect(store.saved.newShowsOffCrew, isTrue);

      expect(find.text('Sam'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await settle(tester);
      expect(crew.blocks['me'], isEmpty);
      expect(find.textContaining('Nobody.'), findsOneWidget);
    });

    testWidgets('The Crew: Seen by switch, on by default, forgets views', (
      tester,
    ) async {
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      crew.views['post-1'] = {'me': DateTime.utc(2026, 11, 1)};
      await pump(tester);
      const title = 'Let my Crew know when I’ve seen their Shows';
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining('Off: your views aren’t recorded'), findsOne);
      tile() => find.widgetWithText(SwitchListTile, title);
      expect(tester.widget<SwitchListTile>(tile()).value, isTrue);

      await tester.ensureVisible(tile());
      await tester.tap(tile());
      await settle(tester);
      expect(crew.profiles['me']!.shareViews, isFalse);
      expect(crew.views['post-1'], isEmpty);
      expect(tester.widget<SwitchListTile>(tile()).value, isFalse);

      await tester.tap(tile());
      await settle(tester);
      expect(crew.profiles['me']!.shareViews, isTrue);
      expect(tester.widget<SwitchListTile>(tile()).value, isTrue);
    });

    testWidgets('The Crew: Seen by switch says so when it can’t save', (
      tester,
    ) async {
      crew = _OfflineViews();
      crew.profiles['me'] = const CrewProfile(userId: 'me', stageName: 'Ryan');
      await pump(tester);
      final tile = find.widgetWithText(
        SwitchListTile,
        'Let my Crew know when I’ve seen their Shows',
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await settle(tester);
      expect(find.text('Couldn’t reach the Crew.'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    });

    testWidgets('Tour defaults and the music app are saved', (tester) async {
      await pump(tester, signedIn: false);
      await tester.tap(find.text('Sunday'));
      await settle(tester);
      await tester.tap(find.text('Friday').last);
      await settle(tester);
      expect(store.saved.headlinerWeekday, DateTime.friday);

      await tester.tap(find.text('Ask me'));
      await settle(tester);
      await tester.tap(find.text(VenuePreference.studio.label).last);
      await settle(tester);
      expect(store.saved.tourVenue, VenuePreference.studio);

      await tester.tap(find.text('Apple Music'));
      await settle(tester);
      expect(store.saved.musicApp, MusicApp.appleMusic);
    });
  });
}

/// A Crew service whose Seen by switch can't reach the server.
class _OfflineViews extends MemoryCrewService {
  _OfflineViews() : super(me: 'me');

  @override
  Future<CrewProfile> setShareViews(CrewProfile profile, bool on) async =>
      throw const CrewException('offline');
}
