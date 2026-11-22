import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';

/// The bundled venue prints, drawn by tool/sample_art.py (no photos, no
/// stock, no outside source material).
///
/// Each one is a single screen of black ink at 16–40% on a transparent PNG.
/// The PNG's alpha is the screen; a Show poster prints it in its venue mark
/// at 60% (`PosterSurface.printStrength`), so 10–24% on the dark Stage
/// Surface. The poster sets the print beside its type, never under it
/// (`PrintBeside`), so the type keeps its full contrast on the surface.
class StageArt {
  /// Live Show: a topographic map with a loop route and mile ticks.
  static const livePrint = AssetImage('assets/images/print_live.png');

  /// Studio Session: a treadmill side-on, console, handrail and belt.
  static const studioPrint = AssetImage('assets/images/print_studio.png');

  static const prints = [livePrint, studioPrint];

  /// Width over height of both prints (810 × 900 px). The subject sits in
  /// the left 60%, which always shows; the rest may run off the poster.
  static const printAspect = 0.9;

  static AssetImage printFor(Venue venue) =>
      venue == Venue.studio ? studioPrint : livePrint;

  /// Decodes both prints ahead of time so a Show poster never paints its
  /// first frame without one. Each is 810 × 900, about 2.9 MB decoded.
  static Future<void> precache(BuildContext context) => Future.wait([
    for (final p in prints) precacheImage(p, context, onError: (_, _) {}),
  ]);
}
