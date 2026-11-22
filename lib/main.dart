import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/crew/crew_controller.dart';
import 'data/local/open_database.dart';
import 'data/music/music_search.dart';
import 'data/music/spotify_music_search.dart';
import 'data/providers.dart';
import 'data/push/push_api.dart';
import 'data/push/push_bridge.dart';
import 'data/push/push_controller.dart';
import 'data/remote/api_client.dart';
import 'data/remote/backend_config.dart';
import 'data/remote/cloudflare_auth_service.dart';
import 'data/remote/cloudflare_crew_service.dart';
import 'data/remote/cloudflare_remote_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Light clock and battery on the dark stage (iPhone status bar).
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final db = await openAppDatabase();
  final overrides = [databaseProvider.overrideWithValue(db)];
  final apiUrl = apiBaseUrl;
  if (apiUrl != null) {
    final httpClient = http.Client();
    final api = ApiClient(baseUrl: apiUrl, db: db, client: httpClient);
    await api.load();
    final auth = CloudflareAuthService(api);
    // A web sign-in comes back to this page with a one-time code in its
    // address, which this exchanges for a session.
    await auth.completeWebSignIn();
    overrides.addAll([
      authServiceProvider.overrideWithValue(auth),
      remoteStoreProvider.overrideWithValue(CloudflareRemoteStore(api)),
      crewServiceProvider.overrideWithValue(CloudflareCrewService(api)),
      pushApiProvider.overrideWithValue(CloudflarePushApi(api)),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        pushBridgeProvider.overrideWithValue(MethodChannelPushBridge.instance),
      // Guests get Spotify too: the search needs no sign-in.
      musicSearchProvider.overrideWith(
        (ref) => FallbackMusicSearch(
          SpotifyMusicSearch(apiUrl: apiUrl, client: httpClient),
          ref.watch(iTunesSearchProvider),
        ),
      ),
    ]);
  }
  runApp(ProviderScope(overrides: overrides, child: const SetlistApp()));
}
