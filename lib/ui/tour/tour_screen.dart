import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/show_math.dart';
import '../../logic/tour_builder.dart';
import '../../models/enums.dart';
import '../../models/show.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'tour_manager_cards.dart';
import 'tour_widgets.dart';

/// The Tour tab: the weekly Tour Schedule, or an invitation to book one.
class TourScreen extends ConsumerWidget {
  const TourScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourAsync = ref.watch(activeTourProvider);
    return Scaffold(
      // The tab shell paints the stage and its glow behind every tab.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: tourAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load The Tour: $e')),
          data: (tour) =>
              tour == null ? const _NoTour() : _Schedule(tour: tour),
        ),
      ),
    );
  }
}

class _NoTour extends StatelessWidget {
  const _NoTour();

  @override
  Widget build(BuildContext context) {
    return MaxWidth(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PosterHeader(
            title: 'THE TOUR',
            children: [
              const SizedBox(height: 8),
              const Text(
                'Every marathon is a tour, and race day is Opening Night. '
                'Answer 8 quick questions and get a week-by-week plan from '
                'the first Rehearsal to the finish line.',
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: _WhiteButton(
                  label: 'Book The Tour',
                  icon: Icons.confirmation_number_outlined,
                  onPressed: () => context.push('/tour/book'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final p in TourPhase.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: phaseColor(p),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          p.subtitle,
                          style: const TextStyle(color: StageColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const TourDisclaimer(),
        ],
      ),
    );
  }
}

/// White pill for use on top of a gradient.
class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onPressed, this.icon});
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: StageColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(
      label.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1),
    ),
  );
}

class _Schedule extends ConsumerStatefulWidget {
  const _Schedule({required this.tour});
  final Tour tour;

  @override
  ConsumerState<_Schedule> createState() => _ScheduleState();
}

class _ScheduleState extends ConsumerState<_Schedule> {
  /// Weeks the runner opened or closed by hand. Others follow the default:
  /// only the current week (or the first, before the Tour starts) is open.
  final Map<int, bool> _open = {};

  int? get _currentWeek => widget.tour.weekContaining(today())?.number;

  bool _isOpen(TourWeek w) {
    final manual = _open[w.number];
    if (manual != null) return manual;
    final current = _currentWeek;
    if (current != null) return w.number == current;
    return w.number == 1 && today().isBefore(widget.tour.startDate);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel The Tour?'),
        content: const Text(
          'The Tour Schedule goes away. Shows you already logged stay on '
          'your Setlist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Tour'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(tourRepositoryProvider).delete(widget.tour.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    final done = ref.watch(tourProgressProvider);
    final shows = ref.watch(showsProvider).value ?? const <Show>[];
    final current = _currentWeek;
    final daysToGo = daysBetween(today(), tour.raceDate);

    return MaxWidth(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _Header(
                tour: tour,
                daysToGo: daysToGo,
                currentWeek: current,
                onRebook: () => context.push('/tour/book'),
                onCancel: _cancel,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(child: _PacesCard(paces: tour.paces)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: TourManagerSection(tour: tour, now: DateTime.now()),
            ),
          ),
          if (tour.warnings.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList.separated(
                itemCount: tour.warnings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final w = splitWarning(tour.warnings[i]);
                  return TourCheckNote(title: w.title, message: w.message);
                },
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'TOUR DATES',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: tour.weeks.length,
              itemBuilder: (_, i) {
                final w = tour.weeks[i];
                return _WeekBlock(
                  week: w,
                  isCurrent: w.number == current,
                  open: _isOpen(w),
                  done: done,
                  shows: shows,
                  onToggle: () => setState(() => _open[w.number] = !_isOpen(w)),
                );
              },
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 96),
            sliver: SliverToBoxAdapter(child: TourDisclaimer()),
          ),
        ],
      ),
    );
  }
}

/// "3:45" for a marathon goal time.
String _hm(int? seconds) {
  final s = seconds ?? 0;
  return '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tour,
    required this.daysToGo,
    required this.currentWeek,
    required this.onRebook,
    required this.onCancel,
  });

  final Tour tour;
  final int daysToGo;
  final int? currentWeek;
  final VoidCallback onRebook;
  final VoidCallback onCancel;

  String get _status {
    if (daysToGo < 0) return 'Opening Night has been played';
    if (daysToGo == 0) return 'Opening Night is today';
    final now = today();
    if (now.isBefore(tour.startDate)) {
      return 'Rehearsals start ${formatShortDate(tour.startDate)}';
    }
    final week = tour.weekContaining(now);
    if (week == null) return '';
    return 'Week ${week.number} of ${tour.weeks.length} · ${week.phase.label}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = switch (tour.setup.goal) {
      TourGoal.finish => 'Goal: finish strong',
      TourGoal.targetTime => 'Goal: ${_hm(tour.setup.goalTimeSeconds)}',
      TourGoal.bq => 'Goal: BQ in ${_hm(tour.setup.goalTimeSeconds)}',
    };
    return PosterSurface(
      gradient: StageColors.headlineGradient,
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: WholeWordsText(
                    tour.name.toUpperCase(),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tour options',
                iconColor: Colors.white,
                onSelected: (v) => v == 'rebook' ? onRebook() : onCancel(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rebook',
                    child: Text('Rebook The Tour'),
                  ),
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel The Tour'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Opening Night · ${formatLongDate(tour.raceDate)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(goal, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _Countdown(daysToGo: daysToGo, status: _status),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: StageColors.background.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TourStrip(tour: tour, currentWeek: currentWeek),
            ),
          ),
        ],
      ),
    );
  }
}

/// "116 DAYS TO GO" with the Tour status beside it, or under it when the
/// status would be squeezed (large text sizes, narrow phones).
class _Countdown extends StatelessWidget {
  const _Countdown({required this.daysToGo, required this.status});
  final int daysToGo;
  final String status;

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );
  static const _statusStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.displayLarge
        ?.copyWith(color: Colors.white, fontFeatures: StageFonts.tabular);
    final label = daysToGo == 1 ? 'DAY TO GO' : 'DAYS TO GO';
    final counter = daysToGo > 0
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$daysToGo', style: big),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(label, style: _labelStyle),
                ),
              ),
            ],
          )
        : null;
    if (status.isEmpty) return counter ?? const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final counterWidth = counter == null
            ? 0.0
            : measureTextWidth(context, '$daysToGo', big) +
                  10 +
                  measureTextWidth(context, label, _labelStyle);
        final room = constraints.maxWidth - counterWidth - 16;
        // Side by side only while the status fits in two lines and no word
        // of it has to break.
        final widestWord = status
            .split(' ')
            .map((w) => measureTextWidth(context, w, _statusStyle))
            .fold(0.0, math.max);
        final sideBySide =
            counter != null &&
            widestWord <= room &&
            measureTextWidth(context, status, _statusStyle) <= room * 2 - 24;
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              counter,
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    status,
                    textAlign: TextAlign.right,
                    style: _statusStyle,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?counter,
            Text(status, style: _statusStyle),
          ],
        );
      },
    );
  }
}

class _PacesCard extends StatelessWidget {
  const _PacesCard({required this.paces});
  final TourPaces? paces;

  @override
  Widget build(BuildContext context) {
    final p = paces;
    if (p == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Running by feel: easy days should be conversational. Log a race '
            'or set a goal time to get pace targets.',
            style: TextStyle(color: StageColors.textMuted),
          ),
        ),
      );
    }
    String pace(double s) => formatPace(s, withUnit: false);
    final items = [
      ('Easy', '${pace(p.easyFast)}–${pace(p.easySlow)}'),
      ('Opening Night', pace(p.marathon)),
      ('Tempo', pace(p.tempo)),
      ('Intervals', pace(p.interval)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The prediction moves under the title when they don't fit on
            // one line.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                WholeWordsText(
                  'PACES PER MILE',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Predicts ${formatDuration(p.predictedMarathonSeconds)}',
                  style: const TextStyle(
                    color: StageColors.amber,
                    fontWeight: FontWeight.w700,
                    fontFeatures: StageFonts.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                for (final (label, value) in items)
                  StatTile(label: label, value: value),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBlock extends StatelessWidget {
  const _WeekBlock({
    required this.week,
    required this.isCurrent,
    required this.open,
    required this.done,
    required this.shows,
    required this.onToggle,
  });

  /// Every Show on the Setlist; this week's ones count toward actual miles.
  final List<Show> shows;
  final TourWeek week;
  final bool isCurrent;
  final bool open;
  final Map<String, Show> done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = phaseColor(week.phase);
    final active = week.shows.where((s) => !s.skipped).toList();
    final logged = active.where((s) => done.containsKey(s.id)).length;
    final all = active.length;
    // Planned vs. actual: every Show run this week counts, planned or not.
    final weekShows = shows.where((s) => week.contains(s.date)).toList();
    final actualMiles = weekShows.fold(0.0, (a, s) => a + s.distanceMiles);
    final hasActual = weekShows.isNotEmpty;
    final past = week.endDate.isBefore(today());
    final numberStyle = theme.textTheme.headlineLarge?.copyWith(
      color: past && !isCurrent ? StageColors.textMuted : color,
      fontFeatures: StageFonts.tabular,
    );
    // Rounded to the half mile: it's a target, not a measurement.
    final plannedText = formatMiles((week.plannedMiles * 2).round() / 2);
    final milesText = hasActual
        ? '${formatMiles(actualMiles, withUnit: false)} / $plannedText'
        : plannedText;
    final loggedText = '$logged of $all logged';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? StageColors.surfaceHigh : StageColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? color.withValues(alpha: 0.7) : StageColors.outline,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The week number column grows with the text size.
                  final numberWidth = math.max(
                    44.0,
                    measureTextWidth(context, '00', numberStyle) + 10,
                  );
                  final milesWidth = math.max(
                    measureTextWidth(context, milesText, _milesStyle),
                    measureTextWidth(context, loggedText, _loggedStyle),
                  );
                  // At large text sizes the miles move under the dates so the
                  // phase name keeps its whole words.
                  final sideBySide =
                      numberWidth +
                          measureTextWidth(
                            context,
                            week.phase.label,
                            _phaseStyle,
                          ) +
                          8 +
                          milesWidth +
                          4 +
                          24 <=
                      constraints.maxWidth;
                  final number = SizedBox(
                    width: numberWidth,
                    child: Text(
                      week.number.toString().padLeft(2, '0'),
                      style: numberStyle,
                    ),
                  );
                  final miles = Column(
                    crossAxisAlignment: sideBySide
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            if (hasActual)
                              TextSpan(
                                text:
                                    '${formatMiles(actualMiles, withUnit: false)} / ',
                              ),
                            TextSpan(
                              text: plannedText,
                              style: hasActual
                                  ? const TextStyle(
                                      color: StageColors.textMuted,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        semanticsLabel: hasActual
                            ? '${formatMiles(actualMiles)} of '
                                  '${formatMiles(week.plannedMiles)} planned'
                            : '${formatMiles(week.plannedMiles)} planned',
                        style: _milesStyle,
                      ),
                      Text(loggedText, style: _loggedStyle),
                    ],
                  );
                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(week.phase.label, style: _phaseStyle),
                          if (week.isRestStop) const TourTag('Rest Stop'),
                          if (isCurrent)
                            const TourTag('This week', color: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatWeekRange(week),
                        style: const TextStyle(
                          color: StageColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (!sideBySide) ...[const SizedBox(height: 4), miles],
                    ],
                  );
                  return Row(
                    children: [
                      number,
                      Expanded(child: info),
                      if (sideBySide) ...[const SizedBox(width: 8), miles],
                      const SizedBox(width: 4),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        color: StageColors.textMuted,
                        semanticLabel: open ? 'Hide days' : 'Show days',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1),
            for (final s in week.shows) _DayRow(show: s, logged: done[s.id]),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

const _phaseStyle = TextStyle(fontWeight: FontWeight.w700);
const _milesStyle = TextStyle(
  fontWeight: FontWeight.w800,
  color: StageColors.amber,
  fontFeatures: StageFonts.tabular,
);
const _loggedStyle = TextStyle(
  color: StageColors.textMuted,
  fontSize: 12,
  fontFeatures: StageFonts.tabular,
);

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _DayRow extends StatelessWidget {
  const _DayRow({required this.show, required this.logged});
  final PlannedShow show;
  final Show? logged;

  @override
  Widget build(BuildContext context) {
    final now = today();
    final isToday = show.date == now;
    final skipped = show.skipped && logged == null;
    final missed = logged == null && (skipped || show.date.isBefore(now));
    final muted = missed ? StageColors.textMuted : StageColors.text;
    final ran = logged;
    final moved = show.rescheduledFrom;
    final String subline;
    if (ran != null) {
      subline =
          'Ran ${formatMiles(ran.distanceMiles)} · '
          '${formatPace(ran.paceSecondsPerMile)}';
    } else if (skipped) {
      subline = 'Skipped';
    } else {
      final venue = show.venue == Venue.studio ? 'Studio Session' : 'Live Show';
      subline = moved == null
          ? venue
          : '$venue · moved from ${_dayNames[moved.weekday - 1]}';
    }
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final weekdayStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
      color: isToday ? StageColors.magenta : StageColors.textMuted,
    );
    final dayStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: isToday ? StageColors.magenta : muted,
      fontFeatures: StageFonts.tabular,
    );
    final dayWidth = math.max(
      44.0,
      math.max(
            measureTextWidth(context, 'WED', weekdayStyle),
            measureTextWidth(context, '00', dayStyle),
          ) +
          6,
    );
    final titleStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: muted,
      decoration: skipped ? TextDecoration.lineThrough : null,
      decorationColor: StageColors.textMuted,
    );
    final milesStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: muted,
      fontFeatures: StageFonts.tabular,
    );

    return InkWell(
      onTap: () => context.push('/tour/show/${show.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // At large text sizes the miles move under the title so its words
            // stay whole.
            final milesText = formatMiles(show.distanceMiles);
            final room =
                constraints.maxWidth -
                dayWidth -
                20 -
                12 -
                measureTextWidth(context, milesText, milesStyle) -
                12 -
                24;
            final sideBySide = show.title
                .split(' ')
                .every((w) => measureTextWidth(context, w, titleStyle) <= room);
            final miles = Text(milesText, style: milesStyle);
            return Row(
              children: [
                SizedBox(
                  // Grows with the text size so "WED" never breaks.
                  width: dayWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekdays[show.date.weekday - 1],
                        style: weekdayStyle,
                      ),
                      Text('${show.date.day}', style: dayStyle),
                    ],
                  ),
                ),
                Icon(
                  workoutIcon(show.workoutType),
                  size: 20,
                  color: show.workoutType == WorkoutType.long || show.isRace
                      ? StageColors.amber
                      : muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(show.title, style: titleStyle),
                      Text(
                        subline,
                        style: TextStyle(
                          color: ran != null
                              ? StageColors.amber
                              : StageColors.textMuted,
                          fontSize: 12.5,
                          fontFeatures: StageFonts.tabular,
                        ),
                      ),
                      if (!sideBySide) miles,
                    ],
                  ),
                ),
                if (sideBySide) miles,
                const SizedBox(width: 12),
                SizedBox(
                  width: 24,
                  child: logged != null
                      ? const Icon(
                          Icons.check_circle,
                          color: StageColors.amber,
                          size: 22,
                          semanticLabel: 'Logged',
                        )
                      : Icon(
                          Icons.radio_button_unchecked,
                          color: StageColors.outline,
                          size: 22,
                          semanticLabel: skipped
                              ? 'Skipped'
                              : missed
                              ? 'Not logged'
                              : 'Planned',
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
