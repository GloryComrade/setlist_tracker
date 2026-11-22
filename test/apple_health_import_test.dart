import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/health/health_import_prefs.dart';
import 'package:setlist_tracker/data/health/health_source.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/backstage/apple_health_card.dart';

class FakeHealth implements HealthSource {
  FakeHealth(this.runs, {this.grant = true, this.deny = false});
  final List<HealthRun> runs;
  final bool grant;
  final bool deny;
  DateTime? askedFrom;

  @override
  bool get available => true;

  @override
  Future<bool> requestAccess() async => grant;

  @override
  Future<List<HealthRun>> fetchRuns(DateTime from, DateTime to) async {
    askedFrom = from;
    if (deny) throw const HealthAccessDenied();
    return runs;
  }
}

HealthRun _run(String id, int daysAgo, double miles, {bool? indoor}) {
  final start = DateTime.now().subtract(Duration(days: daysAgo));
  return HealthRun(
    uuid: id,
    start: start,
    end: start.add(const Duration(minutes: 45)),
    distanceMiles: miles,
    durationSeconds: 2700,
    indoor: indoor,
    sourceName: 'Apple Watch',
  );
}

Future<Database> _db() => newDatabaseFactoryMemory().openDatabase('h.db');

Widget _app(Database db, HealthSource health) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    healthSourceProvider.overrideWithValue(health),
  ],
  child: MaterialApp(
    theme: AppTheme.dark(),
    home: const Scaffold(body: AppleHealthCard()),
  ),
);

/// Sembast and the fake answer on real timers.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pick runs in the sheet and they land on the Setlist', (
    tester,
  ) async {
    final db = (await tester.runAsync(_db))!;
    final health = FakeHealth([
      _run('outdoor', 1, 6.2),
      _run('treadmill', 2, 4, indoor: true),
      _run('skip-me', 3, 3.1),
    ]);
    await tester.pumpWidget(_app(db, health));
    expect(find.text('Apple Health'), findsOneWidget);

    await tester.tap(find.text('Import runs'));
    await _settle(tester);

    expect(find.text('NEW FROM APPLE HEALTH'), findsOneWidget);
    expect(find.text('LIVE SHOW'), findsNWidgets(2));
    expect(find.text('STUDIO SESSION'), findsOneWidget);
    expect(find.text('Add 3 Shows'.toUpperCase()), findsOneWidget);

    // Uncheck the oldest one.
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    expect(find.text('ADD 2 SHOWS'), findsOneWidget);

    await tester.tap(find.text('ADD 2 SHOWS'));
    await _settle(tester);

    expect(find.text('2 Shows added to the Setlist.'), findsOneWidget);
    final shows = (await tester.runAsync(
      () => SembastShowRepository(db).watchAll().first,
    ))!;
    expect(shows.map((s) => s.healthWorkoutId), ['outdoor', 'treadmill']);
    expect(shows.last.venue, Venue.studio);
    expect(await tester.runAsync(() => readLastHealthImport(db)), isNotNull);

    // A second import offers only the run left behind; the 30-day window
    // narrows to the last import.
    await tester.tap(find.text('Import runs'));
    await _settle(tester);
    expect(find.text('ADD 1 SHOW'), findsOneWidget);
    expect(
      health.askedFrom!.isAfter(
        DateTime.now().subtract(const Duration(days: 2)),
      ),
      isTrue,
    );
  });

  testWidgets('nothing new says so', (tester) async {
    final db = (await tester.runAsync(_db))!;
    await tester.pumpWidget(_app(db, FakeHealth(const [])));
    await tester.tap(find.text('Import runs'));
    await _settle(tester);
    expect(find.text('NOTHING NEW'), findsOneWidget);
    expect(
      find.text('No runs in Apple Health from the last 30 days.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('NOTHING NEW'), findsNothing);
  });

  testWidgets('refused access explains where to turn it on', (tester) async {
    final db = (await tester.runAsync(_db))!;
    await tester.pumpWidget(_app(db, FakeHealth(const [], deny: true)));
    await tester.tap(find.text('Import runs'));
    await _settle(tester);
    expect(find.text('APPLE HEALTH IS CLOSED'), findsOneWidget);
    expect(
      find.textContaining(
        'Settings > Health > Data Access & Devices > Setlist Tracker',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hidden where Apple Health does not exist', (tester) async {
    final db = (await tester.runAsync(_db))!;
    await tester.pumpWidget(_app(db, const UnavailableHealthSource()));
    expect(find.text('Apple Health'), findsNothing);
    expect(find.text('Import runs'), findsNothing);
  });
}
