/// What the sync service needs from a cloud backend.
///
/// Supabase implements it in `lib/data/remote/supabase_remote_store.dart`.
/// Tests use an in-memory fake. Nothing here knows about Supabase.
library;

/// One record as the cloud holds it.
class RemoteRow {
  const RemoteRow({
    required this.id,
    required this.data,
    required this.updatedAt,
    required this.syncedAt,
    this.deletedAt,
  });

  final String id;

  /// The record's own JSON, exactly as the app saves it locally.
  final Map<String, Object?> data;

  /// When the record was last edited (on whichever device). Newest wins.
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// When the server last accepted a change to this row. Set by the server
  /// only, so device clocks never decide what counts as "new since last pull".
  final DateTime syncedAt;
}

abstract class RemoteStore {
  /// Inserts or updates rows. The server keeps whichever copy has the later
  /// updatedAt, so an older upload can never overwrite a newer edit.
  Future<void> upsert(String table, List<RemoteRow> rows);

  /// Rows whose syncedAt is after [since] (everything when null), oldest
  /// first, skipping the first [offset] and returning at most [limit].
  Future<List<RemoteRow>> pullSince(
    String table,
    DateTime? since, {
    int offset = 0,
    int limit = 500,
  });
}
