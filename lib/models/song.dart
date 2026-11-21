import 'json_utils.dart';

/// The one song that defined a Show.
///
/// v1 is typed in by hand. The album art and link fields are already here so
/// the v2 Spotify / Apple Music search can fill them without a data migration.
class SongOfTheShow {
  const SongOfTheShow({
    required this.title,
    required this.artist,
    this.note,
    this.albumArtUrl,
    this.spotifyUrl,
    this.appleMusicUrl,
    this.previewUrl,
    this.clipStartSeconds,
    this.clipLengthSeconds,
  });

  final String title;
  final String artist;

  /// e.g. "mile 9 second wind".
  final String? note;

  final String? albumArtUrl;
  final String? spotifyUrl;
  final String? appleMusicUrl;

  /// A short preview of the song (Apple gives a 30-second clip).
  final String? previewUrl;

  /// The part of the preview the runner picked, like an Instagram note.
  /// Seconds into [previewUrl]. Null when no part was picked.
  final double? clipStartSeconds;
  final double? clipLengthSeconds;

  bool get hasClip => previewUrl != null && clipStartSeconds != null;

  Map<String, Object?> toJson() => {
        'title': title,
        'artist': artist,
        'note': note,
        'albumArtUrl': albumArtUrl,
        'spotifyUrl': spotifyUrl,
        'appleMusicUrl': appleMusicUrl,
        'previewUrl': previewUrl,
        'clipStartSeconds': clipStartSeconds,
        'clipLengthSeconds': clipLengthSeconds,
      };

  factory SongOfTheShow.fromJson(Map<String, Object?> json) => SongOfTheShow(
        title: asStringOrNull(json['title']) ?? '',
        artist: asStringOrNull(json['artist']) ?? '',
        note: asStringOrNull(json['note']),
        albumArtUrl: asStringOrNull(json['albumArtUrl']),
        spotifyUrl: asStringOrNull(json['spotifyUrl']),
        appleMusicUrl: asStringOrNull(json['appleMusicUrl']),
        previewUrl: asStringOrNull(json['previewUrl']),
        clipStartSeconds: asDoubleOrNull(json['clipStartSeconds']),
        clipLengthSeconds: asDoubleOrNull(json['clipLengthSeconds']),
      );
}
