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
import 'package:setlist_tracker/ui/charts/charts_screen.dart';

// Sunday 22 Nov 2026; its week starts Monday 16 Nov.
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

Future<void> _pumpCharts(WidgetTester tester, Database db) async {
  tester.view.physicalSize = const Size(780, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        chartsClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: appRouter,
      ),
    ),
  );
  await tester.pumpAndSettle();
  appRouter.go('/charts');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The Charts shows an empty state before the first Show', (
    tester,
  ) async {
    final db = await tester.runAsync(
      () => newDatabaseFactoryMemory().openDatabase('charts_empty.db'),
    );
    await _pumpCharts(tester, db!);

    expect(find.text('The Charts'), findsOneWidget); // the tab
    expect(find.text('THE CHARTS'), findsOneWidget);
    expect(find.text('NOTHING ON THE CHARTS YET'), findsOneWidget);
    // No Tour, so no countdown.
    expect(find.textContaining('OPENING NIGHT'), findsNothing);
    expect(find.text('Weekly miles'), findsNothing);
  });

  testWidgets('The Charts charts Shows, Headliners and the Tour', (
    tester,
  ) async {
    final db = await tester.runAsync(() async {
      final db = await newDatabaseFactoryMemory().openDatabase('charts.db');
      final shows = SembastShowRepository(db);
      // This week: 4 Studio + 6 Live.
      await shows.save(
        _show('a', DateTime(2026, 11, 17, 7), 4, venue: Venue.studio),
      );
      await shows.save(_show('b', DateTime(2026, 11, 18, 7), 6));
      // Last week: three Shows in a row, one a Headliner.
      await shows.save(_show('c', DateTime(2026, 11, 13, 7), 5));
      await shows.save(_show('d', DateTime(2026, 11, 14, 7), 3));
      await shows.save(
        _show('e', DateTime(2026, 11, 15, 7), 12, type: WorkoutType.long),
      );

      final tour = TourBuilder(newId: () => 'p${_ids++}')
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
    await _pumpCharts(tester, db!);

    // Countdown: 119 days from Sun 22 Nov 2026 to Sun 21 Mar 2027.
    expect(
      find.bySemanticsLabel(RegExp('119 days to Opening Night')),
      findsOneWidget,
    );
    expect(find.text('119'), findsOneWidget);

    // Stat tiles.
    expect(find.bySemanticsLabel(RegExp('^This week: 10 mi')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^5 Shows played')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Longest daily streak: 3 days')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Week streak: 1 week')),
      findsOneWidget,
    );

    // Charts carry readable labels.
    expect(
      find.bySemanticsLabel(RegExp(r'^Weekly miles, last 12 weeks\.')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Week of Nov 16: 10 mi \(4 Studio, 6 Live\)'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Headliner progression\. 1 logged, longest 12 mi'),
      ),
      findsOneWidget,
    );
    expect(find.text('Tour plan'), findsOneWidget);
    expect(find.text('On the Tour'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Miles: Studio Sessions 4 mi, 13 percent'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Shows: Studio Sessions 1 Show, 20 percent'),
      ),
      findsOneWidget,
    );

    // The Gold Records door opens the existing screen.
    final door = find.text('Gold Records');
    await tester.ensureVisible(door);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'^Gold Records, [0-9]+ of [0-9]+ pressed')),
      findsOneWidget,
    );
    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(find.text('GOLD RECORDS'), findsOneWidget);
  });
}

var _ids = 0;
