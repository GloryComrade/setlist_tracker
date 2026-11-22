import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/show_math.dart';
import '../../logic/tour_builder.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'tour_widgets.dart';

/// "Book The Tour": the 9-question setup quiz, then a preview to confirm.
///
/// With [featuring], the race (distance and date) comes from a Crew
/// friend's Tour, so the two Tours are co-headlined.
class BookTourScreen extends ConsumerStatefulWidget {
  const BookTourScreen({super.key, this.featuring});

  final TourFeaturing? featuring;

  @override
  ConsumerState<BookTourScreen> createState() => _BookTourScreenState();
}

/// Recent race distances offered as chips.
const _raceDistances = [
  ('5K', 3.10686),
  ('10K', 6.21371),
  ('Half', 13.1094),
  ('Marathon', 26.2188),
];

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class _BookTourScreenState extends ConsumerState<BookTourScreen> {
  static const _questions = 9;
  int _step = 0;
  bool _saving = false;

  /// Opening Night's distance.
  RaceDistance? _distance;
  DateTime? _raceDate;
  bool _suggested = false;
  TourGoal? _goal;
  final _goalTime = TextEditingController();
  final _weekly = TextEditingController();
  final _longest = TextEditingController();
  double? _raceDistance;
  bool _noRace = false;
  final _raceTime = TextEditingController();
  final _easyPace = TextEditingController();
  int _days = 4;
  int _headlinerDay = DateTime.sunday;
  VenuePreference? _venue;

  @override
  void initState() {
    super.initState();
    final f = widget.featuring;
    if (f != null) {
      _distance = f.raceDistance;
      _raceDate = f.raceDate;
    }
    for (final c in [_goalTime, _weekly, _longest, _raceTime, _easyPace]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_goalTime, _weekly, _longest, _raceTime, _easyPace]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  bool get _shortRace =>
      _distance == RaceDistance.fiveK || _distance == RaceDistance.tenK;

  /// "3:45" means 3 h 45 min for a half or marathon goal; "24:30" means
  /// 24 min 30 s for a 5K or 10K.
  int? _goalTimeOf(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length == 2 && !_shortRace) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || m >= 60) return null;
      return h * 3600 + m * 60;
    }
    return parseDuration(t);
  }

  /// Sensible finish times for each distance, in seconds.
  (int, int) get _goalRange => switch (_distance) {
    RaceDistance.fiveK => (12 * 60, 90 * 60),
    RaceDistance.tenK => (25 * 60, 150 * 60),
    RaceDistance.half => (60 * 60, 270 * 60),
    _ => (2 * 3600, 8 * 3600),
  };

  String get _goalRangeText => switch (_distance) {
    RaceDistance.fiveK => 'Use mm:ss, between 12:00 and 1:30:00',
    RaceDistance.tenK => 'Use mm:ss, between 25:00 and 2:30:00',
    RaceDistance.half => 'Use h:mm, between 1:00 and 4:30',
    _ => 'Use h:mm, between 2:00 and 8:00',
  };

  int? get _goalSeconds {
    final s = _goalTimeOf(_goalTime.text);
    final (lo, hi) = _goalRange;
    return s != null && s >= lo && s <= hi ? s : null;
  }

  /// Boston qualifiers are for marathons only.
  List<TourGoal> get _goals => _distance == RaceDistance.marathon
      ? TourGoal.values
      : [TourGoal.finish, TourGoal.targetTime];

  int? get _raceSeconds {
    final s = parseDuration(_raceTime.text);
    return s != null && s > 600 ? s : null;
  }

  double? get _easyPaceSeconds {
    final t = _easyPace.text.trim();
    if (t.isEmpty) return null;
    final s = parseDuration(t);
    return s != null && s >= 300 && s <= 1200 ? s.toDouble() : null;
  }

  bool get _stepValid => switch (_step) {
    0 => _distance != null,
    1 => _raceDate != null,
    2 =>
      _goal == TourGoal.finish ||
          (_goal != null && _goals.contains(_goal) && _goalSeconds != null),
    3 => (_num(_weekly) ?? -1) >= 0 && (_num(_weekly) ?? 0) <= 150,
    4 => (_num(_longest) ?? -1) >= 0 && (_num(_longest) ?? 0) <= 30,
    5 =>
      (_noRace &&
              (_easyPace.text.trim().isEmpty || _easyPaceSeconds != null)) ||
          (_raceDistance != null && _raceSeconds != null),
    6 || 7 => true,
    8 => _venue != null,
    _ => true,
  };

  TourSetup get _setup => TourSetup(
    raceDate: _raceDate!,
    raceDistance: _distance!,
    goal: _goal!,
    goalTimeSeconds: _goal == TourGoal.finish ? null : _goalSeconds,
    currentWeeklyMiles: _num(_weekly) ?? 0,
    longestRecentRunMiles: _num(_longest) ?? 0,
    recentRace: _noRace || _raceDistance == null || _raceSeconds == null
        ? null
        : RaceResult(distanceMiles: _raceDistance!, timeSeconds: _raceSeconds!),
    easyPaceSecondsPerMile: _noRace ? _easyPaceSeconds : null,
    daysPerWeek: _days,
    headlinerWeekday: _headlinerDay,
    venuePreference: _venue!,
  );

  void _next() {
    if (!_stepValid) return;
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      leaveScreen(context, fallback: '/tour');
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _pickDate() async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _raceDate ?? suggestedRaceDate(now, _distance!),
      firstDate: now,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Opening Night',
    );
    if (picked != null) {
      setState(() {
        _raceDate = picked;
        _suggested = false;
      });
    }
  }

  /// Still the friend's race? Changing the date or distance books a solo
  /// Tour instead.
  bool get _stillFeaturing {
    final f = widget.featuring;
    return f != null &&
        _raceDate != null &&
        _distance != null &&
        sameRace(f.raceDate, f.raceDistance, _raceDate!, _distance!);
  }

  Future<void> _book(Tour built) async {
    final f = widget.featuring;
    final tour = _stillFeaturing
        ? Tour(
            id: built.id,
            name: f!.tourName?.trim().isNotEmpty == true
                ? f.tourName!
                : built.name,
            setup: built.setup,
            paces: built.paces,
            weeks: built.weeks,
            warnings: built.warnings,
            featuring: (userId: f.userId, stageName: f.stageName),
            createdAt: built.createdAt,
            updatedAt: built.updatedAt,
          )
        : built;
    setState(() => _saving = true);
    try {
      await ref.read(tourRepositoryProvider).save(tour);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not book The Tour: $e')));
      }
      return;
    }
    if (!mounted) return;
    context.go('/tour');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${tour.name} booked.')));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _step >= _questions;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _step == 0 ? 'Close' : 'Back',
            icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text(preview ? 'YOUR TOUR' : 'BOOK THE TOUR'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: preview ? 1 : (_step + 1) / (_questions + 1),
              minHeight: 4,
              color: StageColors.magenta,
              backgroundColor: StageColors.surfaceHigh,
            ),
          ),
        ),
        body: SafeArea(
          child: MaxWidth(
            width: 640,
            child: preview ? _preview() : _question(),
          ),
        ),
      ),
    );
  }

  Widget _question() {
    final raceWord = switch (_distance) {
      RaceDistance.marathon || null => 'marathon',
      final d => d.label,
    };
    final (title, hint, body) = switch (_step) {
      0 => (
        'Pick your show',
        'The race you\'re training for on Opening Night.',
        _distanceStep(),
      ),
      1 => (
        'When is Opening Night?',
        'Your $raceWord date. Not signed up yet? We can pick one for you.',
        _dateStep(),
      ),
      2 => ('What is the goal?', null, _goalStep()),
      3 => (
        'How many miles a week right now?',
        'Your average over the last month.',
        _numberStep(_weekly, 'Miles per week', 'mi / week'),
      ),
      4 => (
        'Longest run in the past month?',
        'Your Headliners start from here.',
        _numberStep(_longest, 'Longest run', 'mi'),
      ),
      5 => (
        'Any recent race?',
        'A race from the last 3 months sets your paces most accurately.',
        _raceStep(),
      ),
      6 => (
        'How many days a week can you run?',
        'Light weeks may use fewer days.',
        _daysStep(),
      ),
      7 => (
        'Which day is Headliner day?',
        'The long run, usually on a weekend.',
        _headlinerStep(),
      ),
      _ => ('Studio or Live?', null, _venueStep()),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: ValueKey(_step),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            children: [
              Text(
                'Question ${_step + 1} of $_questions',
                style: const TextStyle(
                  color: StageColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: const TextStyle(
                    color: StageColors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (widget.featuring != null && _step <= 1) ...[
                _FeaturingNote(
                  featuring: widget.featuring!,
                  matches:
                      _stillFeaturing ||
                      (_step == 0 &&
                          _distance == widget.featuring!.raceDistance),
                ),
                const SizedBox(height: 16),
              ],
              body,
              if (_step == 0) ...[
                const SizedBox(height: 36),
                const TourDisclaimer(),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              if (_step > 0)
                TextButton(onPressed: _back, child: const Text('Back')),
              const Spacer(),
              GradientButton(
                label: _step == _questions - 1 ? 'See the Tour' : 'Next',
                icon: _step == _questions - 1 ? Icons.auto_awesome : null,
                onPressed: _stepValid ? _next : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Steps ----

  Widget _distanceStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final d in RaceDistance.values) ...[
        _ChoiceTile(
          icon: switch (d) {
            RaceDistance.fiveK => Icons.bolt_outlined,
            RaceDistance.tenK => Icons.directions_run,
            RaceDistance.half => Icons.landscape_outlined,
            RaceDistance.marathon => Icons.emoji_events_outlined,
          },
          title: d.label,
          subtitle: () {
            final r = rulesFor(d);
            return '${d.milesText} · ${r.idealMinWeeks} to ${r.maxWeeks} '
                'week Tour';
          }(),
          selected: _distance == d,
          onTap: () => setState(() {
            if (_distance != d && _suggested) _raceDate = null;
            _distance = d;
            if (!_goals.contains(_goal)) _goal = null;
          }),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _dateStep() {
    final d = _raceDate;
    final weeks = d == null ? null : weeksUntil(today(), d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceTile(
          icon: Icons.event,
          title: d == null ? 'Pick the race date' : formatLongDate(d),
          subtitle: d == null
              ? 'Opens a calendar'
              : '$weeks weeks from now · tap to change',
          selected: d != null && !_suggested,
          onTap: _pickDate,
        ),
        const SizedBox(height: 10),
        _ChoiceTile(
          icon: Icons.auto_awesome,
          title: 'Help me pick',
          subtitle: _suggested
              ? 'Picked ${formatLongDate(_raceDate!)}: '
                    '${rulesFor(_distance!).suggestWeeks} weeks out, the '
                    'sweet spot for a full Tour. Look for a race near it.'
              : 'Suggests a Sunday about '
                    '${rulesFor(_distance!).suggestWeeks} weeks out',
          selected: _suggested,
          onTap: () => setState(() {
            _raceDate = suggestedRaceDate(today(), _distance!);
            _suggested = true;
          }),
        ),
      ],
    );
  }

  Widget _goalStep() {
    final needsTime = _goal == TourGoal.targetTime || _goal == TourGoal.bq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in _goals) ...[
          _ChoiceTile(
            icon: switch (g) {
              TourGoal.finish => Icons.flag_outlined,
              TourGoal.targetTime => Icons.timer_outlined,
              TourGoal.bq => Icons.emoji_events_outlined,
            },
            title: g.label,
            subtitle: g.subtitle,
            selected: _goal == g,
            onTap: () => setState(() => _goal = g),
          ),
          const SizedBox(height: 10),
        ],
        if (needsTime) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _goalTime,
            autofocus: true,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
            decoration: InputDecoration(
              labelText: _goal == TourGoal.bq
                  ? 'Your BQ standard'
                  : 'Goal finish time',
              hintText: switch (_distance) {
                RaceDistance.fiveK => '24:30',
                RaceDistance.tenK => '52:00',
                RaceDistance.half => '1:55',
                _ => '3:45',
              },
              helperText: _goal == TourGoal.bq
                  ? 'The Boston qualifying time for your age group, as h:mm'
                  : _shortRace
                  ? 'Minutes and seconds, as mm:ss'
                  : 'Hours and minutes, as h:mm',
              errorText: _goalTime.text.isNotEmpty && _goalSeconds == null
                  ? _goalRangeText
                  : null,
            ),
            onSubmitted: (_) => _next(),
          ),
        ],
      ],
    );
  }

  Widget _numberStep(TextEditingController c, String label, String suffix) =>
      TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        style: Theme.of(context).textTheme.headlineMedium,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        onSubmitted: (_) => _next(),
      );

  Widget _raceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, miles) in _raceDistances)
              ChoiceChip(
                label: Text(label),
                selected: !_noRace && _raceDistance == miles,
                onSelected: (_) => setState(() {
                  _raceDistance = miles;
                  _noRace = false;
                }),
              ),
            ChoiceChip(
              label: const Text('No recent race'),
              selected: _noRace,
              onSelected: (_) => setState(() {
                _noRace = true;
                _raceDistance = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_raceDistance != null && !_noRace)
          TextField(
            controller: _raceTime,
            autofocus: true,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
            decoration: InputDecoration(
              labelText: 'Finish time',
              hintText: _raceDistance! > 10 ? '1:52:30' : '24:30',
              helperText: 'mm:ss or h:mm:ss',
              errorText: _raceTime.text.isNotEmpty && _raceSeconds == null
                  ? 'Use mm:ss or h:mm:ss'
                  : null,
            ),
            onSubmitted: (_) => _next(),
          ),
        if (_noRace && (_goal == TourGoal.finish))
          TextField(
            controller: _easyPace,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
            decoration: InputDecoration(
              labelText: 'Usual easy pace (optional)',
              hintText: '11:00',
              suffixText: '/ mi',
              helperText: 'Leave blank to run every Show by feel',
              errorText: _easyPace.text.isNotEmpty && _easyPaceSeconds == null
                  ? 'Use mm:ss, like 11:00'
                  : null,
            ),
          ),
        if (_noRace && _goal != TourGoal.finish)
          const Text(
            'No problem. Paces will come from your goal time.',
            style: TextStyle(color: StageColors.textMuted),
          ),
      ],
    );
  }

  Widget _daysStep() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final d in [3, 4, 5, 6])
        _BigChoice(
          label: '$d',
          caption: 'days',
          selected: _days == d,
          onTap: () => setState(() => _days = d),
        ),
    ],
  );

  Widget _headlinerStep() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < 7; i++)
        ChoiceChip(
          label: Text(_weekdayNames[i]),
          selected: _headlinerDay == i + 1,
          onSelected: (_) => setState(() => _headlinerDay = i + 1),
        ),
    ],
  );

  Widget _venueStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final v in VenuePreference.values) ...[
        _ChoiceTile(
          icon: switch (v) {
            VenuePreference.live => Icons.landscape,
            VenuePreference.studio => Icons.graphic_eq,
            VenuePreference.mix => Icons.shuffle,
          },
          title: v.label,
          subtitle: v.subtitle,
          selected: _venue == v,
          onTap: () => setState(() => _venue = v),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  // ---- Preview ----

  Widget _preview() {
    final build = TourBuilder().build(_setup, today: today());
    final tour = build.tour;
    final theme = Theme.of(context);
    final suggestion = build.suggestedDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            children: [
              if (tour != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: StageColors.headlineGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tour.name.toUpperCase(),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tour.setup.raceDistance.label} · '
                        '${tour.weeks.length} weeks · '
                        '${formatShortDate(tour.startDate)} to '
                        '${formatLongDate(tour.raceDate)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 28,
                        runSpacing: 12,
                        children: [
                          _WhiteStat(
                            'Peak week',
                            formatMiles(
                              // Race week isn't a training week.
                              tour.weeks
                                  .take(tour.weeks.length - 1)
                                  .map((w) => w.plannedMiles)
                                  .reduce((a, b) => a > b ? a : b)
                                  .roundToDouble(),
                            ),
                          ),
                          _WhiteStat(
                            'Top Headliner',
                            formatMiles(
                              tour.weeks
                                  .map((w) => w.headliner?.distanceMiles ?? 0)
                                  .reduce((a, b) => a > b ? a : b),
                            ),
                          ),
                          _WhiteStat(
                            'Rest Stops',
                            '${tour.weeks.where((w) => w.isRestStop).length}',
                          ),
                          if (tour.paces != null)
                            _WhiteStat(
                              'Predicted',
                              formatDuration(tour.paces!.predictedRaceSeconds),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: StageColors.background.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TourStrip(tour: tour),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _phaseSummary(tour),
              ],
              for (final c in build.checks) ...[
                const SizedBox(height: 10),
                TourCheckNote(
                  title: c.title,
                  message: c.message,
                  serious: c.serious,
                ),
              ],
              if (suggestion != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _raceDate = suggestion;
                      _suggested = true;
                    }),
                    icon: const Icon(Icons.event_repeat),
                    label: Text('Use ${formatLongDate(suggestion)} instead'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const TourDisclaimer(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              TextButton(onPressed: _back, child: const Text('Back')),
              const Spacer(),
              GradientButton(
                label: _saving ? 'Booking…' : 'Book The Tour',
                icon: Icons.confirmation_number_outlined,
                onPressed: tour == null || _saving ? null : () => _book(tour),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phaseSummary(Tour tour) {
    final rows = <(TourPhase, int, DateTime)>[];
    for (final w in tour.weeks) {
      if (rows.isEmpty || rows.last.$1 != w.phase) {
        rows.add((w.phase, 1, w.startDate));
      } else {
        final last = rows.removeLast();
        rows.add((last.$1, last.$2 + 1, last.$3));
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          children: [
            for (final (phase, count, start) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: phaseColor(phase),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${phase.label} · $count '
                            '${count == 1 ? 'week' : 'weeks'} from '
                            '${formatShortDate(start)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: StageFonts.tabular,
                            ),
                          ),
                          Text(
                            phase.subtitle,
                            style: const TextStyle(
                              color: StageColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhiteStat extends StatelessWidget {
  const _WhiteStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      Text(
        value,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: Colors.white, fontFeatures: StageFonts.tabular),
      ),
    ],
  );
}

/// A selectable row with an icon, a title and one line of help.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? StageColors.magentaDeep.withValues(alpha: 0.18)
            : StageColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? StageColors.magenta : StageColors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? StageColors.magenta : StageColors.textMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: StageColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: StageColors.magenta),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A big square number choice (days per week).
class _BigChoice extends StatelessWidget {
  const _BigChoice({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '$label $caption',
    child: Material(
      color: selected ? StageColors.magentaDeep : StageColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? StageColors.magentaDeep : StageColors.outline,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          height: 84,
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(color: Colors.white),
                ),
                Text(
                  caption,
                  style: TextStyle(
                    color: selected ? Colors.white : StageColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Booking a Tour featuring Sam" above the race questions.
class _FeaturingNote extends StatelessWidget {
  const _FeaturingNote({required this.featuring, required this.matches});

  final TourFeaturing featuring;

  /// False once the runner picks a different race.
  final bool matches;

  @override
  Widget build(BuildContext context) {
    final f = featuring;
    final race = '${f.raceDistance.label} on ${formatLongDate(f.raceDate)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StageColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: matches ? StageColors.amber : StageColors.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            matches ? Icons.groups_2_outlined : Icons.info_outline,
            color: matches ? StageColors.amber : StageColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              matches
                  ? 'Booking a Tour featuring ${f.stageName}: $race. You '
                        'answer the fitness questions for your own plan.'
                  : '${f.stageName} is running the $race. Pick that race '
                        'to co-headline, or keep going for a solo Tour.',
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
