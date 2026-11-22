/// The storage contract for The Crew.
///
/// The screens only know [CrewService]. [SupabaseCrewService] talks to the
/// tables in `supabase/migrations/20261123000000_the_crew.sql`;
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

  /// Shared Shows from you and your Crew, newest first. Leaves out anything
  /// you reported.
  Future<List<CrewPost>> feed();

  /// Show id → when your shared copy was taken.
  Future<Map<String, SharedInfo>> mySharedShows();

  /// Shares a Show, or replaces the copy if it was shared before.
  Future<void> share(String showId, SharedShow show, DateTime showUpdatedAt);

  Future<void> unshare(String showId);

  Future<void> encore(String postId, {required bool on});

  /// Reports a shared Show to the app's owner and hides it from your feed.
  Future<void> report(CrewPost post, String reason);
}
