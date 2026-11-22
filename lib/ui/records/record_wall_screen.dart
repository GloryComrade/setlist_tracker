import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/record_wall.dart';
import '../../logic/show_math.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/download/save_text_file.dart';
import '../widgets/stage_widgets.dart';

/// Every song on the wall, newest first.
final recordWallProvider = Provider<List<WallRecord>>(
  (ref) => buildRecordWall(ref.watch(showsProvider).value ?? const []),
);

final _day = DateFormat('EEE, MMM d, y');

/// The Record Wall: album art from every Song of the Show, plus top artists
/// and a track list to turn into a playlist.
class RecordWallScreen extends ConsumerWidget {
  const RecordWallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(showsProvider).isLoading;
    final wall = ref.watch(recordWallProvider);
    final artists = topArtists(wall);
    final showCount = wall.fold(0, (n, r) => n + r.plays);

    return Scaffold(
      appBar: AppBar(leading: backButtonFor(context, fallback: '/backstage')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : MaxWidth(
              width: 960,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: PosterHeader(
                        title: 'THE RECORD WALL',
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            wall.isEmpty
                                ? 'Every Song of the Show gets a spot here.'
                                : '${_count(wall.length, 'song')} from '
                                      '${_count(showCount, 'Show')}.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (wall.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyWall(),
                    )
                  else ...[
                    if (artists.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _TopArtists(artists: artists),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: _WallHeading(wall: wall),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 150,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                            ),
                        itemCount: wall.length,
                        itemBuilder: (context, i) => _WallTile(record: wall[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

String _count(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';

class _TopArtists extends StatelessWidget {
  const _TopArtists({required this.artists});
  final List<TopArtist> artists;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('TOP ARTISTS', style: theme.textTheme.headlineSmall),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, a) in artists.indexed)
                  Semantics(
                    label:
                        'Number ${i + 1}, ${a.name}: ${_count(a.shows, 'Show')}, '
                        '${formatMiles(a.miles)}',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: i == 0
                                    ? StageColors.amber
                                    : StageColors.textMuted,
                                fontFeatures: StageFonts.tabular,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    _count(a.shows, 'Show'),
                                    formatMiles(a.miles),
                                    if (a.songs > 1) _count(a.songs, 'song'),
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: StageColors.textMuted,
                                    fontSize: 13,
                                    fontFeatures: StageFonts.tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "The Wall" heading with the playlist export actions.
class _WallHeading extends StatelessWidget {
  const _WallHeading({required this.wall});
  final List<WallRecord> wall;

  Future<void> _copyList(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: trackListText(wall)));
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Track list copied. Paste it into TuneMyMusic or Soundiiz to make '
          'a Spotify or Apple Music playlist.',
        ),
      ),
    );
  }

  Future<void> _saveCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final csv = trackListCsv(wall);
    final saved = await saveTextFile('record-wall.csv', csv, 'text/csv');
    if (!saved) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'record-wall.csv downloaded.'
              : 'CSV copied to the clipboard.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'THE WALL',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        PopupMenuButton<void Function()>(
          tooltip: 'Export as a playlist',
          position: PopupMenuPosition.under,
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: () => _copyList(context),
              child: const ListTile(
                leading: Icon(Icons.queue_music),
                title: Text('Copy track list'),
                subtitle: Text('Paste into a playlist maker'),
              ),
            ),
            PopupMenuItem(
              value: () => _saveCsv(context),
              child: ListTile(
                leading: Icon(kIsWeb ? Icons.download : Icons.copy),
                title: Text(kIsWeb ? 'Download CSV' : 'Copy CSV'),
                subtitle: const Text('For a spreadsheet'),
              ),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ios_share, size: 18, color: StageColors.magenta),
                SizedBox(width: 6),
                Text(
                  'Export playlist',
                  style: TextStyle(
                    color: StageColors.magenta,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WallTile extends StatelessWidget {
  const _WallTile({required this.record});
  final WallRecord record;

  @override
  Widget build(BuildContext context) {
    final song = record.song;
    final art = record.albumArtUrl;
    return Semantics(
      button: true,
      label:
          '${song.title} by ${song.artist}, '
          '${_count(record.plays, 'Show')}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (art != null)
              LayoutBuilder(
                builder: (_, c) =>
                    AlbumArt(url: art, size: c.maxWidth, radius: 0),
              )
            else
              _PrintedSleeve(title: song.title, artist: song.artist),
            if (record.plays > 1)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: StageColors.background.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '×${record.plays}',
                    style: const TextStyle(
                      color: StageColors.amber,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      fontFeatures: StageFonts.tabular,
                    ),
                  ),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _showRecordSheet(context, record),
                hoverColor: Colors.white.withValues(alpha: 0.08),
                splashColor: StageColors.magenta.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sleeve for a song typed in by hand, with no album art.
class _PrintedSleeve extends StatelessWidget {
  const _PrintedSleeve({required this.title, required this.artist});
  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    // The same song always gets the same lights.
    const lights = [
      StageColors.liveGradient,
      StageColors.studioGradient,
      StageColors.headlineGradient,
    ];
    final gradient = lights[(title.hashCode ^ artist.hashCode).abs() % 3];
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: LayoutBuilder(
        builder: (context, c) {
          // Archivo Condensed capitals average about 0.5 em wide. Shrink the type until the
          // longest word fits on one line, so no word breaks in the middle.
          final longest = title
              .split(RegExp(r'\s+'))
              .fold(1, (n, w) => w.length > n ? w.length : n);
          final fit = (c.maxWidth - 20) / (longest * 0.5);
          // Never below 11, the smallest size anyone reads on a phone; a
          // word too long for that ellipsizes instead.
          final fontSize =
              (fit.clamp(11.0, 22.0) * (c.maxWidth / 115).clamp(0.6, 1.0))
                  .clamp(11.0, 22.0);
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: StageFonts.display,
                      fontSize: fontSize,
                      height: 0.95,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _showRecordSheet(BuildContext context, WallRecord record) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) {
      final song = record.song;
      final theme = Theme.of(sheetContext);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 96,
                  child: record.albumArtUrl != null
                      ? AlbumArt(url: record.albumArtUrl, size: 96)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _PrintedSleeve(
                            title: song.title,
                            artist: song.artist,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: const TextStyle(
                          color: StageColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        record.plays == 1
                            ? 'Song of 1 Show'
                            : 'Song of ${record.plays} Shows',
                        style: const TextStyle(
                          color: StageColors.amber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final show in record.shows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(iconFor(show.venue), color: StageColors.magenta),
                title: Text(
                  _day.format(show.date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    '${show.venue.label} · ${formatMiles(show.distanceMiles)}',
                    if ((show.song?.note ?? '').trim().isNotEmpty)
                      '“${show.song!.note!.trim()}”',
                  ].join('\n'),
                  style: const TextStyle(color: StageColors.textMuted),
                ),
                isThreeLine: (show.song?.note ?? '').trim().isNotEmpty,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/show/${show.id}');
                },
              ),
          ],
        ),
      );
    },
  );
}

class _EmptyWall extends StatelessWidget {
  const _EmptyWall();

  @override
  Widget build(BuildContext context) => EmptyStage(
    icon: Icons.album_outlined,
    title: 'The wall is bare',
    message:
        'Pick a Song of the Show when you log your next Show and its album '
        'art goes up here.',
    actionLabel: 'Book a Show',
    onAction: () => context.push('/show/new'),
  );
}
