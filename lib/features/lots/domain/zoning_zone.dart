import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'zoning_type.dart';

/// Zona reglamentaria o funcional dentro del lote.
class ZoningZone {
  final String id;
  final String lotId;
  final String name;
  final ZoningType type;
  final Polygon2D boundary;

  const ZoningZone({
    required this.id,
    required this.lotId,
    required this.name,
    required this.type,
    required this.boundary,
  });

  double get area => boundary.area;

  Map<String, dynamic> toJson() => {
        'id': id,
        'lot_id': lotId,
        'name': name,
        'type': type.name,
        'boundary': boundary.toJson(),
      };

  factory ZoningZone.fromJson(Map<String, dynamic> json) => ZoningZone(
        id: json['id'] as String,
        lotId: json['lot_id'] as String,
        name: json['name'] as String,
        type: ZoningType.values.where((e) => e.name == json['type']).firstOrNull ??
            ZoningType.buildableUnoccupied,
        boundary: Polygon2D.fromJson(json['boundary'] as Map<String, dynamic>),
      );
}
