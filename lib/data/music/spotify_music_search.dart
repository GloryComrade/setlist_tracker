/// Spotify song search through the Cloudflare Worker's
/// `/api/spotify/search` route (backend/, docs/cloudflare-api.md). The
/// Worker holds Spotify's secret; the app sends no keys and needs no
/// sign-in.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'music_search.dart';

class SpotifyMusicSearch implements MusicSearch {
  SpotifyMusicSearch({required this.apiUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// The Worker's address, e.g. https://setlist-tracker.example.workers.dev
  final String apiUrl;
  final http.Client _client;

  @override
  Future<List<SongResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$apiUrl/api/spotify/search')
        .replace(queryParameters: {'q': q, 'limit': '25'});
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      // 503 not_configured when the Worker has no Spotify secrets.
      throw Exception('Spotify search failed (${res.statusCode})');
    }
    return parseSpotifyResults(res.body);
  }
}

/// Parses the Worker's `{results: [...]}` answer. Public for tests.
List<SongResult> parseSpotifyResults(String body) {
  final json = jsonDecode(body);
  final results = json is Map ? json['results'] : null;
  if (results is! List) throw const FormatException('No results list');
  final out = <SongResult>[];
  for (final r in results) {
    if (r is! Map) continue;
    final title = r['title'];
    final artist = r['artist'];
    if (title is! String || artist is! String) continue;
    String? str(String key) => r[key] is String ? r[key] as String : null;
    out.add(
      SongResult(
        title: title,
        artist: artist,
        album: str('album'),
        artworkUrl: str('artworkUrl'),
        spotifyUrl: str('spotifyUrl'),
        source: MusicSource.spotify,
      ),
    );
  }
  return out;
}
