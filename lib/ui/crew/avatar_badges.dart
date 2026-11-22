/// The art for the Crew's tour-art badges (ids in
/// `lib/models/avatar_badge.dart`).
///
/// Each badge is one white mark on the runner's avatar color. Most marks
/// are Material Icons, the house icon set; the ones it has no shape for
/// (guitar pick, running shoe, drumsticks, cassette, laurel, crown,
/// spotlight) are drawn here on the same 24-unit grid, filled the same way,
/// so the set reads as one hand. No stock or brand art.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Badges that are a Material Icon.
const _iconBadges = <String, IconData>{
  'mic': Icons.mic,
  'vinyl': Icons.album,
  'headphones': Icons.headphones,
  'lightning': Icons.bolt,
  'star': Icons.star,
  'ticket': Icons.confirmation_number,
  'amp': Icons.speaker,
  'setlist': Icons.queue_music,
  'medal': Icons.military_tech,
  'stopwatch': Icons.timer,
  'mountain': Icons.terrain,
  'flame': Icons.local_fire_department,
  'wave': Icons.waves,
  'moon': Icons.dark_mode,
  'sun': Icons.wb_sunny,
  'heart': Icons.favorite,
  'music-note': Icons.music_note,
};

/// Badges drawn here.
const _drawnBadges = {
  'guitar-pick',
  'sneaker',
  'drumsticks',
  'cassette',
  'laurel',
  'crown',
  'spotlight',
};

/// True when [id] has art (every id in `kAvatarBadges` does).
bool hasBadgeArt(String id) =>
    _iconBadges.containsKey(id) || _drawnBadges.contains(id);

/// The white mark for badge [id], [size] square. Art only: the name is
/// always said by whoever shows it.
class BadgeGlyph extends StatelessWidget {
  const BadgeGlyph(
    this.id, {
    super.key,
    required this.size,
    this.color = Colors.white,
  });

  final String id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = _iconBadges[id];
    final Widget art = icon != null
        ? Icon(icon, size: size, color: color)
        : CustomPaint(
            size: Size.square(size),
            painter: _BadgePainter(id, color),
          );
    return ExcludeSemantics(child: art);
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.id, this.color);
  final String id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Material Icons sit on a 24-unit grid; so does every drawn badge.
    canvas.scale(size.width / 24);
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    switch (id) {
      case 'guitar-pick':
        canvas.drawPath(_guitarPick(), fill);
      case 'sneaker':
        canvas.drawPath(_sneaker(), fill);
      case 'drumsticks':
        _drumsticks(canvas, fill);
      case 'cassette':
        canvas.drawPath(_cassette(), fill);
      case 'laurel':
        _laurel(canvas, fill);
      case 'crown':
        canvas.drawPath(_crown(), fill);
      case 'spotlight':
        _spotlight(canvas, fill);
    }
  }

  static Path _guitarPick() => Path()
    ..moveTo(12, 21.5)
    ..cubicTo(8, 17.6, 3.5, 11.6, 3.5, 7.6)
    ..cubicTo(3.5, 4.2, 7, 2.5, 12, 2.5)
    ..cubicTo(17, 2.5, 20.5, 4.2, 20.5, 7.6)
    ..cubicTo(20.5, 11.6, 16, 17.6, 12, 21.5)
    ..close();

  static Path _sneaker() {
    final upper = Path()
      ..moveTo(2, 15)
      ..lineTo(2, 12.6)
      ..cubicTo(2, 11.7, 2.6, 11.1, 3.5, 10.9)
      ..lineTo(7.6, 9.9)
      ..lineTo(10.2, 6.4)
      ..cubicTo(10.7, 5.7, 11.6, 5.6, 12.2, 6.1)
      ..lineTo(14.4, 7.9)
      ..cubicTo(15.4, 8.7, 16.6, 9.2, 17.9, 9.4)
      ..lineTo(19.6, 9.7)
      ..cubicTo(21, 10, 22, 11.2, 22, 12.6)
      ..lineTo(22, 15)
      ..close();
    // Three lace stripes cut out of the upper.
    final laces = Path();
    for (var i = 0; i < 3; i++) {
      final x = 9.8 + i * 1.9;
      laces.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 9.2 + i * 0.5, 1.1, 2.4),
          const Radius.circular(0.5),
        ),
      );
    }
    final sole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(2, 16.2, 22, 18.8),
          const Radius.circular(1.3),
        ),
      );
    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.difference, upper, laces),
      sole,
    );
  }

  static void _drumsticks(Canvas canvas, Paint fill) {
    final stick = Paint()
      ..color = fill.color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawLine(const Offset(4.5, 20), const Offset(18.2, 6.3), stick);
    canvas.drawLine(const Offset(19.5, 20), const Offset(5.8, 6.3), stick);
    canvas.drawCircle(const Offset(19.2, 5.2), 1.9, fill);
    canvas.drawCircle(const Offset(4.8, 5.2), 1.9, fill);
  }

  static Path _cassette() {
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(2, 5, 22, 19),
          const Radius.circular(2),
        ),
      );
    final window = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(5.5, 8, 18.5, 13.5),
          const Radius.circular(1.2),
        ),
      );
    final reels = Path()
      ..addOval(Rect.fromCircle(center: const Offset(9, 10.75), radius: 1.7))
      ..addOval(Rect.fromCircle(center: const Offset(15, 10.75), radius: 1.7));
    // The tape guide at the bottom edge.
    final guide = Path()
      ..moveTo(7, 19)
      ..lineTo(8.2, 15.6)
      ..lineTo(15.8, 15.6)
      ..lineTo(17, 19)
      ..close();
    final cut = Path.combine(PathOperation.union, window, guide);
    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.difference, body, cut),
      reels,
    );
  }

  static void _laurel(Canvas canvas, Paint fill) {
    for (final side in [-1.0, 1.0]) {
      // Five leaves along an arc from the bottom up each side.
      for (var i = 0; i < 5; i++) {
        final a = math.pi / 2 + side * (0.35 + i * 0.5);
        final c = Offset(12 + 8 * math.cos(a), 12.5 + 8 * math.sin(a));
        canvas.save();
        canvas.translate(c.dx, c.dy);
        // Leaves point along the arc, tipped slightly outward.
        canvas.rotate(a + side * math.pi / 2 - side * 0.35);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 4.4, height: 2),
          fill,
        );
        canvas.restore();
      }
    }
    final stem = Paint()
      ..color = fill.color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final arc = Rect.fromCircle(center: const Offset(12, 12.5), radius: 6.6);
    canvas.drawArc(arc, math.pi / 2 + 0.2, 2.2, false, stem);
    canvas.drawArc(arc, math.pi / 2 - 0.2, -2.2, false, stem);
  }

  static Path _crown() {
    final crown = Path()
      ..moveTo(3, 17.5)
      ..lineTo(3, 8.5)
      ..lineTo(8, 12.4)
      ..lineTo(12, 5.5)
      ..lineTo(16, 12.4)
      ..lineTo(21, 8.5)
      ..lineTo(21, 17.5)
      ..close()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(3, 18.6, 21, 20.6),
          const Radius.circular(0.8),
        ),
      )
      ..addOval(Rect.fromCircle(center: const Offset(3, 7.4), radius: 1.5))
      ..addOval(Rect.fromCircle(center: const Offset(12, 4.3), radius: 1.5))
      ..addOval(Rect.fromCircle(center: const Offset(21, 7.4), radius: 1.5));
    return crown;
  }

  static void _spotlight(Canvas canvas, Paint fill) {
    // The beam is printed at half ink so the lamp reads in front of it.
    final beam = Path()
      ..moveTo(10.6, 9.4)
      ..lineTo(21.5, 17)
      ..quadraticBezierTo(19.5, 21, 15, 21.5)
      ..lineTo(8.6, 11.4)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..color = fill.color.withValues(alpha: 0.5)
        ..isAntiAlias = true,
    );
    canvas.save();
    canvas.translate(7.6, 8.4);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 5.6),
        const Radius.circular(1.4),
      ),
      fill,
    );
    canvas.restore();
    // The yoke and stand.
    final yoke = Paint()
      ..color = fill.color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(const Offset(5.2, 13.2), const Offset(4, 20.5), yoke);
    canvas.drawLine(const Offset(2.5, 20.8), const Offset(7.5, 20.8), yoke);
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.id != id || old.color != color;
}
