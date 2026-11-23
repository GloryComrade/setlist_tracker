import '../logic/show_math.dart';
import 'enums.dart';
import 'gps_track.dart';
import 'json_utils.dart';
import 'track.dart';

/// Extra details for a Studio Session (treadmill run).
class StudioDetails {
  const StudioDetails({
    this.gymName,
    this.treadmillName,
    this.savedMixId,
    this.tracks = const [],
    this.useTrackTotals = true,
    this.inclinePercent,
  });

  /// Highest grade most treadmills go to. Typed inclines are kept to 0 to 15.
  static const maxInclinePercent = 15.0;

  final String? gymName;
  final String? treadmillName;

  /// The Saved Mix this Show started from, if any. Its Tracks were copied in,
  /// so editing the Mix later never changes this Show.
  final String? savedMixId;

  final List<Track> tracks;

  /// When true, the Show's distance and duration come from the Tracks.
  /// When false, the runner typed them (treadmill readouts often differ).
  final bool useTrackTotals;

  /// The incline typed for a Studio Session logged without Tracks, in
  /// percent grade. Ignored once the Show has Tracks: each Track keeps its own.
  final double? inclinePercent;

  TrackTotals get totals => TrackTotals.of(tracks);

  /// The Show's incline: the Tracks' time-weighted average when there are
  /// Tracks, else the typed incline. Null when neither says.
  double? get averageInclinePercent =>
      tracks.isNotEmpty ? totals.averageInclinePercent : inclinePercent;

  Map<String, Object?> toJson() => {
    'gymName': gymName,
    'treadmillName': treadmillName,
    'savedMixId': savedMixId,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'useTrackTotals': useTrackTotals,
    // Absent on Shows saved before build 6, and on Shows with Tracks.
    if (inclinePercent != null) 'inclinePercent': inclinePercent,
  };

  factory StudioDetails.fromJson(Map<String, Object?> json) => StudioDetails(
    gymName: asStringOrNull(json['gymName']),
    treadmillName: asStringOrNull(json['treadmillName']),
    savedMixId: asStringOrNull(json['savedMixId']),
    tracks: asMapList(json['tracks']).map(Track.fromJson).toList(),
    useTrackTotals: json['useTrackTotals'] != false,
    inclinePercent: asDoubleOrNull(json['inclinePercent']),
  );
}

class Weather {
  const Weather({this.tempF, this.windMph, this.conditions});

  final double? tempF;
  final double? windMph;
  final Conditions? conditions;

  bool get isEmpty => tempF == null && windMph == null && conditions == null;

  Map<String, Object?> toJson() => {
    'tempF': tempF,
    'windMph': windMph,
    'conditions': conditions?.name,
  };

  factory Weather.fromJson(Map<String, Object?> json) => Weather(
    tempF: asDoubleOrNull(json['tempF']),
    windMph: asDoubleOrNull(json['windMph']),
    conditions: Conditions.fromName(asStringOrNull(json['conditions'])),
  );
}

/// Extra details for a Live Show (outdoor run).
class LiveDetails {
  const LiveDetails({
    this.routeName,
    this.surface = Surface.road,
    this.elevationGainFt,
    this.weather,
    this.gpxFileId,
    this.gps,
  });

  final String? routeName;
  final Surface surface;
  final double? elevationGainFt;
  final Weather? weather;

  /// Reserved for GPX import (later phase). Always null in Phase 1.
  final String? gpxFileId;

  /// The GPS route, when the Show was recorded with Go Live.
  final GpsTrack? gps;

  Map<String, Object?> toJson() => {
    'routeName': routeName,
    'surface': surface.name,
    'elevationGainFt': elevationGainFt,
    'weather': weather?.toJson(),
    'gpxFileId': gpxFileId,
    if (gps != null) 'gps': gps!.toJson(),
  };

  factory LiveDetails.fromJson(Map<String, Object?> json) {
    final weather = asMap(json['weather']);
    final gps = asMap(json['gps']);
    return LiveDetails(
      routeName: asStringOrNull(json['routeName']),
      surface: Surface.fromName(asStringOrNull(json['surface'])),
      elevationGainFt: asDoubleOrNull(json['elevationGainFt']),
      weather: weather == null ? null : Weather.fromJson(weather),
      gpxFileId: asStringOrNull(json['gpxFileId']),
      gps: gps == null ? null : GpsTrack.fromJson(gps),
    );
  }
}
