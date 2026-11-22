import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/crew/crew_controller.dart';
import 'data/local/open_database.dart';
import 'data/providers.dart';
import 'data/remote/backend_config.dart';
import 'data/remote/supabase_auth_service.dart';
import 'data/remote/supabase_crew_service.dart';
import 'data/remote/supabase_remote_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Light clock and battery on the dark stage (iPhone status bar).
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final db = await openAppDatabase();
  final overrides = [databaseProvider.overrideWithValue(db)];
  if (backendConfigured) {
    // Also finishes a web sign-in: the page comes back with a code in its
    // address, which this exchanges for a session.
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    final client = Supabase.instance.client;
    overrides.addAll([
      authServiceProvider.overrideWithValue(SupabaseAuthService(client)),
      remoteStoreProvider.overrideWithValue(SupabaseRemoteStore(client)),
      crewServiceProvider.overrideWithValue(SupabaseCrewService(client)),
    ]);
  }
  runApp(ProviderScope(overrides: overrides, child: const SetlistApp()));
}
