import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/record_wall.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';

Show _show(String id, int day, SongOfTheShow? song, {double miles = 5}) => Show(
  id: id,
  date: DateTime(2026, 11, day),
  venue: Venue.live,
  workoutType: WorkoutType.easy,
  distanceMiles: miles,
  durationSeconds: 3000,
  effort: 5,
  feel: Feel.fine,
  song: song,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _brightside = SongOfTheShow(
  title: 'Mr. Brightside',
  artist: 'The Killers',
  albumArtUrl: 'https://example.com/hot-fuss.jpg',
);

void main() {
  final shows = [
    _show('1', 1, _brightside, miles: 3),
    _show(
      '2',
      3,
      const SongOfTheShow(title: 'Born to Run', artist: 'Bruce Springsteen'),
    ),
    // Same song typed differently, no art this time.
    _show(
      '3',
      5,
      const SongOfTheShow(title: ' mr. brightside', artist: 'the  killers'),
    ),
    _show(
      '4',
      7,
      const SongOfTheShow(title: 'When You Were Young', artist: 'The Killers'),
      miles: 10,
    ),
    _show('5', 8, null),
    _show('6', 9, const SongOfTheShow(title: '  ', artist: 'Nobody')),
  ];

  test('groups repeat songs and sorts by most recent play', () {
    final wall = buildRecordWall(shows);
    expect(wall.map((r) => r.song.title), [
      'When You Were Young',
      ' mr. brightside',
      'Born to Run',
    ]);
    final brightside = wall[1];
    expect(brightside.plays, 2);
    expect(brightside.shows.map((s) => s.id), ['3', '1']);
    // Art from the earlier pick fills in for the typed one.
    expect(brightside.albumArtUrl, 'https://example.com/hot-fuss.jpg');
    expect(brightside.firstPlayed, DateTime(2026, 11, 1));
  });

  test('top artists rank by Shows, then miles', () {
    final top = topArtists(buildRecordWall(shows));
    expect(top.first.name, 'The Killers');
    expect(top.first.shows, 3);
    expect(top.first.songs, 2);
    expect(top.first.miles, 18);
    expect(top[1].name, 'Bruce Springsteen');
  });

  test('track list and CSV exports', () {
    final wall = buildRecordWall([
      _show('1', 1, _brightside),
      _show(
        '2',
        2,
        const SongOfTheShow(title: 'Hello, "Goodbye"', artist: 'The Beatles'),
      ),
    ]);
    expect(
      trackListText(wall),
      'The Beatles - Hello, "Goodbye"\nThe Killers - Mr. Brightside',
    );
    final csv = trackListCsv(wall).split('\r\n');
    expect(csv.first, startsWith('Title,Artist,Shows'));
    expect(
      csv[1],
      startsWith('"Hello, ""Goodbye""",The Beatles,1,5.00,2026-11-02'),
    );
  });
}
