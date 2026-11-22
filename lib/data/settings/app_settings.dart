/// The runner's preferences from the Settings screen.
///
/// They stay on this device (each phone or browser keeps its own) and are
/// not synced. The screens only know [appSettingsProvider]; where they are
/// kept is behind [SettingsStore], so the store can be swapped (Sembast
/// today, in memory for tests).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../models/json_utils.dart';
import '../../models/tour.dart';
import '../providers.dart';

/// Where "Open in …" sends the Song of the Show.
enum MusicApp {
  spotify('Spotify'),
  appleMusic('Apple Music');

  const MusicApp(this.label);
  final String label;

  static MusicApp fromName(String? name) => MusicApp.values.firstWhere(
    (v) => v.name == name,
    orElse: () => MusicApp.spotify,
  );
}

@immutable
class AppSettings {
  const AppSettings({
    this.newShowsOffCrew = false,
    this.headlinerWeekday = DateTime.sunday,
    this.tourVenue,
    this.musicApp = MusicApp.spotify,
    this.healthImport = true,
    this.healthSave = true,
    this.healthHeartRate = true,
  });

  /// New Shows start "Keep off the Crew".
  final bool newShowsOffCrew;

  /// Book The Tour starts with this Headliner day (DateTime.monday to
  /// DateTime.sunday).
  final int headlinerWeekday;

  /// Book The Tour starts with this answer to "Studio or Live?". Null asks
  /// every time.
  final VenuePreference? tourVenue;
  final MusicApp musicApp;

  /// Shows the Apple Health import (iPhone only).
  final bool healthImport;

  /// New Shows are saved to Apple Health as running workouts (iPhone only).
  final bool healthSave;

  /// The Show page reads heart rate from Apple Health (iPhone only).
  final bool healthHeartRate;

  AppSettings copyWith({
    bool? newShowsOffCrew,
    int? headlinerWeekday,
    VenuePreference? tourVenue,
    bool clearTourVenue = false,
    MusicApp? musicApp,
    bool? healthImport,
    bool? healthSave,
    bool? healthHeartRate,
  }) => AppSettings(
    newShowsOffCrew: newShowsOffCrew ?? this.newShowsOffCrew,
    headlinerWeekday: headlinerWeekday ?? this.headlinerWeekday,
    tourVenue: clearTourVenue ? null : (tourVenue ?? this.tourVenue),
    musicApp: musicApp ?? this.musicApp,
    healthImport: healthImport ?? this.healthImport,
    healthSave: healthSave ?? this.healthSave,
    healthHeartRate: healthHeartRate ?? this.healthHeartRate,
  );

  Map<String, Object?> toJson() => {
    'newShowsOffCrew': newShowsOffCrew,
    'headlinerWeekday': headlinerWeekday,
    'tourVenue': tourVenue?.name,
    'musicApp': musicApp.name,
    'healthImport': healthImport,
    'healthSave': healthSave,
    'healthHeartRate': healthHeartRate,
  };

  /// Anything missing or unknown falls back to the default.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final day = json['headlinerWeekday'] == null
        ? DateTime.sunday
        : asInt(json['headlinerWeekday']);
    final venue = asStringOrNull(json['tourVenue']);
    return AppSettings(
      newShowsOffCrew: json['newShowsOffCrew'] == true,
      headlinerWeekday: day >= DateTime.monday && day <= DateTime.sunday
          ? day
          : DateTime.sunday,
      tourVenue: VenuePreference.values
          .where((v) => v.name == venue)
          .firstOrNull,
      musicApp: MusicApp.fromName(asStringOrNull(json['musicApp'])),
      healthImport: json['healthImport'] != false,
      healthSave: json['healthSave'] != false,
      healthHeartRate: json['healthHeartRate'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.newShowsOffCrew == newShowsOffCrew &&
      other.headlinerWeekday == headlinerWeekday &&
      other.tourVenue == tourVenue &&
      other.musicApp == musicApp &&
      other.healthImport == healthImport &&
      other.healthSave == healthSave &&
      other.healthHeartRate == healthHeartRate;

  @override
  int get hashCode => Object.hash(
    newShowsOffCrew,
    headlinerWeekday,
    tourVenue,
    musicApp,
    healthImport,
    healthSave,
    healthHeartRate,
  );
}

/// Where the settings are kept.
abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// In the app's Sembast database, next to the other small device prefs.
class SembastSettingsStore implements SettingsStore {
  SembastSettingsStore(this._db);
  final Database _db;

  static final _prefs = StoreRef<String, Object?>('app_prefs');
  static const _key = 'settings';

  @override
  Future<AppSettings> load() async {
    final raw = await _prefs.record(_key).get(_db);
    return raw is Map
        ? AppSettings.fromJson(raw.map((k, v) => MapEntry('$k', v)))
        : const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) =>
      _prefs.record(_key).put(_db, settings.toJson());
}

/// Keeps everything in memory (tests and previews).
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.saved = const AppSettings()]);
  AppSettings saved;

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SembastSettingsStore(ref.watch(databaseProvider)),
);

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// Starts with the defaults, then the saved settings as soon as they're
/// read. The app shell reads this at startup, so screens get the saved
/// values.
class AppSettingsController extends Notifier<AppSettings> {
  /// True once the runner changed something, so a slow first read can't
  /// undo it.
  bool _changed = false;

  @override
  AppSettings build() {
    unawaited(_load());
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(settingsStoreProvider).load();
      if (!_changed) state = saved;
    } catch (e) {
      debugPrint('Settings: $e');
    }
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    _changed = true;
    state = change(state);
    try {
      await ref.read(settingsStoreProvider).save(state);
    } catch (e) {
      debugPrint('Settings: $e');
    }
  }
}

/// What Book The Tour starts with.
final tourQuizDefaultsProvider =
    Provider<({int headlinerWeekday, VenuePreference? venue})>((ref) {
      final s = ref.watch(appSettingsProvider);
      return (headlinerWeekday: s.headlinerWeekday, venue: s.tourVenue);
    });
