import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('Block 1 — Centimeter precision & Multi-floor heights', () {
    testWidgets(
      'NumericMetricStepper accepts exact manual decimal input (2.34, 3.82, 2.815) without 0.05 rounding',
      (tester) async {
        double? captured;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                child: NumericMetricStepper(
                  label: 'Ancho',
                  value: 2.00,
                  minVal: 0.10,
                  onChanged: (v) => captured = v,
                ),
              ),
            ),
          ),
        );

        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        await tester.enterText(textFieldFinder, '2.34');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(captured, closeTo(2.34, 1e-6));

        await tester.enterText(textFieldFinder, '3,82');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(captured, closeTo(3.82, 1e-6));

        await tester.enterText(textFieldFinder, '2.815');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(captured, closeTo(2.815, 1e-6));
      },
    );

    test(
      'FloorEditorNotifier supports exact precision (snap: false) while keeping default 0.05 snap',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(floorEditorProvider.notifier);
        final room = Module(
          id: 'mod_exact',
          floorId: container.read(floorEditorProvider).floor.id,
          name: 'Sala',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(1.0, 1.0, 3.0, 4.0),
          status: ElementStatus.existing,
        );
        notifier.addModule(room);

        // Exact mode (snap: false) preserves centimeter & millimeter input
        notifier.setModulePosition('mod_exact', 2.34, 2.815, snap: false);
        notifier.setModuleDimensions('mod_exact', 3.82, 2.34, snap: false);

        var updated = container
            .read(floorEditorProvider)
            .floor
            .modules
            .firstWhere((m) => m.id == 'mod_exact');
        expect(updated.geometry.boundingBox.minX, closeTo(2.34, 1e-6));
        expect(updated.geometry.boundingBox.minY, closeTo(2.815, 1e-6));
        expect(updated.geometry.boundingBox.width, closeTo(3.82, 1e-6));
        expect(updated.geometry.boundingBox.height, closeTo(2.34, 1e-6));

        // Default mode (snap: true) keeps 0.05m grid snap for drag compatibility
        notifier.setModulePosition('mod_exact', 2.03, 4.07);
        updated = container
            .read(floorEditorProvider)
            .floor
            .modules
            .firstWhere((m) => m.id == 'mod_exact');
        expect(updated.geometry.boundingBox.minX, closeTo(2.05, 1e-6));
        expect(updated.geometry.boundingBox.minY, closeTo(4.05, 1e-6));
      },
    );

    test(
      'updateFloorProperties syncs Wall.height for all walls on that floor',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(floorEditorProvider.notifier);
        final floorId = container.read(floorEditorProvider).floor.id;
        final floorWithWalls = container.read(floorEditorProvider).floor.copyWith(
              heightMeters: 2.60,
              walls: [
                Wall(
                  id: 'w1',
                  floorId: floorId,
                  startPoint: const Point2D(0, 0),
                  endPoint: const Point2D(5, 0),
                  height: 2.60,
                  status: ElementStatus.existing,
                ),
                Wall(
                  id: 'w2',
                  floorId: floorId,
                  startPoint: const Point2D(5, 0),
                  endPoint: const Point2D(5, 4),
                  height: 2.60,
                  status: ElementStatus.isNew,
                ),
              ],
            );
        notifier.loadProjectData(
          lot: container.read(floorEditorProvider).lot,
          floor: floorWithWalls,
          allFloors: [floorWithWalls],
        );

        notifier.updateFloorProperties(heightMeters: 2.34);

        final updatedFloor = container.read(floorEditorProvider).floor;
        expect(updatedFloor.heightMeters, closeTo(2.34, 1e-6));
        expect(updatedFloor.walls, hasLength(2));
        for (final w in updatedFloor.walls) {
          expect(w.height, closeTo(2.34, 1e-6));
        }
      },
    );

    test(
      'Floor.usableSpacesArea and wallsFootprintArea include ElementStatus.existing',
      () {
        final floor = Floor(
          id: 'p1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: Polygon2D.fromRect(0, 0, 10, 10),
          maxAllowedArea: 100,
          modules: [
            Module(
              id: 'm_existing',
              floorId: 'p1',
              name: 'Sala Existente',
              moduleType: 'LIVING_ROOM',
              geometry: Polygon2D.fromRect(0, 0, 4.0, 3.0), // 12.0 m²
              status: ElementStatus.existing,
            ),
            Module(
              id: 'm_preserved',
              floorId: 'p1',
              name: 'Cocina Conservada',
              moduleType: 'KITCHEN',
              geometry: Polygon2D.fromRect(4, 0, 3.0, 2.0), // 6.0 m²
              status: ElementStatus.preserved,
            ),
            Module(
              id: 'm_new',
              floorId: 'p1',
              name: 'Estudio Nuevo',
              moduleType: 'STUDY',
              geometry: Polygon2D.fromRect(0, 3, 2.0, 2.0), // 4.0 m²
              status: ElementStatus.isNew,
            ),
            Module(
              id: 'm_demo',
              floorId: 'p1',
              name: 'Cuarto a Demoler',
              moduleType: 'STORAGE',
              geometry: Polygon2D.fromRect(2, 3, 2.0, 2.0), // excluded
              status: ElementStatus.toDemolish,
            ),
          ],
          walls: [
            Wall(
              id: 'w_existing',
              floorId: 'p1',
              startPoint: const Point2D(0, 0),
              endPoint: const Point2D(4, 0),
              thickness: 0.15,
              height: 2.34,
              status: ElementStatus.existing,
            ),
            Wall(
              id: 'w_demo',
              floorId: 'p1',
              startPoint: const Point2D(0, 3),
              endPoint: const Point2D(4, 3),
              thickness: 0.15,
              height: 2.34,
              status: ElementStatus.toDemolish,
            ),
          ],
        );

        expect(floor.usableSpacesArea, closeTo(22.0, 1e-6));
        expect(floor.wallsFootprintArea, closeTo(0.60, 1e-6));
        expect(floor.wallsTotalLinearMeters, closeTo(4.0, 1e-6));
      },
    );

    test(
      'RenovationPlannerEngine uses per-floor real heightMeters (2.34m P1, 2.20m P2) for wall areas',
      () {
        final roomP1 = Module(
          id: 'p1_sala',
          floorId: 'p1',
          name: 'Sala P1',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(0, 0, 5.0, 4.0), // perimeter = 18m
          status: ElementStatus.existing,
          wallFinishId: 'wall_pure_white',
        );
        final roomP2 = Module(
          id: 'p2_hab',
          floorId: 'p2',
          name: 'Habitación P2',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(0, 0, 4.0, 3.0), // perimeter = 14m
          status: ElementStatus.existing,
          wallFinishId: 'wall_pure_white',
        );
        final p1 = Floor(
          id: 'p1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: Polygon2D.fromRect(0, 0, 8, 12),
          maxAllowedArea: 96,
          modules: [roomP1],
        );
        final p2 = Floor(
          id: 'p2',
          buildingId: 'b1',
          floorNumber: 2,
          name: 'Piso 2',
          levelMeters: 2.34,
          heightMeters: 2.20,
          boundary: Polygon2D.fromRect(0, 0, 8, 12),
          maxAllowedArea: 96,
          modules: [roomP2],
        );

        final plan = RenovationPlannerEngine.generatePlan(
          allRooms: [roomP1, roomP2],
          floors: [p1, p2],
          renovateFloors: false,
          renovateBathrooms: false,
          renovateKitchen: false,
          renovateWallsPaint: true,
        );

        // Expected net wall m² = (18 * 2.34 + 14 * 2.20) * 0.85
        // = (42.12 + 30.80) * 0.85 = 72.92 * 0.85 = 61.982 -> 61.98 m²
        final wallMat = plan.materials.firstWhere(
          (m) => m.id == 'mat_custom_wall_wall_pure_white',
        );
        expect(wallMat.quantity, closeTo(61.98, 0.02));
      },
    );

    testWidgets(
      'Viewer3dScreen full-height toggle displays real floor height instead of hardcoded 2.60 m',
      (tester) async {
        final lot = Lot(
          id: 'lot_bogota',
          projectId: 'proj_bogota',
          boundary: Polygon2D.fromRect(0, 0, 7.0, 12.0),
        );
        final p1 = Floor(
          id: 'p1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: lot.boundary,
          maxAllowedArea: 84,
          modules: [
            Module(
              id: 'm1',
              floorId: 'p1',
              name: 'Sala',
              moduleType: 'LIVING_ROOM',
              geometry: Polygon2D.fromRect(0, 0, 4.0, 4.0),
              status: ElementStatus.existing,
            ),
          ],
        );
        final p2 = Floor(
          id: 'p2',
          buildingId: 'b1',
          floorNumber: 2,
          name: 'Piso 2',
          levelMeters: 2.34,
          heightMeters: 2.20,
          boundary: lot.boundary,
          maxAllowedArea: 84,
          modules: [
            Module(
              id: 'm2',
              floorId: 'p2',
              name: 'Alcoba',
              moduleType: 'BEDROOM',
              geometry: Polygon2D.fromRect(0, 0, 4.0, 4.0),
              status: ElementStatus.existing,
            ),
          ],
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(floorEditorProvider.notifier).loadProjectData(
              lot: lot,
              floor: p1,
              allFloors: [p1, p2],
            );

        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Viewer3dScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final toggleBtn = find.byIcon(Icons.view_compact_alt);
        expect(toggleBtn, findsOneWidget);
        final iconBtnWidget = tester.widget<IconButton>(
          find.ancestor(of: toggleBtn, matching: find.byType(IconButton)),
        );
        expect(iconBtnWidget.tooltip, contains('2.34'));
        expect(iconBtnWidget.tooltip, isNot(contains('2.60')));
      },
    );
  });
}
