import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Gold-foil colors for Gold Records. Dark text sits on the foil; the foil
/// is never used for body text on the dark stage (amber does that job).
class GoldColors {
  static const light = Color(0xFFFFE9A8);
  static const mid = Color(0xFFF5C451);
  static const deep = Color(0xFFB7791F);
  static const ink = Color(0xFF1A1206);

  static const foil = LinearGradient(
    colors: [light, mid, deep, mid],
    stops: [0, 0.35, 0.75, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// A record disc: gold with grooves and a label once it's pressed, a faint
/// outline while the slot is still empty.
class GoldDisc extends StatelessWidget {
  const GoldDisc({super.key, this.size = 48, this.pressed = true});

  final double size;
  final bool pressed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _DiscPainter(pressed: pressed),
    ),
  );
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({required this.pressed});
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    if (!pressed) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = StageColors.outline;
      canvas.drawCircle(c, r - 0.6, line);
      canvas.drawCircle(c, r * 0.34, line);
      canvas.drawCircle(c, r * 0.07, Paint()..color = StageColors.outline);
      return;
    }

    // The foil, lit from the top left.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            GoldColors.mid,
            GoldColors.light,
            GoldColors.mid,
            GoldColors.deep,
            GoldColors.mid,
            GoldColors.light,
            GoldColors.mid,
            GoldColors.deep,
            GoldColors.mid,
          ],
          transform: GradientRotation(-math.pi / 5),
        ).createShader(rect),
    );

    // Grooves.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r / 48)
      ..color = GoldColors.deep.withValues(alpha: 0.45);
    for (var f = 0.92; f > 0.42; f -= 0.075) {
      canvas.drawCircle(c, r * f, groove);
    }

    // The center label and spindle hole.
    canvas.drawCircle(c, r * 0.34, Paint()..color = StageColors.magentaDeep);
    canvas.drawCircle(
      c,
      r * 0.34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r / 32)
        ..color = GoldColors.light.withValues(alpha: 0.7),
    );
    canvas.drawCircle(c, r * 0.07, Paint()..color = StageColors.background);
  }

  @override
  bool shouldRepaint(_DiscPainter old) => old.pressed != pressed;
}
