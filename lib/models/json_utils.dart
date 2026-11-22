/// Small helpers for turning JSON maps back into Dart values.
///
/// Storage engines (Sembast today, Supabase later) hand back loosely typed
/// maps, so every read goes through these to stay null-safe.
library;

/// Bumped whenever a saved record's shape changes, so old data can be migrated.
const int kSchemaVersion = 1;

double asDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? fallback);

double? asDoubleOrNull(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

int asInt(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);

String? asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = '$v';
  return s.isEmpty ? null : s;
}

/// Timestamps (createdAt, updatedAt, deletedAt) are saved in UTC.
String utcString(DateTime d) => d.toUtc().toIso8601String();

DateTime? parseDate(Object? v) => v == null ? null : DateTime.tryParse('$v');

Map<String, Object?>? asMap(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry('$k', val)) : null;

List<Map<String, Object?>> asMapList(Object? v) => v is List
    ? v.map(asMap).whereType<Map<String, Object?>>().toList()
    : const [];

/// "2027-04-18": a calendar day with no time or zone.
String dateOnlyString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Reads a calendar day back as local midnight.
DateTime? parseDateOnly(Object? v) {
  final d = parseDate(v);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}
