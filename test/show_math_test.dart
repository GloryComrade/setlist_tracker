import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/show_math.dart';
import 'package:setlist_tracker/models/track.dart';

void main() {
  group('pace', () {
    test('6.2 miles in 52:00 is 8:23 /mi', () {
      final pace = paceSecondsPerMileFor(6.2, 52 * 60);
      expect(formatPace(pace), '8:23 /mi');
    });

    test('no distance gives a dash', () {
      expect(formatPace(paceSecondsPerMileFor(0, 600)), '–');
    });

    test('mph converts to pace and back', () {
      expect(formatPace(paceFromMph(6.0)), '10:00 /mi');
      expect(mphFromPace(480), 7.5);
    });
  });

  group('parseDuration', () {
    test('reads minutes, mm:ss and h:mm:ss', () {
      expect(parseDuration('45'), 2700);
      expect(parseDuration('45:30'), 2730);
      expect(parseDuration('1:05:30'), 3930);
    });

    test('rejects junk', () {
      expect(parseDuration(''), isNull);
      expect(parseDuration('4:75'), isNull);
      expect(parseDuration('a:b'), isNull);
    });

    test('round-trips with formatDuration', () {
      for (final s in [0, 59, 600, 3599, 3600, 3930, 10800]) {
        expect(parseDuration(formatDuration(s)), s);
      }
    });
  });

  group('TrackTotals', () {
    test('adds time and distance, weights incline by time', () {
      const tracks = [
        // 30 min at 6 mph, 1% → 3 miles
        Track(startSeconds: 0, endSeconds: 1800, speedMph: 6, inclinePercent: 1),
        // 10 min at 7.5 mph, 5% → 1.25 miles
        Track(startSeconds: 1800, endSeconds: 2400, speedMph: 7.5, inclinePercent: 5),
      ];
      final t = TrackTotals.of(tracks);
      expect(t.durationSeconds, 2400);
      expect(t.distanceMiles, closeTo(4.25, 1e-9));
      // (1 × 30 + 5 × 10) / 40 = 2.0
      expect(t.averageInclinePercent, closeTo(2.0, 1e-9));
    });

    test('empty list is all zeros', () {
      final t = TrackTotals.of(const []);
      expect(t.durationSeconds, 0);
      expect(t.distanceMiles, 0);
      expect(t.averageInclinePercent, 0);
    });

    test('a Track that ends before it starts counts as zero', () {
      const t = Track(startSeconds: 600, endSeconds: 300, speedMph: 6, inclinePercent: 1);
      expect(t.durationSeconds, 0);
      expect(t.distanceMiles, 0);
    });
  });

  test('weekStart is Monday', () {
    // Sat 2026-11-21 → Mon 2026-11-16
    expect(weekStart(DateTime(2026, 11, 21, 7, 30)), DateTime(2026, 11, 16));
    expect(weekStart(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
  });

  test('formatMiles trims zeros', () {
    expect(formatMiles(6.2), '6.2 mi');
    expect(formatMiles(5), '5 mi');
    expect(formatMiles(4.256, withUnit: false), '4.26');
  });
}
