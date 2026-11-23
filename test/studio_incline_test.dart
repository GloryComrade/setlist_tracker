import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/data/health/health_source.dart';
import 'package:setlist_tracker/logic/gold_records.dart';
import 'package:setlist_tracker/logic/health_import.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/track.dart';
import 'package:setlist_tracker/models/venue_details.dart';
import 'package:setlist_tracker/ui/crew/crew_post_card.dart';

Show _studio(String id, StudioDetails details, {double miles = 3}) => Show(
  id: id,
  date: DateTime(2026, 11, 20, 6),
  venue: Venue.studio,
  workoutType: WorkoutType.easy,
  distanceMiles: miles,
  durationSeconds: 1800,
  effort: 5,
  feel: Feel.fine,
  studio: details,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

HealthRun _run({double? elevation, double miles = 3}) => HealthRun(
  uuid: 'h1',
  start: DateTime(2026, 11, 20, 6),
  end: DateTime(2026, 11, 20, 6, 30),
  distanceMiles: miles,
  durationSeconds: 1800,
  indoor: true,
  elevationGainFt: elevation,
  sourceName: 'Apple Watch',
);

const _tracks = [
  Track(startSeconds: 0, endSeconds: 600, speedMph: 6, inclinePercent: 2),
  Track(startSeconds: 600, endSeconds: 1800, speedMph: 6, inclinePercent: 8),
];

void main() {
  group('StudioDetails incline', () {
    test('round-trips through JSON and stays absent when unset', () {
      const typed = StudioDetails(inclinePercent: 4.5);
      expect(typed.toJson()['inclinePercent'], 4.5);
      expect(StudioDetails.fromJson(typed.toJson()).inclinePercent, 4.5);

      const none = StudioDetails();
      expect(none.toJson().containsKey('inclinePercent'), isFalse);
      // A Show saved before build 6 reads with no incline.
      expect(
        StudioDetails.fromJson({'gymName': 'Y', 'tracks': []}).inclinePercent,
        isNull,
      );
    });

    test('Tracks win over a typed incline', () {
      const withTracks = StudioDetails(tracks: _tracks, inclinePercent: 1);
      expect(withTracks.averageInclinePercent, 6.0);
      const typed = StudioDetails(inclinePercent: 3);
      expect(typed.averageInclinePercent, 3);
      expect(const StudioDetails().averageInclinePercent, isNull);
    });
  });

  group('Health import', () {
    test('a treadmill climb becomes the incline', () {
      // 3 miles = 15,840 ft; 792 ft of climb is a 5% grade.
      expect(inclineFromHealthRun(_run(elevation: 792)), 5.0);
      final s = showFromHealthRun(_run(elevation: 792), now: DateTime.now());
      expect(s.studio!.inclinePercent, 5.0);
    });

    test('no climb means no incline, and it never passes 15%', () {
      expect(inclineFromHealthRun(_run()), isNull);
      expect(inclineFromHealthRun(_run(elevation: 0)), isNull);
      expect(inclineFromHealthRun(_run(elevation: 99999)), 15.0);
    });
  });

  test('Steepest Studio Session counts a typed incline', () {
    final records = computeGoldRecords([
      _studio('tracks', const StudioDetails(tracks: _tracks)),
      _studio('typed', const StudioDetails(inclinePercent: 9.5)),
      _studio('flat', const StudioDetails()),
    ]);
    expect(records[RecordKind.steepestStudio]!.show!.id, 'typed');
    expect(records[RecordKind.steepestStudio]!.value, '9.5%');
  });

  test('the Crew sees a typed incline', () {
    final facts = crewShowFacts(
      _studio('typed', const StudioDetails(inclinePercent: 4.5)),
    );
    expect(facts.single.text, '4.5% incline');
    expect(facts.single.spoken, '4.5 percent incline.');
    expect(crewShowFacts(_studio('flat', const StudioDetails())), isEmpty);
  });
}
