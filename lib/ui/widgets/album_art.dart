import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Square album cover, with a stage-light placeholder when there is no art
/// or it fails to load.
class AlbumArt extends StatelessWidget {
  const AlbumArt({super.key, required this.url, this.size = 56, this.radius = 8});

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: StageColors.headlineGradient),
      child: Icon(Icons.album, color: Colors.white, size: size * 0.55),
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
