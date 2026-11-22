/// Screen reader wording for Show numbers. Pure Dart, no Flutter imports.
///
/// The screen shows "15 mi", "9:20 /mi" and "2:20:00"; VoiceOver can read
/// "mi" as Michigan and "9:20" as a clock time. These say the same values in
/// words ("15 miles", "9 minutes 20 seconds per mile", "2 hours 20
/// minutes"), rounded exactly like [formatMiles], [formatPace] and
/// [formatDuration] in show_math.dart so the ear hears what the eye sees.
library;

import '../models/enums.dart';
import '../models/show.dart';
import '../models/song.dart';
import 'show_math.dart';

String _plural(int n, String one, String many) => n == 1 ? one : many;

/// "15 miles", "6.2 miles", "1 mile". Same rounding as [formatMiles].
String spokenMiles(double miles) {
  final text = formatMiles(miles, withUnit: false);
  return '$text ${text == '1' ? 'mile' : 'miles'}';
}

/// "9 minutes 20 seconds per mile", or "no pace" when [formatPace] shows "–".
String spokenPace(double? secondsPerMile) {
  if (secondsPerMile == null || !secondsPerMile.isFinite) return 'no pace';
  return '${_minutesSeconds(secondsPerMile.round())} per mile';
}

/// "2 hours 20 minutes", "45 minutes 30 seconds", "1 hour 5 seconds".
/// Same whole seconds as [formatDuration]; zero parts are left out.
String spokenDuration(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final h = totalSeconds ~/ 3600;
  final rest = totalSeconds % 3600;
  if (h == 0) return _minutesSeconds(rest);
  final hours = '$h ${_plural(h, 'hour', 'hours')}';
  return rest == 0 ? hours : '$hours ${_minutesSeconds(rest)}';
}

String _minutesSeconds(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  final parts = [
    if (m > 0) '$m ${_plural(m, 'minute', 'minutes')}',
    if (s > 0 || m == 0) '$s ${_plural(s, 'second', 'seconds')}',
  ];
  return parts.join(' ');
}

final _pace = RegExp(r'^(\d+):(\d{2}) /mi$');
final _miles = RegExp(r'^(\d+(?:\.\d+)?) mi$');
final _clock = RegExp(r'^(?:(\d+):)?(\d+):(\d{2})$');
final _range = RegExp(r'^(\d+:\d{2})–(\d+:\d{2})( /mi)?$');
final _outOfTen = RegExp(r'^(\d+)/10$');
final _units = <RegExp, String>{
  RegExp(r'°F$'): ' degrees Fahrenheit',
  RegExp(r' mph$'): ' miles per hour',
  RegExp(r' ft$'): ' feet',
};

/// Spoken form of a value already formatted for a stat, such as a
/// [StatTile] value: "8:42 /mi", "15 mi", "1:05:30", "6/10", "48°F",
/// "7 mph", "320 ft". Anything else comes back unchanged.
String spokenStat(String value) {
  final v = value.trim();
  var m = _pace.firstMatch(v);
  if (m != null) {
    return spokenPace((int.parse(m[1]!) * 60 + int.parse(m[2]!)).toDouble());
  }
  m = _miles.firstMatch(v);
  if (m != null) return spokenMiles(double.parse(m[1]!));
  m = _clock.firstMatch(v);
  if (m != null) {
    final h = int.parse(m[1] ?? '0');
    return spokenDuration(h * 3600 + int.parse(m[2]!) * 60 + int.parse(m[3]!));
  }
  m = _range.firstMatch(v);
  if (m != null) {
    final unit = m[3] ?? '';
    return '${spokenStat(m[1]!)} to ${spokenStat('${m[2]}$unit')}';
  }
  m = _outOfTen.firstMatch(v);
  if (m != null) return '${m[1]} of 10';
  for (final e in _units.entries) {
    if (e.key.hasMatch(v)) return v.replaceFirst(e.key, e.value);
  }
  return value;
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Sunday 22. Headliner, Live Show." The ticket stub and workout line.
String spokenShowHeading(DateTime date, WorkoutType workout, Venue venue) =>
    '${_weekdays[date.weekday - 1]} ${date.day}. '
    '${workout.label}, ${venue.label}.';

/// "15 miles, 9 minutes 20 seconds per mile, 2 hours 20 minutes."
String spokenShowNumbers(double miles, int durationSeconds) =>
    '${spokenMiles(miles)}, '
    '${spokenPace(paceSecondsPerMileFor(miles, durationSeconds))}, '
    '${spokenDuration(durationSeconds)}.';

/// "Song: Lose Yourself by Eminem."
String spokenSong(SongOfTheShow song) =>
    'Song: ${song.title} by ${song.artist}.';

/// Everything a Show card on the Setlist says, in reading order:
/// "Sunday 22. Headliner, Live Show. 15 miles, 9 minutes 20 seconds per
/// mile, 2 hours 20 minutes. Effort 6 of 10, felt Fine. Song: Lose Yourself
/// by Eminem."
String spokenShow(Show show) {
  final song = show.song;
  return [
    spokenShowHeading(show.date, show.workoutType, show.venue),
    spokenShowNumbers(show.distanceMiles, show.durationSeconds),
    'Effort ${show.effort} of 10, felt ${show.feel.label}.',
    if (song != null) spokenSong(song),
  ].join(' ');
}
