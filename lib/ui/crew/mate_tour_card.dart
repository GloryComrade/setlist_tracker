import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/providers.dart';
import '../../models/crew.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'crew_widgets.dart';

final _raceDay = DateFormat('EEE, MMM d, y');

/// Books your own Tour for [mate]'s race. [before] runs first (closing a
/// sheet, say).
void bookTourFeaturing(
  BuildContext context,
  CrewMate mate, {
  VoidCallback? before,
}) {
  final tour = mate.tour;
  if (tour == null) return;
  final router = GoRouter.of(context);
  before?.call();
  router.push(
    '/tour/book',
    extra: TourFeaturing(
      userId: mate.userId,
      stageName: mate.stageName,
      raceDate: tour.raceDate,
      raceDistance: tour.raceDistance,
      tourName: tour.name,
    ),
  );
}

/// A Crew mate's active Tour: the countdown poster, their current week when
/// it's known, and either "Co-headlining `<your Tour>`" or the button that
/// books your own Tour featuring them.
class MateTourCard extends ConsumerWidget {
  const MateTourCard({
    super.key,
    required this.mate,
    this.progress,
    this.onBook,
  });

  final CrewMate mate;

  /// Their current week, from their page. Null hides the week line.
  final CrewWeekProgress? progress;

  /// Overrides what the featuring button does (the sheet closes first).
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tour = mate.tour;
    if (tour == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final mine = ref.watch(activeTourProvider).value;
    final together = coHeadlining(mine, mate);
    final countdown = openingNightLine(tour.raceDate);
    final p = progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PosterSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tour.name.toUpperCase(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${tour.raceDistance.label} · ${_raceDay.format(tour.raceDate)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (countdown != null)
                Text(countdown, style: const TextStyle(color: Colors.white)),
              if (p != null) ...[
                const SizedBox(height: 12),
                Text(
                  'WEEK ${p.week.number} · ${p.week.phase.label.toUpperCase()}'
                  '${p.week.isRestStop ? ' · REST STOP' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weekProgressLine(p),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontFeatures: StageFonts.tabular,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (together)
          Semantics(
            container: true,
            child: Row(
              children: [
                const Icon(Icons.groups, size: 18, color: StageColors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Co-headlining ${mine!.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onBook ?? () => bookTourFeaturing(context, mate),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text('Book a Tour featuring ${mate.stageName}'),
          ),
      ],
    );
  }
}

/// "2 of 5 Shows · 12.4 mi" for a Crew mate's week.
String weekProgressLine(CrewWeekProgress p) =>
    '${p.showsDone} of ${p.showsPlanned} '
    '${p.showsPlanned == 1 ? 'Show' : 'Shows'} · '
    '${p.miles.toStringAsFixed(1)} mi';
