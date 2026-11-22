import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/data/providers.dart';
import 'package:setlist_tracker/data/repositories/repositories.dart';
import 'package:setlist_tracker/models/tour.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/tour/book_tour_screen.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';

/// Keeps what "Book The Tour" saves.
class _FakeTours implements TourRepository {
  final saved = <Tour>[];

  @override
  Future<void> save(Tour item) async => saved.add(item);

  @override
  Future<Tour?> getById(String id) async =>
      saved.where((t) => t.id == id).firstOrNull;

  @override
  Future<void> delete(String id) async {}

  @override
  Stream<List<Tour>> watchAll() => Stream.value(saved);
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// The first Sunday at least [weeks] weeks out.
DateTime _sundayIn(int weeks) {
  final d = _today().add(Duration(days: weeks * 7));
  return DateTime(d.year, d.month, d.day + (DateTime.sunday - d.weekday) % 7);
}

void main() {
  late _FakeTours tours;

  Future<void> pump(WidgetTester tester, {TourFeaturing? featuring}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tours = _FakeTours();
    final router = GoRouter(
      initialLocation: '/tour/book',
      routes: [
        GoRoute(
          path: '/tour',
          builder: (_, _) => const Scaffold(body: Text('TOUR PAGE')),
          routes: [
            GoRoute(
              path: 'book',
              builder: (_, _) => BookTourScreen(featuring: featuring),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tourRepositoryProvider.overrideWithValue(tours)],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool nextEnabled(WidgetTester tester) =>
      tester.widget<GradientButton>(find.byType(GradientButton)).onPressed !=
      null;

  Future<void> tap(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byType(GradientButton));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  /// From the goal step (finish goal) through to the preview.
  Future<void> finishQuiz(WidgetTester tester) async {
    await tap(tester, 'Finish strong');
    await next(tester);
    await type(tester, '15');
    await next(tester);
    await type(tester, '5');
    await next(tester);
    await tap(tester, 'No recent race');
    await next(tester);
    await next(tester); // days
    await next(tester); // Headliner day
    await tap(tester, VenuePreference.live.label);
    expect(find.text('SEE THE TOUR'), findsOneWidget);
    await next(tester);
    expect(find.text('YOUR TOUR'), findsOneWidget);
  }

  testWidgets('Next waits for a distance', (tester) async {
    await pump(tester);
    expect(find.text('Question 1 of 9'), findsOneWidget);
    expect(find.text('PICK YOUR SHOW'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);

    await tap(tester, '10K');
    expect(nextEnabled(tester), isTrue);
    await next(tester);
    expect(find.text('Question 2 of 9'), findsOneWidget);
    expect(find.textContaining('Your 10K date'), findsOneWidget);
    expect(find.textContaining('about 12 weeks out'), findsOneWidget);
  });

  testWidgets('Boston qualifier is only offered for a marathon', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'Half Marathon');
    await next(tester);
    await tap(tester, 'Help me pick');
    await next(tester);
    expect(find.text('Target time'), findsOneWidget);
    expect(find.text(TourGoal.bq.label), findsNothing);

    await tap(tester, 'Back');
    await tap(tester, 'Back');
    await tap(tester, 'Marathon');
    await next(tester);
    // The suggested date followed the distance to 18 weeks.
    expect(find.textContaining('18 weeks out'), findsOneWidget);
    await next(tester);
    expect(find.text(TourGoal.bq.label), findsOneWidget);

    // Switching away from a marathon drops a BQ goal.
    await tap(tester, TourGoal.bq.label);
    await type(tester, '3:30');
    expect(nextEnabled(tester), isTrue);
    await tap(tester, 'Back');
    await tap(tester, 'Back');
    await tap(tester, '5K');
    await next(tester);
    await next(tester);
    expect(find.text(TourGoal.bq.label), findsNothing);
    expect(nextEnabled(tester), isFalse);
  });

  testWidgets('a 5K goal of 24:30 is minutes and seconds', (tester) async {
    await pump(tester);
    await tap(tester, '5K');
    await next(tester);
    await tap(tester, 'Help me pick');
    await next(tester);
    await tap(tester, 'Target time');
    await type(tester, '24:30');
    expect(find.textContaining('Use mm:ss'), findsNothing);
    expect(nextEnabled(tester), isTrue);

    // The same text is 24 hours for a marathon, and the goal box is
    // cleared when the distance changes.
    await tap(tester, 'Back');
    await tap(tester, 'Back');
    await tap(tester, 'Marathon');
    await next(tester);
    await next(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await type(tester, '24:30');
    expect(find.text('Use h:mm, between 2:00 and 8:00'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);

    // Back to a 5K and through to the preview.
    await tap(tester, 'Back');
    await tap(tester, 'Back');
    await tap(tester, '5K');
    await next(tester);
    await next(tester);
    await type(tester, '24:30');
    await next(tester);
    await type(tester, '15');
    await next(tester);
    await type(tester, '5');
    await next(tester);
    await tap(tester, 'No recent race');
    await next(tester);
    await next(tester);
    await next(tester);
    await tap(tester, VenuePreference.live.label);
    await next(tester);
    expect(find.text('YOUR TOUR'), findsOneWidget);
    expect(find.textContaining('5K · '), findsOneWidget);
    expect(find.text('24:30'), findsOneWidget); // Predicted
  });

  group('featuring a Crew friend', () {
    final friendRace = _sundayIn(9);
    final featuring = TourFeaturing(
      userId: 'friend-1',
      stageName: 'Sam',
      raceDate: friendRace,
      raceDistance: RaceDistance.fiveK,
      tourName: "Sam's Spring 5K",
    );

    testWidgets('the prefilled race books a Tour featuring them', (
      tester,
    ) async {
      await pump(tester, featuring: featuring);
      expect(nextEnabled(tester), isTrue);
      expect(find.textContaining('Booking a Tour featuring Sam'), findsOne);
      await next(tester);
      expect(find.textContaining('Booking a Tour featuring Sam'), findsOne);
      await next(tester);
      await finishQuiz(tester);
      await tap(tester, 'BOOK THE TOUR');

      expect(tours.saved, hasLength(1));
      final t = tours.saved.single;
      expect(t.featuring?.userId, 'friend-1');
      expect(t.featuring?.stageName, 'Sam');
      expect(t.name, "Sam's Spring 5K");
      expect(t.setup.raceDistance, RaceDistance.fiveK);
      expect(t.raceDate, friendRace);
      expect(Tour.fromJson(t.toJson()).featuring?.userId, 'friend-1');
      expect(find.text('TOUR PAGE'), findsOneWidget);
    });

    testWidgets('choosing another date books a solo Tour', (tester) async {
      await pump(tester, featuring: featuring);
      await next(tester);
      await tap(tester, 'Help me pick');
      expect(find.textContaining('Sam is running the 5K'), findsOne);
      await next(tester);
      await finishQuiz(tester);
      await tap(tester, 'BOOK THE TOUR');

      final t = tours.saved.single;
      expect(t.featuring, isNull);
      expect(t.name, isNot("Sam's Spring 5K"));
      expect(t.raceDate, isNot(friendRace));
    });

    testWidgets('another distance on the same date books a solo Tour', (
      tester,
    ) async {
      await pump(tester, featuring: featuring);
      await tap(tester, '10K');
      expect(find.textContaining('Sam is running the 5K'), findsOne);
      await next(tester);
      await next(tester);
      await finishQuiz(tester);
      await tap(tester, 'BOOK THE TOUR');

      final t = tours.saved.single;
      expect(t.featuring, isNull);
      expect(t.setup.raceDistance, RaceDistance.tenK);
      expect(t.raceDate, friendRace);
    });
  });
}
