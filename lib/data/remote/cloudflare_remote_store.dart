import '../../models/json_utils.dart';
import '../sync/remote_store.dart';
import 'api_client.dart';

/// [RemoteStore] backed by the Worker's `/api/sync/{table}` routes
/// (docs/cloudflare-api.md). The Worker only ever reads and writes the
/// signed-in runner's own rows, so no user filter is needed here.
class CloudflareRemoteStore implements RemoteStore {
  CloudflareRemoteStore(this._api);
  final ApiClient _api;

  /// The Worker takes at most this many rows per request.
  static const maxRows = 500;

  @override
  Future<void> upsert(String table, List<RemoteRow> rows) async {
    for (var i = 0; i < rows.length; i += maxRows) {
      try {
        await _api.post(
          '/api/sync/${Uri.encodeComponent(table)}',
          body: {
            'rows': [
              for (final r in rows.skip(i).take(maxRows))
                {
                  'id': r.id,
                  'data': r.data,
                  'updatedAt': apiTime(r.updatedAt),
                  'deletedAt': r.deletedAt == null
                      ? null
                      : apiTime(r.deletedAt!),
                },
            ],
          },
        );
      } on ApiException catch (e) {
        // 409: a row id already belongs to another runner. The Worker saved
        // the rest, and retrying would never succeed, so move on.
        if (e.status != 409) rethrow;
      }
    }
  }

  @override
  Future<List<RemoteRow>> pullSince(
    String table,
    DateTime? since, {
    int offset = 0,
    int limit = 500,
  }) async {
    final json = await _api.get(
      '/api/sync/${Uri.encodeComponent(table)}',
      query: {
        if (since != null) 'since': apiTime(since),
        'offset': '$offset',
        'limit': '${limit.clamp(1, maxRows)}',
      },
    );
    final rows = json is Map ? json['rows'] : null;
    if (rows is! List) throw const FormatException('No rows list');
    return [
      for (final r in asMapList(rows))
        RemoteRow(
          id: '${r['id']}',
          data: asMap(r['data']) ?? const {},
          updatedAt: DateTime.parse('${r['updatedAt']}').toUtc(),
          deletedAt: parseDate(r['deletedAt'])?.toUtc(),
          syncedAt: DateTime.parse('${r['syncedAt']}').toUtc(),
        ),
    ];
  }
}
