import 'point_2d.dart';
import 'polygon_2d.dart';

/// Motor geométrico puro en metros.
/// No depende de Flutter UI ni de motores externos.
class GeometryEngine {
  static const double epsilon = Point2D.epsilon;

  /// Verifica si dos segmentos de línea se intersectan.
  static bool segmentsIntersect(
    Point2D p1,
    Point2D p2,
    Point2D p3,
    Point2D p4,
  ) {
    double ccw(Point2D a, Point2D b, Point2D c) {
      return (c.y - a.y) * (b.x - a.x) - (b.y - a.y) * (c.x - a.x);
    }

    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    return false;
  }

  /// Calcula el punto de intersección entre dos rectas infinitas dadas por dos pares de puntos.
  static Point2D? lineIntersection(
    Point2D p1,
    Point2D p2,
    Point2D p3,
    Point2D p4,
  ) {
    final a1 = p2.y - p1.y;
    final b1 = p1.x - p2.x;
    final c1 = a1 * p1.x + b1 * p1.y;

    final a2 = p4.y - p3.y;
    final b2 = p3.x - p4.x;
    final c2 = a2 * p3.x + b2 * p3.y;

    final determinant = a1 * b2 - a2 * b1;
    if (determinant.abs() < epsilon) {
      return null; // Paralelas o colineales
    }

    final x = (b2 * c1 - b1 * c2) / determinant;
    final y = (a1 * c2 - a2 * c1) / determinant;
    return Point2D(x, y);
  }

  /// Recorta un polígono sujeto usando un polígono clipper convexo (Sutherland-Hodgman Algorithm).
  /// Muy eficiente y exacto para recortes contra lotes, pisos, módulos y zonas rectangulares u ortogonales convexas.
  static Polygon2D? clipPolygonSutherlandHodgman(
    Polygon2D subject,
    Polygon2D clipPolygon,
  ) {
    List<Point2D> outputList = List.from(subject.vertices);

    // Asegurar sentido antihorario para el clipper
    final clipVertices = clipPolygon.isClockwise
        ? clipPolygon.vertices.reversed.toList()
        : clipPolygon.vertices;

    final clipCount = clipVertices.length;
    for (int i = 0; i < clipCount; i++) {
      final cp1 = clipVertices[i];
      final cp2 = clipVertices[(i + 1) % clipCount];

      final inputList = List<Point2D>.from(outputList);
      outputList.clear();

      if (inputList.isEmpty) break;

      Point2D s = inputList.last;
      for (final Point2D e in inputList) {
        final isInsideE = _isInsideEdge(e, cp1, cp2);
        final isInsideS = _isInsideEdge(s, cp1, cp2);

        if (isInsideE) {
          if (!isInsideS) {
            final intersection = lineIntersection(cp1, cp2, s, e);
            if (intersection != null) outputList.add(intersection);
          }
          outputList.add(e);
        } else if (isInsideS) {
          final intersection = lineIntersection(cp1, cp2, s, e);
          if (intersection != null) outputList.add(intersection);
        }
        s = e;
      }
    }

    if (outputList.length < 3) return null;
    return Polygon2D(outputList);
  }

  static bool _isInsideEdge(Point2D p, Point2D cp1, Point2D cp2) {
    // Para sentido antihorario: punto a la izquierda de la arista dirigida cp1 -> cp2
    return (cp2.x - cp1.x) * (p.y - cp1.y) - (cp2.y - cp1.y) * (p.x - cp1.x) >= -epsilon;
  }

  /// Determina si dos polígonos colisionan (tienen superposición de área real > 0).
  static bool doPolygonsCollide(Polygon2D a, Polygon2D b) {
    // 1. Broad-phase con AABB
    if (!a.boundingBox.intersects(b.boundingBox)) {
      return false;
    }

    // 2. Si son rectángulos alineados a los ejes, el AABB es suficiente y exacto
    final aIsAxisAlignedRect = _isAxisAlignedRect(a);
    final bIsAxisAlignedRect = _isAxisAlignedRect(b);

    if (aIsAxisAlignedRect && bIsAxisAlignedRect) {
      final intersectionBox = a.boundingBox.intersectionWith(b.boundingBox);
      return intersectionBox != null && intersectionBox.area > epsilon;
    }

    // 3. Algoritmo general con clipping
    final clipped = clipPolygonSutherlandHodgman(a, b) ??
        clipPolygonSutherlandHodgman(b, a);
    return clipped != null && clipped.area > epsilon;
  }

  /// Calcula el área de superposición entre dos polígonos en m².
  static double calculateOverlapArea(Polygon2D a, Polygon2D b) {
    if (!a.boundingBox.intersects(b.boundingBox)) {
      return 0.0;
    }

    // Si ambos son rectángulos alineados a los ejes
    if (_isAxisAlignedRect(a) && _isAxisAlignedRect(b)) {
      final box = a.boundingBox.intersectionWith(b.boundingBox);
      return box != null ? box.area : 0.0;
    }

    final clipped = clipPolygonSutherlandHodgman(a, b) ??
        clipPolygonSutherlandHodgman(b, a);
    return clipped != null ? clipped.area : 0.0;
  }

  /// Calcula el área neta de ampliación nueva (área propuesta menos área superpuesta con lo demolido/existente).
  static double calculateExpansionArea(Polygon2D proposed, Polygon2D existing) {
    final overlap = calculateOverlapArea(proposed, existing);
    final expansion = proposed.area - overlap;
    return expansion > epsilon ? expansion : 0.0;
  }

  /// Valida si el polígono [inner] está completamente contenido dentro del polígono [container].
  static bool polygonContainsPolygon(Polygon2D container, Polygon2D inner) {
    // 1. Broad-phase
    if (!container.boundingBox.containsBoundingBox(inner.boundingBox)) {
      return false;
    }

    // 2. Todos los vértices de inner deben estar dentro o sobre el perímetro de container
    for (final v in inner.vertices) {
      if (!container.containsPoint(v) && !_isPointOnPerimeter(v, container)) {
        return false;
      }
    }

    // 3. Ninguna arista de inner debe cruzar aristas de container
    final nContainer = container.vertices.length;
    final nInner = inner.vertices.length;

    for (int i = 0; i < nContainer; i++) {
      final c1 = container.vertices[i];
      final c2 = container.vertices[(i + 1) % nContainer];

      for (int j = 0; j < nInner; j++) {
        final in1 = inner.vertices[j];
        final in2 = inner.vertices[(j + 1) % nInner];

        if (segmentsIntersect(c1, c2, in1, in2)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Shortest Euclidean distance from point [p] to line segment [a]-[b].
  static double distanceToSegment(Point2D p, Point2D a, Point2D b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return p.distanceTo(a);
    final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq;
    final clampedT = t.clamp(0.0, 1.0);
    final proj = Point2D(a.x + clampedT * dx, a.y + clampedT * dy);
    return p.distanceTo(proj);
  }

  static bool _isPointOnPerimeter(Point2D p, Polygon2D polygon) {
    final n = polygon.vertices.length;
    for (int i = 0; i < n; i++) {
      final a = polygon.vertices[i];
      final b = polygon.vertices[(i + 1) % n];
      if (_isPointOnSegment(p, a, b)) return true;
    }
    return false;
  }

  static bool _isPointOnSegment(Point2D p, Point2D a, Point2D b) {
    final distAP = a.distanceTo(p);
    final distPB = p.distanceTo(b);
    final distAB = a.distanceTo(b);
    return (distAP + distPB - distAB).abs() < epsilon;
  }

  static bool _isAxisAlignedRect(Polygon2D polygon) {
    if (polygon.vertices.length != 4) return false;
    final bb = polygon.boundingBox;
    return (polygon.area - bb.area).abs() < epsilon;
  }
}
