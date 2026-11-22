import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/json_utils.dart';
import '../sync/remote_store.dart';

/// [RemoteStore] backed by the four Supabase tables in
/// `supabase/migrations/`. Row Level Security limits every query to the
/// signed-in runner's own rows, so no user filter is needed here.
class SupabaseRemoteStore implements RemoteStore {
  SupabaseRemoteStore(this._client);
  final SupabaseClient _client;

  @override
  Future<void> upsert(String table, List<RemoteRow> rows) async {
    if (rows.isEmpty) return;
    await _client.from(table).upsert([
      for (final r in rows)
        {
          'id': r.id,
          'data': r.data,
          'updated_at': utcString(r.updatedAt),
          'deleted_at': r.deletedAt == null ? null : utcString(r.deletedAt!),
        },
    ], onConflict: 'id');
  }

  @override
  Future<List<RemoteRow>> pullSince(
    String table,
    DateTime? since, {
    int offset = 0,
    int limit = 500,
  }) async {
    var query = _client
        .from(table)
        .select('id, data, updated_at, deleted_at, synced_at');
    if (since != null) query = query.gt('synced_at', utcString(since));
    final rows = await query
        .order('synced_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    return [
      for (final r in rows)
        RemoteRow(
          id: r['id'] as String,
          data: asMap(r['data']) ?? const {},
          updatedAt: DateTime.parse(r['updated_at'] as String).toUtc(),
          deletedAt: parseDate(r['deleted_at'])?.toUtc(),
          syncedAt: DateTime.parse(r['synced_at'] as String).toUtc(),
        ),
    ];
  }
}
