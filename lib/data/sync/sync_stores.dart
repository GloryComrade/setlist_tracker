/// The local Sembast stores the sync service knows about.
///
/// Each one has a matching Supabase table with the same name. Every save or
/// delete made through a repository also writes an entry in [outboxStore],
/// so the sync service knows what to upload next.
library;

import 'package:sembast/sembast.dart';

/// The record stores that sync, by name. Local store name == Supabase table.
const syncedStoreNames = ['shows', 'gear', 'saved_mixes', 'tours'];

StoreRef<String, Map<String, Object?>> recordStore(String name) =>
    stringMapStoreFactory.store(name);

/// Key `shows/ID` → `{store: shows, id: ID, updatedAt: ...}`.
final outboxStore = stringMapStoreFactory.store('sync_outbox');

/// Small key/value facts about syncing: who owns the local copy, and how far
/// each table has been pulled.
final syncMetaStore = StoreRef<String, Object?>('sync_meta');

const ownerKey = 'owner';
String pullCursorKey(String table) => 'pull/$table';

String outboxKey(String store, String id) => '$store/$id';

/// Queues a record for upload. Call inside the same transaction as the write.
Future<void> enqueue(
  DatabaseClient txn,
  String store,
  String id,
  String updatedAt,
) => outboxStore.record(outboxKey(store, id)).put(txn, {
  'store': store,
  'id': id,
  'updatedAt': updatedAt,
});
