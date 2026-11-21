import 'entity.dart';
import 'json_utils.dart';

/// A pair of shoes (or any kit you want to track miles on).
class Gear implements Entity {
  const Gear({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.startingMiles = 0,
    this.retired = false,
    this.deletedAt,
  });

  @override
  final String id;
  final String name;
  final String? brand;

  /// Miles already on the shoes before they were added to the app.
  final double startingMiles;
  final bool retired;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  String get displayName =>
      brand == null || brand!.isEmpty ? name : '$brand $name';

  Gear copyWith({
    String? name,
    String? brand,
    double? startingMiles,
    bool? retired,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      Gear(
        id: id,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        startingMiles: startingMiles ?? this.startingMiles,
        retired: retired ?? this.retired,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  @override
  Map<String, Object?> toJson() => {
        'schemaVersion': kSchemaVersion,
        'id': id,
        'name': name,
        'brand': brand,
        'startingMiles': startingMiles,
        'retired': retired,
        'createdAt': utcString(createdAt),
        'updatedAt': utcString(updatedAt),
        'deletedAt': deletedAt == null ? null : utcString(deletedAt!),
      };

  factory Gear.fromJson(Map<String, Object?> json) {
    final created = parseDate(json['createdAt']) ?? DateTime.now().toUtc();
    return Gear(
      id: '${json['id']}',
      name: asStringOrNull(json['name']) ?? 'Gear',
      brand: asStringOrNull(json['brand']),
      startingMiles: asDouble(json['startingMiles']),
      retired: json['retired'] == true,
      createdAt: created,
      updatedAt: parseDate(json['updatedAt']) ?? created,
      deletedAt: parseDate(json['deletedAt']),
    );
  }
}
