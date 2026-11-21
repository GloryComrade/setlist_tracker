import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/song.dart';
import '../../theme/app_theme.dart';

/// Plays one part of a song preview. One per screen; dispose it with the
/// screen so audio stops when you leave.
class ClipPlayer {
  final AudioPlayer _player = AudioPlayer();
  String? _loadedUrl;

  Stream<bool> get playing => _player.playingStream;
  bool get isPlaying => _player.playing;

  /// Plays [lengthSeconds] from [startSeconds]. Loops when [loop] is true.
  Future<void> play(String url, double startSeconds, double lengthSeconds,
      {bool loop = false}) async {
    if (_loadedUrl != url) {
      await _player.setUrl(url);
      _loadedUrl = url;
    }
    await _player.setClip(
      start: Duration(milliseconds: (startSeconds * 1000).round()),
      end: Duration(
          milliseconds: ((startSeconds + lengthSeconds) * 1000).round()),
    );
    await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    await _player.seek(Duration.zero);
    unawaited(_player.play());
  }

  Future<void> stop() => _player.pause();

  Future<void> dispose() => _player.dispose();
}

/// Round play/stop button for a song's picked part.
class ClipPlayButton extends StatefulWidget {
  const ClipPlayButton({super.key, required this.song, this.size = 44});
  final SongOfTheShow song;
  final double size;

  @override
  State<ClipPlayButton> createState() => _ClipPlayButtonState();
}

class _ClipPlayButtonState extends State<ClipPlayButton> {
  final _player = ClipPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final s = widget.song;
    if (!s.hasClip) return;
    if (_player.isPlaying) {
      await _player.stop();
      return;
    }
    try {
      await _player.play(
          s.previewUrl!, s.clipStartSeconds!, s.clipLengthSeconds ?? 15);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't play the song. Check your connection.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _player.playing,
      initialData: false,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return IconButton.filled(
          tooltip: playing ? 'Stop' : 'Play your part of the song',
          iconSize: widget.size * 0.55,
          style: IconButton.styleFrom(
            backgroundColor: StageColors.magenta,
            foregroundColor: Colors.white,
            fixedSize: Size.square(widget.size),
          ),
          onPressed: _toggle,
          icon: Icon(playing ? Icons.stop : Icons.play_arrow),
        );
      },
    );
  }
}
