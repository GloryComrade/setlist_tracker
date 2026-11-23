import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/health/health_save.dart';
import '../../data/providers.dart';
import '../../data/settings/app_settings.dart';
import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../logic/spotify_links.dart';
import '../../models/enums.dart';
import '../../models/gear.dart';
import '../../models/show.dart';
import '../../models/venue_details.dart';
import '../../theme/app_theme.dart';
import '../../theme/stage_art.dart';
import '../widgets/album_art.dart';
import '../widgets/clip_player.dart';
import '../widgets/open_link.dart';
import '../widgets/stage_widgets.dart';
import '../live_show/route_poster.dart';
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
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // The Crew stops seeing it after the next sync.
    await ref.read(showRepositoryProvider).delete(showId);
    if (context.mounted) leaveScreen(context);
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
            appBar: AppBar(leading: backButtonFor(context)),
            body: const Center(child: Text('That Show is not on the Setlist.')),
          );
        }
        final gearName = gear
            .where((g) => g.id == show.gearId)
            .firstOrNull
            ?.displayName;
        return Scaffold(
          appBar: AppBar(
            leading: backButtonFor(context),
            title: const Text('THE SHOW'),
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
                    if (show.crewPrivate) const _KeptOffCrew(),
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
                      if (show.live!.gps != null &&
                          !show.live!.gps!.isEmpty) ...[
                        const SizedBox(height: 12),
                        RouteSection(track: show.live!.gps!),
                      ],
                    ],
                    _HeartRate(show: show),
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

/// "Kept off the Crew": only you see this Show.
class _KeptOffCrew extends StatelessWidget {
  const _KeptOffCrew();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: StageColors.textMuted,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kept off the Crew. Only you see this Show.',
              style: TextStyle(fontSize: 13, color: StageColors.textMuted),
            ),
          ),
        ],
      ),
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
      title: formatMiles(show.distanceMiles),
      semanticsTitle: spokenMiles(show.distanceMiles),
      mark: markFor(show.venue),
      titleColor: StageColors.amber,
      venuePrint: StageArt.printFor(show.venue),
      children: [
        Text(
          '${formatPace(show.paceSecondsPerMile)}  ·  '
          '${formatDuration(show.durationSeconds)}',
          semanticsLabel:
              '${spokenPace(show.paceSecondsPerMile)}, '
              '${spokenDuration(show.durationSeconds)}',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontFeatures: StageFonts.tabular,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatShowDateTime(show.date),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [VenueBadge(show.venue)]),
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
      title: 'Details',
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        children: [
          StatTile(label: 'Workout', value: show.workoutType.label),
          StatTile(label: 'Effort', value: '${show.effort}/10'),
          StatTile(
            label: 'Feel',
            value: show.feel.label,
            leading: ExcludeSemantics(child: FeelFace(show.feel, size: 26)),
          ),
          if (gearName != null) StatTile(label: 'Gear', value: gearName!),
        ],
      ),
    );
  }
}

class _SongCard extends ConsumerWidget {
  const _SongCard({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = show.song!;
    // Settings > Song of the Show picks which one leads.
    final appleFirst =
        ref.watch(appSettingsProvider.select((s) => s.musicApp)) ==
        MusicApp.appleMusic;
    final appleUri = song.appleMusicUrl != null
        ? Uri.parse(song.appleMusicUrl!)
        : appleMusicSearchUri(song.title, song.artist);
    return SectionCard(
      title: 'Song of the Show',
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AlbumArt(
                url: song.albumArtUrl,
                size: 96,
                title: song.title,
                artist: song.artist,
                // Titled beside it; a play button may cover it.
                printTitle: false,
              ),
              if (song.hasClip) ClipPlayButton(song: song),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  song.artist,
                  style: const TextStyle(color: StageColors.textMuted),
                ),
                if (song.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '“${song.note}”',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (appleFirst)
                      FilledButton.icon(
                        onPressed: () => openLink(context, appleUri),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Open in Apple Music'),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: StageColors.spotifyGreen,
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
                    if (!appleFirst && song.appleMusicUrl != null)
                      OutlinedButton(
                        onPressed: () =>
                            openLink(context, Uri.parse(song.appleMusicUrl!)),
                        child: const Text('Apple Music'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioSection extends StatelessWidget {
  const _StudioSection({required this.details});
  final StudioDetails details;

  @override
  Widget build(BuildContext context) {
    final where = [
      details.gymName,
      details.treadmillName,
    ].whereType<String>().join(' · ');
    final incline = details.inclinePercent;
    return SectionCard(
      title: details.tracks.isEmpty ? 'The Studio' : 'The Tracks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                where,
                style: const TextStyle(color: StageColors.textMuted),
              ),
            ),
          if (details.tracks.isEmpty && incline != null)
            InclineBar(inclinePercent: incline)
          else if (details.tracks.isEmpty)
            const Text(
              'No Tracks logged.',
              style: TextStyle(color: StageColors.textMuted),
            )
          else ...[
            // Full card width, so the header rule lines up with the totals
            // strip below; scrolls sideways only when the card is too narrow.
            LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 0,
                    columns: const [
                      DataColumn(label: Text('#')),
                      // Takes up the spare width so the table spans the card.
                      DataColumn(
                        label: Text('Time'),
                        columnWidth: FlexColumnWidth(),
                      ),
                      DataColumn(label: Text('mph'), numeric: true),
                      DataColumn(label: Text('Incline'), numeric: true),
                      DataColumn(label: Text('Miles'), numeric: true),
                    ],
                    rows: [
                      for (var i = 0; i < details.tracks.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(
                              Text(
                                '${formatDuration(details.tracks[i].startSeconds)}–'
                                '${formatDuration(details.tracks[i].endSeconds)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                details.tracks[i].speedMph.toStringAsFixed(1),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${details.tracks[i].inclinePercent.toStringAsFixed(1)}%',
                              ),
                            ),
                            DataCell(
                              Text(
                                formatMiles(
                                  details.tracks[i].distanceMiles,
                                  withUnit: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
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
              value: '${n(details.elevationGainFt!)} ft',
            ),
          if (w?.tempF != null)
            StatTile(label: 'Temp', value: '${n(w!.tempF!)}°F'),
          if (w?.windMph != null)
            StatTile(label: 'Wind', value: '${n(w!.windMph!)} mph'),
          if (w?.conditions != null)
            StatTile(label: 'Conditions', value: w!.conditions!.label),
        ],
      ),
    );
  }
}

/// Heart rate from Apple Health for the time of the Show (iPhone only).
/// Read when the page opens; never stored, synced or shown to the Crew.
/// Nothing is drawn when Health has none.
class _HeartRate extends ConsumerWidget {
  const _HeartRate({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gps = show.live?.gps;
    final seconds = gps != null && gps.seconds.isNotEmpty
        ? gps.seconds.last
        : show.durationSeconds;
    final window = (
      start: show.date,
      end: show.date.add(Duration(seconds: seconds > 0 ? seconds : 60)),
    );
    final hr = ref.watch(showHeartRateProvider(window)).value;
    if (hr == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        title: 'Heart Rate',
        trailing: const Icon(
          Icons.favorite_border,
          color: StageColors.magenta,
          semanticLabel: 'From Apple Health',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 16,
              children: [
                StatTile(
                  label: 'Average',
                  value: '${hr.average} bpm',
                  spokenValue: '${hr.average} beats per minute',
                ),
                StatTile(
                  label: 'Max',
                  value: '${hr.max} bpm',
                  spokenValue: '${hr.max} beats per minute',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'From Apple Health. Only on this iPhone; your Crew never sees it.',
              style: TextStyle(color: StageColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
