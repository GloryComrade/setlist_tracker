import '../logic/show_math.dart';
import 'entity.dart';
import 'json_utils.dart';
import 'track.dart';

/// A saved treadmill setup that fills in a Studio Session in one tap.
class SavedMix implements Entity {
  const SavedMix({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
    required this.updatedAt,
    this.gymName,
    this.treadmillName,
    this.deletedAt,
  });

  @override
  final String id;
  final String name;
  final String? gymName;
  final String? treadmillName;
  final List<Track> tracks;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  TrackTotals get totals => TrackTotals.of(tracks);

  SavedMix copyWith({
    String? name,
    String? gymName,
    String? treadmillName,
    List<Track>? tracks,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => SavedMix(
    id: id,
    name: name ?? this.name,
    gymName: gymName ?? this.gymName,
    treadmillName: treadmillName ?? this.treadmillName,
    tracks: tracks ?? this.tracks,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': kSchemaVersion,
    'id': id,
    'name': name,
    'gymName': gymName,
    'treadmillName': treadmillName,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'createdAt': utcString(createdAt),
    'updatedAt': utcString(updatedAt),
    'deletedAt': deletedAt == null ? null : utcString(deletedAt!),
  };

  factory SavedMix.fromJson(Map<String, Object?> json) {
    final created = parseDate(json['createdAt']) ?? DateTime.now().toUtc();
    return SavedMix(
      id: '${json['id']}',
      name: asStringOrNull(json['name']) ?? 'Saved Mix',
      gymName: asStringOrNull(json['gymName']),
      treadmillName: asStringOrNull(json['treadmillName']),
      tracks: asMapList(json['tracks']).map(Track.fromJson).toList(),
      createdAt: created,
      updatedAt: parseDate(json['updatedAt']) ?? created,
      deletedAt: parseDate(json['deletedAt']),
    );
  }
}
