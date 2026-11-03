import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'zoning_zone.dart';

/// Terreno o Lote de implantación del proyecto.
class Lot {
  final String id;
  final String projectId;
  final Polygon2D boundary;
  final double orientationDegrees;
  final List<ZoningZone> zones;

  const Lot({
    required this.id,
    required this.projectId,
    required this.boundary,
    this.orientationDegrees = 0.0,
    this.zones = const [],
  });

  double get totalArea => boundary.area;

  Lot copyWith({
    String? id,
    String? projectId,
    Polygon2D? boundary,
    double? orientationDegrees,
    List<ZoningZone>? zones,
  }) {
    return Lot(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      boundary: boundary ?? this.boundary,
      orientationDegrees: orientationDegrees ?? this.orientationDegrees,
      zones: zones ?? this.zones,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'boundary': boundary.toJson(),
        'boundary_polygon': boundary.toJson(),
        'orientation_degrees': orientationDegrees,
        'zones': zones.map((z) => z.toJson()).toList(),
      };

  factory Lot.fromJson(Map<String, dynamic> json) => Lot(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        boundary: Polygon2D.fromJson(
          (json['boundary'] ?? json['boundary_polygon']) as Map<String, dynamic>,
        ),
        orientationDegrees: (json['orientation_degrees'] as num?)?.toDouble() ?? 0.0,
        zones: (json['zones'] as List<dynamic>?)
                ?.map((z) => ZoningZone.fromJson(z as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
