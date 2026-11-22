import '../logic/show_math.dart';
import 'entity.dart';
import 'enums.dart';
import 'json_utils.dart';
import 'song.dart';
import 'venue_details.dart';

/// One run.
class Show implements Entity {
  const Show({
    required this.id,
    required this.date,
    required this.venue,
    required this.workoutType,
    required this.distanceMiles,
    required this.durationSeconds,
    required this.effort,
    required this.feel,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.notes,
    this.gearId,
    this.song,
    this.studio,
    this.live,
    this.plannedShowId,
  });

  @override
  final String id;

  /// Local date and start time. Saved without a time zone so a 6 AM Show stays
  /// on the same calendar day after travel or a sync.
  final DateTime date;

  final Venue venue;
  final WorkoutType workoutType;
  final double distanceMiles;
  final int durationSeconds;

  /// 1 to 10.
  final int effort;
  final Feel feel;
  final String? notes;
  final String? gearId;
  final SongOfTheShow? song;

  /// Set only on Studio Sessions.
  final StudioDetails? studio;

  /// Set only on Live Shows.
  final LiveDetails? live;

  /// The Tour's Planned Show this run was logged for, if any.
  final String? plannedShowId;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  /// Seconds per mile, or null when distance is zero.
  double? get paceSecondsPerMile =>
      paceSecondsPerMileFor(distanceMiles, durationSeconds);

  Show copyWith({DateTime? updatedAt, DateTime? deletedAt}) => Show(
    id: id,
    date: date,
    venue: venue,
    workoutType: workoutType,
    distanceMiles: distanceMiles,
    durationSeconds: durationSeconds,
    effort: effort,
    feel: feel,
    notes: notes,
    gearId: gearId,
    song: song,
    studio: studio,
    live: live,
    plannedShowId: plannedShowId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': kSchemaVersion,
    'id': id,
    // No "Z": this is the runner's local wall-clock time.
    'date': DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    ).toIso8601String(),
    'venue': venue.name,
    'workoutType': workoutType.name,
    'distanceMiles': distanceMiles,
    'durationSeconds': durationSeconds,
    'effort': effort,
    'feel': feel.name,
    'notes': notes,
    'gearId': gearId,
    'song': song?.toJson(),
    'studio': studio?.toJson(),
    'live': live?.toJson(),
    'plannedShowId': plannedShowId,
    'createdAt': utcString(createdAt),
    'updatedAt': utcString(updatedAt),
    'deletedAt': deletedAt == null ? null : utcString(deletedAt!),
  };

  factory Show.fromJson(Map<String, Object?> json) {
    final song = asMap(json['song']);
    final studio = asMap(json['studio']);
    final live = asMap(json['live']);
    final created = parseDate(json['createdAt']) ?? DateTime.now().toUtc();
    final rawDate = parseDate(json['date']);
    return Show(
      id: '${json['id']}',
      date: rawDate == null
          ? DateTime.now()
          // Strip any zone info: treat it as local wall-clock time.
          : DateTime(
              rawDate.year,
              rawDate.month,
              rawDate.day,
              rawDate.hour,
              rawDate.minute,
            ),
      venue: Venue.fromName(asStringOrNull(json['venue'])),
      workoutType: WorkoutType.fromName(asStringOrNull(json['workoutType'])),
      distanceMiles: asDouble(json['distanceMiles']),
      durationSeconds: asInt(json['durationSeconds']),
      effort: asInt(json['effort'], 5).clamp(1, 10),
      feel: Feel.fromName(asStringOrNull(json['feel'])),
      notes: asStringOrNull(json['notes']),
      gearId: asStringOrNull(json['gearId']),
      song: song == null ? null : SongOfTheShow.fromJson(song),
      studio: studio == null ? null : StudioDetails.fromJson(studio),
      live: live == null ? null : LiveDetails.fromJson(live),
      plannedShowId: asStringOrNull(json['plannedShowId']),
      createdAt: created,
      updatedAt: parseDate(json['updatedAt']) ?? created,
      deletedAt: parseDate(json['deletedAt']),
    );
  }
}
