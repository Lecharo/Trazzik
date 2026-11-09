import 'bounding_box_2d.dart';
import 'point_2d.dart';

/// Representación geométrica 2D de una forma poligonal plana en metros.
class Polygon2D {
  final List<Point2D> vertices;

  Polygon2D(Iterable<Point2D> points) : vertices = List.unmodifiable(points) {
    if (vertices.length < 3) {
      throw ArgumentError('Un polígono debe tener al menos 3 vértices.');
    }
  }

  factory Polygon2D.fromRect(double x, double y, double width, double height) {
    final nx = width < 0 ? x + width : x;
    final ny = height < 0 ? y + height : y;
    final nw = width.abs();
    final nh = height.abs();
    return Polygon2D([
      Point2D(nx, ny),
      Point2D(nx + nw, ny),
      Point2D(nx + nw, ny + nh),
      Point2D(nx, ny + nh),
    ]);
  }

  factory Polygon2D.fromJson(Map<String, dynamic> json) {
    final list = json['vertices'] as List<dynamic>;
    return Polygon2D(
      list.map((v) => Point2D.fromJson(v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() => {
        'vertices': vertices.map((v) => v.toJson()).toList(),
      };

  late final BoundingBox2D boundingBox = BoundingBox2D.fromPoints(vertices);

  /// Área calculada con la fórmula del agrimensor (Shoelace Formula)
  late final double area = _computeArea();

  double _computeArea() {
    double sum = 0.0;
    final n = vertices.length;
    for (int i = 0; i < n; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % n];
      sum += (current.x * next.y) - (next.x * current.y);
    }
    return (sum.abs()) / 2.0;
  }

  /// Perímetro acumulado en metros
  late final double perimeter = _computePerimeter();

  double _computePerimeter() {
    double sum = 0.0;
    final n = vertices.length;
    for (int i = 0; i < n; i++) {
      sum += vertices[i].distanceTo(vertices[(i + 1) % n]);
    }
    return sum;
  }

  /// Verifica si el orden de los vértices es en sentido horario
  late final bool isClockwise = _computeIsClockwise();

  bool _computeIsClockwise() {
    double sum = 0.0;
    final n = vertices.length;
    for (int i = 0; i < n; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % n];
      sum += (next.x - current.x) * (next.y + current.y);
    }
    return sum > 0;
  }

  /// Algoritmo Ray-Casting (Even-Odd rule) para validar si un punto está dentro del polígono
  bool containsPoint(Point2D p) {
    // Broad-phase con bounding box
    if (!boundingBox.containsPoint(p)) {
      return false;
    }

    bool inside = false;
    final n = vertices.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = vertices[i].x, yi = vertices[i].y;
      final xj = vertices[j].x, yj = vertices[j].y;

      final intersect = ((yi > p.y) != (yj > p.y)) &&
          (p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }

    return inside;
  }

  @override
  String toString() => 'Polygon2D(${vertices.length} vertices, area: ${area.toStringAsFixed(2)}m²)';

  /// Traslada todos los vértices del polígono preservando su forma
  Polygon2D translate(double dx, double dy) {
    return Polygon2D(vertices.map((p) => p.translate(dx, dy)));
  }

  /// Escala todos los vértices respecto a un punto de origen (por defecto minX, minY del bounding box)
  Polygon2D scale(double scaleX, double scaleY, {Point2D? origin}) {
    final orig = origin ?? Point2D(boundingBox.minX, boundingBox.minY);
    return Polygon2D(
      vertices.map((p) => Point2D(
            orig.x + (p.x - orig.x) * scaleX,
            orig.y + (p.y - orig.y) * scaleY,
          )),
    );
  }

  /// Rota el polígono 90 grados en sentido horario alrededor de un centro
  Polygon2D rotate90({Point2D? center}) {
    final c = center ??
        Point2D(
          boundingBox.minX + boundingBox.width / 2,
          boundingBox.minY + boundingBox.height / 2,
        );
    return Polygon2D(
      vertices.map((p) {
        final dx = p.x - c.x;
        final dy = p.y - c.y;
        return Point2D(c.x - dy, c.y + dx);
      }),
    );
  }

  /// Espeja horizontalmente respecto a un eje X vertical
  Polygon2D mirrorX(double axisX) {
    return Polygon2D(
      vertices.map((p) => Point2D(2 * axisX - p.x, p.y)),
    );
  }

  /// Espeja verticalmente respecto a un eje Y horizontal
  Polygon2D mirrorY(double axisY) {
    return Polygon2D(
      vertices.map((p) => Point2D(p.x, 2 * axisY - p.y)),
    );
  }
}
