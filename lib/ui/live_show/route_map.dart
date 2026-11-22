import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'route_poster.dart';

/// A route on a real Apple Map (iPhone, MapKit: no API key, no cost), with
/// the line in Neon Magenta, a white start ring and an amber finish. The
/// map is native (`ios/Runner/RouteMapView.swift`). Everywhere else, and in
/// tests, it is the drawn [RouteView].
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.segments, this.aspect = 4 / 3});

  /// Stretches between pauses, each a list of (lat, lng).
  final List<List<(double, double)>> segments;
  final double aspect;

  static bool get _onIPhone =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final points = segments.fold<int>(0, (n, s) => n + s.length);
    if (!_onIPhone || points < 2) {
      return RouteView(segments: segments, aspect: aspect);
    }
    return Semantics(
      image: true,
      label: 'Route map',
      child: AspectRatio(
        aspectRatio: aspect,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: StageColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StageColors.outline),
          ),
          child: UiKitView(
            viewType: 'setlist/route-map',
            creationParams: {
              'segments': [
                for (final s in segments)
                  [
                    for (final (lat, lng) in s) ...[lat, lng],
                  ],
              ],
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
      ),
    );
  }
}
