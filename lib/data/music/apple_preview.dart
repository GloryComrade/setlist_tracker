/// Spotify gives no preview clips, so when a runner picks a Spotify result
/// the app looks the same song up on Apple's catalog (one request, on pick)
/// and borrows its 30-second preview and Apple Music link.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'music_search.dart';

class ApplePreviewLookup {
  ApplePreviewLookup(this._apple);
  final MusicSearch _apple;

  /// [song] with Apple's preview and link when Apple has a confident match.
  /// Returns [song] unchanged when it already has a preview, when nothing
  /// matches, or when the lookup fails.
  Future<SongResult> previewFor(SongResult song) async {
    if (song.previewUrl != null) return song;
    final title = cleanTitle(song.title);
    final artist = primaryArtist(song.artist);
    try {
      final candidates = await _apple.search('$title $artist');
      final match = bestAppleMatch(song, candidates);
      if (match == null) return song;
      return song.withApple(
        appleMusicUrl: match.appleMusicUrl,
        previewUrl: match.previewUrl,
      );
    } catch (_) {
      return song;
    }
  }
}

/// The best candidate with a preview whose title and artist match [song]:
/// an exact title first ("Under Pressure"), then one that only matches once
/// versions are dropped ("Under Pressure (Live)"). Null when none match.
SongResult? bestAppleMatch(SongResult song, List<SongResult> candidates) {
  final title = normalizeForMatch(cleanTitle(song.title));
  final artists = song.artist
      .split(',')
      .map(normalizeForMatch)
      .where((a) => a.isNotEmpty)
      .toList();
  if (title.isEmpty || artists.isEmpty) return null;
  bool sameArtist(SongResult c) {
    final cArtist = normalizeForMatch(c.artist);
    // Apple joins artists as "A & B" or "A feat. B"; Spotify as "A, B".
    return artists.any((a) => _containsWords(cArtist, a));
  }

  final usable = candidates.where((c) => c.previewUrl != null && sameArtist(c));
  for (final c in usable) {
    if (normalizeForMatch(c.title) == title) return c;
  }
  for (final c in usable) {
    if (normalizeForMatch(cleanTitle(c.title)) == title) return c;
  }
  return null;
}

/// Drops versions and features: "Song - Remastered 2011", "Song (feat. X)",
/// "Song [Live]".
String cleanTitle(String title) {
  var t = title.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '');
  t = t.replaceFirst(RegExp(r'\s+-\s+.*$'), '');
  return t.trim().isEmpty ? title.trim() : t.trim();
}

String primaryArtist(String artist) => artist.split(',').first.trim();

/// Lowercase letters and digits only, single-spaced, "&" read as "and",
/// common accents folded.
String normalizeForMatch(String s) {
  var t = s.toLowerCase().replaceAll('&', ' and ');
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', //
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
  };
  accents.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAll(RegExp(r"['’]"), '');
  t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return t.replaceFirst(RegExp(r'^the '), '');
}

/// True when [needle]'s words appear in [haystack] as whole words.
bool _containsWords(String haystack, String needle) =>
    ' $haystack '.contains(' $needle ');

final previewLookupProvider = Provider<ApplePreviewLookup>(
  (ref) => ApplePreviewLookup(ref.watch(iTunesSearchProvider)),
);
