import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'stage_widgets.dart';

/// The printed design of one song's stand-in sleeve, worked out from its
/// title and artist alone, so the same song gets the same sleeve on every
/// device and run, and different songs almost never match.
///
/// Every sleeve is two of the deep shades, always one warm and one cool, so
/// a sleeve never reads as a Live Show or a Studio Session, and white type
/// on either ink stays at 4.6:1 or better.
@immutable
class SleeveDesign {
  const SleeveDesign({
    required this.ground,
    required this.ink,
    required this.layout,
    required this.turn,
    required this.screenCorner,
  });

  factory SleeveDesign.of(String title, String artist) {
    final h = fnv1a(
      '${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}',
    );
    final (warm, cool) = _pairs[h & 3];
    final coolGround = (h >> 2) & 1 == 1;
    return SleeveDesign(
      ground: coolGround ? cool : warm,
      ink: coolGround ? warm : cool,
      layout: SleeveLayout.values[(h >> 3) % SleeveLayout.values.length],
      turn: ((h >> 6) & 0xff) / 255,
      screenCorner: (h >> 14) & 3,
    );
  }

  static const _pairs = [
    (StageColors.magentaDeep, StageColors.violetDeep),
    (StageColors.magentaDeep, StageColors.tealDeep),
    (StageColors.orangeDeep, StageColors.violetDeep),
    (StageColors.orangeDeep, StageColors.tealDeep),
  ];

  /// The paper color: the whole sleeve before the second ink.
  final Color ground;

  /// The second ink, printed in the [layout]'s shape.
  final Color ink;
  final SleeveLayout layout;

  /// 0–1: the layout's angle or position.
  final double turn;

  /// Where the grain starts (0–3), so neighbouring sleeves differ.
  final int screenCorner;

  /// FNV-1a, 32 bit: stable across platforms, unlike `String.hashCode`.
  /// The prime is 2^24 + 0x193, multiplied in two parts so no product
  /// passes 2^53, where web numbers lose their low bits.
  static int fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final u in s.codeUnits) {
      h = (h ^ u) & 0xffffffff;
      h = (h * 0x193 + ((h & 0xff) << 24)) & 0xffffffff;
    }
    // Xorshift finish, so the low bits (ink pair, layout) spread evenly.
    h ^= (h << 13) & 0xffffffff;
    h ^= h >> 17;
    h ^= (h << 5) & 0xffffffff;
    return h;
  }

  @override
  bool operator ==(Object other) =>
      other is SleeveDesign &&
      other.ground == ground &&
      other.ink == ink &&
      other.layout == layout &&
      other.turn == turn &&
      other.screenCorner == screenCorner;

  @override
  int get hashCode => Object.hash(ground, ink, layout, turn, screenCorner);
}

/// The second ink's shape.
enum SleeveLayout {
  /// A straight cut across the sleeve at an angle.
  split,

  /// A big disc rising off the top edge.
  disc,

  /// Three bands of growing weight.
  bands,

  /// Quarter rings from a top corner.
  rings,
}

/// The stand-in sleeve for a song with no album art: a two-ink screen print
/// with the title printed on it, so it is plainly ours and never passes for
/// the record's real cover.
///
/// [printTitle] sets the title and artist across the foot (use it at 90 pt
/// and up, where the sleeve is the song's only label). Without it the
/// sleeve is the print alone: no letter, which at small sizes reads as a
/// Crew avatar or a letter puzzle, and the title is written next to it
/// anyway. The type is part of the art and does not grow with text size:
/// the title and artist are always written out next to it, or in the
/// tile's spoken label.
class SongSleeve extends StatelessWidget {
  const SongSleeve({
    super.key,
    required this.title,
    required this.artist,
    this.printTitle = true,
  });

  final String title;
  final String artist;
  final bool printTitle;

  /// The title's size for a sleeve [width] wide: one size per sleeve size,
  /// so sleeves side by side match whatever their titles.
  static double titleSizeFor(double width) => (width * 0.14).clamp(11.0, 22.0);

  @override
  Widget build(BuildContext context) {
    final design = SleeveDesign.of(title, artist);
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: CustomPaint(
          painter: SleevePainter(design),
          child: printTitle
              ? LayoutBuilder(
                  builder: (context, c) => _titleBlock(context, c.maxWidth),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _titleBlock(BuildContext context, double width) {
    const inset = 10.0;
    final style = TextStyle(
      fontFamily: StageFonts.display,
      fontSize: titleSizeFor(width),
      height: 0.95,
      letterSpacing: 0.4,
      color: Colors.white,
    );
    // Lines break between words. Only a single word too long for the
    // sleeve at its size (rare) sets this sleeve's title smaller, down to
    // 11, so no word is broken in the middle; past that it ellipsizes.
    final words = title.toUpperCase().split(RegExp(r'\s+'));
    final widest = words.fold(0.0, (w, word) {
      final p = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      final n = p.width;
      p.dispose();
      return math.max(w, n);
    });
    final room = width - inset * 2;
    final fontSize = widest > room
        ? math.max(11.0, style.fontSize! * room / widest * 0.98)
        : style.fontSize!;
    return Padding(
      padding: const EdgeInsets.all(inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(fontSize: fontSize),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a [SleeveDesign]: the ground, the second ink, then a black film
/// grain (the stage's texture; only the Gold Records foil keeps a halftone).
class SleevePainter extends CustomPainter {
  const SleevePainter(this.design);
  final SleeveDesign design;

  static const _inkStrength = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = size.shortestSide;
    final d = design;
    final t = d.turn;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(d.ground, BlendMode.src);
    // The second ink prints thin over the ground, so the two inks sit close
    // and the title, not the shape, carries the sleeve. A mix of two deep
    // shades is never lighter than the lighter of them, so white type keeps
    // 4.6:1.
    final inkColor = d.ink.withValues(alpha: _inkStrength);
    final ink = Paint()
      ..color = inkColor
      ..isAntiAlias = true;
    switch (d.layout) {
      case SleeveLayout.split:
        // A cut from the left edge to the right edge, tilted either way.
        final yl = s * (0.30 + 0.35 * t);
        final yr = s * (0.65 - 0.35 * t);
        canvas.drawPath(
          Path()
            ..moveTo(0, yl)
            ..lineTo(size.width, yr)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close(),
          ink,
        );
      case SleeveLayout.disc:
        canvas.drawCircle(
          Offset(s * (0.25 + 0.6 * t), s * 0.08),
          s * (0.42 + 0.12 * t),
          ink,
        );
      case SleeveLayout.bands:
        canvas.save();
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate((t - 0.5) * 0.6);
        canvas.translate(-size.width / 2, -size.height / 2);
        var y = s * 0.06;
        for (final w in const [0.06, 0.10, 0.16]) {
          canvas.drawRect(Rect.fromLTWH(-s * 0.5, y, s * 2, s * w), ink);
          y += s * (w + 0.07);
        }
        canvas.restore();
      case SleeveLayout.rings:
        final c = Offset(t < 0.5 ? 0 : size.width, 0);
        final ring = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..isAntiAlias = true;
        for (var r = 0.3; r < 0.95; r += 0.24) {
          canvas.drawCircle(c, s * r, ring);
        }
    }
    _grain(canvas, size);
    canvas.restore();
  }

  /// The black film grain over the print, shifted by [SleeveDesign
  /// .screenCorner] so two sleeves side by side don't share one grain.
  void _grain(Canvas canvas, Size size) {
    final shift = design.screenCorner * 32.0;
    canvas.save();
    canvas.translate(-shift, -shift);
    const GrainPainter(
      color: Colors.black,
      opacity: 0.22,
    ).paint(canvas, Size(size.width + shift, size.height + shift));
    canvas.restore();
  }

  @override
  bool shouldRepaint(SleevePainter old) => old.design != design;
}
