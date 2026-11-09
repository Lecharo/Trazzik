import 'dart:math' as math;
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'zoning_zone.dart';

/// Normative setback distances extracted from [Lot.zones] in meters.
class LotSetbacks {
  final double front;
  final double rear;
  final double left;
  final double right;

  const LotSetbacks({
    this.front = 0.0,
    this.rear = 0.0,
    this.left = 0.0,
    this.right = 0.0,
  });
}

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

  /// Resolves front, rear, left, and right setback distances from [zones].
  LotSetbacks get setbacks {
    double front = 0.0;
    double rear = 0.0;
    double left = 0.0;
    double right = 0.0;

    for (final zone in zones) {
      final name = zone.name.toLowerCase();
      final zBbox = zone.boundary.boundingBox;
      if (name.contains('frontal')) {
        front = math.max(front, zBbox.height);
      } else if (name.contains('posterior')) {
        rear = math.max(rear, zBbox.height);
      } else if (name.contains('izquierdo')) {
        left = math.max(left, zBbox.width);
      } else if (name.contains('derecho')) {
        right = math.max(right, zBbox.width);
      }
    }

    return LotSetbacks(
      front: front,
      rear: rear,
      left: left,
      right: right,
    );
  }

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
