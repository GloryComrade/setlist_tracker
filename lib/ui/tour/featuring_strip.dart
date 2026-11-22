import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import '../crew/crew_widgets.dart';
import 'tour_widgets.dart';

/// On the Tour tab: one "Featuring Maya" strip for each Crew mate racing the
/// same Opening Night, with how their week is going. Nothing at all when
/// you're signed out or nobody matches.
class FeaturingStrips extends ConsumerWidget {
  const FeaturingStrips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mates = ref.watch(coHeadlinersProvider);
    if (mates.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < mates.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            FeaturingStrip(mate: mates[i]),
          ],
        ],
      ),
    );
  }
}

class FeaturingStrip extends ConsumerWidget {
  const FeaturingStrip({super.key, required this.mate});
  final CrewMate mate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(crewMateProvider(mate.userId)).value;
    final tour = detail?.tour;
    final progress = tour == null
        ? null
        : CrewWeekProgress.of(tour, [
            for (final p in detail!.shows) p.show,
          ], today());
    final line = progress == null
        ? null
        : 'Week ${progress.week.number} · ${progress.showsDone} of '
              '${progress.showsPlanned} '
              '${progress.showsPlanned == 1 ? 'Show' : 'Shows'} · '
              '${progress.miles.toStringAsFixed(1)} mi so far';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/crew/mate/${mate.userId}'),
        child: Semantics(
          button: true,
          label: [
            'Featuring ${mate.stageName}.',
            if (progress != null)
              'Week ${progress.week.number}: ${progress.showsDone} of '
                  '${progress.showsPlanned} Shows, '
                  '${progress.miles.toStringAsFixed(1)} miles so far.',
          ].join(' '),
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                CrewAvatar(name: mate.stageName, color: mate.color, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CrewLabel('Featuring ${mate.stageName}'),
                      const SizedBox(height: 2),
                      Text(
                        line ?? 'Co-headlining Opening Night',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFeatures: StageFonts.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: StageColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
