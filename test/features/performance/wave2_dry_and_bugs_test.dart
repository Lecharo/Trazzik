import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/cad/cad_symbol_drawer.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/ai_advisor/data/architectural_audit_engine.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/walls/domain/wall_generation_engine.dart';

void main() {
  group('Wave 2 DRY Consolidation & Duplication Bug Fixes', () {
    test('Lot.setbacks extracts front, rear, left, and right setbacks once', () {
      final lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 10, 20),
        zones: [
          ZoningZone(
            id: 'z-front',
            lotId: 'lot-1',
            name: 'Retiro Frontal',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 0, 10, 3.0),
          ),
          ZoningZone(
            id: 'z-rear',
            lotId: 'lot-1',
            name: 'Retiro Posterior',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 16.5, 10, 3.5),
          ),
          ZoningZone(
            id: 'z-left',
            lotId: 'lot-1',
            name: 'Retiro Lateral Izquierdo',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 0, 1.2, 20),
          ),
          ZoningZone(
            id: 'z-right',
            lotId: 'lot-1',
            name: 'Retiro Lateral Derecho',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(8.5, 0, 1.5, 20),
          ),
        ],
      );

      final setbacks = lot.setbacks;
      expect(setbacks.front, closeTo(3.0, 1e-6));
      expect(setbacks.rear, closeTo(3.5, 1e-6));
      expect(setbacks.left, closeTo(1.2, 1e-6));
      expect(setbacks.right, closeTo(1.5, 1e-6));
    });

    test('Module.isHabitableRoom includes STUDIO and ArchitecturalAuditEngine audits blind STUDIO rooms', () {
      final studio = Module(
        id: 'm-studio',
        floorId: 'f-1',
        name: 'Estudio / Home Office',
        moduleType: 'STUDIO',
        geometry: Polygon2D.fromRect(3, 5, 4, 4),
        status: ElementStatus.isNew,
      );
      expect(studio.isHabitableRoom, isTrue);

      final floor = Floor(
        id: 'f-1',
        buildingId: 'b-1',
        floorNumber: 0,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 0, 12, 16),
        maxAllowedArea: 192.0,
        modules: [studio],
      );

      final audit = ArchitecturalAuditEngine.auditFloor(floor: floor);
      expect(audit.metrics.totalHabitableRooms, equals(1));
      expect(audit.metrics.blindRoomsCount, equals(1));
    });

    test('ElementStatus.pdfBadgeLabelEs distinguishes existing, toModify, future, and reference', () {
      expect(ElementStatus.existing.pdfBadgeLabelEs, equals('EXISTENTE'));
      expect(ElementStatus.preserved.pdfBadgeLabelEs, equals('EXIST. CONSERVADO'));
      expect(ElementStatus.isNew.pdfBadgeLabelEs, equals('NUEVO PROPUESTO'));
      expect(ElementStatus.toDemolish.pdfBadgeLabelEs, equals('A DEMOLER'));
      expect(ElementStatus.toModify.pdfBadgeLabelEs, equals('A MODIFICAR'));
      expect(ElementStatus.future.pdfBadgeLabelEs, equals('FUTURO / ETAPA 2'));
      expect(ElementStatus.reference.pdfBadgeLabelEs, equals('REFERENCIA'));
    });

    test('GeometryEngine.distanceToSegment computes exact point-to-segment distance', () {
      const a = Point2D(0, 0);
      const b = Point2D(10, 0);
      expect(
        GeometryEngine.distanceToSegment(const Point2D(5, 3), a, b),
        closeTo(3.0, 1e-6),
      );
      expect(
        GeometryEngine.distanceToSegment(const Point2D(-3, 4), a, b),
        closeTo(5.0, 1e-6),
      );
    });

    test('Building3DBuilder delegates auto-wall generation to WallGenerationEngine (open social transitions)', () {
      final living = Module(
        id: 'm-living',
        floorId: 'f-1',
        name: 'Sala de Estar',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(0, 0, 5, 4),
        status: ElementStatus.isNew,
      );
      final dining = Module(
        id: 'm-dining',
        floorId: 'f-1',
        name: 'Comedor',
        moduleType: 'DINING_ROOM',
        geometry: Polygon2D.fromRect(5, 0, 5, 4),
        status: ElementStatus.isNew,
      );
      final floor = Floor(
        id: 'f-1',
        buildingId: 'b-1',
        floorNumber: 0,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 0, 10, 4),
        maxAllowedArea: 40.0,
        modules: [living, dining],
      );
      final lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 10, 4),
      );

      final generatedWalls = WallGenerationEngine.generateWallsForFloor(floor);
      // Should have 4 outer perimeter walls (top, bottom, left, right) and NO partition at x = 5.
      final interiorWallAtX5 = generatedWalls.any(
        (w) =>
            (w.startPoint.x - 5.0).abs() < 0.05 &&
            (w.endPoint.x - 5.0).abs() < 0.05,
      );
      expect(interiorWallAtX5, isFalse);

      final faces = Building3DBuilder.buildScene(
        floors: [floor],
        lot: lot,
      );
      final wallFaces =
          faces.where((f) => f.label == 'Muro Exterior').toList();
      expect(wallFaces.length, equals(generatedWalls.length));
    });

    test('CadSymbolDrawer renders doors, sliding doors, windows, gates, stairs, and compass without error', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      CadSymbolDrawer.drawSwingDoor(
        canvas,
        10,
        10,
        40,
        8,
        40,
        Colors.white,
        flipX: true,
        flipY: false,
      );
      CadSymbolDrawer.drawSlidingDoor(canvas, 60, 10, 60, 8, 40, Colors.white);
      CadSymbolDrawer.drawWindow(canvas, 130, 10, 50, 8, 40, Colors.white);
      CadSymbolDrawer.drawGate(canvas, 190, 10, 80, 10, 40, Colors.white);
      CadSymbolDrawer.drawStairs(
        canvas,
        10,
        40,
        40,
        100,
        40,
        Colors.white,
        flipY: false,
      );
      CadSymbolDrawer.drawNorthCompass(
        canvas,
        const Offset(300, 60),
        22,
        45.0,
      );

      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      expect(picture, isNotNull);
    });
  });
}
