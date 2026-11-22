import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/enums.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';

/// Each phase gets its own stage light, cool to hot to warm-down.
Color phaseColor(TourPhase p) => switch (p) {
  TourPhase.rehearsals => StageColors.violet,
  TourPhase.onTheRoad => StageColors.cyan,
  TourPhase.headlineLeg => StageColors.magenta,
  TourPhase.soundcheck => StageColors.amber,
};

/// Deep shade of the phase light, for fills under white text.
Color phaseFill(TourPhase p) => switch (p) {
  TourPhase.rehearsals => StageColors.violetDeep,
  TourPhase.onTheRoad => StageColors.tealDeep,
  TourPhase.headlineLeg => StageColors.magentaDeep,
  TourPhase.soundcheck => StageColors.orangeDeep,
};

IconData workoutIcon(WorkoutType t) => switch (t) {
  WorkoutType.easy => Icons.directions_run,
  WorkoutType.recovery => Icons.self_improvement,
  WorkoutType.long => Icons.star_rounded,
  WorkoutType.tempo => Icons.speed,
  WorkoutType.intervals => Icons.bolt,
  WorkoutType.race => Icons.celebration,
};

final _short = DateFormat('MMM d');
final _long = DateFormat('EEE, MMM d, y');

String formatShortDate(DateTime d) => _short.format(d);
String formatLongDate(DateTime d) => _long.format(d);

/// "Dec 21 – 27" or "Dec 28 – Jan 3".
String formatWeekRange(TourWeek w) {
  final a = w.startDate;
  final b = w.endDate;
  return a.month == b.month
      ? '${_short.format(a)} – ${b.day}'
      : '${_short.format(a)} – ${_short.format(b)}';
}

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// One bar per week, colored by phase, taller for bigger weeks. The current
/// week is marked so the runner can see where they are on the Tour.
class TourStrip extends StatelessWidget {
  const TourStrip({super.key, required this.tour, this.currentWeek});
  final Tour tour;

  /// 1-based week number, or null before or after the Tour.
  final int? currentWeek;

  @override
  Widget build(BuildContext context) {
    final most = tour.weeks
        .map((w) => w.plannedMiles)
        .fold(1.0, (a, b) => a > b ? a : b);
    return Semantics(
      label: currentWeek == null
          ? '${tour.weeks.length} week Tour'
          : 'Week $currentWeek of ${tour.weeks.length}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final w in tour.weeks)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: FractionallySizedBox(
                          heightFactor: (0.25 + 0.75 * w.plannedMiles / most)
                              .clamp(0.25, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: w.number == currentWeek
                                  ? Colors.white
                                  : phaseColor(w.phase).withValues(
                                      alpha: w.isRestStop ? 0.45 : 0.9,
                                    ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final p in TourPhase.values)
                  if (tour.weeks.any((w) => w.phase == p))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: phaseColor(p),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          p.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small outlined tag, e.g. "REST STOP".
class TourTag extends StatelessWidget {
  const TourTag(this.text, {super.key, this.color = StageColors.amber});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

/// The safety note the brief asks for, shown on the quiz and the schedule.
class TourDisclaimer extends StatelessWidget {
  const TourDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.health_and_safety_outlined,
        size: 18,
        color: StageColors.textMuted,
      ),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'General training guidance, not medical advice. If you are injured '
          'or have a health condition, check with a doctor or coach first.',
          style: TextStyle(color: StageColors.textMuted, fontSize: 12.5),
        ),
      ),
    ],
  );
}

/// Amber or muted note from the plan builder.
class TourCheckNote extends StatelessWidget {
  const TourCheckNote({
    super.key,
    required this.title,
    required this.message,
    this.serious = false,
  });

  final String title;
  final String message;
  final bool serious;

  @override
  Widget build(BuildContext context) {
    final color = serious ? StageColors.amber : StageColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: serious
            ? StageColors.amber.withValues(alpha: 0.10)
            : StageColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: serious
              ? StageColors.amber.withValues(alpha: 0.5)
              : StageColors.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            serious ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: serious ? StageColors.amber : StageColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: StageColors.text,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Splits a saved warning line ("Title: message") back into its parts.
({String title, String message}) splitWarning(String line) {
  final i = line.indexOf(': ');
  if (i < 0) return (title: line, message: '');
  return (title: line.substring(0, i), message: line.substring(i + 2));
}
