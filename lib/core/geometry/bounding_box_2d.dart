import 'dart:math' as math;
import 'point_2d.dart';

/// Bounding Box alineado a los ejes (AABB) para filtrado geométrico rápido (*broad-phase*).
class BoundingBox2D {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const BoundingBox2D({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  factory BoundingBox2D.fromPoints(Iterable<Point2D> points) {
    if (points.isEmpty) {
      return const BoundingBox2D(minX: 0, minY: 0, maxX: 0, maxY: 0);
    }
    double minX = points.first.x;
    double minY = points.first.y;
    double maxX = points.first.x;
    double maxY = points.first.y;

    for (final p in points) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }

    return BoundingBox2D(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  double get width => maxX - minX;
  double get height => maxY - minY;
  double get area => width * height;
  Point2D get center => Point2D((minX + maxX) / 2.0, (minY + maxY) / 2.0);

  bool intersects(BoundingBox2D other) {
    return !(other.minX >= maxX - Point2D.epsilon ||
        other.maxX <= minX + Point2D.epsilon ||
        other.minY >= maxY - Point2D.epsilon ||
        other.maxY <= minY + Point2D.epsilon);
  }

  bool containsPoint(Point2D p) {
    return p.x >= minX - Point2D.epsilon &&
        p.x <= maxX + Point2D.epsilon &&
        p.y >= minY - Point2D.epsilon &&
        p.y <= maxY + Point2D.epsilon;
  }

  bool containsBoundingBox(BoundingBox2D other) {
    return other.minX >= minX - Point2D.epsilon &&
        other.maxX <= maxX + Point2D.epsilon &&
        other.minY >= minY - Point2D.epsilon &&
        other.maxY <= maxY + Point2D.epsilon;
  }

  BoundingBox2D? intersectionWith(BoundingBox2D other) {
    if (!intersects(other)) return null;
    return BoundingBox2D(
      minX: math.max(minX, other.minX),
      minY: math.max(minY, other.minY),
      maxX: math.min(maxX, other.maxX),
      maxY: math.min(maxY, other.maxY),
    );
  }

  @override
  String toString() =>
      'BoundingBox2D([${minX.toStringAsFixed(2)}, ${minY.toStringAsFixed(2)}] -> [${maxX.toStringAsFixed(2)}, ${maxY.toStringAsFixed(2)}])';
}
