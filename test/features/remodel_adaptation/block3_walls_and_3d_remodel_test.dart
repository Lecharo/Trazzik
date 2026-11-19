import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/wall_inspector_section.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('Block 3 — Wall Remodeling Status, Split/Draw & 3D Before/After View', () {
    test('FloorEditorNotifier supports setWallStatus, splitWall, and addManualWall', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      final baseFloor = container.read(floorEditorProvider).floor.copyWith(
            heightMeters: 2.34,
            walls: [
              Wall(
                id: 'w_orig',
                floorId: container.read(floorEditorProvider).floor.id,
                startPoint: const Point2D(0, 0),
                endPoint: const Point2D(6.0, 0),
                thickness: 0.15,
                height: 2.34,
                status: ElementStatus.existing,
              ),
            ],
          );
      notifier.loadProjectData(
        lot: container.read(floorEditorProvider).lot,
        floor: baseFloor,
        allFloors: [baseFloor],
      );

      // Change status
      notifier.setWallStatus('w_orig', ElementStatus.toDemolish);
      expect(
        container.read(floorEditorProvider).floor.walls.first.status,
        equals(ElementStatus.toDemolish),
      );

      // Split 6m wall into two 3m walls
      notifier.splitWall('w_orig');
      final splitWalls = container.read(floorEditorProvider).floor.walls;
      expect(splitWalls, hasLength(2));
      expect(splitWalls[0].length, closeTo(3.0, 1e-6));
      expect(splitWalls[1].length, closeTo(3.0, 1e-6));
      expect(splitWalls[0].endPoint.x, closeTo(3.0, 1e-6));
      expect(splitWalls[1].startPoint.x, closeTo(3.0, 1e-6));

      // Mark only second half as preserved while first remains toDemolish
      notifier.setWallStatus(splitWalls[1].id, ElementStatus.preserved);
      final afterStatus = container.read(floorEditorProvider).floor.walls;
      expect(afterStatus[0].status, equals(ElementStatus.toDemolish));
      expect(afterStatus[1].status, equals(ElementStatus.preserved));

      // Add manual new partition wall inheriting floor height 2.34m
      notifier.addManualWall(
        const Point2D(2.0, 0.0),
        const Point2D(2.0, 3.5),
        thickness: 0.10,
        status: ElementStatus.isNew,
      );
      final withManual = container.read(floorEditorProvider).floor.walls;
      expect(withManual, hasLength(3));
      expect(withManual.last.height, closeTo(2.34, 1e-6));
      expect(withManual.last.status, equals(ElementStatus.isNew));
    });

    testWidgets(
      'WallInspectorSection exposes ElementStatus chips and Split Wall action',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(floorEditorProvider.notifier);
        final wall = Wall(
          id: 'w_ui',
          floorId: container.read(floorEditorProvider).floor.id,
          startPoint: const Point2D(0, 0),
          endPoint: const Point2D(4.0, 0),
          height: 2.34,
          status: ElementStatus.existing,
        );
        final floor = container.read(floorEditorProvider).floor.copyWith(walls: [wall]);
        notifier.loadProjectData(
          lot: container.read(floorEditorProvider).lot,
          floor: floor,
          allFloors: [floor],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WallInspectorSection(
                  wall: wall,
                  notifier: notifier,
                  lang: 'es',
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('wall_status_existing')), findsOneWidget);
        expect(find.byKey(const Key('wall_status_preserved')), findsOneWidget);
        expect(find.byKey(const Key('wall_status_toDemolish')), findsOneWidget);
        expect(find.byKey(const Key('wall_status_isNew')), findsOneWidget);

        await tester.tap(find.byKey(const Key('wall_status_toDemolish')));
        await tester.pump();
        expect(
          container.read(floorEditorProvider).floor.walls.first.status,
          equals(ElementStatus.toDemolish),
        );

        await tester.tap(find.byKey(const Key('split_wall_button')));
        await tester.pump();
        expect(container.read(floorEditorProvider).floor.walls, hasLength(2));
      },
    );

    test(
      'Building3DBuilder filters Before / After and highlights Demolition (red) & New (green) in Comparison mode',
      () {
        final lot = Lot(
          id: 'lot_cmp',
          projectId: 'p1',
          boundary: Polygon2D.fromRect(0, 0, 8, 10),
        );
        final floor = Floor(
          id: 'fl1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: lot.boundary,
          maxAllowedArea: 80,
          modules: [
            Module(
              id: 'm_exist',
              floorId: 'fl1',
              name: 'Sala Existente',
              moduleType: 'LIVING_ROOM',
              geometry: Polygon2D.fromRect(0, 0, 4, 4),
              status: ElementStatus.existing,
            ),
            Module(
              id: 'm_pres',
              floorId: 'fl1',
              name: 'Cocina Conservada',
              moduleType: 'KITCHEN',
              geometry: Polygon2D.fromRect(4, 0, 3, 4),
              status: ElementStatus.preserved,
            ),
            Module(
              id: 'm_demo',
              floorId: 'fl1',
              name: 'Cuarto Demoler',
              moduleType: 'STORAGE',
              geometry: Polygon2D.fromRect(0, 4, 3, 3),
              status: ElementStatus.toDemolish,
            ),
            Module(
              id: 'm_new',
              floorId: 'fl1',
              name: 'Estudio Nuevo',
              moduleType: 'STUDY',
              geometry: Polygon2D.fromRect(3, 4, 3, 3),
              status: ElementStatus.isNew,
            ),
          ],
          walls: [
            Wall(
              id: 'w_demo',
              floorId: 'fl1',
              startPoint: const Point2D(0, 4),
              endPoint: const Point2D(3, 4),
              height: 2.34,
              status: ElementStatus.toDemolish,
            ),
            Wall(
              id: 'w_new',
              floorId: 'fl1',
              startPoint: const Point2D(3, 4),
              endPoint: const Point2D(6, 4),
              height: 2.34,
              status: ElementStatus.isNew,
            ),
          ],
        );

        // BEFORE: existing + preserved + toDemolish (excludes isNew)
        final beforeFaces = Building3DBuilder.buildScene(
          floors: [floor],
          lot: lot,
          viewMode: RemodelViewMode3D.before,
        );
        final beforeRoomIds = beforeFaces
            .where((f) => f.layer == FaceLayer3D.floorFinish)
            .map((f) => f.moduleId)
            .toSet();
        expect(beforeRoomIds, containsAll(['m_exist', 'm_pres', 'm_demo']));
        expect(beforeRoomIds, isNot(contains('m_new')));

        // AFTER: existing + preserved + isNew (excludes toDemolish)
        final afterFaces = Building3DBuilder.buildScene(
          floors: [floor],
          lot: lot,
          viewMode: RemodelViewMode3D.after,
        );
        final afterRoomIds = afterFaces
            .where((f) => f.layer == FaceLayer3D.floorFinish)
            .map((f) => f.moduleId)
            .toSet();
        expect(afterRoomIds, containsAll(['m_exist', 'm_pres', 'm_new']));
        expect(afterRoomIds, isNot(contains('m_demo')));

        // COMPARISON: includes all 4, highlights toDemolish in translucent red & isNew in green
        final cmpFaces = Building3DBuilder.buildScene(
          floors: [floor],
          lot: lot,
          viewMode: RemodelViewMode3D.comparison,
        );
        final cmpRoomIds = cmpFaces
            .where((f) => f.layer == FaceLayer3D.floorFinish)
            .map((f) => f.moduleId)
            .toSet();
        expect(cmpRoomIds, containsAll(['m_exist', 'm_pres', 'm_demo', 'm_new']));

        final demoFloorFace = cmpFaces.firstWhere(
          (f) => f.layer == FaceLayer3D.floorFinish && f.moduleId == 'm_demo',
        );
        expect(demoFloorFace.baseColor.a, lessThan(0.95));
        expect(demoFloorFace.baseColor.r, greaterThan(demoFloorFace.baseColor.g));

        final newFloorFace = cmpFaces.firstWhere(
          (f) => f.layer == FaceLayer3D.floorFinish && f.moduleId == 'm_new',
        );
        expect(newFloorFace.baseColor.g, greaterThan(newFloorFace.baseColor.r));

        final demoWallFaces = cmpFaces.where(
          (f) => f.isWallFace && f.baseColor.a < 0.95 && f.baseColor.r > f.baseColor.g,
        );
        expect(demoWallFaces, isNotEmpty);

        final newWallFaces = cmpFaces.where(
          (f) => f.isWallFace && f.baseColor.g > f.baseColor.r && f.baseColor.g > 0.5,
        );
        expect(newWallFaces, isNotEmpty);
      },
    );

    testWidgets(
      'Viewer3dScreen renders live Antes / Después / Comparativo toggle and switches cleanly',
      (tester) async {
        final lot = Lot(
          id: 'lot1',
          projectId: 'p1',
          boundary: Polygon2D.fromRect(0, 0, 7, 12),
        );
        final floor = Floor(
          id: 'fl1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: lot.boundary,
          maxAllowedArea: 84,
          modules: [
            Module(
              id: 'm1',
              floorId: 'fl1',
              name: 'Sala',
              moduleType: 'LIVING_ROOM',
              geometry: Polygon2D.fromRect(0, 0, 4, 4),
              status: ElementStatus.existing,
            ),
          ],
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(floorEditorProvider.notifier).loadProjectData(
              lot: lot,
              floor: floor,
              allFloors: [floor],
            );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Viewer3dScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('remodel_mode_before')), findsOneWidget);
        expect(find.byKey(const Key('remodel_mode_after')), findsOneWidget);
        expect(find.byKey(const Key('remodel_mode_comparison')), findsOneWidget);

        await tester.tap(find.byKey(const Key('remodel_mode_before')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('remodel_mode_comparison')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('remodel_comparison_legend')), findsOneWidget);
      },
    );
  });
}
