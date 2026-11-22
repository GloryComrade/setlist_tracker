import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';

/// The bundled venue prints, drawn by tool/sample_art.py (no photos, no
/// stock, no outside source material).
///
/// Each one is a single layer of black ink at 16–40% on a transparent PNG.
/// A Show poster paints its venue gradient underneath and the halftone on
/// top, so the print only ever darkens the light: white type keeps the
/// contrast the gradient alone gives it (4.6:1 or better).
class StageArt {
  /// Live Show: a topographic map with a loop route and mile ticks.
  static const livePrint = AssetImage('assets/images/print_live.png');

  /// Studio Session: a treadmill deck running away toward the console.
  static const studioPrint = AssetImage('assets/images/print_studio.png');

  static const prints = [livePrint, studioPrint];

  static AssetImage printFor(Venue venue) =>
      venue == Venue.studio ? studioPrint : livePrint;

  /// Decodes both prints ahead of time so a Show poster never paints its
  /// first frame without one. Each is 1080 × 1080, about 4.7 MB decoded.
  static Future<void> precache(BuildContext context) => Future.wait([
    for (final p in prints) precacheImage(p, context, onError: (_, _) {}),
  ]);
}
