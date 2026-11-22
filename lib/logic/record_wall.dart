/// The Record Wall: every Song of the Show, grouped by song, plus top artists
/// and the playlist export. Worked out from the Shows; nothing is saved.
library;

import '../models/show.dart';
import '../models/song.dart';

/// One song on the wall and every Show it was the Song of.
class WallRecord {
  WallRecord({required this.song, required List<Show> shows})
    : shows = List.unmodifiable(shows);

  /// The most recent pick of this song (its art and links win).
  final SongOfTheShow song;

  /// Newest first.
  final List<Show> shows;

  int get plays => shows.length;
  DateTime get lastPlayed => shows.first.date;
  DateTime get firstPlayed => shows.last.date;

  /// Newest album art across every pick, in case a later pick lost it.
  String? get albumArtUrl {
    for (final s in shows) {
      final url = s.song?.albumArtUrl;
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }
}

class TopArtist {
  const TopArtist({
    required this.name,
    required this.shows,
    required this.miles,
    required this.songs,
  });

  final String name;
  final int shows;
  final double miles;

  /// How many different songs of theirs made the wall.
  final int songs;
}

String _key(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Songs with at least a title, grouped case-insensitively by title and
/// artist, the most recently played first.
List<WallRecord> buildRecordWall(List<Show> shows) {
  final picked =
      shows
          .where((s) => !s.isDeleted && (s.song?.title.trim() ?? '').isNotEmpty)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  final groups = <String, List<Show>>{};
  for (final s in picked) {
    final key = '${_key(s.song!.title)}\u0000${_key(s.song!.artist)}';
    (groups[key] ??= []).add(s);
  }
  // Map keeps insertion order, and the Shows were already newest first.
  return [
    for (final g in groups.values) WallRecord(song: g.first.song!, shows: g),
  ];
}

/// Artists ranked by how many Shows they soundtracked, then by miles.
List<TopArtist> topArtists(List<WallRecord> wall, {int limit = 5}) {
  final byArtist = <String, List<WallRecord>>{};
  for (final r in wall) {
    final name = r.song.artist.trim();
    if (name.isEmpty) continue;
    (byArtist[_key(name)] ??= []).add(r);
  }
  final ranked =
      [
        for (final records in byArtist.values)
          TopArtist(
            name: records.first.song.artist.trim(),
            shows: records.fold(0, (n, r) => n + r.plays),
            miles: records.fold(
              0.0,
              (m, r) => r.shows.fold(m, (m2, s) => m2 + s.distanceMiles),
            ),
            songs: records.length,
          ),
      ]..sort((a, b) {
        final byShows = b.shows.compareTo(a.shows);
        return byShows != 0 ? byShows : b.miles.compareTo(a.miles);
      });
  return ranked.take(limit).toList();
}

/// "Artist - Title", one per line: the format playlist import tools
/// (TuneMyMusic, Soundiiz and others) read from pasted text.
String trackListText(List<WallRecord> wall) => wall
    .map((r) {
      final artist = r.song.artist.trim();
      final title = r.song.title.trim();
      return artist.isEmpty ? title : '$artist - $title';
    })
    .join('\n');

/// A spreadsheet-friendly copy of the wall.
String trackListCsv(List<WallRecord> wall) {
  String cell(String? v) {
    final t = v ?? '';
    return RegExp(r'[",\n\r]').hasMatch(t) ? '"${t.replaceAll('"', '""')}"' : t;
  }

  String day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final rows = [
    'Title,Artist,Shows,Miles,First played,Last played,Apple Music,Spotify',
    for (final r in wall)
      [
        cell(r.song.title.trim()),
        cell(r.song.artist.trim()),
        '${r.plays}',
        r.shows.fold(0.0, (m, s) => m + s.distanceMiles).toStringAsFixed(2),
        day(r.firstPlayed),
        day(r.lastPlayed),
        cell(r.song.appleMusicUrl),
        cell(r.song.spotifyUrl),
      ].join(','),
  ];
  return '${rows.join('\r\n')}\r\n';
}
