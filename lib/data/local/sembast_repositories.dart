import 'package:sembast/sembast.dart';

import '../../models/entity.dart';
import '../../models/gear.dart';
import '../../models/json_utils.dart';
import '../../models/saved_mix.dart';
import '../../models/show.dart';
import '../../models/tour.dart';
import '../repositories/repositories.dart';

/// Shared Sembast code: each record is stored as its JSON map, keyed by id.
class _SembastStore<T extends Entity> {
  _SembastStore(this._db, String storeName, this._fromJson, this._sort)
    : _store = stringMapStoreFactory.store(storeName);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store;
  final T Function(Map<String, Object?>) _fromJson;
  final int Function(T a, T b) _sort;

  Stream<List<T>> watchAll() => _store
      .query(finder: Finder(filter: Filter.isNull('deletedAt')))
      .onSnapshots(_db)
      .map((snaps) {
        final items = snaps.map((s) => _fromJson(s.value)).toList()
          ..sort(_sort);
        return items;
      });

  Future<T?> getById(String id) async {
    final json = await _store.record(id).get(_db);
    if (json == null) return null;
    final item = _fromJson(json);
    return item.isDeleted ? null : item;
  }

  Future<void> save(T item) async {
    final json = Map<String, Object?>.from(item.toJson());
    json['updatedAt'] = utcString(DateTime.now());
    await _store.record(item.id).put(_db, json);
  }

  Future<void> delete(String id) async {
    final record = _store.record(id);
    final json = await record.get(_db);
    if (json == null) return;
    final now = utcString(DateTime.now());
    await record.put(_db, {...json, 'deletedAt': now, 'updatedAt': now});
  }
}

class SembastShowRepository implements ShowRepository {
  SembastShowRepository(Database db)
    : _s = _SembastStore<Show>(
        db,
        'shows',
        Show.fromJson,
        (a, b) => b.date.compareTo(a.date),
      );
  final _SembastStore<Show> _s;

  @override
  Stream<List<Show>> watchAll() => _s.watchAll();
  @override
  Future<Show?> getById(String id) => _s.getById(id);
  @override
  Future<void> save(Show item) => _s.save(item);
  @override
  Future<void> delete(String id) => _s.delete(id);
}

class SembastGearRepository implements GearRepository {
  SembastGearRepository(Database db)
    : _s = _SembastStore<Gear>(
        db,
        'gear',
        Gear.fromJson,
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );
  final _SembastStore<Gear> _s;

  @override
  Stream<List<Gear>> watchAll() => _s.watchAll();
  @override
  Future<Gear?> getById(String id) => _s.getById(id);
  @override
  Future<void> save(Gear item) => _s.save(item);
  @override
  Future<void> delete(String id) => _s.delete(id);
}

class SembastSavedMixRepository implements SavedMixRepository {
  SembastSavedMixRepository(Database db)
    : _s = _SembastStore<SavedMix>(
        db,
        'saved_mixes',
        SavedMix.fromJson,
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  final _SembastStore<SavedMix> _s;

  @override
  Stream<List<SavedMix>> watchAll() => _s.watchAll();
  @override
  Future<SavedMix?> getById(String id) => _s.getById(id);
  @override
  Future<void> save(SavedMix item) => _s.save(item);
  @override
  Future<void> delete(String id) => _s.delete(id);
}

class SembastTourRepository implements TourRepository {
  SembastTourRepository(Database db)
    : _s = _SembastStore<Tour>(
        db,
        'tours',
        Tour.fromJson,
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );
  final _SembastStore<Tour> _s;

  @override
  Stream<List<Tour>> watchAll() => _s.watchAll();
  @override
  Future<Tour?> getById(String id) => _s.getById(id);
  @override
  Future<void> save(Tour item) => _s.save(item);
  @override
  Future<void> delete(String id) => _s.delete(id);
}
