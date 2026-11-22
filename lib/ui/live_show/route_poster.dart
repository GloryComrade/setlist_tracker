import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../logic/gps_math.dart';
import '../../logic/show_math.dart';
import '../../models/gps_track.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';

/// A GPS route drawn like the Live Show print: a neon line on the dark
/// stage, a white start ring, an amber tick at every mile and, while
/// recording, an amber dot where you are. No map tiles: nothing is fetched,
/// and nothing but your own line is shown.
class RouteView extends StatelessWidget {
  const RouteView({
    super.key,
    required this.segments,
    this.live = false,
    this.aspect = 4 / 3,
    this.semanticLabel,
  });

  /// Stretches between pauses, each a list of (lat, lng).
  final List<List<(double, double)>> segments;

  /// Recording: the end of the line is "you are here", not a finish.
  final bool live;
  final double aspect;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final points = segments.fold<int>(0, (n, s) => n + s.length);
    return Semantics(
      image: true,
      label: semanticLabel ?? 'Route map',
      child: AspectRatio(
        aspectRatio: aspect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StageColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StageColors.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: points < 2
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        live
                            ? 'Your route draws here once you get moving.'
                            : 'No route for this Show.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: StageColors.textMuted),
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: RoutePainter(segments: segments, live: live),
                    size: Size.infinite,
                  ),
          ),
        ),
      ),
    );
  }
}

class RoutePainter extends CustomPainter {
  RoutePainter({required this.segments, required this.live});

  final List<List<(double, double)>> segments;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    _paper(canvas, size);
    final all = [for (final s in segments) ...s];
    if (all.length < 2) return;

    // Flat projection, squeezed by latitude so a mile east is as long as a
    // mile north. Fine at the size of a run.
    var minLat = all.first.$1, maxLat = minLat;
    var minLng = all.first.$2, maxLng = minLng;
    for (final (lat, lng) in all) {
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLng = math.min(minLng, lng);
      maxLng = math.max(maxLng, lng);
    }
    final k = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max((maxLng - minLng) * k, 1e-6);
    final h = math.max(maxLat - minLat, 1e-6);
    const pad = 24.0;
    final scale = math.min(
      (size.width - pad * 2) / w,
      (size.height - pad * 2) / h,
    );
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;
    Offset at((double, double) p) =>
        Offset(dx + (p.$2 - minLng) * k * scale, dy + (maxLat - p.$1) * scale);

    final line = Paint()
      ..color = StageColors.magenta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final seg in segments) {
      if (seg.length < 2) continue;
      final path = Path()..moveTo(at(seg.first).dx, at(seg.first).dy);
      for (final p in seg.skip(1)) {
        final o = at(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, line);
    }

    // Mile ticks.
    final tick = Paint()..color = StageColors.amber;
    var run = 0.0;
    var nextMile = metersPerMile;
    for (final seg in segments) {
      for (var i = 1; i < seg.length; i++) {
        final a = seg[i - 1], b = seg[i];
        final step = haversineMeters(a.$1, a.$2, b.$1, b.$2);
        while (step > 0 && run + step >= nextMile) {
          final f = (nextMile - run) / step;
          final o = Offset.lerp(at(a), at(b), f)!;
          canvas.drawCircle(o, 4, tick);
          nextMile += metersPerMile;
        }
        run += step;
      }
    }

    // Start ring.
    final start = at(all.first);
    canvas.drawCircle(start, 7, Paint()..color = StageColors.background);
    canvas.drawCircle(
      start,
      7,
      Paint()
        ..color = StageColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // You are here / the finish.
    final end = at(all.last);
    canvas.drawCircle(
      end,
      live ? 9 : 6,
      Paint()..color = StageColors.background,
    );
    canvas.drawCircle(end, live ? 6.5 : 5, Paint()..color = StageColors.amber);
  }

  /// Faint graph paper, so a short or straight route still sits on
  /// something.
  void _paper(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = StageColors.outline.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.live != live || !identical(old.segments, segments);
}

/// The Show page's route card: the route, then every mile split.
class RouteSection extends StatelessWidget {
  const RouteSection({super.key, required this.track});
  final GpsTrack track;

  @override
  Widget build(BuildContext context) {
    final segments = trackSegments(track);
    return SectionCard(
      title: 'The Route',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RouteView(segments: segments),
          if (track.splits.isNotEmpty) ...[
            const SizedBox(height: 16),
            MileSplits(splits: track.splits),
          ],
        ],
      ),
    );
  }
}

/// "MILE 1  8:52", one row per full mile, the fastest in amber.
class MileSplits extends StatelessWidget {
  const MileSplits({super.key, required this.splits, this.latestFirst = false});
  final List<int> splits;
  final bool latestFirst;

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();
    final fastest = splits.reduce(math.min);
    final order = [for (var i = 0; i < splits.length; i++) i];
    final rows = latestFirst ? order.reversed : order;
    final numberStyle = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontFeatures: StageFonts.tabular);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'MILE SPLITS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: StageColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        for (final i in rows)
          Semantics(
            label:
                'Mile ${i + 1}: ${spokenSplit(splits[i])}'
                '${splits[i] == fastest && splits.length > 1 ? ', fastest' : ''}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        'MILE ${i + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatPace(splits[i].toDouble()),
                        style: numberStyle?.copyWith(
                          color: splits[i] == fastest && splits.length > 1
                              ? StageColors.amber
                              : StageColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String spokenSplit(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m minute${m == 1 ? '' : 's'} $s second${s == 1 ? '' : 's'}';
}
