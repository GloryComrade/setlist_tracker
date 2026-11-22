import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../models/show.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/stage_widgets.dart';

/// One Show on the Setlist, styled like a ticket stub.
class ShowCard extends StatelessWidget {
  const ShowCard({super.key, required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = show.song;
    return Card(
      shape: const TicketBorder(),
      clipBehavior: Clip.antiAlias,
      // One spoken line for the whole ticket, so a screen reader says
      // "15 miles" and "9 minutes 20 seconds per mile", not "15 Michigan".
      child: Semantics(
        container: true,
        button: true,
        label: spokenShow(show),
        child: InkWell(
          onTap: () => context.push('/show/${show.id}'),
          child: ExcludeSemantics(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stub: colored strip with the day.
                  Container(
                    width: 64,
                    decoration: BoxDecoration(
                      gradient: gradientFor(show.venue),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatShowDay(show.date)
                              .split(',')
                              .first
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${show.date.day}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          iconFor(show.venue),
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${show.workoutType.label.toUpperCase()} · '
                                  '${show.venue.label.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: StageColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              FeelFace(show.feel),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // One line of numbers, like a ticket's print run. A
                          // long Headliner shrinks to fit rather than wrapping.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  formatMiles(show.distanceMiles),
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontFeatures: StageFonts.tabular,
                                      ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  formatPace(show.paceSecondsPerMile),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: StageColors.amber,
                                        fontFeatures: StageFonts.tabular,
                                      ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  formatDuration(show.durationSeconds),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: StageColors.textMuted,
                                        fontFeatures: StageFonts.tabular,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Effort ${show.effort}/10',
                            style: const TextStyle(
                              fontSize: 13,
                              color: StageColors.textMuted,
                            ),
                          ),
                          if (song != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (song.albumArtUrl != null) ...[
                                  AlbumArt(
                                    url: song.albumArtUrl,
                                    size: 22,
                                    radius: 4,
                                  ),
                                  const SizedBox(width: 6),
                                ] else ...[
                                  const Icon(
                                    Icons.music_note,
                                    size: 16,
                                    color: StageColors.magenta,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    '${song.title} — ${song.artist}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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
}
