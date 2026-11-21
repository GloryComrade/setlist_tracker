/// Pure math and formatting for Shows. No Flutter imports, so it is easy to
/// unit test and reuse in Phase 2's plan builder.
library;

import '../models/track.dart';

/// Seconds per mile, or null when there is no distance.
double? paceSecondsPerMileFor(double distanceMiles, int durationSeconds) {
  if (distanceMiles <= 0 || durationSeconds <= 0) return null;
  return durationSeconds / distanceMiles;
}

/// "8:42 /mi" style pace, or "–" when it can't be calculated.
String formatPace(double? secondsPerMile, {bool withUnit = true}) {
  if (secondsPerMile == null || !secondsPerMile.isFinite) return '–';
  var total = secondsPerMile.round();
  final minutes = total ~/ 60;
  final seconds = total % 60;
  final text = '$minutes:${seconds.toString().padLeft(2, '0')}';
  return withUnit ? '$text /mi' : text;
}

/// Treadmill speed (mph) to pace in seconds per mile.
double? paceFromMph(double mph) => mph > 0 ? 3600 / mph : null;

/// Pace in seconds per mile to treadmill speed (mph).
double? mphFromPace(double secondsPerMile) =>
    secondsPerMile > 0 ? 3600 / secondsPerMile : null;

/// "1:05:30" when over an hour, otherwise "45:30".
String formatDuration(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Parses what a runner types for a time.
///
/// "45" → 45 minutes, "45:30" → 45 min 30 s, "1:05:30" → 1 h 5 min 30 s.
/// Returns null for anything it can't read.
int? parseDuration(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length > 3) return null;
  final numbers = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p.trim());
    if (n == null || n < 0) return null;
    numbers.add(n);
  }
  switch (numbers.length) {
    case 1:
      return numbers[0] * 60;
    case 2:
      if (numbers[1] >= 60) return null;
      return numbers[0] * 60 + numbers[1];
    default:
      if (numbers[1] >= 60 || numbers[2] >= 60) return null;
      return numbers[0] * 3600 + numbers[1] * 60 + numbers[2];
  }
}

/// "6.2 mi" with up to two decimals, trailing zeros dropped.
String formatMiles(double miles, {bool withUnit = true}) {
  var text = miles.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return withUnit ? '$text mi' : text;
}

/// Totals for a list of treadmill Tracks.
class TrackTotals {
  const TrackTotals({
    required this.durationSeconds,
    required this.distanceMiles,
    required this.averageInclinePercent,
  });

  final int durationSeconds;
  final double distanceMiles;

  /// Time-weighted: a 30-minute Track counts more than a 2-minute one.
  final double averageInclinePercent;

  double? get paceSecondsPerMile =>
      paceSecondsPerMileFor(distanceMiles, durationSeconds);

  static TrackTotals of(List<Track> tracks) {
    var seconds = 0;
    var miles = 0.0;
    var inclineSeconds = 0.0;
    for (final t in tracks) {
      final d = t.durationSeconds;
      seconds += d;
      miles += t.distanceMiles;
      inclineSeconds += t.inclinePercent * d;
    }
    return TrackTotals(
      durationSeconds: seconds,
      distanceMiles: miles,
      averageInclinePercent: seconds == 0 ? 0 : inclineSeconds / seconds,
    );
  }
}

/// Monday of the week [d] falls in, at midnight.
DateTime weekStart(DateTime d) {
  // Built from parts (not subtract) so daylight-saving changes can't shift it.
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}
