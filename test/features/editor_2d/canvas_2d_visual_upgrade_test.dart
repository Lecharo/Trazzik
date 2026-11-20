import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/canvas_2d_painter.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/editor_canvas_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

Floor _buildSampleFloor() {
  const floorId = 'f-2d-upgrade';
  return Floor(
    id: floorId,
    buildingId: 'b-2d-upgrade',
    floorNumber: 1,
    name: 'Piso 1',
    boundary: Polygon2D.fromRect(0, 0, 10, 12),
    maxAllowedArea: 120,
    modules: [
      Module(
        id: 'mod-living',
        floorId: floorId,
        name: 'Sala Principal',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(1.0, 1.0, 4.0, 3.0),
        status: ElementStatus.existing,
        subModules: [
          SubModule(
            id: 'sub-sofa',
            moduleId: 'mod-living',
            name: 'Sofá',
            type: 'SOFA',
            geometry: Polygon2D.fromRect(1.4, 1.4, 1.8, 0.8),
            status: ElementStatus.existing,
          ),
        ],
      ),
      Module(
        id: 'mod-kitchen',
        floorId: floorId,
        name: 'Cocina Nueva',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(5.0, 1.0, 3.0, 3.0),
        status: ElementStatus.isNew,
      ),
      Module(
        id: 'mod-door',
        floorId: floorId,
        name: 'Puerta',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(4.92, 2.0, 0.16, 0.90),
        status: ElementStatus.isNew,
      ),
    ],
    walls: [
      Wall(
        id: 'wall-existing',
        floorId: floorId,
        startPoint: const Point2D(1.0, 1.0),
        endPoint: const Point2D(5.0, 1.0),
        status: ElementStatus.existing,
      ),
      Wall(
        id: 'wall-new',
        floorId: floorId,
        startPoint: const Point2D(5.0, 1.0),
        endPoint: const Point2D(5.0, 4.0),
        status: ElementStatus.isNew,
      ),
      Wall(
        id: 'wall-demo',
        floorId: floorId,
        startPoint: const Point2D(1.0, 4.0),
        endPoint: const Point2D(5.0, 4.0),
        status: ElementStatus.toDemolish,
      ),
    ],
  );
}

Lot _buildSampleLot() => Lot(
      id: 'lot-2d-upgrade',
      projectId: 'proj-2d-upgrade',
      boundary: Polygon2D.fromRect(0, 0, 10, 14),
    );

void main() {
  group('2D Canvas Visual Upgrade — Geometry & Smart Snap Helpers', () {
    test('computeSmartSnapGuides snaps edges within threshold and emits guides', () {
      final floor = _buildSampleFloor();

      // Drag mod-living near mod-kitchen's top (y=1.0) and left (x=5.0)
      final snap = computeSmartSnapGuides(
        candidateX: 1.06, // right edge = 5.06 -> snaps to 5.00
        candidateY: 1.05, // top edge = 1.05 -> snaps to 1.00
        width: 4.0,
        height: 3.0,
        floor: floor,
        excludeModuleId: 'mod-living',
        thresholdMeters: 0.12,
      );

      expect(snap.x, closeTo(1.0, 1e-6));
      expect(snap.y, closeTo(1.0, 1e-6));
      expect(snap.guides.where((g) => g.isVertical), isNotEmpty);
      expect(snap.guides.where((g) => !g.isVertical), isNotEmpty);
    });

    test('computeSmartSnapGuides returns untouched coordinates when far from edges', () {
      final floor = _buildSampleFloor();

      final snap = computeSmartSnapGuides(
        candidateX: 2.33,
        candidateY: 6.42,
        width: 1.2,
        height: 1.1,
        floor: floor,
        excludeModuleId: 'mod-living',
        thresholdMeters: 0.10,
      );

      expect(snap.x, closeTo(2.33, 1e-6));
      expect(snap.y, closeTo(6.42, 1e-6));
      expect(snap.guides, isEmpty);
    });

    test('computeModuleResizeHandles returns 8 handles only for unlocked rectangular rooms', () {
      final floor = _buildSampleFloor();
      final room = floor.modules.first;
      final door = floor.modules.last;

      final roomHandles = computeModuleResizeHandles(room);
      expect(roomHandles.length, 8);
      expect(roomHandles[ResizeHandle2D.topLeft], const Point2D(1.0, 1.0));
      expect(roomHandles[ResizeHandle2D.right], const Point2D(5.0, 2.5));
      expect(roomHandles[ResizeHandle2D.bottomRight], const Point2D(5.0, 4.0));

      expect(computeModuleResizeHandles(room.copyWith(isLocked: true)), isEmpty);
      expect(computeModuleResizeHandles(door), isEmpty);

      final lShaped = room.copyWith(
        geometry: Polygon2D(const [
          Point2D(0, 0),
          Point2D(3, 0),
          Point2D(3, 1),
          Point2D(2, 1),
          Point2D(2, 3),
          Point2D(0, 3),
        ]),
      );
      expect(computeModuleResizeHandles(lShaped), isEmpty);
    });
  });

  group('Canvas2DPainter — Dark/Light Themes, Wall Poché, Rulers & Repaint', () {
    test('paints cleanly in Dark and Light modes with walls, handles, guides, and cursor badge', () {
      final floor = _buildSampleFloor();
      final state = FloorEditorState(
        lot: _buildSampleLot(),
        floor: floor,
        allFloors: [floor],
        zoom: 42.0,
        panOffset: const Offset(60, 60),
        selectedModuleId: 'mod-living',
      );

      for (final isDark in [true, false]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = Canvas2DPainter(
          state,
          lang: 'es',
          isDarkTheme: isDark,
          hoveredModuleId: 'mod-kitchen',
          hoveredWallId: 'wall-new',
          hoveredHandle: ResizeHandle2D.right,
          cursorMeters: const Point2D(3.45, 2.18),
          snapGuides: const [
            SnapGuide2D(isVertical: true, coordinate: 5.0, start: 0.65, end: 4.35),
          ],
        );

        expect(
          () => painter.paint(canvas, const Size(960, 640)),
          returnsNormally,
        );
        recorder.endRecording().dispose();
      }
    });

    test('shouldRepaint detects theme, hover, handle, cursor, and snap guide changes', () {
      final floor = _buildSampleFloor();
      final state = FloorEditorState(
        lot: _buildSampleLot(),
        floor: floor,
        allFloors: [floor],
      );

      final base = Canvas2DPainter(state, isDarkTheme: true);
      expect(base.shouldRepaint(Canvas2DPainter(state, isDarkTheme: true)), isFalse);
      expect(base.shouldRepaint(Canvas2DPainter(state, isDarkTheme: false)), isTrue);
      expect(
        base.shouldRepaint(Canvas2DPainter(state, hoveredModuleId: 'mod-living')),
        isTrue,
      );
      expect(
        base.shouldRepaint(Canvas2DPainter(state, hoveredWallId: 'wall-new')),
        isTrue,
      );
      expect(
        base.shouldRepaint(Canvas2DPainter(state, hoveredHandle: ResizeHandle2D.right)),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          Canvas2DPainter(state, cursorMeters: const Point2D(2.0, 3.0)),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          Canvas2DPainter(
            state,
            snapGuides: const [
              SnapGuide2D(isVertical: true, coordinate: 5.0, start: 0.0, end: 4.0),
            ],
          ),
        ),
        isTrue,
      );
    });
  });

  group('EditorCanvas2D — Interactive Hover Cursor & Direct Handle Resize', () {
    testWidgets(
      'hovering selected room right handle updates cursor and dragging resizes room in 1 Undo step',
      (tester) async {
        final floor = _buildSampleFloor();
        final lot = _buildSampleLot();

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(floorEditorProvider.notifier);
        notifier.loadProjectData(
          lot: lot,
          floor: floor,
          allFloors: [floor],
        );
        notifier.updateZoom(40.0);
        notifier.selectModule('mod-living');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.light(),
              home: const Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 600,
                  child: EditorCanvas2D(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final st = container.read(floorEditorProvider);
        // Selected room mod-living spans x:[1..5], y:[1..4]
        // Right midpoint handle is at (5.0, 2.5) in floor meters
        final canvasTopLeft = tester.getTopLeft(find.byType(EditorCanvas2D));
        final rightHandleGlobal = canvasTopLeft +
            Offset(
              5.0 * st.zoom + st.panOffset.dx,
              2.5 * st.zoom + st.panOffset.dy,
            );

        // Hover over the right handle -> cursor becomes resizeLeftRight
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(rightHandleGlobal);
        await tester.pump();

        final mouseRegion = tester.widget<MouseRegion>(
          find.descendant(
            of: find.byType(EditorCanvas2D),
            matching: find.byType(MouseRegion),
          ),
        );
        expect(mouseRegion.cursor, SystemMouseCursors.resizeLeftRight);

        // Drag right handle +80px (+2.00m at zoom=40) -> width grows from 4.0m to 6.0m
        final gesture = await tester.startGesture(rightHandleGlobal);
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        final resized = container
            .read(floorEditorProvider)
            .floor
            .modules
            .firstWhere((m) => m.id == 'mod-living');
        expect(resized.geometry.boundingBox.width, closeTo(6.0, 0.06));
        expect(resized.geometry.boundingBox.height, closeTo(3.0, 0.06));

        // Single Undo restores original 4.0m width!
        notifier.undo();
        await tester.pump();
        final undone = container
            .read(floorEditorProvider)
            .floor
            .modules
            .firstWhere((m) => m.id == 'mod-living');
        expect(undone.geometry.boundingBox.width, closeTo(4.0, 0.01));
      },
    );
  });
}
