import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/gold_records.dart';
import '../../logic/record_wall.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';
import 'gold_disc.dart';
import 'record_wall_screen.dart';

/// The two doors at the top of Backstage: Gold Records and The Record Wall.
class RecordsEntry extends ConsumerWidget {
  const RecordsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shows = ref.watch(showsProvider).value ?? const [];
    final pressed = computeGoldRecords(shows).length;
    final total = RecordKind.values.length;
    final wall = ref.watch(recordWallProvider);
    // Real covers first, then printed sleeves for songs without art.
    final covers = [
      ...wall.where((r) => r.albumArtUrl != null),
      ...wall.where((r) => r.albumArtUrl == null),
    ].take(4).toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Door(
              label: 'Gold Records',
              caption: pressed == 0
                  ? 'None pressed yet'
                  : '$pressed of $total pressed',
              art: const GoldDisc(size: 52),
              onTap: () => context.push('/backstage/gold-records'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Door(
              label: 'The Record Wall',
              caption: wall.isEmpty
                  ? 'No songs yet'
                  : wall.length == 1
                  ? '1 song'
                  : '${wall.length} songs',
              art: _Mosaic(covers: covers),
              onTap: () => context.push('/backstage/record-wall'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.label,
    required this.caption,
    required this.art,
    required this.onTap,
  });

  final String label;
  final String caption;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $caption',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                art,
                const SizedBox(height: 14),
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(
                    color: StageColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to four records from the wall in a 2 × 2 square: covers, or each
/// song's printed sleeve.
class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.covers});
  final List<WallRecord> covers;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    const cell = (size - 2) / 2;
    if (covers.isEmpty) return const AlbumArt(url: null, size: size);
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            for (var i = 0; i < 4; i++)
              i < covers.length
                  ? AlbumArt(
                      url: covers[i].albumArtUrl,
                      title: covers[i].song.title,
                      artist: covers[i].song.artist,
                      size: cell,
                      radius: 0,
                    )
                  : Container(
                      width: cell,
                      height: cell,
                      color: StageColors.surfaceHigh,
                    ),
          ],
        ),
      ),
    );
  }
}
