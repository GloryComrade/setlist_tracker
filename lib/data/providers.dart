/// The one place that decides which storage the app uses.
///
/// Phase 5 swap: replace the Sembast repositories below with Supabase
/// (or Firebase) ones. Everything else reads data through these providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../models/gear.dart';
import '../models/saved_mix.dart';
import '../models/show.dart';
import '../models/tour.dart';
import 'local/sembast_repositories.dart';
import 'repositories/repositories.dart';

/// Opened in main() and passed in with an override.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final showRepositoryProvider = Provider<ShowRepository>(
  (ref) => SembastShowRepository(ref.watch(databaseProvider)),
);

final gearRepositoryProvider = Provider<GearRepository>(
  (ref) => SembastGearRepository(ref.watch(databaseProvider)),
);

final savedMixRepositoryProvider = Provider<SavedMixRepository>(
  (ref) => SembastSavedMixRepository(ref.watch(databaseProvider)),
);

final tourRepositoryProvider = Provider<TourRepository>(
  (ref) => SembastTourRepository(ref.watch(databaseProvider)),
);

// ---- Live data the screens watch ----

/// The Setlist: every Show, newest first.
final showsProvider = StreamProvider<List<Show>>(
  (ref) => ref.watch(showRepositoryProvider).watchAll(),
);

final gearListProvider = StreamProvider<List<Gear>>(
  (ref) => ref.watch(gearRepositoryProvider).watchAll(),
);

final savedMixesProvider = StreamProvider<List<SavedMix>>(
  (ref) => ref.watch(savedMixRepositoryProvider).watchAll(),
);

/// Total miles per Gear id: starting miles plus every Show that used it.
final gearMilesProvider = Provider<Map<String, double>>((ref) {
  final gear = ref.watch(gearListProvider).value ?? const <Gear>[];
  final shows = ref.watch(showsProvider).value ?? const <Show>[];
  final miles = {for (final g in gear) g.id: g.startingMiles};
  for (final s in shows) {
    final id = s.gearId;
    if (id != null && miles.containsKey(id)) {
      miles[id] = miles[id]! + s.distanceMiles;
    }
  }
  return miles;
});

/// The active Tour: the newest one booked. Null before the first booking.
final activeTourProvider = StreamProvider<Tour?>(
  (ref) => ref
      .watch(tourRepositoryProvider)
      .watchAll()
      .map((tours) => tours.isEmpty ? null : tours.first),
);

/// Planned Show id → the Show logged for it.
///
/// A Show booked from the Tour carries plannedShowId. A Show logged straight
/// from the Setlist on a planned day also counts, so the checkmark still
/// shows up when the runner forgets to start from the Tour.
final tourProgressProvider = Provider<Map<String, Show>>((ref) {
  final tour = ref.watch(activeTourProvider).value;
  final shows = ref.watch(showsProvider).value ?? const <Show>[];
  if (tour == null) return const {};
  final done = <String, Show>{};
  final unlinkedByDay = <DateTime, List<Show>>{};
  for (final s in shows) {
    final id = s.plannedShowId;
    if (id != null) {
      done[id] = s;
    } else {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      unlinkedByDay.putIfAbsent(day, () => []).add(s);
    }
  }
  for (final p in tour.allShows) {
    if (done.containsKey(p.id)) continue;
    final same = unlinkedByDay[p.date];
    if (same != null && same.isNotEmpty) done[p.id] = same.removeLast();
  }
  return done;
});
