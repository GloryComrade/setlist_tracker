/// Copies changes between the on-device database and the cloud.
///
/// The device copy (Sembast) is what the screens read, so the app works the
/// same offline. A sync run:
///  1. pushes every record queued in the outbox,
///  2. pulls rows the server accepted since this device last looked,
///  3. keeps whichever copy of each record was edited last.
library;

import 'package:sembast/sembast.dart';

import '../../models/json_utils.dart';
import 'remote_store.dart';
import 'sync_stores.dart';

class SyncEngine {
  SyncEngine(this._db, this._remote);

  final Database _db;
  final RemoteStore _remote;

  /// Pull pages overlap by this much, in case a slow server write committed
  /// with a slightly earlier timestamp. Re-reading a row is harmless.
  static const pullOverlap = Duration(seconds: 30);

  static const _pushBatch = 200;
  static const _pullPage = 500;

  /// Who the device copy belongs to: null for a guest who never signed in.
  Future<String?> owner() async =>
      await syncMetaStore.record(ownerKey).get(_db) as String?;

  /// Called when [userId] signs in on this device.
  ///
  /// A guest's Shows become that user's: everything on the device is queued
  /// for upload. If a different account's copy is somehow still here, it is
  /// cleared first so two people's data never mix.
  Future<void> adopt(String userId) async {
    final current = await owner();
    if (current == userId) return;
    if (current != null) await clearLocal();
    await _db.transaction((txn) async {
      for (final name in syncedStoreNames) {
        for (final snap in await recordStore(name).find(txn)) {
          final updated =
              snap.value['updatedAt'] as String? ?? utcString(DateTime.now());
          await enqueue(txn, name, snap.key, updated);
        }
        await syncMetaStore.record(pullCursorKey(name)).delete(txn);
      }
      await syncMetaStore.record(ownerKey).put(txn, userId);
    });
  }

  /// Wipes the device copy (after signing out or deleting the account).
  Future<void> clearLocal() => _db.transaction((txn) async {
    for (final name in syncedStoreNames) {
      await recordStore(name).delete(txn);
    }
    await outboxStore.delete(txn);
    await syncMetaStore.delete(txn);
  });

  /// Number of local changes not uploaded yet. Emits on every change.
  Stream<int> watchPending() => outboxStore.query().onCount(_db);

  /// One full sync. Throws if the network or server fails; whatever was
  /// already done stays done, and the next run picks up the rest.
  Future<SyncReport> sync() async {
    final pushed = await _push();
    var pulled = 0;
    for (final name in syncedStoreNames) {
      pulled += await _pull(name);
    }
    return SyncReport(pushed: pushed, pulled: pulled);
  }

  Future<int> _push() async {
    final entries = await outboxStore.find(_db);
    if (entries.isEmpty) return 0;
    final byStore =
        <String, List<RecordSnapshot<String, Map<String, Object?>>>>{};
    for (final e in entries) {
      byStore.putIfAbsent(e.value['store'] as String, () => []).add(e);
    }
    var count = 0;
    for (final MapEntry(key: name, value: queued) in byStore.entries) {
      if (!syncedStoreNames.contains(name)) continue;
      for (var i = 0; i < queued.length; i += _pushBatch) {
        final batch = queued.skip(i).take(_pushBatch).toList();
        final rows = <RemoteRow>[];
        final sent = <String, String>{}; // outbox key → updatedAt sent
        for (final e in batch) {
          final id = e.value['id'] as String;
          final json = await recordStore(name).record(id).get(_db);
          if (json == null) {
            sent[e.key] = e.value['updatedAt'] as String;
            continue;
          }
          final updated = parseDate(json['updatedAt']) ?? DateTime.now();
          rows.add(
            RemoteRow(
              id: id,
              data: json,
              updatedAt: updated.toUtc(),
              deletedAt: parseDate(json['deletedAt'])?.toUtc(),
              syncedAt: DateTime.now().toUtc(),
            ),
          );
          sent[e.key] = e.value['updatedAt'] as String;
        }
        if (rows.isNotEmpty) await _remote.upsert(name, rows);
        count += rows.length;
        // Clear only entries that weren't edited again while uploading.
        await _db.transaction((txn) async {
          for (final MapEntry(key: k, value: at) in sent.entries) {
            final now = await outboxStore.record(k).get(txn);
            if (now != null && now['updatedAt'] == at) {
              await outboxStore.record(k).delete(txn);
            }
          }
        });
      }
    }
    return count;
  }

  Future<int> _pull(String name) async {
    final cursorRecord = syncMetaStore.record(pullCursorKey(name));
    final cursor = parseDate(await cursorRecord.get(_db));
    // One fixed starting point for the whole run, paged by offset, so a big
    // first upload (hundreds of rows within the same second) can't stall it.
    final since = cursor?.subtract(pullOverlap);
    var newest = cursor;
    var offset = 0;
    var count = 0;
    while (true) {
      final rows = await _remote.pullSince(
        name,
        since,
        offset: offset,
        limit: _pullPage,
      );
      if (rows.isEmpty) break;
      await _db.transaction((txn) async {
        for (final row in rows) {
          if (newest == null || row.syncedAt.isAfter(newest!)) {
            newest = row.syncedAt;
          }
          if (await _applyRemote(txn, name, row)) count++;
        }
        await cursorRecord.put(txn, utcString(newest!));
      });
      if (rows.length < _pullPage) break;
      offset += rows.length;
    }
    return count;
  }

  /// Writes [row] locally if it is newer than the device copy. Returns
  /// whether anything changed. Never touches the outbox.
  Future<bool> _applyRemote(Transaction txn, String name, RemoteRow row) async {
    final record = recordStore(name).record(row.id);
    final local = await record.get(txn);
    final localUpdated = parseDate(local?['updatedAt']);
    if (localUpdated != null && !row.updatedAt.isAfter(localUpdated)) {
      return false;
    }
    await record.put(txn, {
      ...row.data,
      'id': row.id,
      'updatedAt': utcString(row.updatedAt),
      'deletedAt': row.deletedAt == null ? null : utcString(row.deletedAt!),
    });
    // If this device had an older unsent edit, the newer cloud copy wins.
    await outboxStore.record(outboxKey(name, row.id)).delete(txn);
    return true;
  }
}

class SyncReport {
  const SyncReport({required this.pushed, required this.pulled});
  final int pushed;
  final int pulled;
}
