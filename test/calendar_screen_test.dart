import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/app.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/logic/tour_builder.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/calendar/calendar_screen.dart';

// Sunday 22 Nov 2026, a Headliner day on the Tour.
final _now = DateTime(2026, 11, 22, 9);

Show _show(
  String id,
  DateTime date,
  double miles, {
  Venue venue = Venue.live,
  WorkoutType type = WorkoutType.easy,
}) => Show(
  id: id,
  date: date,
  venue: venue,
  workoutType: type,
  distanceMiles: miles,
  durationSeconds: (miles * 560).round(),
  effort: 5,
  feel: Feel.good,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<Database> _seed(WidgetTester tester, String name) async {
  final db = await tester.runAsync(() async {
    final db = await newDatabaseFactoryMemory().openDatabase(name);
    final shows = SembastShowRepository(db);
    // Tue 3 Nov is an Easy 3.5 mi on the Tour: logged from the Setlist.
    await shows.save(_show('a', DateTime(2026, 11, 3, 7), 3.6));
    await shows.save(
      _show('b', DateTime(2026, 11, 10, 7), 4, venue: Venue.studio),
    );
    await shows.save(
      _show('c', DateTime(2026, 11, 8, 7), 10, type: WorkoutType.long),
    );
    var n = 0;
    final tour = TourBuilder(newId: () => 'p${n++}')
        .build(
          TourSetup(
            raceDate: DateTime(2027, 3, 21),
            goal: TourGoal.finish,
            currentWeeklyMiles: 20,
            longestRecentRunMiles: 10,
            daysPerWeek: 4,
            headlinerWeekday: DateTime.sunday,
            venuePreference: VenuePreference.mix,
            easyPaceSecondsPerMile: 600,
          ),
          today: DateTime(2026, 11, 1),
        )
        .tour!;
    await SembastTourRepository(db).save(tour);
    return db;
  });
  return db!;
}

Future<void> _pump(
  WidgetTester tester,
  Database db, {
  double textScale = 1,
  String start = '/calendar',
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        calendarClockProvider.overrideWithValue(() => _now),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(375, 812),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: appRouter,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  appRouter.go('/setlist');
  await tester.pumpAndSettle();
  if (start != '/setlist') {
    appRouter.push(start);
    await tester.pumpAndSettle();
  }
}

Future<void> _settleDb(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens from the Setlist header on this month', (tester) async {
    final db = await _seed(tester, 'cal_open.db');
    await _pump(tester, db, start: '/setlist');
    await tester.tap(find.byTooltip('The Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('THE CALENDAR'), findsOneWidget);
    expect(find.text('NOVEMBER'), findsOneWidget);
    expect(find.text('119 days to Opening Night'), findsOneWidget);
    expect(find.text('2026 · 3 Shows · 17.6 mi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each day speaks what is on it', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _seed(tester, 'cal_spoken.db');
    await _pump(tester, db);

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Tuesday, November 3: Easy 3\.5 miles planned, done\. Gold Record$',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Tuesday, November 10: Easy 3\.5 miles planned, done$'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Sunday, November 8: Headliner 10 miles planned, done\. '
          r'Gold Record$',
        ),
      ),
      findsOneWidget,
    );
    // A past run with no Show was missed.
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Thursday, November 5: Easy 3\.5 miles planned, not logged$'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Sunday, November 22: today\. Headliner 11\.5 miles planned$'),
      ),
      findsOneWidget,
    );
    // Week totals are said in words, not "mi".
    expect(
      find.bySemanticsLabel(RegExp(r'^Week 1, Rehearsals\. 13\.6 miles of ')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'Rest Stop')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'\bmi\b')), findsNothing);
    handle.dispose();
  });

  testWidgets('a day opens its Shows and logs a run done as planned', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final db = await _seed(tester, 'cal_sheet.db');
    await _pump(tester, db);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Sunday, November 22:')));
    await tester.pumpAndSettle();
    expect(find.text('SUNDAY, NOVEMBER 22'), findsOneWidget);
    expect(find.text('Headliner'), findsOneWidget);
    expect(find.text('11.5 mi planned · Live Show'), findsOneWidget);

    await tester.tap(find.text('Done as planned'));
    await _settleDb(tester);
    expect(find.text('Done · ran 11.5 mi'), findsOneWidget);
    expect(find.text('Done as planned'), findsNothing);
    expect(find.text('Headliner · Live Show'), findsOneWidget);
    final saved = await tester.runAsync(
      () => SembastShowRepository(db).watchAll().first,
    );
    expect(
      saved!.where((s) => s.workoutType == WorkoutType.long),
      hasLength(2),
    );

    // A logged Show opens its page.
    await tester.tap(find.text('Headliner · Live Show'));
    await tester.pumpAndSettle();
    expect(find.text('THE SHOW'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('arrows and Today move between months', (tester) async {
    final db = await _seed(tester, 'cal_nav.db');
    await _pump(tester, db);

    // The first Show is in November, so there's no month before it.
    final prev = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(prev.onPressed, isNull);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('DECEMBER'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('JANUARY'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('NOVEMBER'), findsOneWidget);
  });

  testWidgets('opens on Opening Night month from a link', (tester) async {
    final db = await _seed(tester, 'cal_link.db');
    await _pump(tester, db, start: '/calendar?month=2027-03');
    expect(find.text('MARCH'), findsOneWidget);
    expect(find.byIcon(Icons.confirmation_number), findsWidgets);
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('opens from the Tour header', (tester) async {
    final db = await _seed(tester, 'cal_tour.db');
    await _pump(tester, db, start: '/setlist');
    appRouter.go('/tour');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('The Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('NOVEMBER'), findsOneWidget);
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('holds together at ${(scale * 100).round()}% text', (
      tester,
    ) async {
      final db = await _seed(tester, 'cal_big_$scale.db');
      await _pump(tester, db, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('NOVEMBER'), findsOneWidget);
      await tester.ensureVisible(find.text('22'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('22'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Done as planned'), findsOneWidget);
    });
  }
}
