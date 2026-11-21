import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/show_math.dart';
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/show/${show.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stub: colored strip with the day.
              Container(
                width: 64,
                decoration: BoxDecoration(gradient: gradientFor(show.venue)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatShowDay(show.date).split(',').first.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1),
                    ),
                    Text(
                      '${show.date.day}',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(color: Colors.white),
                    ),
                    Icon(iconFor(show.venue), color: Colors.white, size: 18),
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
                                  color: StageColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(show.feel.emoji,
                              style: const TextStyle(fontSize: 20)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(formatMiles(show.distanceMiles),
                              style: theme.textTheme.headlineMedium),
                          Text(formatPace(show.paceSecondsPerMile),
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: StageColors.amber)),
                          Text(formatDuration(show.durationSeconds),
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: StageColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Effort ${show.effort}/10',
                          style: const TextStyle(
                              fontSize: 13, color: StageColors.textMuted)),
                      if (song != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (song.albumArtUrl != null) ...[
                              AlbumArt(
                                  url: song.albumArtUrl, size: 22, radius: 4),
                              const SizedBox(width: 6),
                            ] else ...[
                              const Icon(Icons.music_note,
                                  size: 16, color: StageColors.magenta),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                '${song.title} — ${song.artist}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
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
    );
  }
}
