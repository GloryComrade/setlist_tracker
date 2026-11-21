import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/show_math.dart';
import '../../logic/spotify_links.dart';
import '../../models/enums.dart';
import '../../models/gear.dart';
import '../../models/show.dart';
import '../../models/venue_details.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/clip_player.dart';
import '../widgets/open_link.dart';
import '../widgets/stage_widgets.dart';
import '../widgets/track_editor.dart';

/// Everything about one Show.
class ShowDetailScreen extends ConsumerWidget {
  const ShowDetailScreen({super.key, required this.showId});
  final String showId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this Show?'),
        content: const Text('It will be removed from your Setlist.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(showRepositoryProvider).delete(showId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsProvider);
    final gear = ref.watch(gearListProvider).value ?? const <Gear>[];

    return showsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (shows) {
        final show = shows.where((s) => s.id == showId).firstOrNull;
        if (show == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('That Show is not on the Setlist.')),
          );
        }
        final gearName =
            gear.where((g) => g.id == show.gearId).firstOrNull?.displayName;
        return Scaffold(
          appBar: AppBar(
            title: Text(show.workoutType.label.toUpperCase()),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/show/$showId/edit'),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Poster(show: show),
                    const SizedBox(height: 12),
                    _Stats(show: show, gearName: gearName),
                    if (show.song != null) ...[
                      const SizedBox(height: 12),
                      _SongCard(show: show),
                    ],
                    if (show.venue == Venue.studio && show.studio != null) ...[
                      const SizedBox(height: 12),
                      _StudioSection(details: show.studio!),
                    ],
                    if (show.venue == Venue.live && show.live != null) ...[
                      const SizedBox(height: 12),
                      _LiveSection(details: show.live!),
                    ],
                    if (show.notes != null) ...[
                      const SizedBox(height: 12),
                      SectionCard(title: 'Notes', child: Text(show.notes!)),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PosterHeader(
      kicker: formatShowDateTime(show.date),
      title: formatMiles(show.distanceMiles).toUpperCase(),
      gradient: gradientFor(show.venue),
      children: [
        Text(
          '${formatPace(show.paceSecondsPerMile)}  ·  '
          '${formatDuration(show.durationSeconds)}',
          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconFor(show.venue), size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(show.venue.label.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.show, required this.gearName});
  final Show show;
  final String? gearName;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'The Numbers',
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        children: [
          StatTile(label: 'Workout', value: show.workoutType.label),
          StatTile(label: 'Effort', value: '${show.effort}/10'),
          StatTile(label: 'Feel', value: '${show.feel.emoji} ${show.feel.label}'),
          if (gearName != null) StatTile(label: 'Gear', value: gearName!),
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final song = show.song!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AlbumArt(url: song.albumArtUrl, size: 96),
                if (song.hasClip) ClipPlayButton(song: song),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SONG OF THE SHOW',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: StageColors.magenta)),
                  Text(song.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(song.artist,
                      style: const TextStyle(color: StageColors.textMuted)),
                  if (song.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('“${song.note}”',
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: spotifyGreen,
                          foregroundColor: Colors.black,
                        ),
                        // An exact track link when we have one; otherwise
                        // Spotify's search for title + artist.
                        onPressed: () => openLink(
                          context,
                          song.spotifyUrl != null
                              ? Uri.parse(song.spotifyUrl!)
                              : spotifySearchUri(song.title, song.artist),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Open in Spotify'),
                      ),
                      if (song.appleMusicUrl != null)
                        OutlinedButton(
                          onPressed: () => openLink(
                              context, Uri.parse(song.appleMusicUrl!)),
                          child: const Text('Apple Music'),
                        ),
                    ],
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

class _StudioSection extends StatelessWidget {
  const _StudioSection({required this.details});
  final StudioDetails details;

  @override
  Widget build(BuildContext context) {
    final where = [details.gymName, details.treadmillName]
        .whereType<String>()
        .join(' · ');
    return SectionCard(
      title: 'The Tracks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(where,
                  style: const TextStyle(color: StageColors.textMuted)),
            ),
          if (details.tracks.isEmpty)
            const Text('No Tracks logged.',
                style: TextStyle(color: StageColors.textMuted))
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 0,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('mph'), numeric: true),
                  DataColumn(label: Text('Incline'), numeric: true),
                  DataColumn(label: Text('Miles'), numeric: true),
                ],
                rows: [
                  for (var i = 0; i < details.tracks.length; i++)
                    DataRow(cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(Text(
                          '${formatDuration(details.tracks[i].startSeconds)}–'
                          '${formatDuration(details.tracks[i].endSeconds)}')),
                      DataCell(Text(
                          details.tracks[i].speedMph.toStringAsFixed(1))),
                      DataCell(Text(
                          '${details.tracks[i].inclinePercent.toStringAsFixed(1)}%')),
                      DataCell(Text(formatMiles(details.tracks[i].distanceMiles,
                          withUnit: false))),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TrackTotalsBar(totals: details.totals),
            if (!details.useTrackTotals)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Distance and time above were typed in from the treadmill.',
                  style: TextStyle(color: StageColors.textMuted, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LiveSection extends StatelessWidget {
  const _LiveSection({required this.details});
  final LiveDetails details;

  @override
  Widget build(BuildContext context) {
    final w = details.weather;
    String n(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
    return SectionCard(
      title: 'The Venue',
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        children: [
          if (details.routeName != null)
            StatTile(label: 'Route', value: details.routeName!),
          StatTile(label: 'Surface', value: details.surface.label),
          if (details.elevationGainFt != null)
            StatTile(
                label: 'Elevation gain',
                value: '${n(details.elevationGainFt!)} ft'),
          if (w?.tempF != null)
            StatTile(label: 'Temp', value: '${n(w!.tempF!)}°F'),
          if (w?.windMph != null)
            StatTile(label: 'Wind', value: '${n(w!.windMph!)} mph'),
          if (w?.conditions != null)
            StatTile(
                label: 'Conditions',
                value: '${w!.conditions!.emoji} ${w.conditions!.label}'),
        ],
      ),
    );
  }
}
