/// Song search for the Song of the Show picker.
///
/// The UI only knows [MusicSearch]. Today it is backed by Apple's free iTunes
/// Search API, which needs no account or key and returns album art. A Spotify
/// version (which needs a server to hold Spotify's API secret) can replace it
/// in Phase 5 by changing [musicSearchProvider] only.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'jsonp.dart';

/// One search result.
class SongResult {
  const SongResult({
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    this.appleMusicUrl,
    this.previewUrl,
  });

  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final String? appleMusicUrl;

  /// 30-second preview clip (m4a).
  final String? previewUrl;
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

final musicSearchProvider = Provider<MusicSearch>((ref) => ITunesMusicSearch());
