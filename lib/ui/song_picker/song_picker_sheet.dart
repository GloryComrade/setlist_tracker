import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/music/music_search.dart';
import '../../models/song.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';

/// Opens the song picker: search as you type, tap a song to pick it.
/// Returns the picked song (without a note), or null if dismissed.
Future<SongOfTheShow?> showSongPicker(BuildContext context,
    {String initialQuery = ''}) {
  return showModalBottomSheet<SongOfTheShow>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: StageColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
        _error = "Couldn't reach the song search. Check your connection, "
            'or type the song in yourself.';
      });
    }
  }

  void _pick(SongResult r) {
    Navigator.of(context).pop(SongOfTheShow(
      title: r.title,
      artist: r.artist,
      albumArtUrl: r.artworkUrl,
      appleMusicUrl: r.appleMusicUrl,
    ));
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
            child: Text('SONG OF THE SHOW',
                style: Theme.of(context).textTheme.headlineMedium),
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
          if (_loading) const LinearProgressIndicator(minHeight: 2),
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
          text: 'Search for the song that carried this run.');
    }
    if (!_loading && _results.isEmpty) {
      return const _Message(
          icon: Icons.search_off, text: 'No songs found. Try another search.');
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          onTap: () => _pick(r),
          leading: AlbumArt(url: r.artworkUrl, size: 52, radius: 6),
          title: Text(r.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [r.artist, if (r.album != null) r.album].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StageColors.textMuted),
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
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: StageColors.textMuted)),
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
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(SongOfTheShow(
                title: _title.text.trim(), artist: _artist.text.trim()));
          },
          child: const Text('Use this song'),
        ),
      ],
    );
  }
}
