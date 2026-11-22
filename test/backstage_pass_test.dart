import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/gear.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/backstage/backstage_pass_card.dart';

import 'fakes/fake_backend.dart';

void main() {
  testWidgets('sign in, see the pass, sign out clears the device', (
    tester,
  ) async {
    final db = await newDatabaseFactoryMemory().openDatabase('pass.db');
    final remote = FakeRemote();
    final auth = FakeAuth();
    final gear = SembastGearRepository(db);
    await tester.runAsync(
      () => gear.save(
        Gear(
          id: 'g1',
          name: 'Pegasus',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          remoteStoreProvider.overrideWithValue(remote),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: BackstagePassCard()),
        ),
      ),
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('ALL ACCESS'), findsNothing);

    await tester.tap(find.text('Continue with Google'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ryan Runner'), findsOneWidget);
    expect(find.text('ALL ACCESS'), findsOneWidget);
    // The guest's Gear went up to the account.
    expect(remote.tables['gear']?.keys, ['g1']);

    await tester.tap(find.byTooltip('Backstage Pass options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(await tester.runAsync(() => gear.getById('g1')), isNull);
    // Still safe in the account.
    expect(remote.tables['gear']?.keys, ['g1']);
  });

  test('syncedAgo reads like a person would say it', () {
    final now = DateTime(2026, 11, 21, 18);
    expect(syncedAgo(now, now), 'just now');
    expect(
      syncedAgo(now.subtract(const Duration(minutes: 5)), now),
      '5 min ago',
    );
    expect(syncedAgo(now.subtract(const Duration(hours: 3)), now), '3 hr ago');
    expect(syncedAgo(now.subtract(const Duration(days: 1)), now), 'yesterday');
  });
}
