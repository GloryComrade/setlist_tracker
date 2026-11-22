import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/music/apple_preview.dart';
import '../../data/music/music_search.dart';
import '../../models/song.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/clip_player.dart';

/// Opens the song picker: search as you type, tap a song to pick it.
/// Returns the picked song (without a note), or null if dismissed.
Future<SongOfTheShow?> showSongPicker(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showModalBottomSheet<SongOfTheShow>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: StageColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _SongPicker(initialQuery: initialQuery),
    ),
  );
}

class _SongPicker extends ConsumerStatefulWidget {
  const _SongPicker({required this.initialQuery});
  final String initialQuery;

  @override
  ConsumerState<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends ConsumerState<_SongPicker> {
  late final _query = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<SongResult> _results = const [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  /// True while a picked Spotify song looks for Apple's preview clip.
  bool _findingPreview = false;

  /// Set once a song with a preview is tapped: then the sheet shows the
  /// "pick your part" step.
  SongResult? _choosingPartOf;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_requestId;
    if (text.trim().isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(musicSearchProvider).search(text);
      // Ignore answers to an older query that arrive late.
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error =
            "Couldn't reach the song search. Check your connection, "
            'or type the song in yourself.';
      });
    }
  }

  Future<void> _pick(SongResult picked) async {
    if (_findingPreview) return;
    var r = picked;
    if (r.previewUrl == null && r.source == MusicSource.spotify) {
      // Spotify has no clips: borrow Apple's 30-second preview.
      setState(() => _findingPreview = true);
      r = await ref.read(previewLookupProvider).previewFor(r);
      if (!mounted) return;
      setState(() => _findingPreview = false);
    }
    if (r.previewUrl != null) {
      setState(() => _choosingPartOf = r);
      return;
    }
    Navigator.of(context).pop(
      SongOfTheShow(
        title: r.title,
        artist: r.artist,
        albumArtUrl: r.artworkUrl,
        spotifyUrl: r.spotifyUrl,
        appleMusicUrl: r.appleMusicUrl,
      ),
    );
  }

  Future<void> _typeItIn() async {
    final song = await showDialog<SongOfTheShow>(
      context: context,
      builder: (_) => const _ManualSongDialog(),
    );
    if (song != null && mounted) Navigator.of(context).pop(song);
  }

  @override
  Widget build(BuildContext context) {
    final choosing = _choosingPartOf;
    if (choosing != null) {
      return _PartChooser(
        song: choosing,
        onBack: () => setState(() => _choosingPartOf = null),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: StageColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'SONG OF THE SHOW',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search songs or artists',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          _search('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading || _findingPreview)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body()),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: _typeItIn,
            icon: const Icon(Icons.edit),
            label: const Text("Can't find it? Type it in"),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _Message(icon: Icons.wifi_off, text: _error!);
    }
    if (_query.text.trim().isEmpty) {
      return const _Message(
        icon: Icons.queue_music,
        text: 'Search for the song that carried this run.',
      );
    }
    if (!_loading && _results.isEmpty) {
      return const _Message(
        icon: Icons.search_off,
        text: 'No songs found. Try another search.',
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          onTap: () => _pick(r),
          leading: AlbumArt(url: r.artworkUrl, size: 52, radius: 6),
          title: Text(
            r.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [r.artist, if (r.album != null) r.album].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StageColors.textMuted),
          ),
          // Where the result came from, kept quiet: plain text, no logos.
          trailing: Text(
            r.source == MusicSource.spotify ? 'Spotify' : 'Apple Music',
            style: const TextStyle(
              color: StageColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: StageColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: StageColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _ManualSongDialog extends StatefulWidget {
  const _ManualSongDialog();

  @override
  State<_ManualSongDialog> createState() => _ManualSongDialogState();
}

class _ManualSongDialogState extends State<_ManualSongDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _artist = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Type in the song'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Song title'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Add the title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _artist,
                decoration: const InputDecoration(labelText: 'Artist'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Add the artist' : null,
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
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              SongOfTheShow(
                title: _title.text.trim(),
                artist: _artist.text.trim(),
              ),
            );
          },
          child: const Text('Use this song'),
        ),
      ],
    );
  }
}

/// Length of the part you pick, like an Instagram note.
const double kClipLengthSeconds = 15;

/// Step two: slide a 15-second window along the preview to pick your part.
class _PartChooser extends StatefulWidget {
  const _PartChooser({required this.song, required this.onBack});
  final SongResult song;
  final VoidCallback onBack;

  @override
  State<_PartChooser> createState() => _PartChooserState();
}

class _PartChooserState extends State<_PartChooser> {
  final _player = ClipPlayer();
  double _start = 0;

  /// Apple previews are 30 seconds.
  static const double _previewLength = 30;
  double get _maxStart => _previewLength - kClipLengthSeconds;

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    try {
      await _player.play(
        widget.song.previewUrl!,
        _start,
        kClipLengthSeconds,
        loop: true,
      );
    } catch (_) {
      // Browsers can block audio until the first tap; the play button
      // below starts it again.
    }
  }

  void _done() {
    _player.stop();
    final r = widget.song;
    Navigator.of(context).pop(
      SongOfTheShow(
        title: r.title,
        artist: r.artist,
        albumArtUrl: r.artworkUrl,
        spotifyUrl: r.spotifyUrl,
        appleMusicUrl: r.appleMusicUrl,
        previewUrl: r.previewUrl,
        clipStartSeconds: _start,
        clipLengthSeconds: kClipLengthSeconds,
      ),
    );
  }

  String _mmss(double s) => '0:${s.round().toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final r = widget.song;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to search',
                onPressed: () {
                  _player.stop();
                  widget.onBack();
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  'PICK YOUR PART',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(child: AlbumArt(url: r.artworkUrl, size: 180, radius: 16)),
          const SizedBox(height: 16),
          Text(
            r.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            r.artist,
            textAlign: TextAlign.center,
            style: const TextStyle(color: StageColors.textMuted),
          ),
          const Spacer(),
          SizedBox(
            height: 56,
            child: CustomPaint(
              painter: _WaveformPainter(
                startFraction: _start / _previewLength,
                lengthFraction: kClipLengthSeconds / _previewLength,
              ),
            ),
          ),
          Slider(
            value: _start,
            min: 0,
            max: _maxStart,
            divisions: _maxStart.round(),
            label: _mmss(_start),
            onChanged: (v) => setState(() => _start = v),
            onChangeEnd: (_) => _play(),
          ),
          Text(
            'Plays ${_mmss(_start)} to ${_mmss(_start + kClipLengthSeconds)} '
            'of the preview. Slide to pick the part that carried you.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: StageColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<bool>(
                stream: _player.playing,
                initialData: false,
                builder: (context, snap) => IconButton.outlined(
                  tooltip: (snap.data ?? false) ? 'Pause' : 'Play',
                  onPressed: () =>
                      (snap.data ?? false) ? _player.stop() : _play(),
                  icon: Icon(
                    (snap.data ?? false) ? Icons.pause : Icons.play_arrow,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _done,
                icon: const Icon(Icons.check),
                label: const Text('Use this part'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decorative waveform bars with the picked window lit up.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.startFraction, required this.lengthFraction});
  final double startFraction;
  final double lengthFraction;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 60;
    final barWidth = size.width / bars;
    final lit = Paint()..color = StageColors.magenta;
    final dim = Paint()..color = StageColors.outline;
    for (var i = 0; i < bars; i++) {
      // Fixed pseudo-random heights so the shape doesn't jump around.
      final h = (0.25 + 0.75 * (((i * 37) % 17) / 16)) * size.height;
      final x = i * barWidth;
      final f = (i + 0.5) / bars;
      final inWindow =
          f >= startFraction && f <= startFraction + lengthFraction;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + barWidth * 0.2,
            (size.height - h) / 2,
            barWidth * 0.6,
            h,
          ),
          const Radius.circular(2),
        ),
        inWindow ? lit : dim,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.startFraction != startFraction ||
      old.lengthFraction != lengthFraction;
}
