import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/tour/tour_manager_cards.dart';

PlannedShow _p(String id, int day, WorkoutType type, double miles) =>
    PlannedShow(
      id: id,
      date: DateTime(2026, 11, day),
      workoutType: type,
      distanceMiles: miles,
      venue: Venue.live,
      title: type.label,
      targetPaceSecondsPerMile: 660,
      plannedDurationSeconds: (miles * 660).round(),
    );

final _tour = Tour(
  id: 't',
  name: 'Test Tour',
  setup: TourSetup(
    raceDate: DateTime(2027, 3, 14),
    goal: TourGoal.finish,
    currentWeeklyMiles: 20,
    longestRecentRunMiles: 8,
    daysPerWeek: 3,
    headlinerWeekday: DateTime.sunday,
    venuePreference: VenuePreference.live,
  ),
  weeks: [
    TourWeek(
      number: 1,
      startDate: DateTime(2026, 11, 16),
      phase: TourPhase.rehearsals,
      isRestStop: false,
      shows: [
        _p('tue', 17, WorkoutType.easy, 5),
        _p('sun', 22, WorkoutType.long, 10),
      ],
    ),
  ],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  testWidgets('a missed Show card moves the run and logs the change', (
    tester,
  ) async {
    final db = await tester.runAsync(() async {
      final db = await newDatabaseFactoryMemory().openDatabase('tm.db');
      await SembastTourRepository(db).save(_tour);
      return db;
    });
    final now = DateTime(2026, 11, 19, 8);

    Widget app(Tour tour) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db!)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TourManagerSection(tour: tour, now: now),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(_tour));
    await tester.pumpAndSettle();
    expect(find.text('TOUR MANAGER'), findsOneWidget);
    expect(find.text('Missed: Easy (5 mi)'), findsOneWidget);

    await tester.tap(find.text('Move to Thu'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(
      () => SembastTourRepository(db!).getById('t'),
    );
    expect(saved!.showById('tue')!.date, DateTime(2026, 11, 19));
    expect(find.text('The Tour is updated.'), findsOneWidget);

    await tester.pumpWidget(app(saved));
    await tester.pumpAndSettle();
    expect(find.text('Move to Thu'), findsNothing);
    expect(find.text('RECENT CHANGES'), findsOneWidget);
    expect(find.textContaining('Easy moved from Tue 11/17'), findsOneWidget);
  });
}
