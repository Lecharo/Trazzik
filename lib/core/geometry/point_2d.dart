import 'dart:math' as math;

/// Coordenada cartesiana 2D en metros.
/// Inmutable y pura (sin dependencias de Flutter UI).
class Point2D {
  final double x;
  final double y;

  static const double epsilon = 1e-4;

  const Point2D(this.x, this.y);

  double distanceTo(Point2D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Point2D translate(double dx, double dy) => Point2D(x + dx, y + dy);

  Point2D rotate(double angleRadians, [Point2D origin = const Point2D(0, 0)]) {
    final cosTheta = math.cos(angleRadians);
    final sinTheta = math.sin(angleRadians);
    final dx = x - origin.x;
    final dy = y - origin.y;
    return Point2D(
      origin.x + (dx * cosTheta - dy * sinTheta),
      origin.y + (dx * sinTheta + dy * cosTheta),
    );
  }

  Point2D round([int decimals = 3]) {
    final factor = math.pow(10, decimals).toDouble();
    return Point2D(
      (x * factor).round() / factor,
      (y * factor).round() / factor,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Point2D.fromJson(Map<String, dynamic> json) => Point2D(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Point2D &&
        (x - other.x).abs() < epsilon &&
        (y - other.y).abs() < epsilon;
  }

  @override
  int get hashCode => Object.hash((x / epsilon).round(), (y / epsilon).round());

  @override
  String toString() => 'Point2D(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
