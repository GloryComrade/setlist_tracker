import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'song_sleeve.dart';

/// Square album cover.
///
/// - Real art fades in over a quiet Stage Surface High tile with an album
///   mark, which also stays if the art fails to load. A made-up cover never
///   stands in for a real one, not even while it loads.
/// - A song with no art at all ([url] null with a [title]) gets its own
///   printed [SongSleeve]. It prints the title and artist only where the
///   sleeve is the song's label ([printTitle]); slots that set the title
///   beside the art, or put a play button on it, pass `printTitle: false`.
/// - With no song (an empty mosaic), the quiet tile.
///
/// The art is decoration: the song's title and artist always sit next to it
/// as text, so it adds nothing for screen readers.
class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 8,
    this.title,
    this.artist = '',
    this.printTitle,
  });

  final String? url;
  final double size;
  final double radius;

  /// The song, for its printed sleeve when there is no [url].
  final String? title;
  final String artist;

  /// Whether a sleeve prints the title and artist. Defaults to sleeves of
  /// 90 pt and up; below that the sleeve is the print alone.
  final bool? printTitle;

  @override
  Widget build(BuildContext context) {
    final placeholder = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        color: StageColors.surfaceHigh,
        child: Icon(
          Icons.album,
          color: StageColors.textMuted,
          size: size * 0.5,
        ),
      ),
    );
    final Widget art;
    if (url == null) {
      art = title == null
          ? placeholder
          : SizedBox.square(
              dimension: size,
              child: SongSleeve(
                title: title!,
                artist: artist,
                printTitle: (printTitle ?? true) && size >= 90,
              ),
            );
    } else {
      final still = MediaQuery.disableAnimationsOf(context);
      art = Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        // Decode at the size it is drawn, not the cover's full size.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        // On web, fall back to a plain <img> if the image host doesn't
        // allow cross-origin reads.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, _, _) => placeholder,
        frameBuilder: (context, child, frame, sync) => sync
            ? child
            : Stack(
                children: [
                  placeholder,
                  AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: child,
                  ),
                ],
              ),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: art);
  }
}
