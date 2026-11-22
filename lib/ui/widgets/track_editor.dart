import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../models/enums.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';
import 'stage_widgets.dart';

/// Edits a list of treadmill Tracks and shows the running totals.
/// Used by the Studio Session form and the Saved Mix editor.
class TrackEditor extends StatelessWidget {
  const TrackEditor({super.key, required this.tracks, required this.onChanged});

  final List<Track> tracks;
  final ValueChanged<List<Track>> onChanged;

  Future<void> _add(BuildContext context) async {
    final last = tracks.isEmpty ? null : tracks.last;
    final start = last?.endSeconds ?? 0;
    final draft = Track(
      startSeconds: start,
      endSeconds: start + 5 * 60,
      speedMph: last?.speedMph ?? 6.0,
      inclinePercent: last?.inclinePercent ?? 1.0,
    );
    final result = await showTrackDialog(
      context,
      draft,
      number: tracks.length + 1,
    );
    if (result != null) onChanged([...tracks, result]);
  }

  Future<void> _edit(BuildContext context, int index) async {
    final result = await showTrackDialog(
      context,
      tracks[index],
      number: index + 1,
    );
    if (result == null) return;
    final next = [...tracks];
    next[index] = result;
    onChanged(next);
  }

  void _remove(int index) {
    final next = [...tracks]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final totals = TrackTotals.of(tracks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No Tracks yet. Add one for each speed or incline change.',
              style: TextStyle(color: StageColors.textMuted),
            ),
          ),
        for (var i = 0; i < tracks.length; i++)
          _TrackTile(
            number: i + 1,
            track: tracks[i],
            onTap: () => _edit(context, i),
            onDelete: () => _remove(i),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Track'),
          ),
        ),
        if (tracks.isNotEmpty) ...[
          const SizedBox(height: 12),
          TrackTotalsBar(totals: totals),
        ],
      ],
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.number,
    required this.track,
    required this.onTap,
    required this.onDelete,
  });

  final int number;
  final Track track;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final invalid = track.durationSeconds == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: StageColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          container: true,
          button: true,
          label: invalid
              ? 'Track $number. End time must be after start time'
              : 'Track $number, ${spokenDuration(track.startSeconds)} to '
                    '${spokenDuration(track.endSeconds)}. '
                    '${track.speedMph.toStringAsFixed(1)} miles per hour, '
                    '${spokenPace(paceFromMph(track.speedMph))}, '
                    '${track.inclinePercent.toStringAsFixed(1)} percent '
                    'incline, ${spokenMiles(track.distanceMiles)}',
          hint: 'Edit Track',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: StageColors.violetDeep,
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatDuration(track.startSeconds)} – '
                            '${formatDuration(track.endSeconds)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: StageFonts.tabular,
                            ),
                          ),
                          Text(
                            invalid
                                ? 'End time must be after start time'
                                : '${track.speedMph.toStringAsFixed(1)} mph '
                                      '(${formatPace(paceFromMph(track.speedMph))}) · '
                                      '${track.inclinePercent.toStringAsFixed(1)}% · '
                                      '${formatMiles(track.distanceMiles)}',
                            style: TextStyle(
                              color: invalid
                                  ? Theme.of(context).colorScheme.error
                                  : StageColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove Track',
                    onPressed: onDelete,
                    icon: const Icon(Icons.close),
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

/// "TIME 45:00 · MILES 4.5 · AVG INCLINE 1.5%"
class TrackTotalsBar extends StatelessWidget {
  const TrackTotalsBar({super.key, required this.totals});
  final TrackTotals totals;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: StageColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontFeatures: StageFonts.tabular,
            ),
          ),
        ],
      ),
    );
    // Flat Stage Surface High with the Studio mark down its edge.
    return VenueStub(
      venue: Venue.studio,
      markWidth: 4,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          item('TIME', formatDuration(totals.durationSeconds)),
          item('MILES', formatMiles(totals.distanceMiles, withUnit: false)),
          item(
            'AVG INCLINE',
            '${totals.averageInclinePercent.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

/// Dialog to add or edit one Track. Returns null when cancelled.
Future<Track?> showTrackDialog(
  BuildContext context,
  Track initial, {
  required int number,
}) {
  return showDialog<Track>(
    context: context,
    builder: (_) => _TrackDialog(initial: initial, number: number),
  );
}

class _TrackDialog extends StatefulWidget {
  const _TrackDialog({required this.initial, required this.number});
  final Track initial;
  final int number;

  @override
  State<_TrackDialog> createState() => _TrackDialogState();
}

class _TrackDialogState extends State<_TrackDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _start = TextEditingController(
    text: formatDuration(widget.initial.startSeconds),
  );
  late final _end = TextEditingController(
    text: formatDuration(widget.initial.endSeconds),
  );
  late final _speed = TextEditingController(
    text: widget.initial.speedMph.toStringAsFixed(1),
  );
  late final _incline = TextEditingController(
    text: widget.initial.inclinePercent.toStringAsFixed(1),
  );

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _speed.dispose();
    _incline.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Track(
        startSeconds: parseDuration(_start.text)!,
        endSeconds: parseDuration(_end.text)!,
        speedMph: double.parse(_speed.text),
        inclinePercent: double.parse(_incline.text),
      ),
    );
  }

  String? _timeValidator(String? v) =>
      parseDuration(v ?? '') == null ? 'Use mm:ss' : null;

  @override
  Widget build(BuildContext context) {
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final time = [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))];
    return AlertDialog(
      title: Text('Track ${widget.number}'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _start,
                      decoration: const InputDecoration(
                        labelText: 'Start',
                        helperText: 'mm:ss into the run',
                      ),
                      inputFormatters: time,
                      validator: _timeValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _end,
                      // Matching helper keeps Start and End level.
                      decoration: const InputDecoration(
                        labelText: 'End',
                        helperText: 'mm:ss',
                      ),
                      inputFormatters: time,
                      validator: (v) {
                        final end = parseDuration(v ?? '');
                        if (end == null) return 'Use mm:ss';
                        final start = parseDuration(_start.text);
                        if (start != null && end <= start) {
                          return 'After start';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _speed,
                      decoration: const InputDecoration(
                        labelText: 'Speed',
                        suffixText: 'mph',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: decimal,
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0 || n > 20) return '0.1–20';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _incline,
                      decoration: const InputDecoration(
                        labelText: 'Incline',
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: decimal,
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n > 40) return '0–40';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save Track')),
      ],
    );
  }
}
