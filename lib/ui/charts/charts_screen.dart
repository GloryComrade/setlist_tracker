import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/gold_records.dart';
import '../../logic/show_math.dart';
import '../../logic/tour_stats.dart';
import '../../models/show.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import '../records/gold_disc.dart';
import '../widgets/stage_widgets.dart';
import 'chart_widgets.dart';
import 'opening_night_countdown.dart';

/// The clock The Charts reads. Overridden in tests so weeks line up.
final chartsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The Charts: weekly miles, Headliners, streaks and the Studio/Live split.
class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsProvider);
    final tour = ref.watch(activeTourProvider).value;
    final done = ref.watch(tourProgressProvider);
    final now = ref.watch(chartsClockProvider)();

    return Scaffold(
      // The tab shell paints the stage and its glow behind every tab.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: showsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load The Charts: $e')),
          data: (shows) => _Charts(
            shows: shows.where((s) => !s.isDeleted).toList(),
            tour: tour,
            doneIds: done.keys.toSet(),
            now: now,
          ),
        ),
      ),
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({
    required this.shows,
    required this.tour,
    required this.doneIds,
    required this.now,
  });

  final List<Show> shows;
  final Tour? tour;
  final Set<String> doneIds;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tour = this.tour;
    // On the Tour: this training cycle. Before the Tour starts: the last 12
    // weeks leading into it, so earlier Headliners still show.
    final thisWeek = weekStart(now);
    final headliners = headlinerProgression(
      shows,
      now: now,
      tour: tour,
      since: tour != null && now.isBefore(tour.startDate)
          ? DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * 11)
          : null,
    );
    const gap = SizedBox(height: 12);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PosterHeader(
                title: 'THE CHARTS',
                children: [
                  const SizedBox(height: 10),
                  if (tour != null)
                    OpeningNightCountdown(tour: tour, now: now)
                  else
                    const Text(
                      'Every Show you play climbs The Charts.',
                      style: TextStyle(color: Colors.white, height: 1.4),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (shows.isEmpty) ...[
                const _NoShows(),
                if (headliners.isNotEmpty) ...[
                  gap,
                  _HeadlinerCard(points: headliners, now: now),
                ],
              ] else ...[
                _StatsCard(
                  shows: shows,
                  tour: tour,
                  doneIds: doneIds,
                  now: now,
                ),
                gap,
                _WeeklyCard(
                  weeks: weeklyMileage(shows, now: now, tour: tour),
                ),
                gap,
                _HeadlinerCard(points: headliners, now: now),
                gap,
                _SplitCard(split: venueSplit(shows)),
                gap,
                _GoldRecordsLink(shows: shows),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _NoShows extends StatelessWidget {
  const _NoShows();

  @override
  Widget build(BuildContext context) => EmptyStage(
    icon: Icons.leaderboard_outlined,
    title: 'Nothing on The Charts yet',
    message:
        'Book your first Show and your weekly miles, Headliners and '
        'streaks start charting here.',
    actionLabel: 'Book a Show',
    onAction: () => context.push('/show/new'),
  );
}

// ---------------------------------------------------------------------------
// Stat tiles
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.shows,
    required this.tour,
    required this.doneIds,
    required this.now,
  });

  final List<Show> shows;
  final Tour? tour;
  final Set<String> doneIds;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final thisWeek = weeklyMileage(shows, now: now, tour: tour, weeks: 1).last;
    final streak = weekStreak(shows, now: now, tour: tour, doneIds: doneIds);
    final daily = longestDailyStreak(shows);
    final planned = thisWeek.plannedMiles;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _BigStat(
                      label: 'This week',
                      value: formatMiles(thisWeek.totalMiles, withUnit: false),
                      unit: 'mi',
                      color: StageColors.amber,
                      caption: planned != null && planned > 0
                          ? 'of ${formatMiles(planned)} planned'
                          : thisWeek.showCount == 1
                          ? '1 Show'
                          : '${thisWeek.showCount} Shows',
                      semantics:
                          'This week: ${formatMiles(thisWeek.totalMiles)}'
                          '${planned != null && planned > 0 ? ' of ${formatMiles(planned)} planned' : ''}',
                    ),
                  ),
                  const VerticalDivider(width: 24),
                  Expanded(
                    child: _BigStat(
                      label: 'Streak',
                      value: '${streak.current}',
                      unit: streak.current == 1 ? 'wk' : 'wks',
                      caption: 'Longest ${streak.longest}',
                      semantics:
                          'Week streak: ${streak.current} '
                          '${streak.current == 1 ? 'week' : 'weeks'}, '
                          'longest ${streak.longest}. A week counts with '
                          '3 or more Shows or every Tour run done.',
                    ),
                  ),
                  const VerticalDivider(width: 24),
                  Expanded(
                    child: _BigStat(
                      label: 'Shows',
                      value: NumberFormat.decimalPattern().format(shows.length),
                      caption: 'All time',
                      semantics: '${shows.length} Shows played, all time',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Semantics(
              container: true,
              label:
                  'Longest daily streak: $daily '
                  '${daily == 1 ? 'day' : 'days'} in a row with a Show',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_repeat_outlined,
                      size: 18,
                      color: StageColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Back-to-back Shows, longest run',
                        style: TextStyle(
                          color: StageColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '$daily ${daily == 1 ? 'day' : 'days'}',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontFeatures: StageFonts.tabular),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'A streak week has 3+ Shows or every Tour run done.',
              style: TextStyle(color: StageColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.caption,
    required this.semantics,
    this.unit,
    this.color = StageColors.text,
  });

  final String label;
  final String value;
  final String? unit;
  final String caption;
  final String semantics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.headlineLarge
        ?.copyWith(color: color, fontFeatures: StageFonts.tabular);
    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: StageColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: value,
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: big?.copyWith(fontSize: 18),
                      ),
                  ],
                ),
                style: big,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(
                color: StageColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart cards
// ---------------------------------------------------------------------------

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.weeks});
  final List<WeekMiles> weeks;

  @override
  Widget build(BuildContext context) {
    final chart = WeeklyMilesChart(weeks: weeks);
    final total = weeks.fold(0.0, (s, w) => s + w.totalMiles);
    return SectionCard(
      title: 'Weekly miles',
      trailing: Text(
        '${formatMiles(total)} in ${weeks.length} wks',
        style: const TextStyle(
          color: StageColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          chart,
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              const LegendItem(label: 'Studio Sessions', color: studioMark),
              const LegendItem(label: 'Live Shows', color: liveMark),
              if (chart.hasPlan)
                const LegendItem(
                  label: 'Tour plan',
                  color: ghostMark,
                  kind: SwatchKind.dashed,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeadlinerCard extends StatelessWidget {
  const _HeadlinerCard({required this.points, required this.now});
  final List<HeadlinerPoint> points;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final chart = HeadlinerChart(points: points, now: now);
    final fmt = DateFormat('EEE, MMM d');
    final longest = chart.longest;
    final next = chart.next;
    const muted = TextStyle(color: StageColors.textMuted, height: 1.4);

    return SectionCard(
      title: 'Headliners',
      child: chart.isEmpty
          ? const Text(
              'No Headliners yet. Log a long run as a Headliner and watch '
              'the climb toward Opening Night.',
              style: muted,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    if (longest != null)
                      StatTile(
                        label: 'Longest so far',
                        value: formatMiles(longest.miles),
                      ),
                    if (next != null)
                      StatTile(
                        label: 'Next · ${fmt.format(next.date)}',
                        value: formatMiles(next.miles),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                chart,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (chart.logged.isNotEmpty)
                      const LegendItem(
                        label: 'Played',
                        color: headlinerMark,
                        kind: SwatchKind.dot,
                      ),
                    if (chart.planned.isNotEmpty)
                      const LegendItem(
                        label: 'On the Tour',
                        color: ghostMark,
                        kind: SwatchKind.ring,
                      ),
                    const LegendItem(
                      label: 'Peak 18–20 mi',
                      color: liveMark,
                      kind: SwatchKind.band,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.split});
  final VenueSplit split;

  @override
  Widget build(BuildContext context) {
    final studioLead = split.studioMiles > split.liveMiles;
    final share = studioLead
        ? split.studioMilesShare
        : 1 - split.studioMilesShare;
    final pct = (share * 100).round();
    final headline = split.studioMiles == split.liveMiles
        ? 'An even split between the Studio and the stage.'
        : studioLead
        ? '$pct% of your miles were Studio Sessions.'
        : '$pct% of your miles were Live Shows.';

    return SectionCard(
      title: 'Studio vs Live',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 16),
          VenueSplitBar(
            label: 'Miles',
            studio: split.studioMiles,
            live: split.liveMiles,
            format: formatMiles,
          ),
          const SizedBox(height: 20),
          VenueSplitBar(
            label: 'Shows',
            studio: split.studioShows.toDouble(),
            live: split.liveShows.toDouble(),
            format: (v) => v == 1 ? '1 Show' : '${v.round()} Shows',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gold Records door
// ---------------------------------------------------------------------------

class _GoldRecordsLink extends StatelessWidget {
  const _GoldRecordsLink({required this.shows});
  final List<Show> shows;

  @override
  Widget build(BuildContext context) {
    final pressed = computeGoldRecords(shows).length;
    final total = RecordKind.values.length;
    final caption = pressed == 0
        ? 'None pressed yet'
        : '$pressed of $total pressed · your best Shows';
    return Semantics(
      container: true,
      button: true,
      label: 'Gold Records, $caption',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/backstage/gold-records'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GoldDisc(size: 44, pressed: pressed > 0),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOLD RECORDS',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: const TextStyle(
                          color: StageColors.textMuted,
                          fontSize: 13,
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
