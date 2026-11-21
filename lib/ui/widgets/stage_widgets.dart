import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
class VenueBadge extends StatelessWidget {
  const VenueBadge(this.venue, {super.key});
  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradientFor(venue),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
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
