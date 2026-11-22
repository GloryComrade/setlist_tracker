import 'package:material_ui/material_ui.dart';

import '../../logic/tour_stats.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import '../tour/tour_widgets.dart';

/// A one-line version of the Tour header's countdown, for use on a poster:
/// the days to go (the hero figure, in amber), then the date and where the
/// Tour stands.
///
/// Same wording as the Tour tab, so both screens tell the same story.
class OpeningNightCountdown extends StatelessWidget {
  const OpeningNightCountdown({
    super.key,
    required this.tour,
    required this.now,
  });

  final Tour tour;
  final DateTime now;

  String get _status {
    final days = daysToOpeningNight(tour, now);
    if (days < 0) return 'Opening Night has been played';
    if (days == 0) return 'Opening Night is today';
    final day = DateTime(now.year, now.month, now.day);
    if (day.isBefore(tour.startDate)) {
      return 'Rehearsals start ${formatShortDate(tour.startDate)}';
    }
    final week = tour.weekContaining(day);
    if (week == null) return '';
    return 'Week ${week.number} of ${tour.weeks.length} · ${week.phase.label}';
  }

  @override
  Widget build(BuildContext context) {
    final days = daysToOpeningNight(tour, now);
    final status = _status;
    final date = formatLongDate(tour.raceDate);
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    final label = days > 0
        ? '$days ${days == 1 ? 'day' : 'days'} to Opening Night, $date. $status'
        : '$status, $date';

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (days > 0)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$days',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: StageColors.amber,
                      fontFeatures: StageFonts.tabular,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        days == 1
                            ? 'DAY TO OPENING NIGHT'
                            : 'DAYS TO OPENING NIGHT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              days > 0 && status.isNotEmpty ? '$date · $status' : date,
              style: white,
            ),
          ],
        ),
      ),
    );
  }
}
