import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/local/sembast_repositories.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/models/track.dart';
import 'package:setlist_tracker/models/venue_details.dart';

Show _studioShow(String id, DateTime date) => Show(
  id: id,
  date: date,
  venue: Venue.studio,
  workoutType: WorkoutType.intervals,
  distanceMiles: 4.25,
  durationSeconds: 2400,
  effort: 7,
  feel: Feel.encore,
  notes: 'Felt strong',
  song: const SongOfTheShow(
    title: 'Mr. Brightside',
    artist: 'The Killers',
    note: 'last rep',
    previewUrl: 'https://example.com/p.m4a',
    clipStartSeconds: 9,
    clipLengthSeconds: 15,
  ),
  studio: const StudioDetails(
    gymName: 'Downtown Y',
    treadmillName: 'Lane 3',
    tracks: [
      Track(startSeconds: 0, endSeconds: 1800, speedMph: 6, inclinePercent: 1),
      Track(
        startSeconds: 1800,
        endSeconds: 2400,
        speedMph: 7.5,
        inclinePercent: 5,
      ),
    ],
  ),
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

void main() {
  late Database db;
  late SembastShowRepository repo;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = SembastShowRepository(db);
  });

  tearDown(() => db.close());

  test('save and load keeps every field', () async {
    final date = DateTime(2026, 11, 21, 6, 15);
    await repo.save(_studioShow('a', date));
    final loaded = await repo.getById('a');
    expect(loaded, isNotNull);
    expect(loaded!.date, date);
    expect(loaded.venue, Venue.studio);
    expect(loaded.feel, Feel.encore);
    expect(loaded.song!.artist, 'The Killers');
    expect(loaded.song!.hasClip, isTrue);
    expect(loaded.song!.clipStartSeconds, 9);
    expect(loaded.studio!.tracks.length, 2);
    expect(loaded.studio!.totals.distanceMiles, closeTo(4.25, 1e-9));
    expect(loaded.live, isNull);
  });

  test('live show weather round-trips', () async {
    final show = Show(
      id: 'live',
      date: DateTime(2026, 11, 20, 17),
      venue: Venue.live,
      workoutType: WorkoutType.long,
      distanceMiles: 16,
      durationSeconds: 8400,
      effort: 6,
      feel: Feel.good,
      live: const LiveDetails(
        routeName: 'River Loop',
        surface: Surface.trail,
        elevationGainFt: 820,
        weather: Weather(tempF: 41, windMph: 8, conditions: Conditions.cloudy),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repo.save(show);
    final loaded = (await repo.getById('live'))!;
    expect(loaded.live!.surface, Surface.trail);
    expect(loaded.live!.weather!.tempF, 41);
    expect(loaded.live!.weather!.conditions, Conditions.cloudy);
  });

  test('watchAll is newest first and hides deleted Shows', () async {
    await repo.save(_studioShow('old', DateTime(2026, 11, 1)));
    await repo.save(_studioShow('new', DateTime(2026, 11, 20)));
    expect((await repo.watchAll().first).map((s) => s.id), ['new', 'old']);

    await repo.delete('old');
    expect((await repo.watchAll().first).map((s) => s.id), ['new']);
    expect(await repo.getById('old'), isNull);
  });
}
