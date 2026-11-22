/// GPS math for recording a Live Show. Pure Dart, no plugins, so the whole
/// recorder can be unit tested with made-up fixes.
library;

import 'dart:math' as math;

import '../models/gps_track.dart';
import '../models/json_utils.dart';

const metersPerMile = 1609.344;
const feetPerMeter = 3.28084;

/// Fixes less accurate than this are ignored (city canyons, first seconds).
const maxFixAccuracyM = 30.0;

/// Faster than this between two fixes is a GPS jump, not running (about
/// 25 mph).
const maxRunSpeedMps = 11.0;

/// Fixes closer than this to the last kept one are jitter, not progress.
const minStepM = 3.0;

/// Climbs smaller than this are altitude noise.
const elevationNoiseM = 3.0;

/// The saved route keeps a point about this often.
const trackStepM = 10.0;

/// Current pace is read over this much recent moving time.
const currentPaceWindowSeconds = 30;

/// Great-circle distance in meters.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371008.8;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

// ---- Encoded polyline (Google's format, 5 decimal places) ----

String encodePolyline(List<(double, double)> points) {
  final out = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  void write(int v) {
    // Arithmetic, not ~ and <<: on the web those are unsigned 32-bit.
    var n = v < 0 ? -v * 2 - 1 : v * 2;
    while (n >= 0x20) {
      out.writeCharCode((0x20 | (n & 0x1f)) + 63);
      n >>= 5;
    }
    out.writeCharCode(n + 63);
  }

  for (final (lat, lng) in points) {
    final la = (lat * 1e5).round();
    final ln = (lng * 1e5).round();
    write(la - lastLat);
    write(ln - lastLng);
    lastLat = la;
    lastLng = ln;
  }
  return out.toString();
}

List<(double, double)> decodePolyline(String encoded) {
  final points = <(double, double)>[];
  var i = 0;
  var lat = 0;
  var lng = 0;
  int? read() {
    var shift = 0;
    var result = 0;
    while (true) {
      if (i >= encoded.length) return null;
      final b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
      if (b < 0x20) break;
    }
    return (result & 1) != 0 ? -(result >> 1) - 1 : result >> 1;
  }

  while (i < encoded.length) {
    final dLat = read();
    final dLng = read();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    points.add((lat / 1e5, lng / 1e5));
  }
  return points;
}

// ---- The recording ----

/// A kept fix plus where the run was at that moment.
class RecordedPoint {
  const RecordedPoint({
    required this.fix,
    required this.movingSeconds,
    required this.distanceM,
    required this.segment,
  });

  final GpsPoint fix;

  /// Moving time (pauses left out) when this fix arrived.
  final double movingSeconds;

  /// Distance run up to this fix.
  final double distanceM;

  /// Which stretch between pauses it belongs to, from 0.
  final int segment;

  Map<String, Object?> toJson() => {
    ...fix.toJson(),
    'mv': movingSeconds,
    'd': distanceM,
    'seg': segment,
  };

  factory RecordedPoint.fromJson(Map<String, Object?> json) => RecordedPoint(
    fix: GpsPoint.fromJson(json),
    movingSeconds: asDouble(json['mv']),
    distanceM: asDouble(json['d']),
    segment: asInt(json['seg']),
  );
}

/// A Live Show being recorded: start time, the stretches between pauses, and
/// every kept fix. Everything shown on the On Stage screen is worked out
/// from this, and it is saved as JSON as the run goes, so a closed app can
/// pick the run back up.
class LiveRecording {
  LiveRecording({
    required this.startedAt,
    List<DateTime>? resumes,
    List<DateTime>? pauses,
    List<RecordedPoint>? points,
    this.elevationGainM = 0,
    this.elevationBaseM,
    List<double>? splitMovingSeconds,
    this.endedAt,
  }) : resumes = resumes ?? [startedAt],
       pauses = pauses ?? [],
       points = points ?? [],
       splitMovingSeconds = splitMovingSeconds ?? [];

  factory LiveRecording.start(DateTime now) =>
      LiveRecording(startedAt: now.toUtc());

  final DateTime startedAt;

  /// When each moving stretch began; the first is [startedAt].
  final List<DateTime> resumes;

  /// When each stretch ended. One shorter than [resumes] while moving.
  final List<DateTime> pauses;
  final List<RecordedPoint> points;
  double elevationGainM;
  double? elevationBaseM;

  /// Moving time at the end of mile 1, mile 2, ... (cumulative).
  final List<double> splitMovingSeconds;

  /// Set when the runner ends the Show.
  DateTime? endedAt;

  bool get isPaused => pauses.length == resumes.length;
  bool get isEnded => endedAt != null;
  int get segment => resumes.length - 1;

  double get distanceM => points.isEmpty ? 0 : points.last.distanceM;
  double get distanceMiles => distanceM / metersPerMile;
  double get elevationGainFt => elevationGainM * feetPerMeter;

  /// Moving time up to [now] (or the end), pauses left out.
  double movingSecondsAt(DateTime now) {
    var total = 0.0;
    for (var i = 0; i < resumes.length; i++) {
      final end = i < pauses.length ? pauses[i] : (endedAt ?? now);
      final s = end.difference(resumes[i]).inMilliseconds / 1000;
      if (s > 0) total += s;
    }
    return total;
  }

  /// Seconds per mile over the whole Show so far.
  double? averagePaceAt(DateTime now) {
    final miles = distanceMiles;
    if (miles < 0.05) return null;
    return movingSecondsAt(now) / miles;
  }

  /// Seconds per mile over the last [currentPaceWindowSeconds] of moving time
  /// in this stretch. Null while paused or before there's enough to read.
  double? currentPaceAt(DateTime now) {
    if (isPaused || points.isEmpty || points.last.segment != segment) {
      return null;
    }
    final last = points.last;
    final nowMoving = movingSecondsAt(now);
    // No fix for a while: probably standing still.
    if (nowMoving - last.movingSeconds > 15) return null;
    RecordedPoint? from;
    for (var i = points.length - 1; i >= 0; i--) {
      final p = points[i];
      if (p.segment != segment) break;
      from = p;
      if (last.movingSeconds - p.movingSeconds >= currentPaceWindowSeconds) {
        break;
      }
    }
    if (from == null) return null;
    final meters = last.distanceM - from.distanceM;
    final seconds = last.movingSeconds - from.movingSeconds;
    if (meters < 10 || seconds < 5) return null;
    return seconds / (meters / metersPerMile);
  }

  /// Moving seconds each full mile took.
  List<int> get splits {
    final out = <int>[];
    var prev = 0.0;
    for (final s in splitMovingSeconds) {
      out.add((s - prev).round());
      prev = s;
    }
    return out;
  }

  void pause(DateTime now) {
    if (isPaused || isEnded) return;
    pauses.add(now.toUtc());
  }

  void resume(DateTime now) {
    if (!isPaused || isEnded) return;
    resumes.add(now.toUtc());
  }

  void end(DateTime now) {
    if (isEnded) return;
    pause(now);
    endedAt = now.toUtc();
  }

  /// Adds a fix if it is good enough. Returns true when it was kept.
  bool addFix(GpsPoint fix) {
    if (isPaused || isEnded) return false;
    final acc = fix.accuracyM;
    if (acc != null && (acc < 0 || acc > maxFixAccuracyM)) return false;
    final t = fix.time.toUtc();
    if (t.isBefore(resumes.last)) return false;
    final moving = movingSecondsAt(t);
    final last = points.isEmpty ? null : points.last;
    var distance = last?.distanceM ?? 0;
    if (last != null && last.segment == segment) {
      final step = haversineMeters(
        last.fix.lat,
        last.fix.lng,
        fix.lat,
        fix.lng,
      );
      final dt = moving - last.movingSeconds;
      if (dt <= 0) return false;
      if (step < minStepM) return false;
      if (step / dt > maxRunSpeedMps) return false;
      // Mile splits: the moving time where each mile line was crossed.
      final before = distance;
      distance += step;
      var nextMile = (splitMovingSeconds.length + 1) * metersPerMile;
      while (distance >= nextMile) {
        final f = (nextMile - before) / step;
        splitMovingSeconds.add(last.movingSeconds + dt * f);
        nextMile += metersPerMile;
      }
    }
    final alt = fix.altitudeM;
    if (alt != null) {
      final base = elevationBaseM;
      if (base == null) {
        elevationBaseM = alt;
      } else if (alt - base >= elevationNoiseM) {
        elevationGainM += alt - base;
        elevationBaseM = alt;
      } else if (base - alt >= elevationNoiseM) {
        elevationBaseM = alt;
      }
    }
    points.add(
      RecordedPoint(
        fix: fix,
        movingSeconds: moving,
        distanceM: distance,
        segment: segment,
      ),
    );
    return true;
  }

  /// The route to keep on the Show.
  GpsTrack toTrack() {
    // Thinned to a point every [trackStepM] (plus each stretch's first and
    // last), so a marathon stays a few thousand points when it syncs.
    final kept = <RecordedPoint>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final prev = kept.isEmpty ? null : kept.last;
      final edge =
          prev == null ||
          prev.segment != p.segment ||
          i == points.length - 1 ||
          points[i + 1].segment != p.segment;
      if (edge || p.distanceM - prev.distanceM >= trackStepM) kept.add(p);
    }
    final segmentStarts = <int>[];
    for (var i = 1; i < kept.length; i++) {
      if (kept[i].segment != kept[i - 1].segment) segmentStarts.add(i);
    }
    return GpsTrack(
      polyline: encodePolyline([for (final p in kept) (p.fix.lat, p.fix.lng)]),
      seconds: [
        for (final p in kept) p.fix.time.difference(startedAt).inSeconds,
      ],
      altitudeFt: [
        for (final p in kept) ((p.fix.altitudeM ?? 0) * feetPerMeter).round(),
      ],
      splits: splits,
      segmentStarts: segmentStarts,
    );
  }

  Map<String, Object?> toJson() => {
    'startedAt': utcString(startedAt),
    'resumes': [for (final r in resumes) utcString(r)],
    'pauses': [for (final p in pauses) utcString(p)],
    'points': [for (final p in points) p.toJson()],
    'elevationGainM': elevationGainM,
    'elevationBaseM': elevationBaseM,
    'splits': splitMovingSeconds,
    'endedAt': endedAt == null ? null : utcString(endedAt!),
  };

  factory LiveRecording.fromJson(Map<String, Object?> json) {
    final start =
        parseDate(json['startedAt'])?.toUtc() ?? DateTime.now().toUtc();
    List<DateTime> dates(Object? v) =>
        v is List ? [for (final e in v) ?parseDate(e)?.toUtc()] : <DateTime>[];
    final resumes = dates(json['resumes']);
    return LiveRecording(
      startedAt: start,
      resumes: resumes.isEmpty ? [start] : resumes,
      pauses: dates(json['pauses']),
      points: asMapList(json['points']).map(RecordedPoint.fromJson).toList(),
      elevationGainM: asDouble(json['elevationGainM']),
      elevationBaseM: asDoubleOrNull(json['elevationBaseM']),
      splitMovingSeconds: json['splits'] is List
          ? [for (final e in json['splits'] as List) asDouble(e)]
          : [],
      endedAt: parseDate(json['endedAt'])?.toUtc(),
    );
  }
}

/// The points of a saved [GpsTrack], split at pauses, for drawing.
List<List<(double, double)>> trackSegments(GpsTrack track) {
  final pts = decodePolyline(track.polyline);
  if (pts.isEmpty) return const [];
  final cuts = [
    0,
    ...track.segmentStarts.where((i) => i > 0 && i < pts.length),
    pts.length,
  ];
  return [
    for (var i = 0; i < cuts.length - 1; i++)
      if (cuts[i + 1] > cuts[i]) pts.sublist(cuts[i], cuts[i + 1]),
  ];
}
