/// The Crew: running friends who share Shows with each other.
///
/// Everything here lives on the server (the Cloudflare Worker), not on the device: a
/// shared Show is a snapshot copied out of the Setlist, so friends never see
/// anything that wasn't picked for them.
library;

import '../logic/gold_records.dart';
import 'enums.dart';
import 'json_utils.dart';
import 'show.dart';
import 'song.dart';

/// How many avatar colors there are (see `crewColor` in the UI).
const kCrewColors = 4;

/// Your stage name and what you show the Crew.
class CrewProfile {
  const CrewProfile({
    required this.userId,
    required this.stageName,
    this.color = 0,
    this.openingNight,
    this.tourName,
    this.alwaysShare = false,
    this.showOpeningNight = false,
  });

  final String userId;
  final String stageName;

  /// 0 to [kCrewColors] - 1.
  final int color;

  /// Race day of your active Tour, when [showOpeningNight] is on.
  final DateTime? openingNight;
  final String? tourName;

  /// Share every new Show with the Crew without asking.
  final bool alwaysShare;

  /// Let the Crew see your Opening Night countdown.
  final bool showOpeningNight;

  CrewProfile copyWith({
    String? stageName,
    int? color,
    bool? alwaysShare,
    bool? showOpeningNight,
    DateTime? openingNight,
    String? tourName,
    bool clearOpeningNight = false,
  }) => CrewProfile(
    userId: userId,
    stageName: stageName ?? this.stageName,
    color: color ?? this.color,
    alwaysShare: alwaysShare ?? this.alwaysShare,
    showOpeningNight: showOpeningNight ?? this.showOpeningNight,
    openingNight: clearOpeningNight
        ? null
        : (openingNight ?? this.openingNight),
    tourName: clearOpeningNight ? null : (tourName ?? this.tourName),
  );
}

/// Someone in your Crew (or someone you blocked).
class CrewMate {
  const CrewMate({
    required this.userId,
    required this.stageName,
    required this.color,
    required this.since,
    this.openingNight,
    this.tourName,
    this.blocked = false,
  });

  final String userId;
  final String stageName;
  final int color;
  final DateTime since;
  final DateTime? openingNight;
  final String? tourName;
  final bool blocked;
}

/// Who sent an invite code.
class CrewInvitePreview {
  const CrewInvitePreview({
    required this.stageName,
    required this.color,
    this.alreadyCrew = false,
    this.ownInvite = false,
  });

  final String stageName;
  final int color;
  final bool alreadyCrew;
  final bool ownInvite;
}

/// The part of a Show that goes to the Crew. Effort, feel, Gear, Tracks and
/// the route stay on your Setlist; notes go only when you tick them.
class SharedShow {
  const SharedShow({
    required this.date,
    required this.venue,
    required this.workoutType,
    required this.distanceMiles,
    required this.durationSeconds,
    this.song,
    this.goldRecords = const [],
    this.notes,
  });

  final DateTime date;
  final Venue venue;
  final WorkoutType workoutType;
  final double distanceMiles;
  final int durationSeconds;
  final SongOfTheShow? song;

  /// Titles of the Gold Records this Show set, e.g. "Fastest 5K".
  final List<String> goldRecords;
  final String? notes;

  bool get includesNotes => notes != null;

  /// Snapshot of [show]. [allShows] works out which Gold Records it holds.
  factory SharedShow.fromShow(
    Show show, {
    required List<Show> allShows,
    bool includeNotes = false,
  }) {
    final records = computeGoldRecords(allShows).values
        .where((r) => r.show?.id == show.id)
        .map((r) => r.kind.title)
        .toList();
    final song = show.song;
    return SharedShow(
      date: show.date,
      venue: show.venue,
      workoutType: show.workoutType,
      distanceMiles: show.distanceMiles,
      durationSeconds: show.durationSeconds,
      // The clip and its preview stay: friends can hear the part you picked.
      song: song == null
          ? null
          : SongOfTheShow(
              title: song.title,
              artist: song.artist,
              note: song.note,
              albumArtUrl: song.albumArtUrl,
              spotifyUrl: song.spotifyUrl,
              appleMusicUrl: song.appleMusicUrl,
              previewUrl: song.previewUrl,
              clipStartSeconds: song.clipStartSeconds,
              clipLengthSeconds: song.clipLengthSeconds,
            ),
      goldRecords: records,
      notes: includeNotes ? show.notes : null,
    );
  }

  Map<String, Object?> toJson() => {
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
    'song': song?.toJson(),
    'goldRecords': goldRecords,
    'notes': notes,
  };

  factory SharedShow.fromJson(Map<String, Object?> json) {
    final d = parseDate(json['date']) ?? DateTime.now();
    final song = asMap(json['song']);
    final records = json['goldRecords'];
    return SharedShow(
      date: DateTime(d.year, d.month, d.day, d.hour, d.minute),
      venue: Venue.fromName(asStringOrNull(json['venue'])),
      workoutType: WorkoutType.fromName(asStringOrNull(json['workoutType'])),
      distanceMiles: asDouble(json['distanceMiles']),
      durationSeconds: asInt(json['durationSeconds']),
      song: song == null ? null : SongOfTheShow.fromJson(song),
      goldRecords: records is List
          ? records.map((r) => '$r').toList()
          : const [],
      notes: asStringOrNull(json['notes']),
    );
  }
}

/// A Show someone in the Crew shared (or you did).
class CrewPost {
  const CrewPost({
    required this.id,
    required this.ownerId,
    required this.stageName,
    required this.color,
    required this.showId,
    required this.show,
    required this.sharedAt,
    this.encores = 0,
    this.encoredByMe = false,
    this.mine = false,
  });

  final String id;
  final String ownerId;
  final String stageName;
  final int color;
  final String showId;
  final SharedShow show;
  final DateTime sharedAt;
  final int encores;
  final bool encoredByMe;
  final bool mine;

  CrewPost withEncore(bool on) => CrewPost(
    id: id,
    ownerId: ownerId,
    stageName: stageName,
    color: color,
    showId: showId,
    show: show,
    sharedAt: sharedAt,
    encores: encores - (encoredByMe ? 1 : 0) + (on ? 1 : 0),
    encoredByMe: on,
    mine: mine,
  );
}

/// One of your Shows on the Crew feed: when it was copied and whether the
/// notes went with it.
class SharedInfo {
  const SharedInfo({required this.showUpdatedAt, required this.includesNotes});
  final DateTime showUpdatedAt;
  final bool includesNotes;
}
