/// Represents a building entity implanted on a project's [Lot].
class ProjectBuilding {
  final String id;
  final String lotId;
  final String name;
  final int? floorsCount;
  final int orderIndex;

  const ProjectBuilding({
    required this.id,
    required this.lotId,
    required this.name,
    this.floorsCount,
    this.orderIndex = 1,
  });

  factory ProjectBuilding.fromJson(Map<String, dynamic> json) {
    return ProjectBuilding(
      id: json['id'] as String,
      lotId: json['lot_id'] as String,
      name: (json['name'] as String?) ?? 'Edificación Principal',
      floorsCount: (json['floors_count'] as num?)?.toInt(),
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 1,
    );
  }
}
