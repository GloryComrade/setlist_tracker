import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
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

/// The news line on a featuring strip, shown and spoken: this week's
/// progress, else their latest Show, else that there's nothing yet.
({String text, String spoken}) featuringNews(
  CrewMateDetail? detail,
  DateTime today,
) {
  if (detail == null) {
    return (
      text: 'Co-headlining Opening Night',
      spoken: 'Co-headlining Opening Night.',
    );
  }
  final shows = [
    for (final p in detail.shows)
      if (!p.show.isDeleted) p.show,
  ];
  final tour = detail.tour;
  final progress = tour == null
      ? null
      : CrewWeekProgress.of(tour, shows, today);
  if (progress != null && progress.showsDone > 0) {
    final n = progress.showsPlanned;
    return (
      text:
          'Week ${progress.week.number} · ${progress.showsDone} of $n '
          '${n == 1 ? 'Show' : 'Shows'} · '
          '${progress.miles.toStringAsFixed(1)} mi so far',
      spoken:
          'Week ${progress.week.number}: ${progress.showsDone} of $n '
          '${n == 1 ? 'Show' : 'Shows'}, '
          '${spokenMiles(progress.miles)} so far.',
    );
  }
  if (progress != null) {
    return (text: 'No Shows yet this week', spoken: 'No Shows yet this week.');
  }
  if (shows.isEmpty) {
    return (text: 'No Shows yet', spoken: 'No Shows yet.');
  }
  final latest = shows.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
  final workout = latest.workoutType.label;
  final pace = latest.paceSecondsPerMile;
  return (
    text: [
      '${DateFormat('EEE').format(latest.date)} · '
          '${formatMiles(latest.distanceMiles)} $workout',
      if (pace != null) formatPace(pace),
    ].join(', '),
    spoken:
        'Latest Show: ${DateFormat('EEEE').format(latest.date)}, '
        '${spokenMiles(latest.distanceMiles)} $workout'
        '${pace == null ? '' : ', ${spokenPace(pace)}'}.',
  );
}

class FeaturingStrip extends ConsumerWidget {
  const FeaturingStrip({super.key, required this.mate});
  final CrewMate mate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(crewMateProvider(mate.userId)).value;
    final news = featuringNews(detail, today());
    void open() => context.push('/crew/mate/${mate.userId}');
    return Semantics(
      container: true,
      button: true,
      label: 'Featuring ${mate.stageName}. ${news.spoken}',
      hint: 'Opens ${mate.stageName}’s page',
      excludeSemantics: true,
      onTap: open,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                CrewAvatar(
                  name: mate.stageName,
                  color: mate.color,
                  size: 40,
                  badge: mate.avatarBadge,
                  photoUrl: mate.avatarUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CrewLabel('Featuring'),
                      Text(
                        mate.stageName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        news.text,
                        style: const TextStyle(
                          fontSize: 13,
                          color: StageColors.textMuted,
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
