import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';

import '../../models/enums.dart';
import '../../theme/app_theme.dart';

final _dayFormat = DateFormat('EEE, MMM d');
final _fullFormat = DateFormat('EEE, MMM d, y · h:mm a');

String formatShowDay(DateTime d) => _dayFormat.format(d);
String formatShowDateTime(DateTime d) => _fullFormat.format(d);

LinearGradient gradientFor(Venue venue) => venue == Venue.studio
    ? StageColors.studioGradient
    : StageColors.liveGradient;

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

/// Small pill that says "STUDIO SESSION" or "LIVE SHOW".
///
/// On a poster that is already lit in the venue's gradient, set [onPoster] so
/// the pill turns into a dark cut-out instead of vanishing into its own color.
class VenueBadge extends StatelessWidget {
  const VenueBadge(this.venue, {super.key, this.onPoster = false});
  final Venue venue;
  final bool onPoster;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: onPoster ? null : gradientFor(venue),
        color: onPoster ? Colors.black26 : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(venue), size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            venue.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
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

/// A gradient block printed like a screen-printed gig poster: the stage-light
/// gradient with a halftone dot screen that fades in toward the bottom-right
/// corner. The dots are dark ink, so white type on top only gains contrast.
class PosterSurface extends StatelessWidget {
  const PosterSurface({
    super.key,
    required this.gradient,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.ink = Colors.black,
  });

  final Gradient gradient;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// The halftone dot color, drawn at low opacity.
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: CustomPaint(
        painter: HalftonePainter(ink: ink),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Halftone dots on a 45° screen, growing from nothing on the left to about
/// a third of the cell at the bottom-right.
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

/// Big gradient banner used at the top of screens.
class PosterHeader extends StatelessWidget {
  const PosterHeader({
    super.key,
    required this.title,
    this.gradient = StageColors.headlineGradient,
    this.children = const [],
  });

  final String title;
  final Gradient gradient;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PosterSurface(
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.displayMedium?.copyWith(color: Colors.white),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// House lights for the main tabs: two soft stage lights spilling down from
/// above, magenta on one side and violet on the other. Sits behind the tab's
/// content; the tab screens leave their own background transparent.
class StageGlow extends StatelessWidget {
  const StageGlow({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 440,
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.85, -1.15),
                      radius: 1.1,
                      colors: [Color(0x38E0157A), Color(0x00E0157A)],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.9, -1.2),
                      radius: 1.0,
                      colors: [Color(0x406D28D9), Color(0x006D28D9)],
                    ),
                  ),
                ),
              ],
            ),
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
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            GradientButton(
              label: actionLabel!,
              icon: Icons.add,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled number, e.g. "PACE / 8:42 /mi".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontFeatures: StageFonts.tabular),
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
                  child: Text(
                    title,
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

/// Primary call-to-action with the stage-light gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: StageColors.headlineGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
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
