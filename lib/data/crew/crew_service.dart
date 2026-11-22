/// The storage contract for The Crew.
///
/// The screens only know [CrewService]. [CloudflareCrewService] talks to the
/// Worker's `/api/crew` routes (docs/cloudflare-api.md);
/// [MemoryCrewService] keeps everything in memory for tests and previews.
library;

import '../../models/crew.dart';

/// Something the server refused, in words a runner can read.
class CrewException implements Exception {
  const CrewException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class CrewService {
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
}
