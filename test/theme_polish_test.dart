import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/setlist/show_card.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('a long Headliner keeps its numbers on one ticket line', (
    tester,
  ) async {
    final show = Show(
      id: 'h',
      date: DateTime(2026, 11, 8, 7),
      venue: Venue.live,
      workoutType: WorkoutType.long,
      distanceMiles: 14.33,
      durationSeconds: 8600,
      effort: 8,
      feel: Feel.good,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(_wrap(ShowCard(show: show), width: 340));
    expect(tester.takeException(), isNull);

    final miles = tester.getTopLeft(find.text('14.33 mi'));
    final time = tester.getTopLeft(find.text('2:23:20'));
    expect((miles.dy - time.dy).abs(), lessThan(12));

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.shape, isA<TicketBorder>());
  });

  testWidgets('EmptyStage shows one action only when given one', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        EmptyStage(
          icon: Icons.album_outlined,
          title: 'The wall is bare',
          message: 'Pick a Song of the Show.',
          actionLabel: 'Book a Show',
          onAction: () => tapped = true,
        ),
      ),
    );
    expect(find.text('THE WALL IS BARE'), findsOneWidget);
    await tester.tap(find.text('BOOK A SHOW'));
    expect(tapped, isTrue);

    await tester.pumpWidget(
      _wrap(
        const EmptyStage(
          icon: Icons.queue_music,
          title: 'No Shows yet',
          message: 'Book your first one and start the Setlist.',
        ),
      ),
    );
    expect(find.byType(StageButton), findsNothing);
  });

  testWidgets('the grain paints without errors at any poster size', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const PosterHeader(title: 'THE SETLIST')));
    expect(tester.takeException(), isNull);
    expect(find.byType(PosterSurface), findsOneWidget);
  });
}
