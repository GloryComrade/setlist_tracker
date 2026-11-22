import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/gps/live_recorder.dart';
import '../../logic/gps_math.dart';
import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../models/enums.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'route_poster.dart';

/// On Stage: recording a Live Show with GPS (iPhone only).
///
/// The clock, miles and paces are read off [liveRecorderProvider], which
/// keeps recording when this screen closes or the phone locks.
class OnStageScreen extends ConsumerWidget {
  const OnStageScreen({super.key});

  Future<void> _end(
    BuildContext context,
    WidgetRef ref, {
    bool ask = true,
  }) async {
    if (ask) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End the Show?'),
          content: const Text(
            'The GPS stops and you book it next. Tip: hold End Show to skip '
            'this question.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep running'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('End Show'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(liveRecorderProvider.notifier).end();
    if (context.mounted) context.pushReplacement('/show/new?live=1');
  }

  Future<void> _throwAway(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Throw this run away?'),
        content: const Text(
          'The route and the numbers are gone for good. Nothing goes on the '
          'Setlist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Throw it away'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(liveRecorderProvider.notifier).clear();
    if (context.mounted) leaveScreen(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(liveRecorderProvider);
    final rec = st.recording;
    final now = st.now ?? DateTime.now();
    final available = ref.watch(locationSourceProvider).available;

    final moving = rec?.movingSecondsAt(now).round() ?? 0;
    final miles = rec?.distanceMiles ?? 0;
    final current = rec?.currentPaceAt(now);
    final average = rec?.averagePaceAt(now);
    final splits = rec?.splits ?? const <int>[];

    return Scaffold(
      appBar: AppBar(
        leading: backButtonFor(context),
        title: const Text('ON STAGE'),
      ),
      body: !available
          ? const EmptyStage(
              icon: Icons.phone_iphone,
              title: 'iPhone only',
              message:
                  'Going Live needs the iPhone app, which keeps the GPS '
                  'running with your screen locked. Here, Book a Show '
                  'after your run.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MaxWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Poster(
                        phase: st.phase,
                        moving: moving,
                        miles: miles,
                        currentPace: current,
                      ),
                      const SizedBox(height: 10),
                      _Signal(phase: st.phase, accuracyM: st.lastAccuracyM),
                      const SizedBox(height: 12),
                      RouteView(
                        segments: _segments(rec),
                        live: st.live,
                        semanticLabel: 'Your route so far',
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'The Numbers',
                        child: Wrap(
                          spacing: 28,
                          runSpacing: 16,
                          children: [
                            StatTile(
                              label: 'Average pace',
                              value: formatPace(average),
                            ),
                            StatTile(
                              label: 'Elevation gain',
                              value:
                                  '${(rec?.elevationGainFt ?? 0).round()} ft',
                            ),
                          ],
                        ),
                      ),
                      if (splits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: MileSplits(
                              splits: splits,
                              latestFirst: true,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: !available
          ? null
          : _Controls(
              phase: st.phase,
              onStart: () => ref.read(liveRecorderProvider.notifier).start(),
              onPause: () => ref.read(liveRecorderProvider.notifier).pause(),
              onResume: () => ref.read(liveRecorderProvider.notifier).resume(),
              onEnd: () => _end(context, ref),
              onEndNow: () => _end(context, ref, ask: false),
              onBook: () => context.pushReplacement('/show/new?live=1'),
              onThrowAway: () => _throwAway(context, ref),
              onSettings: () => ref.read(locationSourceProvider).openSettings(),
              onRetry: () => ref.read(liveRecorderProvider.notifier).reset(),
            ),
    );
  }

  List<List<(double, double)>> _segments(LiveRecording? rec) {
    if (rec == null || rec.points.isEmpty) return const [];
    final out = <List<(double, double)>>[];
    var seg = -1;
    for (final p in rec.points) {
      if (p.segment != seg) {
        out.add([]);
        seg = p.segment;
      }
      out.last.add((p.fix.lat, p.fix.lng));
    }
    return out;
  }
}

/// The Live gradient poster with the clock and the two numbers that matter
/// mid-run: miles and pace right now (and the same pace in mph).
class _Poster extends StatelessWidget {
  const _Poster({
    required this.phase,
    required this.moving,
    required this.miles,
    required this.currentPace,
  });

  final RecorderPhase phase;
  final int moving;
  final double miles;
  final double? currentPace;

  String get _status => switch (phase) {
    RecorderPhase.recording => 'Live now',
    RecorderPhase.paused => 'Paused',
    RecorderPhase.ended => 'Show over',
    _ => 'Doors open',
  };

  @override
  Widget build(BuildContext context) {
    final display = Theme.of(context).textTheme.displayLarge;
    final mph = currentPace == null ? null : mphFromPace(currentPace!);
    return PosterSurface(
      gradient: gradientFor(Venue.live),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VenueBadge(Venue.live, onPoster: true),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Time: ${spokenDuration(moving)}',
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatDuration(moving),
                  style: display?.copyWith(
                    color: Colors.white,
                    fontSize: 88,
                    fontFeatures: StageFonts.tabular,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _PosterStat(
                label: 'Miles',
                value: miles.toStringAsFixed(2),
                spoken: spokenMiles(double.parse(miles.toStringAsFixed(2))),
              ),
              _PosterStat(
                label: 'Pace now',
                value: formatPace(currentPace),
                spoken: spokenPace(currentPace),
              ),
              _PosterStat(
                label: 'mph',
                value: mph == null ? '–' : mph.toStringAsFixed(1),
                spoken: mph == null
                    ? 'not yet'
                    : '${mph.toStringAsFixed(1)} miles per hour',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PosterStat extends StatelessWidget {
  const _PosterStat({
    required this.label,
    required this.value,
    required this.spoken,
  });
  final String label;
  final String value;
  final String spoken;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label: $spoken',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontFeatures: StageFonts.tabular,
            ),
          ),
        ],
      ),
    ),
  );
}

/// One quiet line on how good the GPS is.
class _Signal extends StatelessWidget {
  const _Signal({required this.phase, required this.accuracyM});
  final RecorderPhase phase;
  final double? accuracyM;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color color) = switch (phase) {
      RecorderPhase.ready || RecorderPhase.loading => (
        Icons.lock_outline,
        'Keeps recording with your screen locked.',
        StageColors.textMuted,
      ),
      RecorderPhase.starting => (
        Icons.gps_not_fixed,
        'Asking for your location…',
        StageColors.textMuted,
      ),
      RecorderPhase.denied => (
        Icons.location_disabled,
        'Location is off for Setlist Tracker. Turn it on in Settings to go '
            'Live.',
        StageColors.amber,
      ),
      RecorderPhase.servicesOff => (
        Icons.location_disabled,
        'Location Services are off on this iPhone. Turn them on in '
            'Settings, Privacy & Security.',
        StageColors.amber,
      ),
      RecorderPhase.paused => (
        Icons.pause_circle_outline,
        'Paused. The clock and the GPS are stopped.',
        StageColors.textMuted,
      ),
      RecorderPhase.ended => (
        Icons.flag_outlined,
        'Show over. Book it to put it on the Setlist.',
        StageColors.textMuted,
      ),
      RecorderPhase.recording => switch (accuracyM) {
        null => (
          Icons.gps_not_fixed,
          'Finding GPS… Open sky helps.',
          StageColors.amber,
        ),
        final a when a <= 15 => (
          Icons.gps_fixed,
          'GPS locked, within ${(a * feetPerMeter).round()} ft.',
          StageColors.textMuted,
        ),
        final a when a <= maxFixAccuracyM => (
          Icons.gps_fixed,
          'GPS fair, within ${(a * feetPerMeter).round()} ft.',
          StageColors.textMuted,
        ),
        _ => (
          Icons.gps_not_fixed,
          'GPS weak. Miles wait for a better fix.',
          StageColors.amber,
        ),
      },
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

/// The buttons, pinned to the bottom where a thumb finds them.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
    required this.onEndNow,
    required this.onBook,
    required this.onThrowAway,
    required this.onSettings,
    required this.onRetry,
  });

  final RecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;
  final VoidCallback onEndNow;
  final VoidCallback onBook;
  final VoidCallback onThrowAway;
  final VoidCallback onSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const tall = Size.fromHeight(56);
    Widget endButton() => FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: tall),
      onPressed: onEnd,
      onLongPress: onEndNow,
      icon: const Icon(Icons.stop),
      label: const Text('End Show'),
    );
    final Widget child = switch (phase) {
      RecorderPhase.loading || RecorderPhase.starting => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      ),
      RecorderPhase.ready => SizedBox(
        width: double.infinity,
        child: GradientButton(
          label: 'Go Live',
          icon: Icons.mic,
          onPressed: onStart,
        ),
      ),
      RecorderPhase.denied || RecorderPhase.servicesOff => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: tall),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: tall),
              onPressed: onSettings,
              child: const Text('Open Settings'),
            ),
          ),
        ],
      ),
      RecorderPhase.recording => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: tall),
              onPressed: onPause,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: endButton()),
        ],
      ),
      RecorderPhase.paused => Row(
        children: [
          Expanded(
            child: GradientButton(
              label: 'Resume',
              icon: Icons.play_arrow,
              onPressed: onResume,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: endButton()),
        ],
      ),
      RecorderPhase.ended => Row(
        children: [
          TextButton(onPressed: onThrowAway, child: const Text('Throw away')),
          const SizedBox(width: 12),
          Expanded(
            child: GradientButton(
              label: 'Book this Show',
              icon: Icons.confirmation_number_outlined,
              onPressed: onBook,
            ),
          ),
        ],
      ),
    };
    return Material(
      color: StageColors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          // heightFactor 1: as tall as the buttons, not the screen.
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
