/// Song search for the Song of the Show picker.
///
/// The UI only knows [MusicSearch]. With backend settings it searches Spotify
/// through the `spotify-search` Supabase Edge Function (which holds Spotify's
/// API secret) and falls back to Apple's free iTunes Search API whenever that
/// fails. Local-only builds search iTunes directly.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../remote/backend_config.dart';
import 'jsonp.dart';
import 'spotify_music_search.dart';

/// Which catalog a result came from.
enum MusicSource { apple, spotify }

/// One search result.
class SongResult {
  const SongResult({
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    this.appleMusicUrl,
    this.spotifyUrl,
    this.previewUrl,
    this.source = MusicSource.apple,
  });

  final MusicSource source;
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final String? appleMusicUrl;

  /// Set on Spotify results (https://open.spotify.com/track/...).
  final String? spotifyUrl;

  /// 30-second preview clip (m4a). Spotify gives none, so a picked Spotify
  /// result borrows Apple's (see apple_preview.dart).
  final String? previewUrl;

  /// This result with Apple's links filled in.
  SongResult withApple({String? appleMusicUrl, String? previewUrl}) =>
      SongResult(
        title: title,
        artist: artist,
        album: album,
        artworkUrl: artworkUrl,
        appleMusicUrl: appleMusicUrl ?? this.appleMusicUrl,
        spotifyUrl: spotifyUrl,
        previewUrl: previewUrl ?? this.previewUrl,
        source: source,
      );
}

abstract class MusicSearch {
  /// Songs matching [query], best match first. Throws on network errors.
  Future<List<SongResult>> search(String query);
}

class ITunesMusicSearch implements MusicSearch {
  ITunesMusicSearch({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  Future<List<SongResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': q,
      'media': 'music',
      'entity': 'song',
      'limit': '25',
    });
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw Exception('Song search failed (${res.statusCode})');
      }
      return parseITunesResults(res.body);
    } catch (_) {
      // Some browsers block the request outright (no CORS header); Apple's
      // search also answers JSONP, which browsers always allow.
      if (!kIsWeb) rethrow;
      return parseITunesResults(await fetchJsonp(uri));
    }
  }
}

/// Parses an iTunes Search API response. Public for tests.
List<SongResult> parseITunesResults(String body) {
  final json = jsonDecode(body);
  final results = json is Map ? json['results'] : null;
  if (results is! List) return const [];
  final out = <SongResult>[];
  for (final r in results) {
    if (r is! Map) continue;
    final title = r['trackName'];
    final artist = r['artistName'];
    if (title is! String || artist is! String) continue;
    final art = r['artworkUrl100'];
    out.add(
      SongResult(
        title: title,
        artist: artist,
        album: r['collectionName'] as String?,
        // Ask for a sharper 600px cover instead of the 100px thumbnail.
        artworkUrl: art is String
            ? art.replaceFirst(RegExp(r'/\d+x\d+bb\.'), '/600x600bb.')
            : null,
        appleMusicUrl: r['trackViewUrl'] as String?,
        previewUrl: r['previewUrl'] as String?,
      ),
    );
  }
  return out;
}

/// Tries [primary]; if it throws (function not deployed, offline, Spotify
/// down), runs the same query on [fallback] so the picker keeps working.
class FallbackMusicSearch implements MusicSearch {
  FallbackMusicSearch(this.primary, this.fallback);
  final MusicSearch primary;
  final MusicSearch fallback;

  @override
  Future<List<SongResult>> search(String query) async {
    try {
      return await primary.search(query);
    } catch (_) {
      return fallback.search(query);
    }
  }
}

/// Apple's catalog: the fallback search, and where Spotify picks get their
/// 30-second preview.
final iTunesSearchProvider = Provider<ITunesMusicSearch>(
  (ref) => ITunesMusicSearch(),
);

final musicSearchProvider = Provider<MusicSearch>((ref) {
  final itunes = ref.watch(iTunesSearchProvider);
  if (!backendConfigured) return itunes;
  // Guests get Spotify too: the publishable key is enough to call it.
  return FallbackMusicSearch(
    SpotifyMusicSearch(
      functionsUrl: '$supabaseUrl/functions/v1',
      apiKey: supabaseKey,
      accessToken: supabaseAccessToken,
    ),
    itunes,
  );
});
