/// The storage contracts the UI depends on.
///
/// Nothing in here knows about Sembast, Supabase or Firebase. To move to a
/// cloud backend, write new classes that implement these and change
/// `lib/data/providers.dart` to use them. The screens don't change.
library;

import '../../models/gear.dart';
import '../../models/saved_mix.dart';
import '../../models/show.dart';
import '../../models/tour.dart';

/// Basic save / load / delete for one kind of record.
abstract class Repository<T> {
  /// Every record that isn't deleted. Emits again whenever anything changes.
  Stream<List<T>> watchAll();

  Future<T?> getById(String id);

  /// Inserts or updates. Implementations stamp updatedAt.
  Future<void> save(T item);

  /// Soft delete: sets deletedAt so the removal can sync later.
  Future<void> delete(String id);
}

/// Shows, newest first.
abstract class ShowRepository implements Repository<Show> {}

/// Gear, in the order it was added.
abstract class GearRepository implements Repository<Gear> {}

/// Saved Mixes, sorted by name.
abstract class SavedMixRepository implements Repository<SavedMix> {}

/// Tours, newest first. The newest one is the active Tour.
abstract class TourRepository implements Repository<Tour> {}
