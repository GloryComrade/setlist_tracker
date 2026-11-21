import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/data/music/music_search.dart';

void main() {
  test('parses iTunes results and upsizes the album art', () {
    const body = '''
{"resultCount":2,"results":[
 {"wrapperType":"track","trackName":"Mr. Brightside","artistName":"The Killers",
  "collectionName":"Hot Fuss",
  "artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/Music/v4/ab/cd/source/100x100bb.jpg",
  "trackViewUrl":"https://music.apple.com/us/album/mr-brightside/1?i=2"},
 {"wrapperType":"track","artistName":"No title here"}
]}''';
    final results = parseITunesResults(body);
    expect(results, hasLength(1));
    final r = results.single;
    expect(r.title, 'Mr. Brightside');
    expect(r.artist, 'The Killers');
    expect(r.album, 'Hot Fuss');
    expect(r.artworkUrl, endsWith('/600x600bb.jpg'));
    expect(r.appleMusicUrl, startsWith('https://music.apple.com/'));
  });

  test('bad or empty bodies give no results', () {
    expect(parseITunesResults('{"results":[]}'), isEmpty);
    expect(parseITunesResults('{"oops":1}'), isEmpty);
  });
}
