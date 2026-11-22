import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/health/health_import_prefs.dart';
import '../../data/health/health_source.dart';
import '../../data/providers.dart';
import '../../data/settings/app_settings.dart';
import '../../logic/health_import.dart';
import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';

const _settingsPath =
    'Settings > Health > Data Access & Devices > Setlist Tracker';

/// Backstage card that brings runs in from Apple Health. Only on iPhone: on
/// web (and anywhere Health doesn't exist) it renders nothing.
class AppleHealthCard extends ConsumerStatefulWidget {
  const AppleHealthCard({super.key});

  @override
  ConsumerState<AppleHealthCard> createState() => _AppleHealthCardState();
}

class _AppleHealthCardState extends ConsumerState<AppleHealthCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(healthSourceProvider).available ||
        !ref.watch(appSettingsProvider.select((s) => s.healthImport))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        title: 'Apple Health',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bring in runs from your Apple Watch or iPhone as Shows.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _import,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: StageColors.textMuted,
                      ),
                    )
                  : const Icon(Icons.favorite_border),
              label: Text(_busy ? 'Checking Apple Health…' : 'Import runs'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    final source = ref.read(healthSourceProvider);
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    DateTime? last;
    List<HealthRun>? runs;
    try {
      if (await source.requestAccess()) {
        last = await readLastHealthImport(db);
        final now = DateTime.now();
        final found = await source.fetchRuns(healthImportStart(last, now), now);
        final repo = ref.read(showRepositoryProvider);
        final shows = await repo.watchAll().first;
        runs = newHealthRuns(found, shows);
        // Runs imported before routes came along get their map now.
        for (final s in showsWithNewRoutes(found, shows, now: now)) {
          await repo.save(s);
        }
      }
    } on HealthAccessDenied {
      runs = null;
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn’t read Apple Health. Try again in a moment.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final added = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HealthImportSheet(runs: runs, lastImport: last),
    );
    if (added == null || added == 0) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$added ${added == 1 ? 'Show' : 'Shows'} added to the Setlist.',
        ),
      ),
    );
  }
}

/// The list of new runs, all checked, with one button to add them.
///
/// [runs] null means Health refused access. Pops with the number of Shows
/// added.
class HealthImportSheet extends ConsumerStatefulWidget {
  const HealthImportSheet({super.key, required this.runs, this.lastImport});

  final List<HealthRun>? runs;
  final DateTime? lastImport;

  @override
  ConsumerState<HealthImportSheet> createState() => _HealthImportSheetState();
}

class _HealthImportSheetState extends ConsumerState<HealthImportSheet> {
  late final Set<String> _picked = {
    for (final r in widget.runs ?? const <HealthRun>[]) r.uuid,
  };
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final runs = widget.runs;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        // Hugs its content, and stays readable on a wide window.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: runs == null
                ? const _Message(
                    icon: Icons.lock_outline,
                    title: 'Apple Health is closed',
                    message:
                        'Setlist Tracker can’t read your workouts. To let it, go '
                        'to $_settingsPath and turn on Workouts.',
                  )
                : runs.isEmpty
                ? _Message(
                    icon: Icons.favorite_border,
                    title: 'Nothing new',
                    message: widget.lastImport == null
                        ? 'No runs in Apple Health from the last '
                              '$healthFirstImportDays days.'
                        : 'No new runs in Apple Health since '
                              '${DateFormat('MMM d').format(widget.lastImport!)}.',
                    hint:
                        'Missing a run? Check that Workouts is on in '
                        '$_settingsPath.',
                  )
                : _list(context, runs),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<HealthRun> runs) {
    final n = _picked.length;
    final count = '${runs.length} ${runs.length == 1 ? 'run' : 'runs'}';
    final since = widget.lastImport == null
        ? 'from the last $healthFirstImportDays days'
        : 'since ${DateFormat('MMM d').format(widget.lastImport!)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEW FROM APPLE HEALTH',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '$count $since. Uncheck any you don’t want on the Setlist.',
                style: const TextStyle(color: StageColors.textMuted),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: runs.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 56, endIndent: 8),
            itemBuilder: (_, i) {
              final r = runs[i];
              return _RunRow(
                run: r,
                checked: _picked.contains(r.uuid),
                onChanged: (on) => setState(
                  () => on ? _picked.add(r.uuid) : _picked.remove(r.uuid),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: StageButton(
            label: n == 0
                ? 'Pick a run to add'
                : 'Add $n ${n == 1 ? 'Show' : 'Shows'}',
            icon: Icons.add,
            onPressed: n == 0 || _saving ? null : () => _add(runs),
          ),
        ),
      ],
    );
  }

  Future<void> _add(List<HealthRun> runs) async {
    setState(() => _saving = true);
    final repo = ref.read(showRepositoryProvider);
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    var added = 0;
    try {
      for (final r in runs) {
        if (!_picked.contains(r.uuid)) continue;
        await repo.save(showFromHealthRun(r, now: now));
        added++;
      }
      await saveLastHealthImport(db, now);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Couldn’t add the Shows. Try again.'
                : 'Added $added, then something went wrong. Try the rest again.',
          ),
        ),
      );
      return;
    }
    if (mounted) Navigator.pop(context, added);
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({
    required this.run,
    required this.checked,
    required this.onChanged,
  });

  final HealthRun run;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = venueForHealthRun(run);
    final when = [
      DateFormat('h:mm a').format(run.start),
      ?run.sourceName,
    ].join(' · ');
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false)),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatShowDay(run.start),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        VenueBadge(venue),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatMiles(run.distanceMiles),
                            semanticsLabel: spokenMiles(run.distanceMiles),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontFeatures: StageFonts.tabular,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatPace(
                              paceSecondsPerMileFor(
                                run.distanceMiles,
                                run.durationSeconds,
                              ),
                            ),
                            semanticsLabel: spokenPace(
                              paceSecondsPerMileFor(
                                run.distanceMiles,
                                run.durationSeconds,
                              ),
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: StageColors.amber,
                              fontFeatures: StageFonts.tabular,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatDuration(run.durationSeconds),
                            semanticsLabel: spokenDuration(run.durationSeconds),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: StageColors.textMuted,
                              fontFeatures: StageFonts.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      when,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: StageColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty and refused states, laid out like [EmptyStage] with an optional
/// small hint underneath.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyStage(icon: icon, title: title, message: message),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: StageColors.textMuted,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
