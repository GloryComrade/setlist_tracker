/// The Tour Manager: rules (no AI) that watch the Setlist and suggest
/// changes to The Tour. Each suggestion is a note card on the Tour tab with
/// Apply and Not now. Nothing changes until the runner taps Apply.
library;

import 'dart:math' as math;

import '../models/enums.dart';
import '../models/show.dart';
import '../models/tour.dart';
import 'show_math.dart';
import 'tour_builder.dart';

/// A run this many sec/mi under the plan counts as "faster than planned".
const double kFasterBySeconds = 15;

/// Most a single pace update moves things, in sec/mi.
const double kMaxPaceShift = 15;

/// Effort that counts as "too hard" on an easy or recovery run.
const int kHardEffort = 8;

/// How many in a row before the Tour Manager speaks up.
const int kInARow = 3;

/// Lighter week: miles kept, as a share of the plan.
const double kLighterWeekShare = 0.75;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool _isHard(WorkoutType t) =>
    t == WorkoutType.long ||
    t == WorkoutType.tempo ||
    t == WorkoutType.intervals ||
    t == WorkoutType.race;

bool _isEasy(WorkoutType t) =>
    t == WorkoutType.easy || t == WorkoutType.recovery;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _dayName(DateTime d) => _weekdays[d.weekday - 1];
String _dayText(DateTime d) => '${_dayName(d)} ${d.month}/${d.day}';

enum SuggestionKind { missedShow, lighterWeek, fasterPaces }

/// One note card from the Tour Manager.
class TourSuggestion {
  const TourSuggestion({
    required this.key,
    required this.kind,
    required this.title,
    required this.message,
    required this.applyLabel,
    required this.apply,
  });

  /// Stable id, saved in Tour.dismissed on "Not now".
  final String key;
  final SuggestionKind kind;
  final String title;
  final String message;
  final String applyLabel;

  /// The Tour with the change made and logged. Takes the current time for
  /// the adjustment stamp.
  final Tour Function(DateTime now) apply;
}

/// Every suggestion that applies right now, most urgent first.
List<TourSuggestion> tourSuggestions(
  Tour tour, {
  required List<Show> shows,
  required Map<String, Show> done,
  required DateTime now,
}) {
  final out = <TourSuggestion?>[
    missedShowSuggestion(tour, done: done, now: now),
    lighterWeekSuggestion(tour, shows: shows, now: now),
    fasterPacesSuggestion(tour, done: done, now: now),
  ];
  return [
    for (final s in out)
      if (s != null && !tour.dismissed.contains(s.key)) s,
  ];
}

/// "Apply": makes the change and retires the card so it can't come back.
Tour applySuggestion(Tour tour, TourSuggestion s, DateTime now) =>
    dismissSuggestion(s.apply(now), s.key);

/// "Not now": the card stays away for good.
Tour dismissSuggestion(Tour tour, String key) =>
    tour.copyWith(dismissed: [...tour.dismissed, key]);

// ---------------------------------------------------------------------------
// Missed Shows
// ---------------------------------------------------------------------------

Tour _replaceShows(
  Tour tour,
  TourWeek week,
  List<PlannedShow> shows,
  TourAdjustment adj, {
  bool? isRestStop,
}) {
  final sorted = [...shows]..sort((a, b) => a.date.compareTo(b.date));
  return tour.copyWith(
    weeks: [
      for (final w in tour.weeks)
        w.number == week.number
            ? w.copyWith(shows: sorted, isRestStop: isRestStop)
            : w,
    ],
    adjustments: [...tour.adjustments, adj],
  );
}

/// A run in this week whose day has passed with nothing logged. Only the
/// current week: once a week is over, its misses are history, and nothing
/// ever spills into next week.
TourSuggestion? missedShowSuggestion(
  Tour tour, {
  required Map<String, Show> done,
  required DateTime now,
}) {
  final today = _day(now);
  final week = tour.weekContaining(today);
  if (week == null) return null;
  final missed = week.shows.where(
    (p) =>
        !p.skipped &&
        !p.isRace &&
        p.date.isBefore(today) &&
        !done.containsKey(p.id) &&
        !tour.dismissed.contains('missed:${p.id}'),
  );
  if (missed.isEmpty) return null;
  final p = missed.first;
  final active = week.shows.where((s) => !s.skipped && s.id != p.id).toList();
  final busy = {for (final s in active) s.date};
  final hardDays = {
    for (final s in active)
      if (_isHard(s.workoutType)) s.date,
  };
  final headliner = active
      .where((s) => s.workoutType == WorkoutType.long)
      .map((s) => s.date)
      .firstOrNull;
  final open = [
    for (var d = today; !d.isAfter(week.endDate); d = _addDays(d, 1))
      if (!busy.contains(d)) d,
  ];

  bool nextToHard(DateTime d) =>
      hardDays.contains(_addDays(d, -1)) || hardDays.contains(_addDays(d, 1));
  bool dayBeforeHeadliner(DateTime d) =>
      headliner != null && _addDays(d, 1) == headliner;

  DateTime? target;
  if (_isHard(p.workoutType)) {
    target = open.where((d) => !nextToHard(d)).firstOrNull;
  } else {
    target =
        open.where((d) => !dayBeforeHeadliner(d)).firstOrNull ??
        open.firstOrNull;
  }

  final what = '${p.title} (${formatMiles(p.distanceMiles)})';
  if (target != null) {
    final to = target;
    return TourSuggestion(
      key: 'missed:${p.id}',
      kind: SuggestionKind.missedShow,
      title: 'Missed: $what',
      message:
          'It was on ${_dayText(p.date)}. ${_dayName(to)} is open, so it can '
          'move there without doubling up.',
      applyLabel: 'Move to ${_dayName(to)}',
      apply: (at) => _replaceShows(
        tour,
        week,
        [
          for (final s in week.shows)
            s.id == p.id
                ? s.copyWith(
                    date: to,
                    rescheduledFrom: s.rescheduledFrom ?? s.date,
                  )
                : s,
        ],
        TourAdjustment(
          kind: AdjustmentKind.rescheduled,
          at: at,
          note: '${p.title} moved from ${_dayText(p.date)} to ${_dayText(to)}',
        ),
      ),
    );
  }

  // A missed Headliner or workout matters more than an easy run: run it
  // in place of a later easy run, as long as that day isn't next to another
  // hard day.
  if (_isHard(p.workoutType)) {
    final swap = active
        .where(
          (s) =>
              _isEasy(s.workoutType) &&
              !s.date.isBefore(today) &&
              !done.containsKey(s.id) &&
              !nextToHard(s.date),
        )
        .firstOrNull;
    if (swap != null) {
      return TourSuggestion(
        key: 'missed:${p.id}',
        kind: SuggestionKind.missedShow,
        title: 'Missed: $what',
        message:
            'The rest of the week is full. Run it on ${_dayText(swap.date)} '
            'in place of the ${formatMiles(swap.distanceMiles)} '
            '${swap.title.toLowerCase()} run, which gets skipped.',
        applyLabel: 'Swap with ${_dayName(swap.date)}',
        apply: (at) => _replaceShows(
          tour,
          week,
          [
            for (final s in week.shows)
              if (s.id == p.id)
                s.copyWith(
                  date: swap.date,
                  rescheduledFrom: s.rescheduledFrom ?? s.date,
                )
              else if (s.id == swap.id)
                s.copyWith(skipped: true)
              else
                s,
          ],
          TourAdjustment(
            kind: AdjustmentKind.rescheduled,
            at: at,
            note:
                '${p.title} moved from ${_dayText(p.date)} to '
                '${_dayText(swap.date)}; ${swap.title} skipped',
          ),
        ),
      );
    }
  }

  return TourSuggestion(
    key: 'missed:${p.id}',
    kind: SuggestionKind.missedShow,
    title: 'Missed: $what',
    message:
        "There's no open day left this week that won't pile runs up. "
        'Skip it and keep the rest of the week as planned.',
    applyLabel: 'Skip it',
    apply: (at) => _replaceShows(
      tour,
      week,
      [
        for (final s in week.shows)
          s.id == p.id ? s.copyWith(skipped: true) : s,
      ],
      TourAdjustment(
        kind: AdjustmentKind.skipped,
        at: at,
        note: '${p.title} on ${_dayText(p.date)} skipped',
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Lighter week
// ---------------------------------------------------------------------------

/// The last [kInARow] easy or recovery Shows (within two weeks) were all
/// effort 8+. Suggests turning next week into a Rest Stop.
TourSuggestion? lighterWeekSuggestion(
  Tour tour, {
  required List<Show> shows,
  required DateTime now,
}) {
  final today = _day(now);
  final easy =
      shows
          .where(
            (s) =>
                !s.isDeleted &&
                _isEasy(s.workoutType) &&
                !_day(s.date).isAfter(today),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  if (easy.length < kInARow) return null;
  final recent = easy.take(kInARow).toList();
  if (recent.any((s) => s.effort < kHardEffort)) return null;
  if (_day(recent.last.date).isBefore(_addDays(today, -14))) return null;

  final current = tour.weekContaining(today);
  final next = current == null
      ? (today.isBefore(tour.startDate) ? tour.weeks.first : null)
      : tour.weeks.where((w) => w.number == current.number + 1).firstOrNull;
  if (next == null ||
      next.isRestStop ||
      next.phase == TourPhase.soundcheck ||
      next.shows.any((s) => s.isRace)) {
    return null;
  }

  final newShows = [
    for (final s in next.shows)
      s.skipped
          ? s
          : replanShow(
              s,
              type: _isHard(s.workoutType) && s.workoutType != WorkoutType.long
                  ? WorkoutType.easy
                  : s.workoutType,
              miles: math.max(
                3.0,
                (s.distanceMiles * kLighterWeekShare * 2).round() / 2,
              ),
              paces: tour.paces,
            ),
  ];
  final newMiles = newShows
      .where((s) => !s.skipped)
      .fold(0.0, (sum, s) => sum + s.distanceMiles);

  return TourSuggestion(
    key: 'lighter:${recent.first.id}',
    kind: SuggestionKind.lighterWeek,
    title: 'Your easy runs feel hard',
    message:
        'Your last $kInARow easy runs were all effort $kHardEffort or higher. '
        'That can mean tired legs. Make week ${next.number} a Rest Stop: '
        '${formatMiles(next.plannedMiles)} becomes about '
        '${formatMiles(newMiles)}, and the workout becomes an easy run.',
    applyLabel: 'Make it a Rest Stop',
    apply: (at) => _replaceShows(
      tour,
      next,
      newShows,
      TourAdjustment(
        kind: AdjustmentKind.lighterWeek,
        at: at,
        note:
            'Week ${next.number} made a Rest Stop '
            '(${formatMiles(next.plannedMiles)} to ${formatMiles(newMiles)})',
      ),
      isRestStop: true,
    ),
  );
}

// ---------------------------------------------------------------------------
// Faster paces
// ---------------------------------------------------------------------------

/// The last [kInARow] easy runs and Headliners logged for the Tour (within
/// three weeks) were all at least [kFasterBySeconds] sec/mi faster than
/// planned at effort 6 or lower. Offers to update every pace.
TourSuggestion? fasterPacesSuggestion(
  Tour tour, {
  required Map<String, Show> done,
  required DateTime now,
}) {
  final paces = tour.paces;
  if (paces == null) return null;
  final today = _day(now);
  // Only runs since the last pace update count, so one update can't
  // trigger the next.
  final lastUpdate = tour.adjustments
      .where((a) => a.kind == AdjustmentKind.paces)
      .map((a) => a.at.toLocal())
      .fold<DateTime?>(null, (m, a) => m == null || a.isAfter(m) ? a : m);
  final runs = <({Show show, double gap})>[];
  for (final p in tour.allShows) {
    final s = done[p.id];
    final target = p.targetPaceSecondsPerMile;
    if (s == null || target == null) continue;
    if (lastUpdate != null && !s.date.isAfter(lastUpdate)) continue;
    if (!(_isEasy(p.workoutType) || p.workoutType == WorkoutType.long)) {
      continue;
    }
    final pace = s.paceSecondsPerMile;
    if (pace == null) continue;
    runs.add((show: s, gap: target - pace));
  }
  runs.sort((a, b) => b.show.date.compareTo(a.show.date));
  if (runs.length < kInARow) return null;
  final recent = runs.take(kInARow).toList();
  if (_day(recent.last.show.date).isBefore(_addDays(today, -21))) return null;
  if (recent.any((r) => r.gap < kFasterBySeconds || r.show.effort > 6)) {
    return null;
  }
  // "Done as planned" logs exactly the plan, so it never triggers this.
  final gaps = recent.map((r) => r.gap).toList()..sort();
  final median = gaps[gaps.length ~/ 2];
  final shift = math.min(kMaxPaceShift, (median / 5).floor() * 5.0);
  if (shift <= 0) return null;
  final updated = fasterPaces(paces, shift);

  return TourSuggestion(
    key: 'paces:${recent.first.show.id}',
    kind: SuggestionKind.fasterPaces,
    title: "You're ahead of the plan",
    message:
        'Your last $kInARow easy runs and Headliners were about '
        '${median.round()} sec/mi faster than planned and felt comfortable. '
        'Update every pace by ${shift.round()} sec/mi? Easy becomes '
        '${formatPace(updated.easyFast, withUnit: false)}–'
        '${formatPace(updated.easySlow)}, and treadmill speeds and Tracks '
        'for the rest of The Tour change to match.',
    applyLabel: 'Update paces',
    apply: (at) => tour.copyWith(
      paces: updated,
      weeks: [
        for (final w in tour.weeks)
          w.copyWith(
            shows: [
              for (final s in w.shows)
                s.date.isBefore(today) || done.containsKey(s.id)
                    ? s
                    : speedUpShow(s, shift),
            ],
          ),
      ],
      adjustments: [
        ...tour.adjustments,
        TourAdjustment(
          kind: AdjustmentKind.paces,
          at: at,
          note:
              'Paces ${shift.round()} sec/mi faster; predicted Opening Night '
              '${formatDuration(updated.predictedMarathonSeconds)}',
        ),
      ],
    ),
  );
}
