/// Saving new Shows to Apple Health as running workouts.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/gps_track.dart';
import '../../models/show.dart';
import '../providers.dart';
import '../settings/app_settings.dart';
import 'health_source.dart';

/// What Health gets for [show]: a run from its start for its duration, a
/// treadmill run for a Studio Session, with the recorded [route] if any.
HealthRunToSave healthRunFor(Show show, {List<GpsPoint> route = const []}) {
  final start = route.isNotEmpty ? route.first.time.toLocal() : show.date;
  final end = route.isNotEmpty
      ? route.last.time.toLocal()
      : show.date.add(Duration(seconds: show.durationSeconds));
  return HealthRunToSave(
    start: start,
    // A paused run ends later than start + moving time; never before it.
    end: end.isAfter(start.add(Duration(seconds: show.durationSeconds)))
        ? end
        : start.add(Duration(seconds: show.durationSeconds)),
    distanceMiles: show.distanceMiles,
    indoor: show.venue == Venue.studio,
    route: route,
  );
}

/// True when [show] should go to Health: saving is on, Health is here, and
/// it didn't come from (or already go to) Health.
bool shouldSaveToHealth(Show show, AppSettings settings, HealthSource health) =>
    settings.healthSave &&
    health.available &&
    show.healthWorkoutId == null &&
    show.distanceMiles > 0 &&
    show.durationSeconds > 0;

/// Saves a just-booked [show] to Health and keeps Health's id on it, so the
/// import never brings it back as a second Show. Quietly does nothing when
/// saving is off or Health says no.
Future<void> saveShowToHealth(
  Ref ref,
  Show show, {
  List<GpsPoint> route = const [],
}) async {
  final health = ref.read(healthSourceProvider);
  if (!shouldSaveToHealth(show, ref.read(appSettingsProvider), health)) return;
  try {
    await health.requestAccess();
    final uuid = await health.saveRun(healthRunFor(show, route: route));
    if (uuid == null) return;
    final repo = ref.read(showRepositoryProvider);
    final latest = await repo.getById(show.id) ?? show;
    await repo.save(
      latest.copyWith(healthWorkoutId: uuid, updatedAt: DateTime.now()),
    );
  } catch (e) {
    debugPrint('Apple Health save: $e');
  }
}

/// Runs [saveShowToHealth] from a screen that may close before it ends.
final healthSaverProvider = Provider<HealthSaver>(HealthSaver.new);

class HealthSaver {
  HealthSaver(this._ref);
  final Ref _ref;

  Future<void> save(Show show, {List<GpsPoint> route = const []}) =>
      saveShowToHealth(_ref, show, route: route);
}

/// Heart rate during a Show, read from Health on iPhone. Null off iPhone,
/// with the setting off, or when Health has none.
final showHeartRateProvider = FutureProvider.autoDispose
    .family<HeartRateSummary?, ({DateTime start, DateTime end})>((
      ref,
      w,
    ) async {
      final health = ref.watch(healthSourceProvider);
      final on = ref.watch(
        appSettingsProvider.select((s) => s.healthHeartRate),
      );
      if (!on || !health.available) return null;
      try {
        return await health.heartRate(w.start, w.end);
      } catch (e) {
        debugPrint('Heart rate: $e');
        return null;
      }
    });
