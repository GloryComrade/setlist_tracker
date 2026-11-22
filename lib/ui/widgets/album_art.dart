import 'package:material_ui/material_ui.dart';

import '../../theme/stage_art.dart';

/// Square album cover. With no art, or while it loads or if it fails, a
/// sample sleeve stands in: the same one for the same [seed] (usually the
/// song's title and artist).
class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 8,
    this.seed = '',
  });

  final String? url;
  final double size;
  final double radius;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final placeholder = Image(
      image: StageArt.sleeveFor(seed),
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // On web, fall back to a plain <img> if the image host doesn't
              // allow cross-origin reads.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}
