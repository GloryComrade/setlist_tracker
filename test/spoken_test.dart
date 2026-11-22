import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/show_math.dart';
import 'package:setlist_tracker/logic/spoken.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/song.dart';

void main() {
  group('spokenMiles', () {
    test('says miles, singular for exactly one', () {
      expect(spokenMiles(15), '15 miles');
      expect(spokenMiles(6.2), '6.2 miles');
      expect(spokenMiles(1), '1 mile');
      expect(spokenMiles(0), '0 miles');
    });

    test('rounds like formatMiles', () {
      for (final m in [3.105, 13.1, 26.2188, 0.999, 1.004]) {
        expect(
          spokenMiles(m),
          startsWith('${formatMiles(m, withUnit: false)} '),
        );
      }
      expect(spokenMiles(1.004), '1 mile');
    });
  });

  group('spokenPace', () {
    test('minutes and seconds per mile', () {
      expect(spokenPace(560), '9 minutes 20 seconds per mile');
      expect(spokenPace(600), '10 minutes per mile');
      expect(spokenPace(61), '1 minute 1 second per mile');
      expect(spokenPace(45), '45 seconds per mile');
    });

    test('rounds like formatPace', () {
      final pace = paceSecondsPerMileFor(6.2, 52 * 60);
      expect(formatPace(pace), '8:23 /mi');
      expect(spokenPace(pace), '8 minutes 23 seconds per mile');
      expect(spokenPace(599.6), '10 minutes per mile');
    });

    test('no pace where formatPace shows a dash', () {
      expect(spokenPace(null), 'no pace');
      expect(spokenPace(double.infinity), 'no pace');
    });
  });

  group('spokenDuration', () {
    test('leaves out zero parts', () {
      expect(spokenDuration(8400), '2 hours 20 minutes');
      expect(spokenDuration(3930), '1 hour 5 minutes 30 seconds');
      expect(spokenDuration(3605), '1 hour 5 seconds');
      expect(spokenDuration(3600), '1 hour');
      expect(spokenDuration(2730), '45 minutes 30 seconds');
      expect(spokenDuration(60), '1 minute');
      expect(spokenDuration(0), '0 seconds');
      expect(spokenDuration(-5), '0 seconds');
    });
  });

  group('spokenStat', () {
    test('reads formatted stat values', () {
      expect(spokenStat('8:42 /mi'), '8 minutes 42 seconds per mile');
      expect(spokenStat('15 mi'), '15 miles');
      expect(spokenStat('1:05:30'), '1 hour 5 minutes 30 seconds');
      expect(spokenStat('45:30'), '45 minutes 30 seconds');
      expect(spokenStat('6/10'), '6 of 10');
      expect(spokenStat('48°F'), '48 degrees Fahrenheit');
      expect(spokenStat('7 mph'), '7 miles per hour');
      expect(spokenStat('320 ft'), '320 feet');
      expect(spokenStat('8:30–9:00'), '8 minutes 30 seconds to 9 minutes');
    });

    test('round-trips the formatters', () {
      expect(spokenStat(formatMiles(13.1)), spokenMiles(13.1));
      expect(spokenStat(formatPace(531)), spokenPace(531));
      expect(spokenStat(formatDuration(8400)), spokenDuration(8400));
    });

    test('leaves words alone', () {
      expect(spokenStat('Headliner'), 'Headliner');
      expect(spokenStat('Road'), 'Road');
      expect(spokenStat('12'), '12');
    });
  });

  test('a whole Show card in words', () {
    final show = Show(
      id: 's1',
      date: DateTime(2026, 11, 22, 7),
      venue: Venue.live,
      workoutType: WorkoutType.long,
      distanceMiles: 15,
      durationSeconds: 8400,
      effort: 6,
      feel: Feel.fine,
      song: const SongOfTheShow(title: 'Lose Yourself', artist: 'Eminem'),
      createdAt: DateTime.utc(2026, 11, 22),
      updatedAt: DateTime.utc(2026, 11, 22),
    );
    expect(
      spokenShow(show),
      'Sunday 22. Headliner, Live Show. 15 miles, 9 minutes 20 seconds per '
      'mile, 2 hours 20 minutes. Effort 6 of 10, felt Fine. Song: Lose '
      'Yourself by Eminem.',
    );
  });
}
