import 'json_utils.dart';

/// One GPS fix, in the units the phone gives (degrees, meters), plus the
/// time since the Show started.
class GpsPoint {
  const GpsPoint({
    required this.lat,
    required this.lng,
    required this.time,
    this.altitudeM,
    this.accuracyM,
  });

  final double lat;
  final double lng;

  /// Wall-clock time of the fix (UTC).
  final DateTime time;
  final double? altitudeM;

  /// Horizontal accuracy radius. Null when the phone doesn't say.
  final double? accuracyM;

  Map<String, Object?> toJson() => {
    'lat': lat,
    'lng': lng,
    't': time.toUtc().millisecondsSinceEpoch,
    if (altitudeM != null) 'alt': altitudeM,
    if (accuracyM != null) 'acc': accuracyM,
  };

  factory GpsPoint.fromJson(Map<String, Object?> json) => GpsPoint(
    lat: asDouble(json['lat']),
    lng: asDouble(json['lng']),
    time: DateTime.fromMillisecondsSinceEpoch(asInt(json['t']), isUtc: true),
    altitudeM: asDoubleOrNull(json['alt']),
    accuracyM: asDoubleOrNull(json['acc']),
  );
}

/// The GPS route of a recorded Live Show, kept small enough to sync.
///
/// [polyline] is Google's encoded polyline format (5 decimal places, about a
/// meter). [seconds] holds, for each point, the seconds since the Show
/// started, and [altitudeFt] its altitude in feet (rounded), so the route can
/// be drawn, replayed and written to Apple Health with its times. [splits]
/// are the moving seconds each full mile took.
class GpsTrack {
  const GpsTrack({
    required this.polyline,
    this.seconds = const [],
    this.altitudeFt = const [],
    this.splits = const [],
    this.segmentStarts = const [],
  });

  final String polyline;
  final List<int> seconds;
  final List<int> altitudeFt;

  /// Moving seconds for mile 1, mile 2, ... Only full miles.
  final List<int> splits;

  /// Index of the first point of each stretch after a pause (the line is
  /// not drawn across a pause). Empty when the Show was never paused.
  final List<int> segmentStarts;

  bool get isEmpty => polyline.isEmpty;

  Map<String, Object?> toJson() => {
    'polyline': polyline,
    'seconds': seconds,
    'altitudeFt': altitudeFt,
    'splits': splits,
    if (segmentStarts.isNotEmpty) 'segmentStarts': segmentStarts,
  };

  factory GpsTrack.fromJson(Map<String, Object?> json) => GpsTrack(
    polyline: asStringOrNull(json['polyline']) ?? '',
    seconds: _ints(json['seconds']),
    altitudeFt: _ints(json['altitudeFt']),
    splits: _ints(json['splits']),
    segmentStarts: _ints(json['segmentStarts']),
  );

  static List<int> _ints(Object? v) =>
      v is List ? [for (final e in v) asInt(e)] : const [];
}
