import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../data/providers.dart';
import '../../logic/calendar.dart';
import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../logic/tour_logging.dart';
import '../../models/enums.dart';
import '../../models/show.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import '../records/gold_disc.dart';
import '../tour/tour_widgets.dart';
import '../widgets/stage_widgets.dart';

/// "Now" for The Calendar. Tests pin it to a fixed day.
final calendarClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The Calendar: a month at a time, logged Shows and the Tour's plan on one
/// grid. Opened from the Setlist and Tour headers.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialMonth});

  /// The month to open on; today's month when null or out of range.
  final DateTime? initialMonth;

  /// Reads "2027-03" from `/calendar?month=2027-03`.
  static DateTime? parseMonth(String? text) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(text ?? '');
    if (m == null) return null;
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    return DateTime(int.parse(m.group(1)!), month);
  }

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  PageController? _pages;
  int _index = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      pages.jumpToPage(i);
    } else {
      pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openDay(DateTime date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DaySheet(date: date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showsAsync = ref.watch(showsProvider);
    final tourAsync = ref.watch(activeTourProvider);
    final now = ref.watch(calendarClockProvider)();
    final today = DateTime(now.year, now.month, now.day);

    Widget body;
    int? todayIndex;
    if (showsAsync.hasError || tourAsync.hasError) {
      body = Center(
        child: Text(
          'Could not load The Calendar: '
          '${showsAsync.error ?? tourAsync.error}',
        ),
      );
    } else if (!showsAsync.hasValue || !tourAsync.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final shows = showsAsync.value!;
      final tour = tourAsync.value;
      final done = ref.watch(tourProgressProvider);
      final months = calendarMonths(shows: shows, tour: tour, today: today);
      todayIndex = months.indexOf(monthOf(today));
      if (_pages == null) {
        final wanted = widget.initialMonth == null
            ? -1
            : months.indexOf(monthOf(widget.initialMonth!));
        _index = wanted >= 0 ? wanted : todayIndex;
        _pages = PageController(initialPage: _index);
      }
      _index = _index.clamp(0, months.length - 1);
      final gold = goldRecordDays(shows);
      final month = months[_index];
      final monthShows = shows
          .where(
            (s) => s.date.year == month.year && s.date.month == month.month,
          )
          .toList();
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _MonthPoster(
              month: month,
              showCount: monthShows.length,
              miles: monthShows.fold(0.0, (a, s) => a + s.distanceMiles),
              countdown: tour == null
                  ? null
                  : openingNightCountdown(tour, today),
              onPrevious: _index > 0 ? () => _goTo(_index - 1) : null,
              onNext: _index < months.length - 1
                  ? () => _goTo(_index + 1)
                  : null,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: months.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _MonthPage(
                month: buildCalendarMonth(
                  months[i],
                  shows: shows,
                  tour: tour,
                  done: done,
                  today: today,
                  goldDays: gold,
                ),
                firstWeekday: calendarFirstWeekday(tour),
                hasTour: tour != null,
                onDay: _openDay,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: backButtonFor(context),
        title: const Text('THE CALENDAR'),
        actions: [
          if (todayIndex != null)
            TextButton(
              onPressed: _index == todayIndex ? null : () => _goTo(todayIndex!),
              child: const Text('Today'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(top: false, child: MaxWidth(child: body)),
    );
  }
}

class _MonthPoster extends StatelessWidget {
  const _MonthPoster({
    required this.month,
    required this.showCount,
    required this.miles,
    required this.countdown,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final int showCount;
  final double miles;
  final String? countdown;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = calendarMonthTitle(month);
    final name = title.split(' ').first;
    final shows = '$showCount ${showCount == 1 ? 'Show' : 'Shows'}';
    final summary = showCount == 0
        ? '${month.year} · No Shows'
        : '${month.year} · $shows · ${formatMiles(miles)}';
    final spokenSummary = showCount == 0
        ? 'No Shows'
        : '$shows, ${spokenMiles(miles)}';
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    Widget arrow(IconData icon, String tip, VoidCallback? onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      color: Colors.white,
      disabledColor: Colors.white.withValues(alpha: 0.35),
      icon: Icon(icon),
    );
    return PosterSurface(
      padding: const EdgeInsets.fromLTRB(20, 14, 6, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: WholeWordsText(
                    name.toUpperCase(),
                    semanticsLabel: title,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary,
                  semanticsLabel: spokenSummary,
                  style: white.copyWith(fontFeatures: StageFonts.tabular),
                ),
                if (countdown != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          countdown!,
                          style: white.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: StageFonts.tabular,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          arrow(Icons.chevron_left, 'Previous month', onPrevious),
          arrow(Icons.chevron_right, 'Next month', onNext),
        ],
      ),
    );
  }
}

const _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _stripe = 3.0;
const _stripeGap = 5.0;

const _numberStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  fontFeatures: StageFonts.tabular,
);
const _milesStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w800,
  fontFeatures: StageFonts.tabular,
);
const _labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
const _totalStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w800,
  color: StageColors.amber,
  fontFeatures: StageFonts.tabular,
);
const _plannedStyle = TextStyle(
  fontSize: 12,
  color: StageColors.textMuted,
  fontFeatures: StageFonts.tabular,
);
const _restStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.8,
  color: StageColors.amber,
);

class _MonthPage extends StatelessWidget {
  const _MonthPage({
    required this.month,
    required this.firstWeekday,
    required this.hasTour,
    required this.onDay,
  });

  final CalendarMonth month;
  final int firstWeekday;
  final bool hasTour;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    // The squares hold at 150% text; past that they'd stop being a grid, so
    // they stop growing there (like chart axes). The day sheet and every
    // spoken label carry the full detail at any size.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // The week totals sit in a right column while the squares stay
            // wide enough for "28" and a mile count; otherwise under the row.
            final totalsWidth =
                [
                  measureTextWidth(context, '00.0', _totalStyle),
                  measureTextWidth(context, '/ 00.5 mi', _plannedStyle),
                  measureTextWidth(context, 'REST', _restStyle),
                ].fold(0.0, math.max) +
                6;
            final minCell = math.max(
              40.0,
              measureTextWidth(context, '00.0', _milesStyle) + 6,
            );
            final sideTotals =
                (width - _stripe - _stripeGap - totalsWidth) / 7 >= minCell;
            final cellWidth =
                (width -
                    _stripe -
                    _stripeGap -
                    (sideTotals ? totalsWidth : 0)) /
                7;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      const SizedBox(width: _stripe + _stripeGap),
                      for (var i = 0; i < 7; i++)
                        SizedBox(
                          width: cellWidth,
                          child: Text(
                            _weekdayLabels[(firstWeekday - 1 + i) % 7],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: StageColors.textMuted,
                            ),
                          ),
                        ),
                      if (sideTotals) SizedBox(width: totalsWidth),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                for (final w in month.weeks)
                  _WeekRow(
                    week: w,
                    cellWidth: cellWidth,
                    totalsWidth: sideTotals ? totalsWidth : null,
                    onDay: onDay,
                  ),
                const SizedBox(height: 16),
                _Legend(hasTour: hasTour),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.week,
    required this.cellWidth,
    required this.totalsWidth,
    required this.onDay,
  });

  final CalendarWeek week;
  final double cellWidth;

  /// Null when the totals go under the row instead of beside it.
  final double? totalsWidth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final tw = week.tourWeek;
    final miles = weekMilesText(week);
    final showTotals = tw != null || week.doneMiles > 0;
    final rest = tw?.isRestStop ?? false;
    final side = totalsWidth != null;
    final totals = !showTotals
        ? const SizedBox.shrink()
        : Semantics(
            label: [
              if (tw != null) 'Week ${tw.number}, ${tw.phase.label}',
              if (rest) 'Rest Stop',
              spokenWeekMiles(week),
            ].join('. '),
            child: ExcludeSemantics(
              child: side
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (miles.done != null)
                          Text(miles.done!, style: _totalStyle),
                        if (miles.planned != null)
                          Text(
                            miles.done == null
                                ? miles.planned!
                                : '/ ${miles.planned}',
                            style: _plannedStyle,
                          ),
                        if (rest) ...[
                          const SizedBox(height: 2),
                          const Text(
                            'REST\nSTOP',
                            textAlign: TextAlign.right,
                            style: _restStyle,
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        if (rest) const Text('REST STOP', style: _restStyle),
                        const Spacer(),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (miles.done != null)
                                TextSpan(text: miles.done, style: _totalStyle),
                              if (miles.planned != null)
                                TextSpan(
                                  text: miles.done == null
                                      ? miles.planned
                                      : ' / ${miles.planned}',
                                  style: _plannedStyle,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: _stripe + _stripeGap),
        for (final d in week.days)
          SizedBox(
            width: cellWidth,
            child: _DayCell(
              day: d,
              width: cellWidth,
              onTap: () => onDay(d.date),
            ),
          ),
        if (side)
          SizedBox(
            width: totalsWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: totals,
            ),
          ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: StageColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row,
              if (!side && showTotals)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _stripe + _stripeGap + 4,
                    0,
                    8,
                    6,
                  ),
                  child: totals,
                ),
            ],
          ),
          // The Tour phase, as a thin light down the row's edge.
          if (tw != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _stripe,
              child: ColoredBox(
                color: phaseColor(tw.phase)
                    .withValues(alpha: rest ? 0.5 : 0.95),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.width, required this.onTap});

  final CalendarDay day;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final marks = <Widget>[
      for (final s in day.shows.take(2)) _VenueDot(venue: s.venue),
      for (final p in day.plans.take(2)) _PlanMark(plan: p, missed: day.isPast),
      if (day.goldRecord) const GoldDisc(size: 12),
      if (day.openingNight)
        const Icon(
          Icons.confirmation_number,
          size: 14,
          color: StageColors.amber,
        ),
    ];

    final pending = day.pending;
    final firstPlan = day.plans
        .where((p) => !p.skipped)
        .cast<CalendarPlan?>()
        .firstWhere((_) => true, orElse: () => null);
    final String? milesText;
    final Color milesColor;
    if (day.shows.isNotEmpty) {
      milesText = formatMiles(_round1(day.loggedMiles), withUnit: false);
      milesColor = StageColors.amber;
    } else if (pending.isNotEmpty) {
      milesText = formatMiles(
        pending.fold(0.0, (a, p) => a + p.plan.distanceMiles),
        withUnit: false,
      );
      milesColor = StageColors.textMuted;
    } else {
      milesText = null;
      milesColor = StageColors.textMuted;
    }
    final label = firstPlan == null
        ? null
        : calendarShortLabel(firstPlan.plan.workoutType);
    final big =
        firstPlan != null &&
        (firstPlan.plan.workoutType == WorkoutType.long ||
            firstPlan.plan.isRace);
    final showLabel =
        label != null &&
        measureTextWidth(context, label, _labelStyle) <= width - 4;

    final number = Text(
      '${day.date.day}',
      style: _numberStyle.copyWith(
        color: day.isToday ? StageColors.goldInk : StageColors.text,
      ),
    );
    final circle = 24 * scale;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: circle,
          child: Center(
            child: day.isToday
                ? Container(
                    width: circle,
                    height: circle,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: StageColors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: number,
                  )
                : number,
          ),
        ),
        const SizedBox(height: 4),
        if (marks.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: marks,
          ),
        if (milesText != null) ...[
          const SizedBox(height: 2),
          Text(
            milesText,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: _milesStyle.copyWith(color: milesColor),
          ),
        ],
        if (showLabel)
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: _labelStyle.copyWith(
              color: big ? StageColors.amber : StageColors.textMuted,
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: spokenCalendarDay(day),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 64 * scale),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
            child: Opacity(opacity: day.inMonth ? 1 : 0.35, child: content),
          ),
        ),
      ),
    );
  }
}

double _round1(double v) => (v * 10).round() / 10;

/// A logged Show: a dot in its venue's mark.
class _VenueDot extends StatelessWidget {
  const _VenueDot({required this.venue});
  final Venue venue;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(shape: BoxShape.circle, color: markFor(venue)),
  );
}

/// A planned run: an open ring, a check once it's done, faint when skipped.
class _PlanMark extends StatelessWidget {
  const _PlanMark({required this.plan, this.missed = false});
  final CalendarPlan plan;

  /// Its day has passed without a Show.
  final bool missed;

  @override
  Widget build(BuildContext context) {
    if (plan.done) {
      return const Icon(Icons.check_circle, size: 13, color: StageColors.amber);
    }
    final big = plan.plan.workoutType == WorkoutType.long || plan.plan.isRace;
    return Opacity(
      opacity: plan.skipped || missed ? 0.4 : 1,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: big ? StageColors.amber : StageColors.textMuted,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hasTour});
  final bool hasTour;

  @override
  Widget build(BuildContext context) {
    Widget item(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 14, child: Center(child: mark)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: StageColors.textMuted, fontSize: 12),
        ),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          item(const _VenueDot(venue: Venue.live), 'Live Show'),
          item(const _VenueDot(venue: Venue.studio), 'Studio Session'),
          if (hasTour) ...[
            item(
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: StageColors.textMuted, width: 1.5),
                ),
              ),
              'Planned',
            ),
            item(
              const Icon(
                Icons.check_circle,
                size: 13,
                color: StageColors.amber,
              ),
              'Done',
            ),
            item(
              const Icon(
                Icons.confirmation_number,
                size: 14,
                color: StageColors.amber,
              ),
              'Opening Night',
            ),
          ],
          item(const GoldDisc(size: 12), 'Gold Record'),
        ],
      ),
    );
  }
}

/// What's on one day: the Shows logged and the Tour's plan, each opening its
/// page, with "Done as planned" for a run still to log.
class _DaySheet extends ConsumerStatefulWidget {
  const _DaySheet({required this.date});
  final DateTime date;

  @override
  ConsumerState<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<_DaySheet> {
  String? _saving;

  Future<void> _doneAsPlanned(PlannedShow p) async {
    setState(() => _saving = p.id);
    final now = ref.read(calendarClockProvider)();
    final show = showFromPlan(p, id: const Uuid().v4(), now: now);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(showRepositoryProvider).save(show);
    } catch (e) {
      if (mounted) setState(() => _saving = null);
      messenger.showSnackBar(SnackBar(content: Text('Could not log it: $e')));
      return;
    }
    if (mounted) setState(() => _saving = null);
    messenger.showSnackBar(
      SnackBar(content: Text('${p.title} logged as planned.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shows = ref.watch(showsProvider).value ?? const <Show>[];
    final tour = ref.watch(activeTourProvider).value;
    final done = ref.watch(tourProgressProvider);
    final now = ref.watch(calendarClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final day = calendarDayFor(
      widget.date,
      shows: shows,
      tour: tour,
      done: done,
      today: today,
      goldDays: goldRecordDays(shows),
    );
    final week = tour?.weekContaining(widget.date);
    final theme = Theme.of(context);
    final linked = {
      for (final p in day.plans)
        if (p.logged != null) p.logged!.id,
    };
    final extraShows = day.shows.where((s) => !linked.contains(s.id)).toList();

    final tags = <String>[
      if (day.isToday) 'Today',
      if (week != null) 'Week ${week.number} · ${week.phase.label}',
      if (week?.isRestStop ?? false) 'Rest Stop',
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Semantics(
              header: true,
              child: WholeWordsText(
                spokenCalendarDate(widget.date).toUpperCase(),
                semanticsLabel: spokenCalendarDate(widget.date),
                style: theme.textTheme.headlineMedium,
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tags.join(' · '),
                style: const TextStyle(color: StageColors.textMuted),
              ),
            ],
            if (day.openingNight || day.goldRecord) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (day.openingNight)
                    const _Flag(
                      mark: Icon(
                        Icons.confirmation_number,
                        size: 18,
                        color: StageColors.amber,
                      ),
                      text: 'Opening Night',
                    ),
                  if (day.goldRecord)
                    const _Flag(
                      mark: GoldDisc(size: 18),
                      text: 'A Gold Record was set',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (day.isEmpty)
              const Text(
                'Nothing booked. A day off the road.',
                style: TextStyle(color: StageColors.textMuted),
              ),
            for (final p in day.plans) ...[
              _PlanRow(
                entry: p,
                saving: _saving == p.plan.id,
                canLog:
                    !p.done &&
                    !p.skipped &&
                    canLogAsPlanned(p.plan) &&
                    !p.plan.date.isAfter(today),
                onDone: _saving == null ? () => _doneAsPlanned(p.plan) : null,
              ),
              const SizedBox(height: 10),
            ],
            for (final s in [
              ...day.shows.where((s) => linked.contains(s.id)),
              ...extraShows,
            ]) ...[_ShowRow(show: s), const SizedBox(height: 10)],
          ],
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.mark, required this.text});
  final Widget mark;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      mark,
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          color: StageColors.amber,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// The row container shared by both kinds of entry.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.spoken,
    required this.onTap,
    this.trailing,
    this.titleStyle,
    this.subtitleColor = StageColors.textMuted,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String spoken;
  final VoidCallback onTap;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: spoken,
    excludeSemantics: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ).merge(titleStyle),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13,
                      fontFeatures: StageFonts.tabular,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            const Icon(Icons.chevron_right, color: StageColors.textMuted),
          ],
        ),
      ),
    ),
  );
}

class _ShowRow extends StatelessWidget {
  const _ShowRow({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final parts = [
      formatMiles(show.distanceMiles),
      if (show.paceSecondsPerMile != null) formatPace(show.paceSecondsPerMile),
      if (show.durationSeconds > 0) formatDuration(show.durationSeconds),
    ];
    return _EntryTile(
      leading: VenueStub(
        venue: show.venue,
        width: 40,
        height: 40,
        markWidth: 4,
        borderRadius: BorderRadius.circular(10),
        child: Icon(iconFor(show.venue), color: markFor(show.venue), size: 20),
      ),
      title: '${show.workoutType.label} · ${show.venue.label}',
      subtitle: parts.join(' · '),
      subtitleColor: StageColors.amber,
      spoken: spokenShow(show),
      onTap: () => context.push('/show/${show.id}'),
    );
  }
}

const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.entry,
    required this.saving,
    required this.canLog,
    required this.onDone,
  });

  final CalendarPlan entry;
  final bool saving;
  final bool canLog;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final p = entry.plan;
    final big = p.workoutType == WorkoutType.long || p.isRace;
    final moved = p.rescheduledFrom;
    final String subtitle;
    if (entry.done) {
      subtitle = 'Done · ran ${formatMiles(entry.logged!.distanceMiles)}';
    } else if (entry.skipped) {
      subtitle = 'Skipped';
    } else {
      subtitle = [
        '${formatMiles(p.distanceMiles)} planned',
        p.venue.label,
        if (moved != null) 'moved from ${_dayShort[moved.weekday - 1]}',
      ].join(' · ');
    }
    final status = entry.done
        ? 'done'
        : entry.skipped
        ? 'skipped'
        : 'planned';
    final tile = _EntryTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: big ? StageColors.amber : StageColors.outline,
            width: 1.5,
          ),
        ),
        child: Icon(
          workoutIcon(p.workoutType),
          size: 20,
          color: big ? StageColors.amber : StageColors.text,
        ),
      ),
      title: p.title,
      titleStyle: entry.skipped
          ? const TextStyle(
              color: StageColors.textMuted,
              decoration: TextDecoration.lineThrough,
              decorationColor: StageColors.textMuted,
            )
          : null,
      subtitle: subtitle,
      subtitleColor: entry.done ? StageColors.amber : StageColors.textMuted,
      spoken:
          'Tour date: ${p.title}, ${spokenMiles(p.distanceMiles)}, '
          '${p.venue.label}, $status',
      trailing: entry.done
          ? const Icon(Icons.check_circle, color: StageColors.amber, size: 22)
          : null,
      onTap: () => context.push('/tour/show/${p.id}'),
    );
    if (!canLog) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: saving ? null : onDone,
          icon: const Icon(Icons.check),
          label: Text(saving ? 'Logging…' : 'Done as planned'),
        ),
      ],
    );
  }
}
