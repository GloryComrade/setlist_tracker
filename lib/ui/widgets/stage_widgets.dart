import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';

import '../../logic/spoken.dart';
import '../../models/enums.dart';
import '../../theme/app_theme.dart';
import '../../theme/stage_art.dart';

final _dayFormat = DateFormat('EEE, MMM d');
final _fullFormat = DateFormat('EEE, MMM d, y · h:mm a');

String formatShowDay(DateTime d) => _dayFormat.format(d);
String formatShowDateTime(DateTime d) => _fullFormat.format(d);

/// The venue's one mark color: Live Show magenta, Studio Session cyan. Used
/// only as a mark (an edge, an outline, a dot or a label), never to fill a
/// large area.
Color markFor(Venue venue) =>
    venue == Venue.studio ? StageColors.studioMark : StageColors.liveMark;

IconData iconFor(Venue venue) =>
    venue == Venue.studio ? Icons.graphic_eq : Icons.landscape;

IconData iconForConditions(Conditions c) => switch (c) {
  Conditions.clear => Icons.wb_sunny_outlined,
  Conditions.cloudy => Icons.cloud_outlined,
  Conditions.rain => Icons.umbrella_outlined,
  Conditions.snow => Icons.ac_unit,
  Conditions.fog => Icons.dehaze,
  Conditions.windy => Icons.air,
};

/// Small pill that says "STUDIO SESSION" or "LIVE SHOW": an outline in the
/// venue mark with the icon and label in the same mark. Reads the same on the
/// stage, on a card and on a poster.
class VenueBadge extends StatelessWidget {
  const VenueBadge(this.venue, {super.key});
  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final mark = markFor(venue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: mark, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(venue), size: 14, color: mark),
          const SizedBox(width: 4),
          Text(
            venue.label.toUpperCase(),
            style: TextStyle(
              color: mark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// The texture printed over a [PosterSurface].
enum PosterTexture {
  /// Film grain, the stage's own texture.
  grain,

  /// Printed halftone dots: the Gold Records foil only.
  halftone,
}

/// A flat poster block: Stage Surface with a 1px Stage Outline and a film
/// grain, white type on top. Posters never fill with color.
///
/// A Show poster sets [mark] to its venue mark (`markFor(venue)`), drawn as
/// a 5pt edge down the left side, and can add its [venuePrint] from
/// [StageArt], printed in the same mark at about 20% beside the type, never
/// under it: see [PrintBeside].
///
/// [PosterSurface.foil] is the Gold Records foil: flat Gold Mid with Gold
/// Deep halftone dots, the one halftone left in the app.
class PosterSurface extends StatelessWidget {
  const PosterSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.mark,
    this.venuePrint,
  }) : fill = StageColors.surface,
       outline = StageColors.outline,
       texture = PosterTexture.grain;

  /// The Gold Records foil: Gold Mid, no outline, Gold Deep dots. Type on
  /// it is Gold Ink.
  const PosterSurface.foil({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
  }) : fill = StageColors.goldMid,
       outline = null,
       texture = PosterTexture.halftone,
       mark = null,
       venuePrint = null;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// The flat fill: Stage Surface, or Gold Mid on the foil.
  final Color fill;

  /// The 1px border, or null for none.
  final Color? outline;

  final PosterTexture texture;

  /// A venue mark for the left edge, Show posters only.
  final Color? mark;

  /// A venue print (`StageArt.printFor(venue)`), Show posters only. It is
  /// printed in [mark] (Live magenta when there is none).
  final ImageProvider? venuePrint;

  /// How wide the venue mark runs down the left edge.
  static const markWidth = 5.0;

  /// The print's ink: the mark at 60% over the print's own 16–40% screen, so
  /// 10–24% on the poster.
  static const printStrength = 0.6;

  @override
  Widget build(BuildContext context) {
    // Full width whatever the child is, so the texture, which is laid out
    // by the poster's size, always covers the whole poster.
    final body = SizedBox(
      width: double.infinity,
      child: CustomPaint(
        painter: texture == PosterTexture.halftone
            ? const HalftonePainter(ink: StageColors.goldDeep)
            : const GrainPainter(),
        foregroundPainter: mark == null ? null : EdgeMarkPainter(mark!),
        child: Padding(padding: padding, child: child),
      ),
    );
    final shape = BorderRadius.circular(radius);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: fill, borderRadius: shape),
      foregroundDecoration: outline == null
          ? null
          : BoxDecoration(
              border: Border.all(color: outline!),
              borderRadius: shape,
            ),
      child: venuePrint == null
          ? body
          : PrintBeside(
              aspect: StageArt.printAspect,
              print: _PosterPrint(
                image: venuePrint!,
                ink: (mark ?? StageColors.liveMark).withValues(
                  alpha: printStrength,
                ),
              ),
              body: body,
            ),
    );
  }
}

/// A venue mark as a solid edge down the left side of its box. The box's
/// own rounded clip shapes its ends.
class EdgeMarkPainter extends CustomPainter {
  const EdgeMarkPainter(this.color, {this.width = PosterSurface.markWidth});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(EdgeMarkPainter old) =>
      old.color != color || old.width != width;
}

/// A ticket stub or calendar tile: Stage Surface High with the venue mark as
/// a [PosterSurface.markWidth] edge on its left.
class VenueStub extends StatelessWidget {
  const VenueStub({
    super.key,
    required this.venue,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.markWidth = PosterSurface.markWidth,
  });

  final Venue venue;
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double markWidth;

  @override
  Widget build(BuildContext context) {
    Widget stub = CustomPaint(
      foregroundPainter: EdgeMarkPainter(markFor(venue), width: markWidth),
      child: Container(
        width: width,
        height: height,
        color: StageColors.surfaceHigh,
        padding: padding,
        alignment: width != null && height != null ? Alignment.center : null,
        child: child,
      ),
    );
    if (borderRadius != null) {
      stub = ClipRRect(borderRadius: borderRadius!, child: stub);
    }
    return stub;
  }
}

/// Film grain: fine specks of [color] at [opacity] scattered over the box.
///
/// The specks come from one fixed 128pt tile built once from a fixed seed,
/// repeated across the box, so the grain is the same on every frame and
/// every run and never shimmers. Put it under a [RepaintBoundary] when the
/// content over it scrolls, so it is painted once.
class GrainPainter extends CustomPainter {
  const GrainPainter({
    this.color = Colors.white,
    this.opacity = StageColors.grainOpacity,
  });

  final Color color;
  final double opacity;

  static const tile = 128.0;

  /// Two speck sets: fine ones at [opacity] and fewer, brighter ones at
  /// 1.6×, which is what makes it read as grain rather than a screen.
  static final List<Float32List> _specks = _makeSpecks();

  static List<Float32List> _makeSpecks() {
    // A fixed linear congruential generator: the same tile everywhere.
    var seed = 0x2545F491;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    Float32List set(int n) {
      final list = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        list[i * 2] = next() * tile;
        list[i * 2 + 1] = next() * tile;
      }
      return list;
    }

    return [set(1600), set(380)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fine = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    final bright = Paint()
      ..color = color.withValues(alpha: math.min(1, opacity * 1.6))
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.square;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawRawPoints(PointMode.points, _specks[0], fine);
        canvas.drawRawPoints(PointMode.points, _specks[1], bright);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GrainPainter old) =>
      old.color != color || old.opacity != opacity;
}

/// Lays out [body] at full width, then sets [print] beside its type: as
/// tall as the poster, [aspect] wide for its height, against the right edge,
/// or starting [gap] past the widest line of type and running off the edge
/// when the type is wide. If less than [minShowing] of the print would show
/// (long lines, large text sizes), the print is left out, so it is never
/// under the type at any text size.
///
/// "Type" is every line of text in [body], icons included. A pill around
/// type (a Venue Badge) pads it by less than [gap], so it stays clear too.
class PrintBeside extends MultiChildRenderObjectWidget {
  PrintBeside({
    super.key,
    required Widget print,
    required Widget body,
    required this.aspect,
    this.gap = 20,
    this.minShowing = 0.6,
  }) : super(
         children: [
           IgnorePointer(child: print),
           body,
         ],
       );

  final double aspect;
  final double gap;
  final double minShowing;

  @override
  RenderPrintBeside createRenderObject(BuildContext context) =>
      RenderPrintBeside(aspect: aspect, gap: gap, minShowing: minShowing);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPrintBeside renderObject,
  ) => renderObject
    ..aspect = aspect
    ..gap = gap
    ..minShowing = minShowing;
}

class RenderPrintBeside extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  RenderPrintBeside({
    required this._aspect,
    required this._gap,
    required this._minShowing,
  });

  double _aspect;
  set aspect(double v) {
    if (v == _aspect) return;
    _aspect = v;
    markNeedsLayout();
  }

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  double _minShowing;
  set minShowing(double v) {
    if (v == _minShowing) return;
    _minShowing = v;
    markNeedsLayout();
  }

  /// Where the print was set in the last layout, or null if it was left
  /// out. In this box's coordinates.
  Rect? get printRect => _printRect;
  Rect? _printRect;

  RenderBox get _print => firstChild!;
  RenderBox get _body => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PrintParentData) {
      child.parentData = _PrintParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _body.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicWidth(double height) =>
      _body.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) =>
      _body.getMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) =>
      _body.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _body.getDryLayout(constraints);

  @override
  void performLayout() {
    _body.layout(constraints, parentUsesSize: true);
    (_body.parentData! as ContainerBoxParentData<RenderBox>).offset =
        Offset.zero;
    size = constraints.constrain(_body.size);

    final typeRight = _rightmostType(_body);
    final width = size.height * _aspect;
    final left = math.max(typeRight + _gap, size.width - width);
    final showing = size.width - left;
    final pd = _print.parentData! as ContainerBoxParentData<RenderBox>;
    if (width <= 0 || showing < width * _minShowing) {
      _print.layout(BoxConstraints.tight(Size.zero));
      pd.offset = Offset.zero;
      _printRect = null;
    } else {
      _print.layout(BoxConstraints.tight(Size(width, size.height)));
      pd.offset = Offset(left, 0);
      _printRect = Rect.fromLTWH(left, 0, showing, size.height);
    }
  }

  /// The right edge of the widest line of type in [root], in [root]'s
  /// coordinates. Reads only text layout and offsets, which a parent may
  /// read during its own layout, never a descendant's size.
  double _rightmostType(RenderBox root) {
    var right = 0.0;
    void visit(RenderObject node) {
      if (node is RenderParagraph && node.hasSize) {
        final length = node.text.toPlainText().length;
        final boxes = node.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: length),
        );
        final toRoot = node.getTransformTo(root);
        for (final b in boxes) {
          right = math.max(
            right,
            MatrixUtils.transformRect(toRoot, b.toRect()).right,
          );
        }
      }
      node.visitChildren(visit);
    }

    root.visitChildren(visit);
    return right;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_printRect != null) {
      context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        (context, offset) => context.paintChild(
          _print,
          offset +
              (_print.parentData! as ContainerBoxParentData<RenderBox>).offset,
        ),
      );
    }
    context.paintChild(_body, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: Offset.zero,
        position: position,
        hitTest: (result, p) => _body.hitTest(result, position: p),
      );
}

class _PrintParentData extends ContainerBoxParentData<RenderBox> {}

/// The venue print, filling the box [PrintBeside] gives it (the box has the
/// print's own aspect), printed in [ink]: the print's own alpha is the
/// screen, [ink] the color. Faded in if it was not decoded in time (the app
/// precaches both, so this is rare).
class _PosterPrint extends StatelessWidget {
  const _PosterPrint({required this.image, required this.ink});
  final ImageProvider image;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Image(
      image: image,
      fit: BoxFit.fill,
      color: ink,
      colorBlendMode: BlendMode.srcIn,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: child,
            ),
    );
  }
}

/// Halftone dots on a 45° screen, growing from nothing on the left to about
/// a third of the cell at the bottom-right. The Gold Records foil only
/// ([PosterSurface.foil]); everywhere else the texture is [GrainPainter].
class HalftonePainter extends CustomPainter {
  const HalftonePainter({this.ink = Colors.black, this.opacity = 0.2});

  final Color ink;
  final double opacity;

  static const _cell = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = ink.withValues(alpha: opacity)
      ..isAntiAlias = true;
    const maxR = _cell * 0.36;
    var row = 0;
    for (var y = _cell / 2; y < size.height + _cell; y += _cell * 0.866) {
      final offset = row.isOdd ? _cell / 2 : 0.0;
      for (var x = offset; x < size.width + _cell; x += _cell) {
        // 0 at 40% across, 1 at the right edge; deeper toward the bottom.
        final across = ((x / size.width) - 0.4) / 0.6;
        if (across <= 0) continue;
        final down = 0.45 + 0.55 * (y / size.height).clamp(0.0, 1.0);
        final r = maxR * math.min(1.0, across) * down;
        if (r < 0.35) continue;
        canvas.drawCircle(Offset(x, y), r, paint);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(HalftonePainter old) =>
      old.ink != ink || old.opacity != opacity;
}

/// The flat poster at the top of screens: a [PosterSurface] with the title
/// in Display.
class PosterHeader extends StatelessWidget {
  const PosterHeader({
    super.key,
    required this.title,
    this.children = const [],
    this.semanticsTitle,
    this.venuePrint,
    this.mark,
    this.titleColor = Colors.white,
  });

  final String title;

  /// See [PosterSurface.venuePrint].
  final ImageProvider? venuePrint;

  /// See [PosterSurface.mark].
  final Color? mark;

  /// White, or amber for a hero figure (the miles on a Show poster).
  final Color titleColor;

  /// What a screen reader says for [title] when it differs, e.g. "15 miles"
  /// for "15 mi".
  final String? semanticsTitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PosterSurface(
      mark: mark,
      venuePrint: venuePrint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterTitleRow(
            title: WholeWordsText(
              title,
              semanticsLabel: semanticsTitle,
              style: theme.textTheme.displayMedium?.copyWith(color: titleColor),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// What every tab's poster shows at its top-right corner (the Settings
/// button), set once by the tab shell. Posters outside the tabs, and
/// screens tested on their own, have none.
class PosterCornerAction extends InheritedWidget {
  const PosterCornerAction({
    super.key,
    required this.action,
    required super.child,
  });

  final Widget action;

  static Widget? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PosterCornerAction>()?.action;

  @override
  bool updateShouldNotify(PosterCornerAction old) => old.action != action;
}

/// A poster's title with the [PosterCornerAction] (if any) at its right,
/// top-aligned. [trailing] goes before it.
class PosterTitleRow extends StatelessWidget {
  const PosterTitleRow({super.key, required this.title, this.trailing});

  final Widget title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final corner = PosterCornerAction.maybeOf(context);
    if (corner == null && trailing == null) return title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        ?trailing,
        ?corner,
      ],
    );
  }
}

/// House lights down for the main tabs: a fine film grain over the stage,
/// painted once behind the tab's content (the tab screens leave their own
/// background transparent).
class StageGrain extends StatelessWidget {
  const StageGrain({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: GrainPainter())),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// A Card outline cut like a ticket: two punched notches where the stub meets
/// the ticket, and a perforated tear line between them.
class TicketBorder extends ShapeBorder {
  const TicketBorder({
    this.stubWidth = 64,
    this.notchRadius = 7,
    this.radius = 16,
    this.side = const BorderSide(color: StageColors.outline),
  });

  final double stubWidth;
  final double notchRadius;
  final double radius;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _ticket(Rect rect) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final x = rect.left + stubWidth;
    final notches = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(x, rect.top), radius: notchRadius),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(x, rect.bottom), radius: notchRadius),
      );
    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _ticket(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _ticket(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Perforations: dark holes punched down the tear line.
    final x = rect.left + stubWidth;
    final holes = Paint()..color = StageColors.background;
    const hole = 1.6;
    const step = 7.0;
    final top = rect.top + notchRadius + 5;
    final bottom = rect.bottom - notchRadius - 5;
    for (var y = top; y <= bottom; y += step) {
      canvas.drawCircle(Offset(x, y), hole, holes);
    }
    if (side.style != BorderStyle.none) {
      canvas.drawPath(_ticket(rect.deflate(side.width / 2)), side.toPaint());
    }
  }

  @override
  ShapeBorder scale(double t) => TicketBorder(
    stubWidth: stubWidth * t,
    notchRadius: notchRadius * t,
    radius: radius * t,
    side: side.scale(t),
  );
}

/// The one empty state: an icon, a poster headline, one sentence that says
/// what to do in tour words, and at most one action.
class EmptyStage extends StatelessWidget {
  const EmptyStage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: StageColors.textMuted),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              message,
              style: const TextStyle(color: StageColors.textMuted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            StageButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// How a Show felt, as a face on one flat stage color: cool teal for a rough
/// night, warming to the amber Encore. Drawn from Material icons so it looks
/// the same on web and iPhone (emoji don't). The face keeps 4.6:1 or better
/// on its fill.
class FeelFace extends StatelessWidget {
  const FeelFace(this.feel, {super.key, this.size = 22, this.dim = false});
  final Feel feel;
  final double size;

  /// Unpicked choices in the feel picker sit back at half strength.
  final bool dim;

  /// One flat fill per feel, and the face's color on it.
  static const fills = {
    Feel.rough: StageColors.tealDeep,
    Feel.offKey: StageColors.violetDeep,
    Feel.fine: StageColors.feelFine,
    Feel.good: StageColors.magentaDeep,
    Feel.encore: StageColors.amber,
  };

  static Color faceOn(Feel feel) =>
      feel == Feel.encore ? StageColors.goldInk : Colors.white;

  static const _icons = {
    Feel.rough: Icons.sentiment_very_dissatisfied_rounded,
    Feel.offKey: Icons.sentiment_dissatisfied_rounded,
    Feel.fine: Icons.sentiment_neutral_rounded,
    Feel.good: Icons.sentiment_satisfied_rounded,
    Feel.encore: Icons.sentiment_very_satisfied_rounded,
  };

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.45 : 1,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fills[feel]),
      alignment: Alignment.center,
      child: Icon(
        _icons[feel],
        size: size * 0.74,
        color: faceOn(feel),
        semanticLabel: feel.label,
      ),
    ),
  );
}

/// A labelled number, e.g. "PACE / 8:42 /mi".
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.leading,
    this.spokenValue,
  });
  final String label;
  final String value;

  /// What a screen reader says for [value]. Defaults to [spokenStat], which
  /// turns "8:42 /mi" into "8 minutes 42 seconds per mile".
  final String? spokenValue;

  /// Drawn before the value, e.g. the [FeelFace] on the Show page.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: ${spokenValue ?? spokenStat(value)}',
      child: ExcludeSemantics(child: _tile(context)),
    );
  }

  Widget _tile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: StageColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontFeatures: StageFonts.tabular),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A titled card that groups part of a form or detail screen.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: WholeWordsText(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// The screen's one main action: a flat amber pill with Gold Ink type
/// (10.1:1). At most one per screen.
class StageButton extends StatelessWidget {
  const StageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        // Said in its own case; the caps are only for the eye.
        label: label,
        child: Material(
          color: StageColors.amber,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: StageColors.goldInk.withValues(alpha: 0.12),
            highlightColor: StageColors.goldInk.withValues(alpha: 0.08),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: StageColors.goldInk),
                      const SizedBox(width: 8),
                    ],
                    // Wraps rather than overflowing on a narrow phone.
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: StageColors.goldInk,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps content readable on wide browser windows.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 720});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}

/// Goes back, or to [fallback] when the screen was opened directly from a
/// link and there is nothing to go back to.
void leaveScreen(BuildContext context, {String fallback = '/setlist'}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// App bar back button that still works when a screen was opened from a link.
Widget? backButtonFor(BuildContext context, {String fallback = '/setlist'}) =>
    context.canPop()
    ? null
    : IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(fallback),
      );

/// How wide [text] lays out on one line in [context], with the screen's
/// text size (Dynamic Type) applied. [style] is merged onto the ambient
/// [DefaultTextStyle], the same way a [Text] would draw it.
double measureTextWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Big poster type that wraps only between words. At large text sizes a
/// word too long for one line (BACKSTAGE at 200%) is set a little smaller
/// instead of being broken in the middle.
class WholeWordsText extends StatelessWidget {
  const WholeWordsText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.semanticsLabel,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// What a screen reader says instead of [text], as on [Text].
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        var fit = scaler;
        if (constraints.maxWidth.isFinite) {
          final widest = text
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .map((w) => measureTextWidth(context, w, style))
              .fold(0.0, math.max);
          if (widest > constraints.maxWidth) {
            final size =
                DefaultTextStyle.of(context).style.merge(style).fontSize ?? 14;
            final scaled =
                scaler.scale(size) * 0.99 * constraints.maxWidth / widest;
            // Never smaller than the type at 100%.
            fit = TextScaler.linear(math.max(scaled, size) / size);
          }
        }
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          textScaler: fit,
          semanticsLabel: semanticsLabel,
        );
      },
    );
  }
}
