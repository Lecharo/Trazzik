import 'dart:math' as math;
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';

/// Entidad constructiva Muro independiente.
class Wall {
  final String id;
  final String floorId;
  final Point2D startPoint;
  final Point2D endPoint;
  final double thickness;
  final double height;
  final ElementStatus status;

  const Wall({
    required this.id,
    required this.floorId,
    required this.startPoint,
    required this.endPoint,
    this.thickness = 0.15,
    this.height = 2.60,
    required this.status,
  });

  double get length => startPoint.distanceTo(endPoint);

  double get grossArea => length * height;

  Wall copyWith({
    String? id,
    String? floorId,
    Point2D? startPoint,
    Point2D? endPoint,
    double? thickness,
    double? height,
    ElementStatus? status,
  }) {
    return Wall(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      thickness: thickness ?? this.thickness,
      height: height ?? this.height,
      status: status ?? this.status,
    );
  }

  /// Genera la huella poligonal 2D del muro considerando su espesor centrado en el eje.
  Polygon2D get footprint {
    final dx = endPoint.x - startPoint.x;
    final dy = endPoint.y - startPoint.y;
    final len = length;
    if (len < Point2D.epsilon) {
      return Polygon2D.fromRect(startPoint.x, startPoint.y, thickness, thickness);
    }

    final halfThickness = thickness / 2.0;
    final nx = -dy / len * halfThickness;
    final ny = dx / len * halfThickness;

    return Polygon2D([
      Point2D(startPoint.x + nx, startPoint.y + ny),
      Point2D(endPoint.x + nx, endPoint.y + ny),
      Point2D(endPoint.x - nx, endPoint.y - ny),
      Point2D(startPoint.x - nx, startPoint.y - ny),
    ]);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor_id': floorId,
        'start_point': startPoint.toJson(),
        'end_point': endPoint.toJson(),
        'thickness': thickness,
        'height': height,
        'status': status.name,
      };

  factory Wall.fromJson(Map<String, dynamic> json) => Wall(
        id: json['id'] as String,
        floorId: json['floor_id'] as String,
        startPoint: Point2D.fromJson(json['start_point'] as Map<String, dynamic>),
        endPoint: Point2D.fromJson(json['end_point'] as Map<String, dynamic>),
        thickness: (json['thickness'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        status: ElementStatus.values.byName(json['status'] as String),
      );

  /// Elimina muros duplicados o idénticos (mismo trazo espacial sin importar la dirección)
  static List<Wall> deduplicate(Iterable<Wall> walls) {
    final unique = <Wall>[];
    for (final w in walls) {
      final isDuplicate = unique.any((existing) {
        final sameDir = (existing.startPoint.distanceTo(w.startPoint) < 0.05 &&
            existing.endPoint.distanceTo(w.endPoint) < 0.05);
        final oppDir = (existing.startPoint.distanceTo(w.endPoint) < 0.05 &&
            existing.endPoint.distanceTo(w.startPoint) < 0.05);
        return sameDir || oppDir;
      });
      if (!isDuplicate) {
        unique.add(w);
      }
    }
    return unique;
  }
}
