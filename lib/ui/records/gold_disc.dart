import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Short names for the gold-foil tokens in [StageColors], kept so Gold
/// Records code reads naturally. Dark [ink] sits on the foil; the foil is
/// never used for body text on the dark stage (amber does that job).
class GoldColors {
  static const light = StageColors.goldLight;
  static const mid = StageColors.goldMid;
  static const deep = StageColors.goldDeep;
  static const ink = StageColors.goldInk;
}

/// A record disc in flat rings: Gold Mid with Gold Deep grooves and rim and a
/// Gold Ink label once it's pressed, a faint outline while the slot is still
/// empty.
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

    // The foil: one flat gold, with a Gold Deep rim so it holds its edge
    // on the gold poster too.
    canvas.drawCircle(c, r, Paint()..color = GoldColors.mid);
    canvas.drawCircle(
      c,
      r - math.max(0.6, r / 40),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, r / 20)
        ..color = GoldColors.deep,
    );

    // Grooves.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r / 48)
      ..color = GoldColors.deep.withValues(alpha: 0.6);
    for (var f = 0.84; f > 0.42; f -= 0.075) {
      canvas.drawCircle(c, r * f, groove);
    }

    // The center label and spindle hole.
    canvas.drawCircle(c, r * 0.34, Paint()..color = GoldColors.ink);
    canvas.drawCircle(c, r * 0.07, Paint()..color = GoldColors.mid);
  }

  @override
  bool shouldRepaint(_DiscPainter old) => old.pressed != pressed;
}
