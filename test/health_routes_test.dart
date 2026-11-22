import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/data/health/health_source.dart';
import 'package:setlist_tracker/logic/gps_math.dart';
import 'package:setlist_tracker/logic/health_import.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/gps_track.dart';
import 'package:setlist_tracker/models/venue_details.dart';

final t0 = DateTime.utc(2026, 11, 20, 13);
const _degPerM = 1 / 111195.0;

/// An Apple Watch route: due north at 3 m/s, a fix a second.
List<GpsPoint> watchRoute(int seconds, {DateTime? from}) => [
  for (var i = 0; i <= seconds; i++)
    GpsPoint(
      lat: 40 + i * 3 * _degPerM,
      lng: -105,
      time: (from ?? t0).add(Duration(seconds: i)),
      accuracyM: 5,
    ),
];

HealthRun run(String id, {bool? indoor, List<GpsPoint> route = const []}) =>
    HealthRun(
      uuid: id,
      start: t0.toLocal(),
      end: t0.add(const Duration(seconds: 900)).toLocal(),
      distanceMiles: 1.68,
      durationSeconds: 900,
      indoor: indoor,
      route: route,
    );

void main() {
  group('matchRoute', () {
    final mine = (
      start: t0,
      end: t0.add(const Duration(minutes: 15)),
      fixes: watchRoute(900),
    );
    final other = (
      start: t0.add(const Duration(hours: 3)),
      end: t0.add(const Duration(hours: 4)),
      fixes: watchRoute(10),
    );

    test('picks the route recorded during the run', () {
      expect(
        matchRoute(t0, t0.add(const Duration(minutes: 15)), [other, mine]),
        same(mine.fixes),
      );
    });

    test('ignores routes from another time', () {
      expect(
        matchRoute(t0, t0.add(const Duration(minutes: 15)), [other]),
        isNull,
      );
    });

    test('ignores a route that barely touches the run', () {
      final edge = (
        start: t0.add(const Duration(minutes: 14)),
        end: t0.add(const Duration(minutes: 60)),
        fixes: watchRoute(10),
      );
      expect(
        matchRoute(t0, t0.add(const Duration(minutes: 15)), [edge]),
        isNull,
      );
    });
  });

  test('an imported outdoor run keeps its route as a map', () {
    final show = showFromHealthRun(run('w1', route: watchRoute(900)), now: t0);
    final gps = show.live!.gps!;
    expect(decodePolyline(gps.polyline).length, greaterThan(100));
    expect(gps.splits, hasLength(1));
  });

  test('treadmill runs and runs without GPS have no map', () {
    expect(
      showFromHealthRun(
        run('w2', indoor: true, route: watchRoute(60)),
        now: t0,
      ).live,
      isNull,
    );
    expect(showFromHealthRun(run('w3'), now: t0).live!.gps, isNull);
  });

  test('Shows imported before routes get theirs on the next import', () {
    final old = showFromHealthRun(run('w4'), now: t0);
    final withMap = showFromHealthRun(
      run('w5', route: watchRoute(60)),
      now: t0,
    );
    final handLogged = showFromHealthRun(run('w6'), now: t0).copyWith();
    final updated = showsWithNewRoutes(
      [run('w4', route: watchRoute(900)), run('w5', route: watchRoute(900))],
      [old, withMap, handLogged],
      now: t0.add(const Duration(days: 1)),
    );
    expect(updated.map((s) => s.id), [old.id]);
    final live = updated.single.live!;
    expect(live.gps, isNotNull);
    expect(live.surface, old.live!.surface);
    expect(updated.single.healthWorkoutId, 'w4');
    expect(updated.single.venue, Venue.live);
    expect(const LiveDetails().gps, isNull);
  });
}
