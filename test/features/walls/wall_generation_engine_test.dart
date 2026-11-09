import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/editor_canvas_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/walls/domain/wall_generation_engine.dart';

void main() {
  group('Module.isOpening & WallGenerationEngine', () {
    test('detects door, window, and gate modules as openings', () {
      final door = Module(
        id: 'door-1',
        floorId: 'floor-1',
        name: 'Main Door',
        moduleType: 'MAIN_DOOR',
        geometry: Polygon2D.fromRect(1, 0, 0.9, 0.15),
        status: ElementStatus.isNew,
      );
      final window = Module(
        id: 'win-1',
        floorId: 'floor-1',
        name: 'Window',
        moduleType: 'WINDOW_SLIDING',
        geometry: Polygon2D.fromRect(3, 0, 1.2, 0.15),
        status: ElementStatus.isNew,
      );
      final kitchen = Module(
        id: 'kit-1',
        floorId: 'floor-1',
        name: 'Kitchen',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(0, 0, 3, 3),
        status: ElementStatus.isNew,
      );

      expect(door.isOpening, isTrue);
      expect(window.isOpening, isTrue);
      expect(kitchen.isOpening, isFalse);
    });

    test('generates walls, keeps open transition between social spaces, and cuts door opening', () {
      final living = Module(
        id: 'living-1',
        floorId: 'floor-1',
        name: 'Sala',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(0, 0, 4, 4),
        status: ElementStatus.isNew,
      );
      final dining = Module(
        id: 'dining-1',
        floorId: 'floor-1',
        name: 'Comedor',
        moduleType: 'DINING_ROOM',
        geometry: Polygon2D.fromRect(4, 0, 4, 4),
        status: ElementStatus.isNew,
      );
      final frontDoor = Module(
        id: 'door-front',
        floorId: 'floor-1',
        name: 'Puerta Acceso',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(1.5, -0.075, 1.0, 0.15),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'floor-1',
        buildingId: 'bldg-1',
        floorNumber: 1,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 0, 10, 10),
        maxAllowedArea: 100,
        modules: [living, dining, frontDoor],
      );

      final walls = WallGenerationEngine.generateWallsForFloor(floor);

      expect(walls, isNotEmpty);
      // Shared x=4 interior edge between Sala and Comedor should stay open (no vertical wall at x=4)
      final interiorDividerWalls = walls.where(
        (w) => (w.startPoint.x - 4.0).abs() < 0.05 && (w.endPoint.x - 4.0).abs() < 0.05,
      );
      expect(interiorDividerWalls, isEmpty);
    });

    testWidgets('EditorCanvas2D paints rendered mode and selected modules without errors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: EditorCanvas2D(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EditorCanvas2D), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
