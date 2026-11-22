import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/gold_records.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/track.dart';
import 'package:setlist_tracker/models/venue_details.dart';

Show _show(
  String id,
  DateTime date, {
  double miles = 5,
  int seconds = 3000,
  Venue venue = Venue.live,
  WorkoutType type = WorkoutType.easy,
  double? elevation,
  List<Track> tracks = const [],
  DateTime? deletedAt,
}) => Show(
  id: id,
  date: date,
  venue: venue,
  workoutType: type,
  distanceMiles: miles,
  durationSeconds: seconds,
  effort: 5,
  feel: Feel.fine,
  live: venue == Venue.live ? LiveDetails(elevationGainFt: elevation) : null,
  studio: venue == Venue.studio ? StudioDetails(tracks: tracks) : null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  deletedAt: deletedAt,
);

void main() {
  test('no Shows means no records', () {
    expect(computeGoldRecords(const []), isEmpty);
  });

  test('longest Show, longest Headliner and fastest pace', () {
    final shows = [
      _show('a', DateTime(2026, 10, 1), miles: 6, seconds: 3000), // 8:20
      _show(
        'b',
        DateTime(2026, 10, 4),
        miles: 14,
        seconds: 14 * 570,
        type: WorkoutType.long,
      ),
      _show('c', DateTime(2026, 10, 6), miles: 3.1, seconds: 1395),
      // Fast but under a mile: never counts for pace.
      _show('d', DateTime(2026, 10, 7), miles: 0.5, seconds: 120),
    ];
    final r = computeGoldRecords(shows);
    expect(r[RecordKind.longestShow]!.show!.id, 'b');
    expect(r[RecordKind.longestShow]!.value, '14 mi');
    expect(r[RecordKind.longestHeadliner]!.show!.id, 'b');
    expect(r[RecordKind.fastestPace]!.show!.id, 'c'); // 7:30 /mi
    expect(r[RecordKind.fastestPace]!.value, '7:30 /mi');
  });

  test('race times come from average pace on a long-enough Show', () {
    final shows = [
      // 3.1 mi logged counts as a 5K (within slack), 7:30 /mi.
      _show('five', DateTime(2026, 9, 1), miles: 3.1, seconds: 1395),
      // 6.5 mi at 8:00 /mi: sets the 10K, and is slower for the 5K.
      _show('ten', DateTime(2026, 9, 8), miles: 6.5, seconds: 3120),
    ];
    final r = computeGoldRecords(shows);
    expect(r[RecordKind.fastest5k]!.show!.id, 'five');
    expect(r[RecordKind.fastest5k]!.value, '23:18'); // 450 s × 3.10686
    expect(r[RecordKind.fastest10k]!.show!.id, 'ten');
    expect(r[RecordKind.fastest10k]!.value, '49:43'); // 480 s × 6.21371
    expect(r.containsKey(RecordKind.fastestHalf), isFalse);
    expect(r.containsKey(RecordKind.fastestFull), isFalse);
  });

  test('biggest week runs Monday to Sunday, biggest month by calendar', () {
    final shows = [
      // Mon Nov 2 to Sun Nov 8, 2026: 4 + 6 + 10 = 20.
      _show('m', DateTime(2026, 11, 2), miles: 4),
      _show('w', DateTime(2026, 11, 4), miles: 6),
      _show('s', DateTime(2026, 11, 8), miles: 10),
      // Next Monday starts a new week.
      _show('n', DateTime(2026, 11, 9), miles: 12),
      _show('o', DateTime(2026, 10, 30), miles: 3),
    ];
    final r = computeGoldRecords(shows);
    final week = r[RecordKind.biggestWeek]!;
    expect(week.value, '20 mi');
    expect(week.date, DateTime(2026, 11, 2));
    expect(week.periodShowCount, 3);
    expect(week.show, isNull);
    expect(r[RecordKind.biggestMonth]!.value, '32 mi');
    expect(r[RecordKind.biggestMonth]!.date, DateTime(2026, 11));
  });

  test('ties go to the Show that got there first', () {
    final shows = [
      _show('later', DateTime(2026, 8, 20), miles: 10),
      _show('first', DateTime(2026, 8, 1), miles: 10),
    ];
    expect(
      computeGoldRecords(shows)[RecordKind.longestShow]!.show!.id,
      'first',
    );
  });

  test('climbs, scopes and deleted Shows', () {
    final shows = [
      _show('hill', DateTime(2026, 7, 1), elevation: 1234),
      _show(
        'tread',
        DateTime(2026, 7, 2),
        miles: 3,
        venue: Venue.studio,
        tracks: const [
          Track(
            startSeconds: 0,
            endSeconds: 600,
            speedMph: 6,
            inclinePercent: 2,
          ),
          Track(
            startSeconds: 600,
            endSeconds: 1800,
            speedMph: 6,
            inclinePercent: 8,
          ),
        ],
      ),
      _show(
        'gone',
        DateTime(2026, 7, 3),
        miles: 30,
        deletedAt: DateTime.utc(2026, 7, 4),
      ),
    ];
    final all = computeGoldRecords(shows);
    expect(all[RecordKind.mostClimbing]!.value, '1,234 ft');
    expect(all[RecordKind.steepestStudio]!.value, '6.0%');
    expect(all[RecordKind.longestShow]!.show!.id, 'hill');

    final live = computeGoldRecords(shows, scope: RecordScope.live);
    expect(live.containsKey(RecordKind.steepestStudio), isFalse);
    expect(RecordKind.steepestStudio.appliesTo(RecordScope.live), isFalse);

    final studio = computeGoldRecords(shows, scope: RecordScope.studio);
    expect(studio[RecordKind.longestShow]!.show!.id, 'tread');
    expect(studio.containsKey(RecordKind.mostClimbing), isFalse);
  });
}
