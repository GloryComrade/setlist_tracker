/// Shared shape of every saved record (Show, Gear, Saved Mix).
///
/// The id is a UUID string and the timestamps are what a sync service such as
/// Supabase needs later: updatedAt decides which copy wins, and deletedAt is a
/// soft delete so a removal can sync to other devices.
abstract class Entity {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime? get deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, Object?> toJson();
}
