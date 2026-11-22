import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:setlist_tracker/data/music/apple_preview.dart';
import 'package:setlist_tracker/data/music/music_search.dart';
import 'package:setlist_tracker/data/music/spotify_music_search.dart';

const _functionBody = '''
{"results":[
 {"title":"Mr. Brightside","artist":"The Killers","album":"Hot Fuss",
  "artworkUrl":"https://i.scdn.co/image/big",
  "spotifyUrl":"https://open.spotify.com/track/003vvx7Niy0yvhvHt4a68B",
  "durationMs":222973},
 {"title":"Under Pressure","artist":"Queen, David Bowie","album":null},
 {"artist":"No title"}
]}''';

class _FakeSearch implements MusicSearch {
  _FakeSearch(this.results, {this.fail = false});
  final List<SongResult> results;
  final bool fail;
  final queries = <String>[];

  @override
  Future<List<SongResult>> search(String query) async {
    queries.add(query);
    if (fail) throw Exception('offline');
    return results;
  }
}

SpotifyMusicSearch _spotify(http.Client client) => SpotifyMusicSearch(
  apiUrl: 'https://setlist-tracker.example.workers.dev',
  client: client,
);

void main() {
  group('SpotifyMusicSearch', () {
    test('parses the function answer into Spotify results', () {
      final results = parseSpotifyResults(_functionBody);
      expect(results, hasLength(2));
      final r = results.first;
      expect(r.title, 'Mr. Brightside');
      expect(r.artist, 'The Killers');
      expect(r.album, 'Hot Fuss');
      expect(r.artworkUrl, 'https://i.scdn.co/image/big');
      expect(r.spotifyUrl, startsWith('https://open.spotify.com/track/'));
      expect(r.source, MusicSource.spotify);
      expect(r.previewUrl, isNull);
      expect(results[1].artist, 'Queen, David Bowie');
      expect(results[1].album, isNull);
    });

    test('a body without a results list is an error, not "no songs"', () {
      expect(() => parseSpotifyResults('{"error":"x"}'), throwsFormatException);
      expect(parseSpotifyResults('{"results":[]}'), isEmpty);
    });

    test('asks the Worker with no keys and no sign-in', () async {
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(_functionBody, 200);
      });
      final results = await _spotify(client).search('  mr brightside ');
      expect(results, hasLength(2));
      expect(sent.method, 'GET');
      expect(sent.url.scheme, 'https');
      expect(sent.url.host, 'setlist-tracker.example.workers.dev');
      expect(sent.url.path, '/api/spotify/search');
      expect(sent.url.queryParameters, {'q': 'mr brightside', 'limit': '25'});
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(sent.headers.containsKey('apikey'), isFalse);
    });

    test('empty queries make no request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      expect(await _spotify(client).search('   '), isEmpty);
      expect(calls, 0);
    });

    test('a failed call throws', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'error': 'nope'}), 502),
      );
      expect(_spotify(client).search('queen'), throwsException);
    });
  });

  group('FallbackMusicSearch', () {
    const apple = SongResult(title: 'Song', artist: 'Band');

    test('uses Spotify when it answers', () async {
      final spotify = _FakeSearch([
        const SongResult(
          title: 'Song',
          artist: 'Band',
          source: MusicSource.spotify,
        ),
      ]);
      final itunes = _FakeSearch([apple]);
      final results = await FallbackMusicSearch(spotify, itunes).search('x');
      expect(results.single.source, MusicSource.spotify);
      expect(itunes.queries, isEmpty);
    });

    test('falls back to Apple when Spotify fails', () async {
      final spotify = _FakeSearch(const [], fail: true);
      final itunes = _FakeSearch([apple]);
      final results = await FallbackMusicSearch(spotify, itunes).search('x');
      expect(results.single.source, MusicSource.apple);
      expect(itunes.queries, ['x']);
    });

    test('falls back when the Worker has no Spotify secrets (503)', () async {
      final notDeployed = _spotify(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'not_configured', 'message': 'Off'}),
            503,
          ),
        ),
      );
      final itunes = _FakeSearch([apple]);
      final results = await FallbackMusicSearch(
        notDeployed,
        itunes,
      ).search('song');
      expect(results.single.title, 'Song');
    });
  });

  group('Apple preview for a Spotify pick', () {
    const picked = SongResult(
      title: 'Under Pressure - Remastered 2011',
      artist: 'Queen, David Bowie',
      album: 'Hot Space',
      artworkUrl: 'spotify-art',
      spotifyUrl: 'https://open.spotify.com/track/abc',
      source: MusicSource.spotify,
    );

    SongResult apple(String title, String artist, {String? preview}) =>
        SongResult(
          title: title,
          artist: artist,
          appleMusicUrl: 'https://music.apple.com/$title',
          previewUrl: preview,
        );

    test('takes the matching preview and Apple link, keeps Spotify', () async {
      final itunes = _FakeSearch([
        apple('Under Pressure (Live)', 'Queen', preview: 'live.m4a'),
        apple('Pressure', 'Queen & David Bowie', preview: 'wrong.m4a'),
        apple('Under Pressure', 'Queen & David Bowie', preview: 'right.m4a'),
      ]);
      final r = await ApplePreviewLookup(itunes).previewFor(picked);
      // One request, searching the clean title and the main artist.
      expect(itunes.queries, ['Under Pressure Queen']);
      // The exact title beats the live version listed above it.
      expect(r.previewUrl, 'right.m4a');
      expect(r.appleMusicUrl, 'https://music.apple.com/Under Pressure');
      expect(r.spotifyUrl, picked.spotifyUrl);
      expect(r.artworkUrl, 'spotify-art');
      expect(r.source, MusicSource.spotify);
    });

    test('matches across punctuation, accents and "the"', () {
      const song = SongResult(
        title: "Don't Stop Me Now",
        artist: 'The Killers',
        source: MusicSource.spotify,
      );
      final match = bestAppleMatch(song, [
        apple('Dont Stop Me Now', 'Killers', preview: 'a.m4a'),
      ]);
      expect(match?.previewUrl, 'a.m4a');
      expect(
        bestAppleMatch(const SongResult(title: 'Café', artist: 'Beyoncé'), [
          apple('Cafe', 'Beyonce', preview: 'b.m4a'),
        ])?.previewUrl,
        'b.m4a',
      );
    });

    test('falls back to a live or remastered version', () {
      expect(
        bestAppleMatch(picked, [
          apple('Under Pressure (Live)', 'Queen', preview: 'live.m4a'),
        ])?.previewUrl,
        'live.m4a',
      );
    });

    test('no confident match leaves the preview empty', () async {
      final itunes = _FakeSearch([
        apple('Under Pressure', 'Some Cover Band', preview: 'cover.m4a'),
        apple('Under Pressure', 'Queen'), // no preview
      ]);
      final r = await ApplePreviewLookup(itunes).previewFor(picked);
      expect(r.previewUrl, isNull);
      expect(r.appleMusicUrl, isNull);
      expect(r.spotifyUrl, picked.spotifyUrl);
    });

    test('artist must match a whole name, not part of a word', () {
      expect(
        bestAppleMatch(const SongResult(title: 'Song', artist: 'Queen'), [
          apple('Song', 'Queensryche', preview: 'x.m4a'),
        ]),
        isNull,
      );
    });

    test('a failed lookup keeps the song as picked', () async {
      final r = await ApplePreviewLookup(_FakeSearch(const [], fail: true))
          .previewFor(picked);
      expect(identical(r, picked), isTrue);
    });

    test('songs that already have a preview make no request', () async {
      final itunes = _FakeSearch(const []);
      final withClip = apple('Song', 'Band', preview: 'p.m4a');
      expect(
        identical(
          await ApplePreviewLookup(itunes).previewFor(withClip),
          withClip,
        ),
        isTrue,
      );
      expect(itunes.queries, isEmpty);
    });

    test('cleanTitle drops versions and features', () {
      expect(cleanTitle('Song - Remastered 2011'), 'Song');
      expect(cleanTitle('Song (feat. Someone)'), 'Song');
      expect(cleanTitle('Song [Live]'), 'Song');
      expect(cleanTitle('(Untitled)'), '(Untitled)');
    });
  });
}
