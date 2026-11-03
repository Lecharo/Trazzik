import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/demolition/domain/replacement_relationship.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('Serialización y Mapeo Bidireccional de Dominio <-> Supabase', () {
    test('Serializa y reconstruye Floor completo con Módulos, Muros y Reemplazo', () {
      final module = Module(
        id: 'mod-1',
        floorId: 'floor-1',
        name: 'Cocina Nueva',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2.0, 3.0, 2.80, 3.80),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: 'sub-1',
            moduleId: 'mod-1',
            name: 'Mesón',
            type: 'COUNTERTOP',
            geometry: Polygon2D.fromRect(2.0, 3.0, 0.60, 2.0),
            status: ElementStatus.isNew,
          ),
        ],
      );

      final wall = Wall(
        id: 'wall-1',
        floorId: 'floor-1',
        startPoint: Point2D(0, 0),
        endPoint: Point2D(5.0, 0),
        thickness: 0.15,
        height: 2.60,
        status: ElementStatus.isNew,
      );

      final replacement = ReplacementRelationship(
        id: 'rel-1',
        floorId: 'floor-1',
        existingElementId: 'mod-old-kitchen',
        proposedElementId: 'mod-1',
        relationshipType: RelationshipType.expand,
        overlapArea: 6.72,
        expandedArea: 3.92,
        notes: 'Ampliación de cocina sobre zona demolida',
      );

      final originalFloor = Floor(
        id: 'floor-1',
        buildingId: 'bldg-1',
        floorNumber: 1,
        name: 'Piso 1 - Remodelación',
        boundary: Polygon2D.fromRect(0, 0, 15.30, 20.0),
        maxAllowedArea: 138.0,
        modules: [module],
        walls: [wall],
        replacementRelationships: [replacement],
      );

      // Simular persistencia a JSONB / Map de PostgreSQL
      final jsonMap = originalFloor.toJson();

      // Reconstruir desde los datos
      final restoredFloor = Floor.fromJson(jsonMap);

      expect(restoredFloor.id, equals(originalFloor.id));
      expect(restoredFloor.name, equals('Piso 1 - Remodelación'));
      expect(restoredFloor.modules.length, equals(1));
      expect(restoredFloor.modules.first.name, equals('Cocina Nueva'));
      expect(restoredFloor.modules.first.subModules.length, equals(1));
      expect(restoredFloor.modules.first.subModules.first.name, equals('Mesón'));
      expect(restoredFloor.walls.length, equals(1));
      expect(restoredFloor.walls.first.length, closeTo(5.0, 1e-4));
      expect(restoredFloor.replacementRelationships.length, equals(1));
      expect(restoredFloor.replacementRelationships.first.expandedArea, closeTo(3.92, 1e-4));
    });

    test('Serializa y reconstruye Lot con Zonas Normativas', () {
      final lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 15.30, 20.0),
        orientationDegrees: 45.0,
        zones: [
          ZoningZone(
            id: 'zone-1',
            lotId: 'lot-1',
            name: 'Zona Construible',
            type: ZoningType.buildableUnoccupied,
            boundary: Polygon2D.fromRect(0, 0, 15.30, 15.0),
          ),
          ZoningZone(
            id: 'zone-2',
            lotId: 'lot-1',
            name: 'Retiro Posterior',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 15.0, 15.30, 5.0),
          ),
        ],
      );

      final jsonMap = lot.toJson();
      final restoredLot = Lot.fromJson(jsonMap);

      expect(restoredLot.id, equals(lot.id));
      expect(restoredLot.orientationDegrees, closeTo(45.0, 1e-4));
      expect(restoredLot.zones.length, equals(2));
      expect(restoredLot.zones.first.type, equals(ZoningType.buildableUnoccupied));
      expect(restoredLot.zones.last.type, equals(ZoningType.nonBuildable));
    });

    test('Serializa y reconstruye Project', () {
      final project = Project(
        id: 'proj-1',
        name: 'Remodelación Casa Residencial',
        description: 'Proyecto de intervención paramétrica',
        ownerId: 'user-uuid-123',
        country: 'Colombia',
        stateProvince: 'Cundinamarca',
        city: 'Bogotá',
        address: 'Cra 15 # 93-20',
      );

      final jsonMap = project.toJson();
      final restored = Project.fromJson(jsonMap);

      expect(restored.id, equals(project.id));
      expect(restored.name, equals('Remodelación Casa Residencial'));
      expect(restored.ownerId, equals('user-uuid-123'));
      expect(restored.country, equals('Colombia'));
      expect(restored.stateProvince, equals('Cundinamarca'));
      expect(restored.city, equals('Bogotá'));
      expect(restored.address, equals('Cra 15 # 93-20'));
    });
  });
}
