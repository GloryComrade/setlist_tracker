import 'package:material_ui/material_ui.dart';

import '../models/enums.dart';

/// The bundled venue prints, drawn by tool/sample_art.py (no photos, no
/// stock, no outside source material).
///
/// Each one is a single screen of black ink at 16–40% on a transparent PNG.
/// A Show poster paints its venue gradient underneath and the halftone on
/// top, so the print only ever darkens the light: white type keeps the
/// contrast the gradient alone gives it (4.6:1 or better). The poster sets
/// the print beside its type, never under it (`PrintBeside`).
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
