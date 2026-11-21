import 'json_utils.dart';

/// One treadmill segment of a Studio Session.
///
/// Times are elapsed seconds from the start of the Show, so a Track from
/// 10:00 to 15:00 has startSeconds 600 and endSeconds 900.
class Track {
  const Track({
    required this.startSeconds,
    required this.endSeconds,
    required this.speedMph,
    required this.inclinePercent,
  });

  final int startSeconds;
  final int endSeconds;
  final double speedMph;
  final double inclinePercent;

  int get durationSeconds =>
      endSeconds > startSeconds ? endSeconds - startSeconds : 0;

  /// mph × hours.
  double get distanceMiles => speedMph * durationSeconds / 3600;

  Track copyWith({
    int? startSeconds,
    int? endSeconds,
    double? speedMph,
    double? inclinePercent,
  }) =>
      Track(
        startSeconds: startSeconds ?? this.startSeconds,
        endSeconds: endSeconds ?? this.endSeconds,
        speedMph: speedMph ?? this.speedMph,
        inclinePercent: inclinePercent ?? this.inclinePercent,
      );

  Map<String, Object?> toJson() => {
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'speedMph': speedMph,
        'inclinePercent': inclinePercent,
      };

  factory Track.fromJson(Map<String, Object?> json) => Track(
        startSeconds: asInt(json['startSeconds']),
        endSeconds: asInt(json['endSeconds']),
        speedMph: asDouble(json['speedMph']),
        inclinePercent: asDouble(json['inclinePercent']),
      );

  @override
  bool operator ==(Object other) =>
      other is Track &&
      other.startSeconds == startSeconds &&
      other.endSeconds == endSeconds &&
      other.speedMph == speedMph &&
      other.inclinePercent == inclinePercent;

  @override
  int get hashCode =>
      Object.hash(startSeconds, endSeconds, speedMph, inclinePercent);
}
