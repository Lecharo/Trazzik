import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/bounding_box_2d.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';

void main() {
  group('Point2D & BoundingBox2D', () {
    test('Calcula distancia euclidiana correctamente', () {
      final p1 = Point2D(0, 0);
      final p2 = Point2D(3, 4);
      expect(p1.distanceTo(p2), closeTo(5.0, 1e-4));
    });

    test('BoundingBox2D detecta intersecciones y contención', () {
      final bb1 = BoundingBox2D(minX: 0, minY: 0, maxX: 10, maxY: 10);
      final bb2 = BoundingBox2D(minX: 5, minY: 5, maxX: 15, maxY: 15);
      final bbOutside = BoundingBox2D(minX: 20, minY: 20, maxX: 30, maxY: 30);

      expect(bb1.intersects(bb2), isTrue);
      expect(bb1.intersects(bbOutside), isFalse);
      expect(bb1.containsPoint(Point2D(5, 5)), isTrue);
      expect(bb1.containsPoint(Point2D(15, 15)), isFalse);
    });
  });

  group('Polygon2D', () {
    test('Calcula área de rectángulo simple con Shoelace formula', () {
      final rect = Polygon2D.fromRect(0, 0, 4.0, 5.0);
      expect(rect.area, closeTo(20.0, 1e-4));
      expect(rect.perimeter, closeTo(18.0, 1e-4));
    });

    test('Calcula área de polígono compuesto en forma de L', () {
      // Forma de L: rectángulo inferior de 4x2 más bloque superior de 2x3
      // Vértices: (0,0) -> (4,0) -> (4,2) -> (2,2) -> (2,5) -> (0,5)
      final lShape = Polygon2D([
        Point2D(0, 0),
        Point2D(4, 0),
        Point2D(4, 2),
        Point2D(2, 2),
        Point2D(2, 5),
        Point2D(0, 5),
      ]);

      // Área teórica: (4 * 2) + (2 * 3) = 8 + 6 = 14.0 m²
      expect(lShape.area, closeTo(14.0, 1e-4));
      expect(lShape.perimeter, closeTo(4 + 2 + 2 + 3 + 2 + 5, 1e-4)); // 18m
      expect(lShape.containsPoint(Point2D(1, 1)), isTrue);
      expect(lShape.containsPoint(Point2D(1, 4)), isTrue);
      expect(lShape.containsPoint(Point2D(3, 4)), isFalse); // En el vacío de la L
    });
  });

  group('GeometryEngine — Escenario de Remodelación & Colisiones', () {
    test('Calcula área existente, superpuesta y ampliación según caso Cocina (2.10x3.20 vs 2.80x3.80)', () {
      // Cocina existente: 2.10 x 3.20 = 6.72 m²
      final existingKitchen = Polygon2D.fromRect(0, 0, 2.10, 3.20);
      // Cocina nueva: 2.80 x 3.80 = 10.64 m²
      final newKitchen = Polygon2D.fromRect(0, 0, 2.80, 3.80);

      expect(existingKitchen.area, closeTo(6.72, 1e-4));
      expect(newKitchen.area, closeTo(10.64, 1e-4));

      // Detección de colisión
      expect(GeometryEngine.doPolygonsCollide(existingKitchen, newKitchen), isTrue);

      // Área de coincidencia (superposición)
      final overlap = GeometryEngine.calculateOverlapArea(existingKitchen, newKitchen);
      expect(overlap, closeTo(6.72, 1e-4));

      // Área neta de ampliación nueva (10.64 - 6.72 = 3.92 m²)
      final expansion = GeometryEngine.calculateExpansionArea(newKitchen, existingKitchen);
      expect(expansion, closeTo(3.92, 1e-4));
    });

    test('Verifica contención de polígono dentro de otro (módulo dentro de piso)', () {
      final floor = Polygon2D.fromRect(0, 0, 15.0, 20.0);
      final moduleInside = Polygon2D.fromRect(2, 2, 4, 5);
      final moduleOverflowing = Polygon2D.fromRect(12, 18, 5, 5); // Sobresale en X e Y

      expect(GeometryEngine.polygonContainsPolygon(floor, moduleInside), isTrue);
      expect(GeometryEngine.polygonContainsPolygon(floor, moduleOverflowing), isFalse);
    });

    test('Dos rectángulos adyacentes que comparten arista no colisionan como área interna', () {
      final roomA = Polygon2D.fromRect(0, 0, 4, 4);
      final roomB = Polygon2D.fromRect(4, 0, 4, 4); // Comparte el borde x=4

      expect(GeometryEngine.doPolygonsCollide(roomA, roomB), isFalse);
      expect(GeometryEngine.calculateOverlapArea(roomA, roomB), closeTo(0.0, 1e-4));
    });
  });
}
