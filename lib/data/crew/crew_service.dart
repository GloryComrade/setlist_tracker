/// The storage contract for The Crew.
///
/// The screens only know [CrewService]. [CloudflareCrewService] talks to the
/// Worker's `/api/crew` routes (docs/cloudflare-api.md);
/// [MemoryCrewService] keeps everything in memory for tests and previews.
library;

import 'dart:typed_data';

import '../../models/crew.dart';

/// Something the server refused, in words a runner can read.
class CrewException implements Exception {
  const CrewException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class CrewService implements CrewTourInvites, CrewShowAudience {
  /// Null until a stage name is picked.
  Future<CrewProfile?> myProfile();

  Future<CrewProfile> saveProfile(CrewProfile profile);

  /// OKs the Crew seeing every Show from now on (ends
  /// [CrewProfile.allActivityPending]). Sends the stage name and color too.
  Future<CrewProfile> acceptAllActivity(CrewProfile profile);

  /// Your invite code (six letters and digits), made if needed. Lasts a week.
  Future<String> inviteCode();

  /// Who sent [code]. Null when it expired or doesn't exist.
  Future<CrewInvitePreview?> previewInvite(String code);

  /// Joins the Crew of whoever sent [code].
  Future<void> join(String code);

  /// Your Crew and the runners you blocked.
  Future<List<CrewMate>> crew();

  Future<void> leave(String userId);
  Future<void> block(String userId);
  Future<void> unblock(String userId);

  /// Shows from you and your Crew, newest first. Leaves out Shows kept off
  /// the Crew and anything you reported.
  Future<List<CrewPost>> feed();

  /// A Crew mate's page: their active Tour and Setlist. Null when they
  /// aren't in your Crew.
  Future<CrewMateDetail?> mate(String userId);

  Future<void> encore(String postId, {required bool on});

  /// Reports a Crew mate's Show to the app's owner and hides it from your feed.
  Future<void> report(CrewPost post, String reason);

  // ---- Profile pictures ----

  /// Saves [badge] (one of `kAvatarBadges`, or null for none) on [profile].
  Future<CrewProfile> saveAvatarBadge(CrewProfile profile, String? badge);

  /// Uploads your photo: a square JPEG of at most [kMaxAvatarBytes].
  Future<CrewProfile> uploadAvatar(Uint8List jpeg);

  Future<CrewProfile> removeAvatar();

  /// The photo at an `avatarUrl` (yours or a Crew mate's).
  Future<Uint8List> avatarBytes(String url);

  /// Reports a Crew mate's photo to the app's owner.
  Future<void> reportAvatar(String userId, String reason);
}

/// The server doesn't have that Tour yet (it hasn't synced). Sync, then try
/// again.
class TourNotSyncedException extends CrewException {
  const TourNotSyncedException()
    : super('That Tour isn’t backstage yet. Try again in a moment.');
}

/// Tour invites: ask Crew mates onto your Tour. Part of [CrewService].
abstract interface class CrewTourInvites {
  /// Invites [userIds] onto your synced Tour [tourId]. Returns who is
  /// invited now: Crew mates only, anyone else is skipped. Throws
  /// [TourNotSyncedException] while the server doesn't have the Tour.
  Future<List<String>> inviteToTour(String tourId, List<String> userIds);

  /// Invites to you that you haven't dismissed, from your Crew, whose
  /// Opening Night is still to come. Soonest first.
  Future<List<CrewTourInvite>> tourInvites();

  /// "Not this time": the invite goes away for good.
  Future<void> dismissTourInvite(String id);
}

/// The biggest photo the server takes.
const kMaxAvatarBytes = 64 * 1024;

/// Seen by, who gave Encores, and Shout-outs on a Show. Part of
/// [CrewService].
abstract interface class CrewShowAudience {
  /// Turns "Let my Crew know when I've seen their Shows" on or off. Off also
  /// forgets the views already recorded.
  Future<CrewProfile> setShareViews(CrewProfile profile, bool on);

  /// Turns "Tell me when my Crew plays a Show" on or off for every phone
  /// you're signed in on.
  Future<CrewProfile> setNotifyShows(CrewProfile profile, bool on);

  /// You saw a Crew mate's Show. Does nothing on your own Shows or with the
  /// switch off.
  Future<void> markSeen(String postId);

  /// Who gave the Show an Encore, and on your own Shows who saw it.
  Future<CrewAudience> audience(String postId);

  /// The Show's Shout-outs, oldest first.
  Future<List<CrewShoutout>> shoutouts(String postId);

  /// Posts a Shout-out of 1 to [kMaxShoutoutChars] characters.
  Future<CrewShoutout> addShoutout(String postId, String body);

  /// Yours, or any on your own Show.
  Future<void> deleteShoutout(String id);

  /// Reports a Shout-out to the app's owner and hides it from you.
  Future<void> reportShoutout(String id, String reason);
}
