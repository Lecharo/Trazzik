import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/canvas_2d_painter.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/editor_canvas_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/live_split_3d_pane.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

({Lot lot, Floor floor1, Floor floor2}) _buildTwoStoryProject() {
  final lot = Lot(
    id: 'lot-comp',
    projectId: 'proj-comp',
    boundary: Polygon2D.fromRect(0, 0, 10, 14),
  );
  final floor1 = Floor(
    id: 'f1-comp',
    buildingId: 'b-comp',
    floorNumber: 1,
    name: 'Piso 1',
    boundary: Polygon2D.fromRect(0, 0, 10, 12),
    maxAllowedArea: 120,
    modules: [
      Module(
        id: 'm1-living',
        floorId: 'f1-comp',
        name: 'Sala',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(1.0, 1.0, 4.0, 3.0),
        status: ElementStatus.existing,
      ),
      Module(
        id: 'm1-kitchen',
        floorId: 'f1-comp',
        name: 'Cocina',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(5.0, 1.0, 3.0, 3.0),
        status: ElementStatus.isNew,
      ),
      Module(
        id: 'm1-old-shed',
        floorId: 'f1-comp',
        name: 'Depósito Viejo',
        moduleType: 'STORAGE',
        geometry: Polygon2D.fromRect(8.0, 1.0, 1.5, 2.0),
        status: ElementStatus.toDemolish,
      ),
      Module(
        id: 'm1-stairs',
        floorId: 'f1-comp',
        name: 'Escalera',
        moduleType: 'STAIRS',
        geometry: Polygon2D.fromRect(1.0, 4.0, 2.0, 3.0),
        status: ElementStatus.existing,
      ),
      Module(
        id: 'm1-door',
        floorId: 'f1-comp',
        name: 'Puerta',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(4.92, 2.0, 0.16, 0.90),
        status: ElementStatus.isNew,
      ),
    ],
    walls: [
      Wall(
        id: 'w1-front',
        floorId: 'f1-comp',
        startPoint: const Point2D(1.0, 1.0),
        endPoint: const Point2D(8.0, 1.0),
        status: ElementStatus.existing,
      ),
      Wall(
        id: 'w1-demo',
        floorId: 'f1-comp',
        startPoint: const Point2D(8.0, 1.0),
        endPoint: const Point2D(8.0, 3.0),
        status: ElementStatus.toDemolish,
      ),
    ],
  );

  final floor2 = Floor(
    id: 'f2-comp',
    buildingId: 'b-comp',
    floorNumber: 2,
    name: 'Piso 2',
    levelMeters: 2.60,
    boundary: Polygon2D.fromRect(0, 0, 10, 12),
    maxAllowedArea: 120,
    modules: [
      Module(
        id: 'm2-bed',
        floorId: 'f2-comp',
        name: 'Alcoba Principal',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(1.0, 1.0, 4.0, 3.5),
        status: ElementStatus.isNew,
      ),
    ],
  );

  return (lot: lot, floor1: floor1, floor2: floor2);
}

void main() {
  group('Block A — 2D Onion-Skin Ghost, Chain Dimensions & Precision Nudge', () {
    test('ghostReferenceFloor resolves floor immediately below and paints cleanly', () {
      final data = _buildTwoStoryProject();
      final stateF1 = FloorEditorState(
        lot: data.lot,
        floor: data.floor1,
        allFloors: [data.floor1, data.floor2],
        showFloorGhost: true,
      );
      expect(stateF1.ghostReferenceFloor, isNull);

      final stateF2 = FloorEditorState(
        lot: data.lot,
        floor: data.floor2,
        allFloors: [data.floor1, data.floor2],
        showFloorGhost: true,
        showPerimeterDimensions: true,
      );
      expect(stateF2.ghostReferenceFloor?.id, data.floor1.id);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = Canvas2DPainter(stateF2, isDarkTheme: false);
      expect(
        () => painter.paint(canvas, const Size(960, 640)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('computeExteriorChainDimensions clusters touching rooms and excludes openings & demolished rooms', () {
      final data = _buildTwoStoryProject();
      final chain = computeExteriorChainDimensions(data.floor1);

      // Active non-opening rooms on X: [1.0..5.0], [5.0..8.0], [1.0..3.0] -> stops: 1.0, 3.0, 5.0, 8.0
      expect(chain.xStops, [1.0, 3.0, 5.0, 8.0]);
      // Active non-opening rooms on Y: [1.0..4.0], [4.0..7.0] -> stops: 1.0, 4.0, 7.0
      expect(chain.yStops, [1.0, 4.0, 7.0]);
      expect(chain.totalWidth, closeTo(7.0, 1e-6));
      expect(chain.totalDepth, closeTo(6.0, 1e-6));
    });

    test('nudgeSelectedElement moves unlocked module by exact cm deltas and supports Undo', () {
      final data = _buildTwoStoryProject();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: data.lot,
        floor: data.floor1,
        allFloors: [data.floor1, data.floor2],
      );
      notifier.selectModule('m1-living');

      notifier.nudgeSelectedElement(0.05, 0.0);
      notifier.nudgeSelectedElement(0.0, 0.01);

      final moved = container
          .read(floorEditorProvider)
          .floor
          .modules
          .firstWhere((m) => m.id == 'm1-living');
      expect(moved.geometry.boundingBox.minX, closeTo(1.05, 1e-6));
      expect(moved.geometry.boundingBox.minY, closeTo(1.01, 1e-6));

      notifier.undo();
      final afterUndo = container
          .read(floorEditorProvider)
          .floor
          .modules
          .firstWhere((m) => m.id == 'm1-living');
      expect(afterUndo.geometry.boundingBox.minY, closeTo(1.00, 1e-6));
    });

    testWidgets('right-clicking a room opens context menu and toggles lock without panning', (tester) async {
      final data = _buildTwoStoryProject();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: data.lot,
        floor: data.floor1,
        allFloors: [data.floor1, data.floor2],
      );
      notifier.updateZoom(40.0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SizedBox(width: 800, height: 600, child: EditorCanvas2D()),
            ),
          ),
        ),
      );
      await tester.pump();

      final st = container.read(floorEditorProvider);
      final topLeft = tester.getTopLeft(find.byType(EditorCanvas2D));
      final roomCenterGlobal = topLeft +
          Offset(
            3.0 * st.zoom + st.panOffset.dx,
            2.5 * st.zoom + st.panOffset.dy,
          );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.down(roomCenterGlobal, buttons: kSecondaryMouseButton),
      );
      await tester.sendEventToBinding(pointer.up());
      await tester.pumpAndSettle();

      expect(find.text('Bloquear posición'), findsOneWidget);
      await tester.tap(find.text('Bloquear posición'));
      await tester.pumpAndSettle();

      final locked = container
          .read(floorEditorProvider)
          .floor
          .modules
          .firstWhere((m) => m.id == 'm1-living');
      expect(locked.isLocked, isTrue);
    });
  });

  group('Block B — Live 2D+3D Split-Screen, 3D ViewCube & Before/After Curtain', () {
    testWidgets('EditorScreen toggles Live 2D+3D Split-Screen on desktop viewport', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final data = _buildTwoStoryProject();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: data.lot,
        floor: data.floor2,
        allFloors: [data.floor1, data.floor2],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const EditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Onion-skin toggle is visible on Floor 2
      expect(find.byKey(const Key('toggle_floor_ghost_btn')), findsOneWidget);
      expect(find.byKey(const Key('toggle_perimeter_dims_btn')), findsOneWidget);
      expect(find.byKey(const Key('toggle_split_view_3d_btn')), findsOneWidget);
      expect(find.byType(LiveSplit3dPane), findsNothing);

      // Enable Live 2D+3D Split-Screen
      await tester.tap(find.byKey(const Key('toggle_split_view_3d_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(LiveSplit3dPane), findsOneWidget);

      // Close via pane close button
      await tester.tap(find.byKey(const Key('close_split_3d_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(LiveSplit3dPane), findsNothing);
    });

    testWidgets('Viewer3dScreen exposes ViewCube presets and interactive Before/After Split Curtain', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final data = _buildTwoStoryProject();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: data.lot,
        floor: data.floor1,
        allFloors: [data.floor1, data.floor2],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Viewer3dScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ViewCube camera presets are visible & interactive
      expect(find.byKey(const Key('viewer_3d_viewcube_bar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('camera_preset_top')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('camera_preset_front')));
      await tester.pump();

      // Activate Before/After Split Curtain Slider
      await tester.tap(find.byKey(const Key('toggle_curtain_view_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('curtain_before_badge')), findsOneWidget);
      expect(find.byKey(const Key('curtain_after_badge')), findsOneWidget);
      expect(find.byKey(const Key('curtain_split_handle')), findsOneWidget);

      // Drag curtain handle horizontally
      await tester.drag(
        find.byKey(const Key('curtain_split_handle')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('curtain_split_handle')), findsOneWidget);

      // Switching back to "Después" dismisses the curtain cleanly
      await tester.tap(find.byKey(const Key('remodel_mode_after')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('curtain_split_handle')), findsNothing);
    });
  });
}
