import 'dart:async';

import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/sync/remote_store.dart';

/// Behaves like the Supabase tables: newest updatedAt wins, and the server
/// stamps syncedAt from its own steadily rising clock.
class FakeRemote implements RemoteStore {
  final tables = <String, Map<String, RemoteRow>>{};
  var _clock = DateTime.utc(2026, 1, 1);
  var pulls = 0;

  DateTime _tick() => _clock = _clock.add(const Duration(milliseconds: 1));

  @override
  Future<void> upsert(String table, List<RemoteRow> rows) async {
    final t = tables.putIfAbsent(table, () => {});
    for (final r in rows) {
      final old = t[r.id];
      if (old != null && r.updatedAt.isBefore(old.updatedAt)) continue;
      t[r.id] = RemoteRow(
        id: r.id,
        data: r.data,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
        syncedAt: _tick(),
      );
    }
  }

  @override
  Future<List<RemoteRow>> pullSince(
    String table,
    DateTime? since, {
    int offset = 0,
    int limit = 500,
  }) async {
    pulls++;
    final rows =
        (tables[table]?.values ?? const <RemoteRow>[])
            .where((r) => since == null || r.syncedAt.isAfter(since))
            .toList()
          ..sort((a, b) {
            final c = a.syncedAt.compareTo(b.syncedAt);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
    return rows.skip(offset).take(limit).toList();
  }
}

class FakeAuth implements AuthService {
  FakeAuth([this.current]);
  final _changes = StreamController<PassHolder?>.broadcast();

  @override
  PassHolder? current;

  @override
  bool get available => true;

  @override
  Stream<PassHolder?> changes() => _changes.stream;

  void signInAs(PassHolder h) {
    current = h;
    _changes.add(h);
  }

  @override
  Future<void> signInWithGoogle() async => signInAs(
    const PassHolder(id: 'r1', name: 'Ryan Runner', email: 'ryan@example.com'),
  );

  @override
  Future<void> signInWithApple() => signInWithGoogle();

  @override
  Future<void> signOut() async {
    current = null;
    _changes.add(null);
  }

  @override
  Future<void> deleteAccount() => signOut();
}
