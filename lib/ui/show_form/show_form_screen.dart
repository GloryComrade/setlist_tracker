import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/providers.dart';
import '../../logic/show_math.dart';
import '../../logic/tour_logging.dart';
import '../../models/enums.dart';
import '../../models/gear.dart';
import '../../models/saved_mix.dart';
import '../../models/show.dart';
import '../../models/song.dart';
import '../../models/tour.dart';
import '../../models/track.dart';
import '../../models/venue_details.dart';
import '../../theme/app_theme.dart';
import '../backstage/gear_dialog.dart';
import '../song_picker/song_picker_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/clip_player.dart';
import '../widgets/stage_widgets.dart';
import '../widgets/track_editor.dart';

/// "Book a Show": logs a new Show or edits an existing one.
class ShowFormScreen extends ConsumerStatefulWidget {
  const ShowFormScreen({super.key, this.showId, this.plannedShowId});

  /// Null for a new Show.
  final String? showId;

  /// A new Show logged for this Planned Show on The Tour. The form starts
  /// filled in from the plan.
  final String? plannedShowId;

  @override
  ConsumerState<ShowFormScreen> createState() => _ShowFormScreenState();
}

class _ShowFormScreenState extends ConsumerState<ShowFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  Show? _existing;
  String? _plannedShowId;

  // The Basics
  Venue? _venue;
  DateTime _date = DateTime.now();
  WorkoutType _workout = WorkoutType.easy;

  // Studio Session
  final _gym = TextEditingController();
  final _treadmill = TextEditingController();
  List<Track> _tracks = [];
  bool _useTrackTotals = true;
  String? _savedMixId;

  // Live Show
  final _route = TextEditingController();
  Surface _surface = Surface.road;
  final _elevation = TextEditingController();
  final _temp = TextEditingController();
  final _wind = TextEditingController();
  Conditions? _conditions;

  // The Numbers
  final _distance = TextEditingController();
  final _duration = TextEditingController();

  // How It Felt
  int _effort = 5;
  Feel _feel = Feel.good;
  final _notes = TextEditingController();

  String? _gearId;

  // Song of the Show
  /// Picked from the song search (or typed in). The note is separate.
  SongOfTheShow? _pickedSong;
  final _songNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pace preview updates as you type.
    _distance.addListener(_refresh);
    _duration.addListener(_refresh);
    _load();
  }

  void _refresh() => setState(() {});

  Future<void> _load() async {
    final id = widget.showId;
    if (id != null) {
      final show = await ref.read(showRepositoryProvider).getById(id);
      if (show != null) _fill(show);
    } else if (widget.plannedShowId != null) {
      final tour = await ref.read(activeTourProvider.future);
      final plan = tour?.showById(widget.plannedShowId!);
      if (plan != null) _fillFromPlan(plan);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fill(Show s) {
    _existing = s;
    _venue = s.venue;
    _date = s.date;
    _workout = s.workoutType;
    _distance.text = formatMiles(s.distanceMiles, withUnit: false);
    _duration.text = formatDuration(s.durationSeconds);
    _effort = s.effort;
    _feel = s.feel;
    _notes.text = s.notes ?? '';
    _gearId = s.gearId;
    _pickedSong = s.song;
    _songNote.text = s.song?.note ?? '';
    final st = s.studio;
    if (st != null) {
      _gym.text = st.gymName ?? '';
      _treadmill.text = st.treadmillName ?? '';
      _tracks = [...st.tracks];
      _useTrackTotals = st.useTrackTotals;
      _savedMixId = st.savedMixId;
    }
    final lv = s.live;
    if (lv != null) {
      _route.text = lv.routeName ?? '';
      _surface = lv.surface;
      _elevation.text = _numText(lv.elevationGainFt);
      _temp.text = _numText(lv.weather?.tempF);
      _wind.text = _numText(lv.weather?.windMph);
      _conditions = lv.weather?.conditions;
    }
  }

  /// Starts a new Show from the Tour's plan, as if it went exactly to plan.
  void _fillFromPlan(PlannedShow p) {
    final planned = showFromPlan(p, id: '', now: DateTime.now());
    _plannedShowId = p.id;
    _venue = planned.venue;
    _date = planned.date;
    _workout = planned.workoutType;
    _distance.text = formatMiles(planned.distanceMiles, withUnit: false);
    if (planned.durationSeconds > 0) {
      _duration.text = formatDuration(planned.durationSeconds);
    }
    _effort = planned.effort;
    final st = planned.studio;
    if (st != null) {
      _tracks = [...st.tracks];
      _useTrackTotals = st.useTrackTotals;
    }
  }

  String _numText(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  @override
  void dispose() {
    for (final c in [
      _gym,
      _treadmill,
      _route,
      _elevation,
      _temp,
      _wind,
      _distance,
      _duration,
      _notes,
      _songNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// True when distance and duration come from the Tracks.
  bool get _autoTotals =>
      _venue == Venue.studio && _useTrackTotals && _tracks.isNotEmpty;

  double? get _distanceValue => _autoTotals
      ? TrackTotals.of(_tracks).distanceMiles
      : double.tryParse(_distance.text.trim());

  int? get _durationValue => _autoTotals
      ? TrackTotals.of(_tracks).durationSeconds
      : parseDuration(_duration.text);

  void _setTracks(List<Track> tracks) {
    setState(() {
      _tracks = tracks;
      if (!_useTrackTotals || tracks.isEmpty) return;
      final t = TrackTotals.of(tracks);
      _distance.text = formatMiles(t.distanceMiles, withUnit: false);
      _duration.text = formatDuration(t.durationSeconds);
    });
  }

  void _applyMix(SavedMix mix) {
    setState(() {
      _savedMixId = mix.id;
      if (mix.gymName != null) _gym.text = mix.gymName!;
      if (mix.treadmillName != null) _treadmill.text = mix.treadmillName!;
      _useTrackTotals = true;
    });
    _setTracks([...mix.tracks]);
  }

  Future<void> _saveAsMix() async {
    final name = await showNameDialog(
      context,
      title: 'Save as a Mix',
      label: 'Mix name',
      initial: _gym.text,
    );
    if (name == null || name.isEmpty) return;
    final now = DateTime.now();
    final mix = SavedMix(
      id: const Uuid().v4(),
      name: name,
      gymName: _blankToNull(_gym.text),
      treadmillName: _blankToNull(_treadmill.text),
      tracks: [..._tracks],
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(savedMixRepositoryProvider).save(mix);
    if (!mounted) return;
    setState(() => _savedMixId = mix.id);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Saved Mix "$name" is ready.')));
  }

  Future<void> _addGear() async {
    final gear = await showGearDialog(context);
    if (gear == null) return;
    await ref.read(gearRepositoryProvider).save(gear);
    if (mounted) setState(() => _gearId = gear.id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked == null) return;
    setState(
      () => _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  String? _blankToNull(String s) => s.trim().isEmpty ? null : s.trim();
  double? _num(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _save() async {
    final venue = _venue;
    if (venue == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (venue == Venue.studio && _tracks.any((t) => t.durationSeconds == 0)) {
      _snack('One of the Tracks ends before it starts. Fix it to save.');
      return;
    }
    final distance = _distanceValue;
    final duration = _durationValue;
    if (distance == null ||
        distance <= 0 ||
        duration == null ||
        duration <= 0) {
      _snack('Add a distance and a duration.');
      return;
    }
    setState(() => _saving = true);

    final now = DateTime.now();
    final picked = _pickedSong;
    final weather = Weather(
      tempF: _num(_temp),
      windMph: _num(_wind),
      conditions: _conditions,
    );

    final show = Show(
      id: _existing?.id ?? const Uuid().v4(),
      date: _date,
      venue: venue,
      workoutType: _workout,
      distanceMiles: distance,
      durationSeconds: duration,
      effort: _effort,
      feel: _feel,
      notes: _blankToNull(_notes.text),
      gearId: _gearId,
      song: picked == null
          ? null
          : SongOfTheShow(
              title: picked.title,
              artist: picked.artist,
              note: _blankToNull(_songNote.text),
              albumArtUrl: picked.albumArtUrl,
              spotifyUrl: picked.spotifyUrl,
              appleMusicUrl: picked.appleMusicUrl,
              previewUrl: picked.previewUrl,
              clipStartSeconds: picked.clipStartSeconds,
              clipLengthSeconds: picked.clipLengthSeconds,
            ),
      studio: venue == Venue.studio
          ? StudioDetails(
              gymName: _blankToNull(_gym.text),
              treadmillName: _blankToNull(_treadmill.text),
              savedMixId: _savedMixId,
              tracks: _tracks,
              useTrackTotals: _useTrackTotals,
            )
          : null,
      live: venue == Venue.live
          ? LiveDetails(
              routeName: _blankToNull(_route.text),
              surface: _surface,
              elevationGainFt: _num(_elevation),
              weather: weather.isEmpty ? null : weather,
              gpxFileId: _existing?.live?.gpxFileId,
            )
          : null,
      plannedShowId: _plannedShowId ?? _existing?.plannedShowId,
      healthWorkoutId: _existing?.healthWorkoutId,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final repo = ref.read(showRepositoryProvider);
      await repo.save(show);
      if (_existing == null) {
        // Read it back for the saved updatedAt, so it isn't shared twice.
        final saved = await repo.getById(show.id);
        if (saved != null) {
          unawaited(
            ref.read(crewControllerProvider.notifier).shareIfAlways(saved),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Could not save the Show: $e');
      }
      return;
    }
    if (!mounted) return;
    _snack(_existing == null ? 'Show booked.' : 'Show updated.');
    leaveScreen(context);
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.showId != null;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (isEdit && _existing == null) {
      return Scaffold(
        appBar: AppBar(leading: backButtonFor(context)),
        body: const Center(
          child: Text('That Show is no longer on the Setlist.'),
        ),
      );
    }
    final venue = _venue;
    return Scaffold(
      appBar: AppBar(
        leading: backButtonFor(context),
        title: Text(isEdit ? 'EDIT SHOW' : 'BOOK A SHOW'),
        actions: [
          if (venue != null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      body: venue == null
          ? _VenuePicker(onPicked: (v) => setState(() => _venue = v))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MaxWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _basics(venue, isEdit),
                        const SizedBox(height: 12),
                        if (venue == Venue.studio) _studio() else _live(),
                        const SizedBox(height: 12),
                        _numbers(),
                        const SizedBox(height: 12),
                        _felt(),
                        const SizedBox(height: 12),
                        _gear(),
                        const SizedBox(height: 12),
                        _song(),
                        const SizedBox(height: 24),
                        Center(
                          child: GradientButton(
                            label: isEdit ? 'Save changes' : 'Book it',
                            icon: Icons.mic,
                            onPressed: _saving ? null : _save,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _basics(Venue venue, bool isEdit) {
    return SectionCard(
      title: 'The Basics',
      trailing: isEdit
          ? VenueBadge(venue)
          : ActionChip(
              avatar: Icon(iconFor(venue), size: 16),
              label: Text(venue.label),
              onPressed: () => setState(() => _venue = null),
              tooltip: 'Change type',
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(formatShowDay(_date)),
              ),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(TimeOfDay.fromDateTime(_date).format(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _Label('Workout type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in WorkoutType.values)
                ChoiceChip(
                  label: Text(w.label),
                  selected: _workout == w,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _workout = w),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studio() {
    final mixes = ref.watch(savedMixesProvider).value ?? const <SavedMix>[];
    return SectionCard(
      title: 'Studio Session',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mixes.isNotEmpty) ...[
            const _Label('Start from a Saved Mix'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in mixes)
                  ActionChip(
                    avatar: Icon(
                      _savedMixId == m.id ? Icons.check_circle : Icons.album,
                      size: 18,
                      color: StageColors.cyan,
                    ),
                    label: Text(m.name),
                    onPressed: () => _applyMix(m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _gym,
                  decoration: const InputDecoration(labelText: 'Gym'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _treadmill,
                  decoration: const InputDecoration(labelText: 'Treadmill'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Tracks'),
          TrackEditor(tracks: _tracks, onChanged: _setTracks),
          if (_tracks.isNotEmpty) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useTrackTotals,
              onChanged: (v) {
                setState(() => _useTrackTotals = v);
                if (v) _setTracks(_tracks);
              },
              title: const Text('Use Track totals for distance and time'),
              subtitle: const Text(
                'Turn off to type what the treadmill screen said.',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saveAsMix,
                icon: const Icon(Icons.library_add),
                label: const Text('Save these Tracks as a Mix'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _live() {
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))];
    return SectionCard(
      title: 'Live Show',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _route,
            decoration: const InputDecoration(
              labelText: 'Route',
              hintText: 'e.g. River Loop',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          const _Label('Surface'),
          SegmentedButton<Surface>(
            segments: [
              for (final s in Surface.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {_surface},
            onSelectionChanged: (v) => setState(() => _surface = v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _elevation,
            decoration: const InputDecoration(
              labelText: 'Elevation gain',
              suffixText: 'ft',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimal,
          ),
          const SizedBox(height: 16),
          const _Label('Weather'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _temp,
                  decoration: const InputDecoration(
                    labelText: 'Temperature',
                    suffixText: '°F',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: decimal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _wind,
                  decoration: const InputDecoration(
                    labelText: 'Wind',
                    suffixText: 'mph',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: decimal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in Conditions.values)
                ChoiceChip(
                  avatar: Icon(iconForConditions(c), size: 18),
                  label: Text(c.label),
                  selected: _conditions == c,
                  showCheckmark: false,
                  onSelected: (sel) =>
                      setState(() => _conditions = sel ? c : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numbers() {
    final auto = _autoTotals;
    final pace = paceSecondsPerMileFor(
      _distanceValue ?? 0,
      _durationValue ?? 0,
    );
    return SectionCard(
      title: 'The Numbers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _distance,
                  enabled: !auto,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    suffixText: 'mi',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: (v) {
                    if (auto) return null;
                    final n = double.tryParse((v ?? '').trim());
                    return n == null || n <= 0 ? 'Miles, e.g. 6.2' : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _duration,
                  enabled: !auto,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    hintText: 'h:mm:ss or mm:ss',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  ],
                  validator: (v) {
                    if (auto) return null;
                    final n = parseDuration(v ?? '');
                    return n == null || n <= 0 ? 'e.g. 52:30' : null;
                  },
                ),
              ),
            ],
          ),
          if (auto)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Filled in from your Tracks.',
                style: TextStyle(color: StageColors.textMuted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          StatTile(label: 'Pace', value: formatPace(pace)),
        ],
      ),
    );
  }

  Widget _felt() {
    return SectionCard(
      title: 'How It Felt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _Label('Effort'),
              const Spacer(),
              Text(
                '$_effort / 10',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: StageColors.amber),
              ),
            ],
          ),
          Slider(
            value: _effort.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_effort',
            onChanged: (v) => setState(() => _effort = v.round()),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final f in Feel.values)
                Semantics(
                  button: true,
                  selected: _feel == f,
                  label: f.label,
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _feel = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _feel == f
                              ? StageColors.text
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: FeelFace(f, size: 44, dim: _feel != f),
                    ),
                  ),
                ),
            ],
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _feel.label,
                style: const TextStyle(color: StageColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _gear() {
    final all = ref.watch(gearListProvider).value ?? const <Gear>[];
    // Retired Gear stays visible only if this Show already uses it.
    final options = all.where((g) => !g.retired || g.id == _gearId).toList();
    final selected = options.any((g) => g.id == _gearId) ? _gearId : null;
    return SectionCard(
      title: 'Gear',
      trailing: TextButton.icon(
        onPressed: _addGear,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      child: options.isEmpty
          ? const Text(
              'No Gear yet. Add your shoes to track their miles.',
              style: TextStyle(color: StageColors.textMuted),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: selected == null,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _gearId = null),
                ),
                for (final g in options)
                  ChoiceChip(
                    label: Text(g.displayName),
                    selected: selected == g.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _gearId = g.id),
                  ),
              ],
            ),
    );
  }

  Future<void> _pickSong() async {
    final picked = await showSongPicker(context);
    if (picked != null && mounted) setState(() => _pickedSong = picked);
  }

  Widget _song() {
    final song = _pickedSong;
    return SectionCard(
      title: 'Song of the Show',
      trailing: const Icon(Icons.music_note, color: StageColors.magenta),
      child: song == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _pickSong,
                icon: const Icon(Icons.search),
                label: const Text('Pick a song'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AlbumArt(
                          url: song.albumArtUrl,
                          size: 64,
                          seed: '${song.title}|${song.artist}',
                        ),
                        if (song.hasClip) ClipPlayButton(song: song, size: 36),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StageColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Change song',
                      onPressed: _pickSong,
                      icon: const Icon(Icons.swap_horiz),
                    ),
                    IconButton(
                      tooltip: 'Remove song',
                      onPressed: () => setState(() => _pickedSong = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _songNote,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. mile 9 second wind',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: StageColors.textMuted,
      ),
    ),
  );
}

/// First step of a new Show: two big poster cards.
class _VenuePicker extends StatelessWidget {
  const _VenuePicker({required this.onPicked});
  final ValueChanged<Venue> onPicked;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "WHAT KIND OF SHOW?",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              for (final v in Venue.values) ...[
                _VenueCard(venue: v, onTap: () => onPicked(v)),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.onTap});
  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blurb = venue == Venue.studio
        ? 'Treadmill run. Log your Tracks: speed and incline for each stretch.'
        : 'Outdoor run. Route, surface, elevation and weather.';
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: gradientFor(venue)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(iconFor(venue), size: 56, color: Colors.white),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.label.toUpperCase(),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        blurb,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
