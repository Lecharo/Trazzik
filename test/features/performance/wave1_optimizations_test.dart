import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/canvas_2d_painter.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/plan_export/domain/plan_export_options.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('Wave 1 — Domain memoization, area accuracy & serialization', () {
    test(
      'Floor.usableSpacesArea and calculatedBuiltArea exclude DOOR, WINDOW, and GATE openings',
      () {
        final room = Module(
          id: 'room-1',
          floorId: 'floor-1',
          name: 'Living Room',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(0, 0, 4.0, 5.0), // 20.0 m2
          status: ElementStatus.isNew,
        );
        final door = Module(
          id: 'door-1',
          floorId: 'floor-1',
          name: 'Main Door',
          moduleType: 'DOOR',
          geometry: Polygon2D.fromRect(0, 0, 0.9, 0.9), // 0.81 m2
          status: ElementStatus.isNew,
        );
        final window = Module(
          id: 'win-1',
          floorId: 'floor-1',
          name: 'Front Window',
          moduleType: 'WINDOW',
          geometry: Polygon2D.fromRect(1, 0, 1.5, 0.2), // 0.30 m2
          status: ElementStatus.isNew,
        );
        final gate = Module(
          id: 'gate-1',
          floorId: 'floor-1',
          name: 'Garage Gate',
          moduleType: 'GATE',
          geometry: Polygon2D.fromRect(0, 5, 3.0, 0.25), // 0.75 m2
          status: ElementStatus.isNew,
        );
        final wall = Wall(
          id: 'wall-1',
          floorId: 'floor-1',
          startPoint: const Point2D(0, 0),
          endPoint: const Point2D(4, 0), // 4.0m * 0.15m = 0.60 m2
          thickness: 0.15,
          status: ElementStatus.isNew,
        );

        final floor = Floor(
          id: 'floor-1',
          buildingId: 'bld-1',
          floorNumber: 1,
          name: 'Level 1',
          boundary: Polygon2D.fromRect(0, 0, 10, 15),
          maxAllowedArea: 100,
          modules: [room, door, window, gate],
          walls: [wall],
        );

        expect(floor.usableSpacesArea, closeTo(20.0, 1e-6));
        expect(floor.wallsFootprintArea, closeTo(0.60, 1e-6));
        expect(floor.calculatedBuiltArea, closeTo(20.60, 1e-6));
      },
    );

    test(
      'Module.fromJson restores isLocked from geometry JSONB when top-level column is absent',
      () {
        final original = Module(
          id: '11111111-1111-4111-8111-111111111111',
          floorId: '22222222-2222-4222-8222-222222222222',
          name: 'Master Suite',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(1, 1, 3.5, 4.0),
          status: ElementStatus.isNew,
          flipX: true,
          isLocked: true,
          createdAt: DateTime.utc(2026, 1, 1),
        );

        final supabaseRow = <String, dynamic>{
          'id': original.id,
          'floor_id': original.floorId,
          'name': original.name,
          'module_type': original.moduleType,
          'geometry': {
            ...original.geometry.toJson(),
            'flip_x': original.flipX,
            'flip_y': original.flipY,
            'is_locked': original.isLocked,
          },
          'status': original.status.name,
          'sub_modules': const <Map<String, dynamic>>[],
          'created_at': original.createdAt.toIso8601String(),
        };

        final restored = Module.fromJson(supabaseRow);
        expect(restored.isLocked, isTrue);
        expect(restored.flipX, isTrue);
      },
    );

    test(
      'Wall.deduplicate collapses same-direction and opposite-direction duplicates within 5cm',
      () {
        final w1 = Wall(
          id: 'w1',
          floorId: 'f1',
          startPoint: const Point2D(0.0, 0.0),
          endPoint: const Point2D(5.0, 0.0),
          status: ElementStatus.isNew,
        );
        final w2Reverse = Wall(
          id: 'w2',
          floorId: 'f1',
          startPoint: const Point2D(5.02, 0.01),
          endPoint: const Point2D(0.01, -0.01),
          status: ElementStatus.isNew,
        );
        final w3Distinct = Wall(
          id: 'w3',
          floorId: 'f1',
          startPoint: const Point2D(0.0, 3.0),
          endPoint: const Point2D(5.0, 3.0),
          status: ElementStatus.isNew,
        );

        final deduped = Wall.deduplicate([w1, w2Reverse, w3Distinct]);
        expect(deduped.map((w) => w.id).toList(), ['w1', 'w3']);
      },
    );
  });

  group('Wave 1 — Render & PDF export invalidation guards', () {
    test(
      'PlanExportOptions.hasSameVisualPlanLayers ignores title-block text edits',
      () {
        const base = PlanExportOptions(
          projectName: 'Casa A',
          pageFormat: PdfPageFormat.a4,
          scaleLabel: '1:50',
        );
        final editedMetadata = base.copyWith(
          projectName: 'Casa B Modificada',
          clientName: 'Nuevo Cliente',
          sheetCode: 'PL-09',
          pageFormat: PdfPageFormat.a3,
        );
        final toggledWalls = base.copyWith(includeWalls: false);

        expect(base.hasSameVisualPlanLayers(editedMetadata), isTrue);
        expect(base == editedMetadata, isFalse);
        expect(base.hasSameVisualPlanLayers(toggledWalls), isFalse);
      },
    );

    test(
      'Canvas2DPainter.shouldRepaint skips non-visual undoStack and dirtyFloorIds updates',
      () {
        final lot = Lot(
          id: 'lot-1',
          projectId: 'proj-1',
          boundary: Polygon2D.fromRect(0, 0, 10, 20),
        );
        final floor = Floor(
          id: 'floor-1',
          buildingId: 'bld-1',
          floorNumber: 1,
          name: 'Level 1',
          boundary: Polygon2D.fromRect(0, 3, 10, 14),
          maxAllowedArea: 140,
        );
        final s1 = FloorEditorState(floor: floor, lot: lot);
        final s2NonVisual = s1.copyWith(
          undoStack: [floor],
          dirtyFloorIds: {'floor-1'},
          hasUnsavedChanges: true,
        );
        final s3ZoomChanged = s1.copyWith(zoom: s1.zoom * 1.2);

        final p1 = Canvas2DPainter(s1);
        expect(Canvas2DPainter(s2NonVisual).shouldRepaint(p1), isFalse);
        expect(Canvas2DPainter(s3ZoomChanged).shouldRepaint(p1), isTrue);
      },
    );

    test('Face3D caches normal, centroid, and defaultShadedColor consistently', () {
      final face = Face3D(
        vertices: const [
          Point3D(0, 0, 0),
          Point3D(2, 0, 0),
          Point3D(2, 2, 0),
          Point3D(0, 2, 0),
        ],
        baseColor: const Color(0xFF4FC3F7),
      );

      expect(identical(face.normal, face.normal), isTrue);
      expect(identical(face.centroid, face.centroid), isTrue);
      expect(
        face.defaultShadedColor,
        equals(face.computeShadedColor(Face3D.defaultSunLight)),
      );
    });

    testWidgets(
      'Room position updates during drag do not trigger rebuilds of floor-header consumers',
      (tester) async {
        var headerBuilds = 0;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  final header = ref.watch(
                    floorEditorProvider.select(
                      (s) => (id: s.floor.id, name: s.floor.name),
                    ),
                  );
                  headerBuilds++;
                  return Text(header.name);
                },
              ),
            ),
          ),
        );

        expect(headerBuilds, 1);

        final element = tester.element(find.byType(Consumer));
        final container = ProviderScope.containerOf(element);
        final notifier = container.read(floorEditorProvider.notifier);
        final firstRoom = container
            .read(floorEditorProvider)
            .floor
            .modules
            .firstWhere((m) => !m.isOpening);

        notifier.beginInteraction();
        notifier.setModulePosition(firstRoom.id, 1.25, 2.50);
        await tester.pump();
        notifier.setModulePosition(firstRoom.id, 1.50, 2.75);
        await tester.pump();
        notifier.endInteraction();
        await tester.pump();

        expect(headerBuilds, 1);
      },
    );
  });
}
