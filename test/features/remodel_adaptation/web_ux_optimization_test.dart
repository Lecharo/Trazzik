import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/editor_canvas_2d.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart';

void main() {
  group('Desktop Web UX Optimizations — 2D/3D Mouse, Zoom & Keyboard Shortcuts', () {
    test(
      'FloorEditorNotifier.zoomAtPoint keeps world coordinate under cursor fixed',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(floorEditorProvider.notifier);
        final before = container.read(floorEditorProvider);
        const focal = Offset(300, 220);
        final worldBeforeX = (focal.dx - before.panOffset.dx) / before.zoom;
        final worldBeforeY = (focal.dy - before.panOffset.dy) / before.zoom;

        notifier.zoomAtPoint(before.zoom * 1.4, focal);

        final after = container.read(floorEditorProvider);
        expect(after.zoom, greaterThan(before.zoom));
        final worldAfterX = (focal.dx - after.panOffset.dx) / after.zoom;
        final worldAfterY = (focal.dy - after.panOffset.dy) / after.zoom;
        expect(worldAfterX, closeTo(worldBeforeX, 1e-6));
        expect(worldAfterY, closeTo(worldBeforeY, 1e-6));
      },
    );

    test(
      'cancelActiveToolsOrSelection and deleteSelectedElement respect modes and locks',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(floorEditorProvider.notifier);
        final floorId = container.read(floorEditorProvider).floor.id;

        notifier.toggleDrawWallMode();
        expect(container.read(floorEditorProvider).isDrawWallMode, isTrue);
        notifier.cancelActiveToolsOrSelection();
        expect(container.read(floorEditorProvider).isDrawWallMode, isFalse);

        final unlocked = Module(
          id: 'mod_del_test',
          floorId: floorId,
          name: 'Estudio',
          moduleType: 'STUDY',
          geometry: Polygon2D.fromRect(1, 1, 2, 2),
          status: ElementStatus.isNew,
        );
        notifier.addModule(unlocked);
        notifier.selectModule('mod_del_test');
        notifier.deleteSelectedElement();
        expect(
          container
              .read(floorEditorProvider)
              .floor
              .modules
              .any((m) => m.id == 'mod_del_test'),
          isFalse,
        );

        final locked = unlocked.copyWith(id: 'mod_locked_test', isLocked: true);
        notifier.addModule(locked);
        notifier.selectModule('mod_locked_test');
        notifier.deleteSelectedElement();
        expect(
          container
              .read(floorEditorProvider)
              .floor
              .modules
              .any((m) => m.id == 'mod_locked_test'),
          isTrue,
        );
      },
    );

    testWidgets(
      'EditorCanvas2D zooms on mouse wheel PointerScrollEvent and uses precise cursor in draw-wall mode',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: EditorCanvas2D()),
            ),
          ),
        );

        final initialZoom = container.read(floorEditorProvider).zoom;
        final center = tester.getCenter(find.byType(EditorCanvas2D));
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(center));
        await tester.sendEventToBinding(
          pointer.scroll(const Offset(0, -120)),
        );
        await tester.pump();

        expect(
          container.read(floorEditorProvider).zoom,
          greaterThan(initialZoom),
        );

        container.read(floorEditorProvider.notifier).toggleDrawWallMode();
        await tester.pump();
        final mouseRegion = tester.widget<MouseRegion>(
          find.descendant(
            of: find.byType(EditorCanvas2D),
            matching: find.byType(MouseRegion),
          ),
        );
        expect(mouseRegion.cursor, equals(SystemMouseCursors.precise));
      },
    );

    testWidgets(
      'EditorScreen keyboard shortcuts handle Ctrl+Z undo, Ctrl+Y redo, and Escape',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: EditorScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final notifier = container.read(floorEditorProvider.notifier);
        final initialCount =
            container.read(floorEditorProvider).floor.modules.length;
        notifier.addModule(
          Module(
            id: 'mod_kbd',
            floorId: container.read(floorEditorProvider).floor.id,
            name: 'Cuarto Teclado',
            moduleType: 'STUDY',
            geometry: Polygon2D.fromRect(1, 1, 2, 2),
            status: ElementStatus.isNew,
          ),
        );
        await tester.pump();
        expect(
          container.read(floorEditorProvider).floor.modules.length,
          equals(initialCount + 1),
        );

        // Ctrl+Z -> Undo
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(
          container.read(floorEditorProvider).floor.modules.length,
          equals(initialCount),
        );

        // Ctrl+Y -> Redo
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyY);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyY);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(
          container.read(floorEditorProvider).floor.modules.length,
          equals(initialCount + 1),
        );

        // Escape exits draw-wall mode
        notifier.toggleDrawWallMode();
        await tester.pump();
        expect(container.read(floorEditorProvider).isDrawWallMode, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(container.read(floorEditorProvider).isDrawWallMode, isFalse);
      },
    );

    testWidgets(
      'AxonometricCanvas3D pans on secondary mouse button drag without orbiting',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final state = container.read(floorEditorProvider);
        final faces = Building3DBuilder.buildScene(
          floors: [state.floor],
          lot: state.lot,
        );

        Offset? capturedPan;
        bool orbited = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AxonometricCanvas3D(
                faces: faces,
                onPanChanged: (p) => capturedPan = p,
                onOrbitChanged: (_, _) => orbited = true,
              ),
            ),
          ),
        );

        final center = tester.getCenter(find.byType(AxonometricCanvas3D));
        final pointer = TestPointer(2, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.down(center, buttons: kSecondaryMouseButton),
        );
        await tester.sendEventToBinding(pointer.move(center + const Offset(40, 25)));
        await tester.sendEventToBinding(pointer.up());
        await tester.pump();

        expect(capturedPan, isNotNull);
        expect(capturedPan!.dx, closeTo(40, 1e-6));
        expect(capturedPan!.dy, closeTo(25, 1e-6));
        expect(orbited, isFalse);
      },
    );
  });
}
