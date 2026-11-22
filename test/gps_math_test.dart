import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/data/health/health_save.dart';
import 'package:setlist_tracker/data/health/health_source.dart';
import 'package:setlist_tracker/logic/gps_math.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/gps_track.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/venue_details.dart';

final t0 = DateTime.utc(2026, 11, 22, 14);

/// Degrees of latitude per meter (north-south lines are the same length
/// everywhere).
const _degPerM = 1 / 111195.0;

/// A runner heading due north at [mps] meters a second, one fix a second.
List<GpsPoint> north(
  int seconds, {
  double mps = 3,
  DateTime? from,
  double startLat = 40,
  double? alt,
}) {
  final start = from ?? t0;
  return [
    for (var i = 0; i <= seconds; i++)
      GpsPoint(
        lat: startLat + i * mps * _degPerM,
        lng: -105,
        time: start.add(Duration(seconds: i)),
        accuracyM: 5,
        altitudeM: alt,
      ),
  ];
}

void main() {
  group('polyline', () {
    test('round trips to about a meter', () {
      final pts = [(40.0, -105.0), (40.00123, -105.00456), (39.99, -104.5)];
      final back = decodePolyline(encodePolyline(pts));
      expect(back.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(back[i].$1, closeTo(pts[i].$1, 1e-5));
        expect(back[i].$2, closeTo(pts[i].$2, 1e-5));
      }
    });

    test('matches Google\'s worked example', () {
      expect(
        encodePolyline([(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]),
        '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      );
    });
  });

  test('haversine: a degree of latitude is about 69 miles', () {
    expect(
      haversineMeters(40, -105, 41, -105) / metersPerMile,
      closeTo(69, 0.2),
    );
  });

  group('LiveRecording', () {
    test('miles, moving time and pace from steady fixes', () {
      final rec = LiveRecording.start(t0);
      for (final p in north(600)) {
        rec.addFix(p);
      }
      final end = t0.add(const Duration(seconds: 600));
      expect(rec.distanceM, closeTo(1800, 2));
      expect(rec.movingSecondsAt(end), 600);
      // 3 m/s is 8:56 /mi.
      expect(rec.averagePaceAt(end), closeTo(metersPerMile / 3, 2));
      expect(rec.currentPaceAt(end), closeTo(metersPerMile / 3, 2));
      expect(rec.splits.length, 1);
      expect(rec.splits.first, closeTo(536, 1));
    });

    test('ignores bad fixes, jumps and jitter', () {
      final rec = LiveRecording.start(t0);
      final pts = north(10);
      for (final p in pts) {
        rec.addFix(p);
      }
      final before = rec.distanceM;
      // Poor accuracy.
      expect(
        rec.addFix(
          GpsPoint(
            lat: 40.01,
            lng: -105,
            time: t0.add(const Duration(seconds: 11)),
            accuracyM: 80,
          ),
        ),
        isFalse,
      );
      // A 500 m jump in a second.
      expect(
        rec.addFix(
          GpsPoint(
            lat: pts.last.lat + 500 * _degPerM,
            lng: -105,
            time: t0.add(const Duration(seconds: 12)),
            accuracyM: 5,
          ),
        ),
        isFalse,
      );
      // Standing still.
      expect(
        rec.addFix(
          GpsPoint(
            lat: pts.last.lat + 1 * _degPerM,
            lng: -105,
            time: t0.add(const Duration(seconds: 13)),
            accuracyM: 5,
          ),
        ),
        isFalse,
      );
      expect(rec.distanceM, before);
    });

    test('a pause stops the clock and the line', () {
      final rec = LiveRecording.start(t0);
      for (final p in north(100)) {
        rec.addFix(p);
      }
      rec.pause(t0.add(const Duration(seconds: 100)));
      // Fixes while paused don't count.
      expect(
        rec.addFix(north(1, from: t0.add(const Duration(seconds: 150))).last),
        isFalse,
      );
      final back = t0.add(const Duration(seconds: 400));
      rec.resume(back);
      // Picks up 200 m further on (walked while paused): not counted.
      for (final p in north(100, from: back, startLat: 40 + 500 * _degPerM)) {
        rec.addFix(p);
      }
      final end = back.add(const Duration(seconds: 100));
      expect(rec.movingSecondsAt(end), 200);
      expect(rec.distanceM, closeTo(600, 2));
      final track = rec.toTrack();
      // Thinned to about every 10 m (every 4th fix at 3 m/s), broken at
      // the pause.
      expect(track.segmentStarts, hasLength(1));
      final segs = trackSegments(track);
      expect(segs, hasLength(2));
      expect(segs.first.length, inInclusiveRange(25, 30));
      expect(segs.first.last.$1, closeTo(40 + 300 * _degPerM, 1e-5));
    });

    test('elevation gain ignores small wobbles', () {
      final rec = LiveRecording.start(t0);
      final alts = <double>[
        1600,
        1601,
        1600,
        1602,
        1610,
        1609,
        1611,
        1605,
        1615,
      ];
      final pts = north(alts.length - 1);
      for (var i = 0; i < alts.length; i++) {
        final p = pts[i];
        rec.addFix(
          GpsPoint(
            lat: p.lat,
            lng: p.lng,
            time: p.time,
            accuracyM: 5,
            altitudeM: alts[i],
          ),
        );
      }
      // 1600 -> 1610 (+10), 1611 is noise, drop to 1605, -> 1615 (+10).
      expect(rec.elevationGainM, closeTo(20, 0.01));
    });

    test('saves and loads mid-run', () {
      final rec = LiveRecording.start(t0);
      for (final p in north(30, alt: 1600)) {
        rec.addFix(p);
      }
      rec.pause(t0.add(const Duration(seconds: 30)));
      final back = LiveRecording.fromJson(rec.toJson());
      expect(back.distanceM, rec.distanceM);
      expect(back.isPaused, isTrue);
      expect(back.points.length, rec.points.length);
      expect(back.movingSecondsAt(t0.add(const Duration(hours: 1))), 30);
    });

    test('the Show keeps a GpsTrack that survives JSON', () {
      final rec = LiveRecording.start(t0);
      for (final p in north(700, alt: 1600)) {
        rec.addFix(p);
      }
      rec.end(t0.add(const Duration(seconds: 700)));
      final show = Show(
        id: 's',
        date: t0.toLocal(),
        venue: Venue.live,
        workoutType: WorkoutType.easy,
        distanceMiles: rec.distanceMiles,
        durationSeconds: 700,
        effort: 5,
        feel: Feel.good,
        live: LiveDetails(gps: rec.toTrack()),
        createdAt: t0,
        updatedAt: t0,
      );
      final back = Show.fromJson(show.toJson());
      final gps = back.live!.gps!;
      final n = decodePolyline(gps.polyline).length;
      expect(n, inInclusiveRange(170, 180));
      expect(gps.seconds, hasLength(n));
      expect(gps.altitudeFt, hasLength(n));
      expect(gps.seconds.last, 700);
      expect(gps.splits.length, 1);
      // Old Live Shows have no route.
      final old = show.toJson()..['live'] = {'surface': 'road'};
      expect(Show.fromJson(old).live!.gps, isNull);
    });
  });

  group('Apple Health save', () {
    Show show({Venue venue = Venue.live, String? healthId}) => Show(
      id: 's',
      date: DateTime(2026, 11, 22, 7),
      venue: venue,
      workoutType: WorkoutType.easy,
      distanceMiles: 5,
      durationSeconds: 2700,
      effort: 5,
      feel: Feel.good,
      healthWorkoutId: healthId,
      createdAt: t0,
      updatedAt: t0,
    );

    test('a hand-logged Show runs from its start for its time', () {
      final run = healthRunFor(show(venue: Venue.studio));
      expect(run.start, DateTime(2026, 11, 22, 7));
      expect(run.end, DateTime(2026, 11, 22, 7, 45));
      expect(run.indoor, isTrue);
      expect(run.distanceMiles, 5);
    });

    test('a recorded Show spans its route, pauses included', () {
      final route = [
        GpsPoint(lat: 40, lng: -105, time: t0),
        GpsPoint(
          lat: 40.1,
          lng: -105,
          time: t0.add(const Duration(minutes: 50)),
        ),
      ];
      final run = healthRunFor(show(), route: route);
      expect(run.start, t0.toLocal());
      expect(run.end, t0.add(const Duration(minutes: 50)).toLocal());
      expect(run.indoor, isFalse);
    });

    test('heart rate summary drops impossible readings', () {
      final hr = summarizeHeartRate([140, 150, 160, 0, 400]);
      expect(hr!.average, 150);
      expect(hr.max, 160);
      expect(hr.samples, 3);
      expect(summarizeHeartRate([]), isNull);
    });
  });
}
