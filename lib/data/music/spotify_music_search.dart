/// Spotify song search through the `spotify-search` Supabase Edge Function
/// (supabase/functions/spotify-search). The function holds Spotify's secret;
/// the app only sends the project's publishable key, plus the runner's
/// session token when signed in.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'music_search.dart';

class SpotifyMusicSearch implements MusicSearch {
  SpotifyMusicSearch({
    required this.functionsUrl,
    required this.apiKey,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// e.g. https://xxxx.supabase.co/functions/v1
  final String functionsUrl;

  /// The publishable (anon) key.
  final String apiKey;

  /// The signed-in session's access token, or null for a guest.
  final String? Function() accessToken;
  final http.Client _client;

  @override
  Future<List<SongResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$functionsUrl/spotify-search')
        .replace(queryParameters: {'q': q, 'limit': '25'});
    final res = await _client
        .get(
          uri,
          headers: {
            'apikey': apiKey,
            'Authorization': 'Bearer ${accessToken() ?? apiKey}',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Spotify search failed (${res.statusCode})');
    }
    return parseSpotifyResults(res.body);
  }
}

/// Parses the function's `{results: [...]}` answer. Public for tests.
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

/// The current session's token, or null when signed out. Only called in
/// builds with backend settings, after Supabase.initialize in main().
String? supabaseAccessToken() {
  try {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  } catch (_) {
    return null;
  }
}
