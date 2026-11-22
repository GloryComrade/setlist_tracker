import 'package:sembast/sembast.dart';

/// Small on-device settings (shared with the Setlist's Backstage Pass nudge).
/// Not synced: each device remembers its own last import.
final _prefs = StoreRef<String, Object?>('app_prefs');
const _lastImportKey = 'healthLastImport';

/// When runs were last brought in from Apple Health. Null before the first.
Future<DateTime?> readLastHealthImport(DatabaseClient db) async {
  final v = await _prefs.record(_lastImportKey).get(db);
  return v == null ? null : DateTime.tryParse('$v')?.toLocal();
}

Future<void> saveLastHealthImport(DatabaseClient db, DateTime when) =>
    _prefs.record(_lastImportKey).put(db, when.toUtc().toIso8601String());
