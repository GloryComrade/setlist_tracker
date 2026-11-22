import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

/// The bundled sample art, drawn by tool/sample_art.py (no photos, no stock,
/// no real album covers).
///
/// Stage backdrops sit behind poster-sized blocks; sample sleeves stand in
/// for a song with no album art.
class StageArt {
  static const live = AssetImage('assets/images/stage_live.jpg');
  static const studio = AssetImage('assets/images/stage_studio.jpg');
  static const headline = AssetImage('assets/images/stage_headline.jpg');

  static const sleeves = [
    AssetImage('assets/images/sleeve_city_lights.jpg'),
    AssetImage('assets/images/sleeve_night_drive.jpg'),
    AssetImage('assets/images/sleeve_spin_cycle.jpg'),
    AssetImage('assets/images/sleeve_front_row.jpg'),
    AssetImage('assets/images/sleeve_frequency.jpg'),
    AssetImage('assets/images/sleeve_high_country.jpg'),
  ];

  /// The backdrop that matches a stage-light gradient, or null for a
  /// gradient that keeps its flat light (the Gold Records foil).
  static AssetImage? backdropFor(Gradient gradient) {
    if (gradient == StageColors.liveGradient) return live;
    if (gradient == StageColors.studioGradient) return studio;
    if (gradient == StageColors.headlineGradient) return headline;
    return null;
  }

  /// The same song always gets the same sleeve, on every device and run.
  static AssetImage sleeveFor(String seed) {
    var h = 0;
    for (final u in seed.codeUnits) {
      h = (h * 31 + u) & 0x3fffffff;
    }
    return sleeves[h % sleeves.length];
  }
}
