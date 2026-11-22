import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../data/providers.dart';
import '../../logic/show_math.dart';
import '../../logic/tour_logging.dart';
import '../../models/enums.dart';
import '../../models/show.dart';
import '../../models/tour.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import '../widgets/track_editor.dart';
import 'tour_widgets.dart';

/// One run on the Tour Schedule: what to do, machine settings for Studio
/// Sessions, and one-tap logging.
class PlannedShowScreen extends ConsumerStatefulWidget {
  const PlannedShowScreen({super.key, required this.plannedShowId});
  final String plannedShowId;

  @override
  ConsumerState<PlannedShowScreen> createState() => _PlannedShowScreenState();
}

class _PlannedShowScreenState extends ConsumerState<PlannedShowScreen> {
  bool _saving = false;

  Future<void> _doneAsPlanned(PlannedShow p) async {
    setState(() => _saving = true);
    final show = showFromPlan(p, id: const Uuid().v4(), now: DateTime.now());
    try {
      await ref.read(showRepositoryProvider).save(show);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not log it: $e')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Show logged. Add how it felt and a song?'),
        action: SnackBarAction(
          label: 'Edit',
          textColor: StageColors.magenta,
          onPressed: () => context.push('/show/${show.id}/edit'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tourAsync = ref.watch(activeTourProvider);
    final done = ref.watch(tourProgressProvider);

    return tourAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (tour) {
        final p = tour?.showById(widget.plannedShowId);
        if (tour == null || p == null) {
          return Scaffold(
            appBar: AppBar(leading: backButtonFor(context, fallback: '/tour')),
            body: const Center(
              child: Text('That Show is not on the Tour Schedule.'),
            ),
          );
        }
        final week = tour.weekOf(p.id)!;
        final logged = done[p.id];
        return Scaffold(
          appBar: AppBar(
            leading: backButtonFor(context, fallback: '/tour'),
            title: Text('TOUR DATE · WEEK ${week.number}'),
          ),
          body: SafeArea(
            child: MaxWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _Hero(show: p, week: week, paces: tour.paces),
                  const SizedBox(height: 12),
                  if (p.detail != null)
                    SectionCard(
                      title: 'The set',
                      child: Text(
                        p.detail!,
                        style: const TextStyle(fontSize: 15, height: 1.45),
                      ),
                    ),
                  if (p.venue == Venue.studio) ...[
                    const SizedBox(height: 12),
                    _MachineSettings(show: p),
                  ],
                  const SizedBox(height: 20),
                  if (logged != null)
                    _LoggedNote(show: logged)
                  else
                    _Actions(
                      plan: p,
                      saving: _saving,
                      onDone: () => _doneAsPlanned(p),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.show, required this.week, required this.paces});
  final PlannedShow show;
  final TourWeek week;
  final TourPaces? paces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pace = show.targetPaceSecondsPerMile;
    final easyRange =
        paces != null &&
        (show.workoutType == WorkoutType.easy ||
            show.workoutType == WorkoutType.recovery ||
            show.workoutType == WorkoutType.long);
    return PosterSurface(
      gradient: show.isRace
          ? StageColors.headlineGradient
          : gradientFor(show.venue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VenueBadge(show.venue, onPoster: true),
              const SizedBox(width: 8),
              if (week.isRestStop)
                const TourTag('Rest Stop', color: Colors.white),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            show.title.toUpperCase(),
            style: theme.textTheme.displayLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatLongDate(show.date)} · ${week.phase.label}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _Stat('Miles', formatMiles(show.distanceMiles, withUnit: false)),
              if (easyRange)
                _Stat(
                  'Pace',
                  '${formatPace(paces!.easyFast, withUnit: false)}–'
                      '${formatPace(paces!.easySlow, withUnit: false)}',
                )
              else if (pace != null)
                _Stat('Pace', formatPace(pace, withUnit: false))
              else
                const _Stat('Pace', 'By feel'),
              if (show.plannedDurationSeconds != null)
                _Stat('About', formatDuration(show.plannedDurationSeconds!)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      Text(
        value,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: Colors.white, fontFeatures: StageFonts.tabular),
      ),
    ],
  );
}

/// The treadmill program, Track by Track, as you'd punch it in.
class _MachineSettings extends StatelessWidget {
  const _MachineSettings({required this.show});
  final PlannedShow show;

  @override
  Widget build(BuildContext context) {
    final tracks = show.tracks;
    if (tracks.isEmpty) {
      return const SectionCard(
        title: 'Machine settings',
        child: Text(
          'Set the belt to a speed that feels conversational, at 1% incline. '
          'Add a race or goal time to the Tour to get exact speeds.',
          style: TextStyle(color: StageColors.textMuted),
        ),
      );
    }
    const head = TextStyle(
      color: StageColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    );
    const cell = TextStyle(
      fontWeight: FontWeight.w600,
      fontFeatures: StageFonts.tabular,
    );
    return SectionCard(
      title: 'Machine settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text('#', style: head)),
                Expanded(flex: 5, child: Text('TIME', style: head)),
                Expanded(flex: 3, child: Text('MPH', style: head)),
                Expanded(flex: 3, child: Text('INCLINE', style: head)),
                Expanded(
                  flex: 3,
                  child: Text('PACE', style: head, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          for (var i = 0; i < tracks.length; i++)
            _TrackRow(number: i + 1, track: tracks[i], style: cell),
          const SizedBox(height: 12),
          TrackTotalsBar(totals: TrackTotals.of(tracks)),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.number,
    required this.track,
    required this.style,
  });

  final int number;
  final Track track;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final fast = track.speedMph >= 7.5;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: StageColors.outline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number',
              style: style.copyWith(color: StageColors.textMuted),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              '${formatDuration(track.startSeconds)}–'
              '${formatDuration(track.endSeconds)}',
              style: style,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              track.speedMph.toStringAsFixed(1),
              style: style.copyWith(
                color: fast ? StageColors.magenta : null,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${track.inclinePercent.toStringAsFixed(1)}%',
              style: style,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatPace(paceFromMph(track.speedMph), withUnit: false),
              style: style.copyWith(color: StageColors.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.plan,
    required this.saving,
    required this.onDone,
  });

  final PlannedShow plan;
  final bool saving;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final quick = canLogAsPlanned(plan);
    final differently = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      onPressed: saving
          ? null
          : () => context.push('/show/new?plan=${plan.id}'),
      icon: const Icon(Icons.edit_note),
      label: Text(quick ? 'Log it differently' : 'Log this Show'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quick) ...[
          GradientButton(
            label: saving ? 'Logging…' : 'Done as planned',
            icon: Icons.check,
            onPressed: saving ? null : onDone,
          ),
          const SizedBox(height: 8),
          const Text(
            'Logs this Show with the planned distance, time and settings. '
            'You can edit it after.',
            textAlign: TextAlign.center,
            style: TextStyle(color: StageColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
        ],
        differently,
      ],
    );
  }
}

class _LoggedNote extends StatelessWidget {
  const _LoggedNote({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final pace = show.paceSecondsPerMile;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/show/${show.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: StageColors.amber,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Played',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${formatMiles(show.distanceMiles)} · '
                      '${formatDuration(show.durationSeconds)} · '
                      '${formatPace(pace)}',
                      style: const TextStyle(
                        color: StageColors.textMuted,
                        fontFeatures: StageFonts.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'View Show',
                style: TextStyle(
                  color: StageColors.magenta,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right, color: StageColors.magenta),
            ],
          ),
        ),
      ),
    );
  }
}
