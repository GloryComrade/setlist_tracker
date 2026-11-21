import '../logic/show_math.dart';
import 'enums.dart';
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
  });

  final String? gymName;
  final String? treadmillName;

  /// The Saved Mix this Show started from, if any. Its Tracks were copied in,
  /// so editing the Mix later never changes this Show.
  final String? savedMixId;

  final List<Track> tracks;

  /// When true, the Show's distance and duration come from the Tracks.
  /// When false, the runner typed them (treadmill readouts often differ).
  final bool useTrackTotals;

  TrackTotals get totals => TrackTotals.of(tracks);

  Map<String, Object?> toJson() => {
        'gymName': gymName,
        'treadmillName': treadmillName,
        'savedMixId': savedMixId,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'useTrackTotals': useTrackTotals,
      };

  factory StudioDetails.fromJson(Map<String, Object?> json) => StudioDetails(
        gymName: asStringOrNull(json['gymName']),
        treadmillName: asStringOrNull(json['treadmillName']),
        savedMixId: asStringOrNull(json['savedMixId']),
        tracks: asMapList(json['tracks']).map(Track.fromJson).toList(),
        useTrackTotals: json['useTrackTotals'] != false,
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
  });

  final String? routeName;
  final Surface surface;
  final double? elevationGainFt;
  final Weather? weather;

  /// Reserved for GPX import (later phase). Always null in Phase 1.
  final String? gpxFileId;

  Map<String, Object?> toJson() => {
        'routeName': routeName,
        'surface': surface.name,
        'elevationGainFt': elevationGainFt,
        'weather': weather?.toJson(),
        'gpxFileId': gpxFileId,
      };

  factory LiveDetails.fromJson(Map<String, Object?> json) {
    final weather = asMap(json['weather']);
    return LiveDetails(
      routeName: asStringOrNull(json['routeName']),
      surface: Surface.fromName(asStringOrNull(json['surface'])),
      elevationGainFt: asDoubleOrNull(json['elevationGainFt']),
      weather: weather == null ? null : Weather.fromJson(weather),
      gpxFileId: asStringOrNull(json['gpxFileId']),
    );
  }
}
