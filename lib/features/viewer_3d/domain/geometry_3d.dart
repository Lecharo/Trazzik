import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Punto en el espacio euclidiano 3D (X: Ancho, Y: Fondo, Z: Cota/Elevación en metros)
class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);

  Point3D operator +(Point3D other) =>
      Point3D(x + other.x, y + other.y, z + other.z);

  Point3D operator -(Point3D other) =>
      Point3D(x - other.x, y - other.y, z - other.z);

  Point3D scale(double factor) =>
      Point3D(x * factor, y * factor, z * factor);
}

/// Cara poligonal plana 3D para renderizado axonométrico con iluminación y ordenamiento de profundidad
class Face3D {
  static const Point3D defaultSunLight = Point3D(0.577, -0.577, 0.577);

  final List<Point3D> vertices;
  final Color baseColor;
  final String? label;
  final bool isEdgeVisible;

  Face3D({
    required this.vertices,
    required this.baseColor,
    this.label,
    this.isEdgeVisible = true,
  });

  /// Centroide tridimensional de la cara
  late final Point3D centroid = _computeCentroid();

  Point3D _computeCentroid() {
    if (vertices.isEmpty) return const Point3D(0, 0, 0);
    double sx = 0, sy = 0, sz = 0;
    for (final v in vertices) {
      sx += v.x;
      sy += v.y;
      sz += v.z;
    }
    final n = vertices.length.toDouble();
    return Point3D(sx / n, sy / n, sz / n);
  }

  /// Vector normal de la cara
  late final Point3D normal = _computeNormal();

  Point3D _computeNormal() {
    if (vertices.length < 3) return const Point3D(0, 0, 1);
    final p0 = vertices[0];
    final p1 = vertices[1];
    final p2 = vertices[2];

    final ax = p1.x - p0.x;
    final ay = p1.y - p0.y;
    final az = p1.z - p0.z;

    final bx = p2.x - p0.x;
    final by = p2.y - p0.y;
    final bz = p2.z - p0.z;

    // Producto vectorial (cross product)
    final nx = ay * bz - az * by;
    final ny = az * bx - ax * bz;
    final nz = ax * by - ay * bx;

    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len == 0) return const Point3D(0, 0, 1);
    return Point3D(nx / len, ny / len, nz / len);
  }

  /// Color precalculado con la fuente solar direccional estándar (45° cenital)
  late final Color defaultShadedColor = computeShadedColor(defaultSunLight);

  /// Calcula el color sombreado según la fuente de luz direccional (Sol arquitectónico cenital a 45°)
  Color computeShadedColor(Point3D lightDir) {
    final norm = normal;
    // Producto punto
    final dot = norm.x * lightDir.x + norm.y * lightDir.y + norm.z * lightDir.z;
    final intensity = (dot.clamp(-0.2, 1.0) + 0.2) / 1.2;
    // Factor de luminosidad ambiente mínima (0.45 a 1.0)
    final brightness = 0.45 + 0.55 * intensity;

    return Color.fromARGB(
      (baseColor.a * 255.0).round().clamp(0, 255),
      (baseColor.r * 255.0 * brightness).round().clamp(0, 255),
      (baseColor.g * 255.0 * brightness).round().clamp(0, 255),
      (baseColor.b * 255.0 * brightness).round().clamp(0, 255),
    );
  }
}
