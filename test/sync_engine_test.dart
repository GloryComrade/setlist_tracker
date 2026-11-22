import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/sync/sync_engine.dart';
import 'package:setlist_tracker/models/gear.dart';

import 'fakes/fake_backend.dart';

Gear _gear(String id, String name) => Gear(
  id: id,
  name: name,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late FakeRemote remote;
  var dbCount = 0;

  Future<Database> newDb() =>
      newDatabaseFactoryMemory().openDatabase('d${dbCount++}.db');

  setUp(() => remote = FakeRemote());

  test(
    'guest Gear uploads on first sign-in, then the outbox is empty',
    () async {
      final db = await newDb();
      final engine = SyncEngine(db, remote);
      await SembastGearRepository(db).save(_gear('g1', 'Pegasus'));
      await engine.adopt('runner-1');
      final report = await engine.sync();
      expect(report.pushed, 1);
      expect(remote.tables['gear']!.keys, ['g1']);
      expect(await engine.watchPending().first, 0);
      expect(await engine.owner(), 'runner-1');
    },
  );

  test('a second device gets the Gear, and edits flow both ways', () async {
    final phone = await newDb();
    final laptop = await newDb();
    final phoneSync = SyncEngine(phone, remote);
    final laptopSync = SyncEngine(laptop, remote);
    final phoneGear = SembastGearRepository(phone);
    final laptopGear = SembastGearRepository(laptop);

    await phoneGear.save(_gear('g1', 'Pegasus'));
    await phoneSync.adopt('r');
    await phoneSync.sync();

    await laptopSync.adopt('r');
    await laptopSync.sync();
    expect((await laptopGear.getById('g1'))?.name, 'Pegasus');

    final g = (await laptopGear.getById('g1'))!;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await laptopGear.save(g.copyWith(name: 'Pegasus 41'));
    await laptopSync.sync();
    await phoneSync.sync();
    expect((await phoneGear.getById('g1'))?.name, 'Pegasus 41');

    await phoneGear.delete('g1');
    await phoneSync.sync();
    await laptopSync.sync();
    expect(await laptopGear.getById('g1'), isNull);
  });

  test(
    'the newer edit wins when both devices changed the same record',
    () async {
      final a = await newDb();
      final b = await newDb();
      final aSync = SyncEngine(a, remote);
      final bSync = SyncEngine(b, remote);
      await SembastGearRepository(a).save(_gear('g1', 'Original'));
      await aSync.adopt('r');
      await aSync.sync();
      await bSync.adopt('r');
      await bSync.sync();

      final aGear = SembastGearRepository(a);
      final bGear = SembastGearRepository(b);
      await aGear.save((await aGear.getById('g1'))!.copyWith(name: 'Older'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await bGear.save((await bGear.getById('g1'))!.copyWith(name: 'Newer'));

      // The newer edit reaches the server first; the older one must not win.
      await bSync.sync();
      await aSync.sync();
      await bSync.sync();
      expect((await aGear.getById('g1'))?.name, 'Newer');
      expect((await bGear.getById('g1'))?.name, 'Newer');
    },
  );

  test('a big first upload pulls completely on another device', () async {
    final a = await newDb();
    final repo = SembastGearRepository(a);
    for (var i = 0; i < 1203; i++) {
      await repo.save(_gear('g${i.toString().padLeft(4, '0')}', 'Pair $i'));
    }
    final aSync = SyncEngine(a, remote);
    await aSync.adopt('r');
    await aSync.sync();

    final b = await newDb();
    final bSync = SyncEngine(b, remote);
    await bSync.adopt('r');
    final report = await bSync.sync();
    expect(report.pulled, 1203);
    expect((await SembastGearRepository(b).watchAll().first).length, 1203);
  });

  test('signing in as someone else clears the old copy first', () async {
    final db = await newDb();
    final engine = SyncEngine(db, remote);
    await SembastGearRepository(db).save(_gear('g1', 'Mine'));
    await engine.adopt('runner-1');
    await engine.adopt('runner-2');
    expect(await SembastGearRepository(db).getById('g1'), isNull);
    expect(await engine.watchPending().first, 0);
  });

  test('clearLocal empties the device copy', () async {
    final db = await newDb();
    final engine = SyncEngine(db, remote);
    await SembastGearRepository(db).save(_gear('g1', 'Mine'));
    await engine.adopt('r');
    await engine.sync();
    await engine.clearLocal();
    expect(await SembastGearRepository(db).watchAll().first, isEmpty);
    expect(await engine.owner(), isNull);
  });
}
