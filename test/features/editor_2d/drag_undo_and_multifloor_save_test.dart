import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/editor_canvas_2d.dart';
import 'package:trazzik/features/floors/data/supabase_floor_repository.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/furniture_template.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_brief.dart';

class _FakeFloorRepository implements SupabaseFloorRepository {
  final List<Floor> savedFloors = [];
  final Set<String> removedFloorIds = {};

  @override
  Future<void> saveProjectFloors({
    required List<Floor> dirtyFloors,
    Set<String> deletedFloorIds = const {},
  }) async {
    removedFloorIds.addAll(deletedFloorIds);
    savedFloors.addAll(dirtyFloors);
  }

  @override
  Future<void> deleteFloors(Iterable<String> floorIds) async {
    removedFloorIds.addAll(floorIds);
  }

  @override
  Future<void> saveFloor(Floor floor) async {
    savedFloors.add(floor);
  }

  @override
  Future<Floor?> getFloorById(String id) async => null;

  @override
  Future<List<Floor>> getFloorsByBuildingId(String buildingId) async => const [];
}

void main() {
  late Lot testLot;
  late Floor floor1;
  late Floor floor2;

  setUp(() {
    testLot = Lot(
      id: '11111111-1111-4111-8111-111111111111',
      projectId: '22222222-2222-4222-8222-222222222222',
      boundary: Polygon2D.fromRect(0, 0, 12, 20),
    );

    floor1 = Floor(
      id: '33333333-3333-4333-8333-333333333333',
      buildingId: '44444444-4444-4444-8444-444444444444',
      floorNumber: 1,
      name: 'Planta Baja',
      boundary: Polygon2D.fromRect(0, 0, 10, 16),
      maxAllowedArea: 160,
      modules: [
        Module(
          id: '55555555-5555-4555-8555-555555555555',
          floorId: '33333333-3333-4333-8333-333333333333',
          name: 'Sala Principal',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(1.0, 1.0, 4.0, 3.0),
          status: ElementStatus.isNew,
        ),
      ],
    );

    floor2 = Floor(
      id: '66666666-6666-4666-8666-666666666666',
      buildingId: '44444444-4444-4444-8444-444444444444',
      floorNumber: 2,
      name: 'Planta Alta',
      levelMeters: 2.80,
      boundary: Polygon2D.fromRect(0, 0, 10, 16),
      maxAllowedArea: 160,
      modules: [
        Module(
          id: '77777777-7777-4777-8777-777777777777',
          floorId: '66666666-6666-4666-8666-666666666666',
          name: 'Dormitorio 1',
          moduleType: 'BEDROOM',
          geometry: Polygon2D.fromRect(1.0, 1.0, 3.5, 3.5),
          status: ElementStatus.isNew,
        ),
      ],
    );
  });

  group('Canvas Drag Transactions & Undo Integrity', () {
    test('setModulePosition short-circuits sub-grid jitter without polluting undoStack', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: testLot,
        floor: floor1,
        allFloors: [floor1, floor2],
      );

      final initialState = container.read(floorEditorProvider);
      final modId = floor1.modules.first.id;

      // Sub-grid jitter (< 2.5cm from 1.00m snaps back to 1.00m)
      notifier.setModulePosition(modId, 1.01, 0.99);
      notifier.setModulePosition(modId, 1.02, 1.01);

      final afterState = container.read(floorEditorProvider);
      expect(identical(initialState, afterState), isTrue);
      expect(afterState.undoStack, isEmpty);
      expect(afterState.hasUnsavedChanges, isFalse);
    });

    test('beginInteraction + multi-frame drag records a single Undo entry and syncs allFloors on undo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: testLot,
        floor: floor1,
        allFloors: [floor1, floor2],
      );

      final modId = floor1.modules.first.id;
      final sofaTpl = FurnitureTemplate.catalog.firstWhere((f) => f.type == 'SOFA');
      notifier.addFurnitureToModule(modId, sofaTpl);
      final undoAfterFurnish = container.read(floorEditorProvider).undoStack.length;
      expect(undoAfterFurnish, equals(1));

      // Simulate 20 drag frames moving 2.00m right and 1.50m down
      notifier.beginInteraction();
      for (int step = 1; step <= 20; step++) {
        notifier.setModulePosition(
          modId,
          1.0 + step * 0.10,
          1.0 + step * 0.075,
        );
      }
      notifier.endInteraction();

      final draggedState = container.read(floorEditorProvider);
      // Entire 20-frame drag coalesced into ONE undo step on top of addFurnitureToModule
      expect(draggedState.undoStack.length, equals(2));

      final movedRoom = draggedState.floor.modules.first;
      expect(movedRoom.geometry.boundingBox.minX, closeTo(3.0, 0.001));
      expect(movedRoom.geometry.boundingBox.minY, closeTo(2.5, 0.001));
      // Interior furniture moved together with the room (no SUBMODULE_OUTSIDE_MODULE error)
      expect(
        movedRoom.geometry.boundingBox.containsBoundingBox(
          movedRoom.subModules.first.geometry.boundingBox,
        ),
        isTrue,
      );
      expect(
        draggedState.issues.where((i) => i.code == 'SUBMODULE_OUTSIDE_MODULE'),
        isEmpty,
      );

      // Single Undo reverts the entire drag gesture AND keeps allFloors synchronized
      notifier.undo();
      final undoneState = container.read(floorEditorProvider);
      expect(undoneState.floor.modules.first.geometry.boundingBox.minX, closeTo(1.0, 0.001));
      expect(
        undoneState.allFloors.first.modules.first.geometry.boundingBox.minX,
        closeTo(1.0, 0.001),
      );
    });

    test('beginInteraction + endInteraction without grid movement leaves state clean', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(lot: testLot, floor: floor1, allFloors: [floor1]);

      notifier.beginInteraction();
      notifier.setModulePosition(floor1.modules.first.id, 1.01, 1.02);
      notifier.endInteraction();

      final state = container.read(floorEditorProvider);
      expect(state.undoStack, isEmpty);
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.dirtyFloorIds, isEmpty);
    });

    test('undoStack is bounded to maxUndoHistory and rotateFloor180 is atomic', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(lot: testLot, floor: floor1, allFloors: [floor1]);
      final modId = floor1.modules.first.id;

      notifier.rotateFloor180();
      expect(container.read(floorEditorProvider).undoStack.length, equals(1));

      for (int i = 1; i <= 65; i++) {
        notifier.setModulePosition(modId, 0.05 * (i % 40), 1.0);
      }

      expect(
        container.read(floorEditorProvider).undoStack.length,
        equals(FloorEditorNotifier.maxUndoHistory),
      );
    });

    testWidgets('EditorCanvas2D pan drag coalesces pointer frames into a single Undo entry', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(lot: testLot, floor: floor1, allFloors: [floor1]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
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

      final state0 = container.read(floorEditorProvider);
      // Room is at (1.0..5.0, 1.0..4.0) meters; convert center (3.0, 2.5) to canvas pixels
      final startPx = Offset(
        state0.panOffset.dx + 3.0 * state0.zoom,
        state0.panOffset.dy + 2.5 * state0.zoom,
      );

      final gesture = await tester.startGesture(startPx);
      for (int i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(10, 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();

      final afterDrag = container.read(floorEditorProvider);
      expect(afterDrag.undoStack.length, equals(1));
      expect(afterDrag.floor.modules.first.geometry.boundingBox.minX, greaterThan(2.0));
    });
  });

  group('Multi-Floor Dirty Tracking & Persistence', () {
    test('editing Floor 1 then switching to Floor 2 preserves dirtyFloorIds and per-floor Undo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: testLot,
        floor: floor1,
        allFloors: [floor1, floor2],
      );

      // Edit Floor 1
      notifier.setModulePosition(floor1.modules.first.id, 2.0, 2.0);
      expect(container.read(floorEditorProvider).hasUnsavedChanges, isTrue);
      expect(container.read(floorEditorProvider).dirtyFloorIds, contains(floor1.id));
      expect(container.read(floorEditorProvider).undoStack.length, equals(1));

      // Switch to Floor 2 -> unsaved status MUST remain true!
      notifier.switchFloor(floor2.id);
      final stateOnFloor2 = container.read(floorEditorProvider);
      expect(stateOnFloor2.floor.id, equals(floor2.id));
      expect(stateOnFloor2.hasUnsavedChanges, isTrue);
      expect(stateOnFloor2.dirtyFloorIds, contains(floor1.id));
      expect(stateOnFloor2.floorsToSave.map((f) => f.id), contains(floor1.id));
      expect(stateOnFloor2.undoStack, isEmpty);

      // Switch back to Floor 1 -> Floor 1's Undo history is preserved!
      notifier.switchFloor(floor1.id);
      expect(container.read(floorEditorProvider).undoStack.length, equals(1));
    });

    test('applyMultiStoryBrief generates valid UUID floor IDs and marks both floors dirty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(lot: testLot, floor: floor1, allFloors: [floor1]);

      const brief = MultiStoryBrief(
        garagePlacement: GaragePlacement.frontSetbackSemiCovered,
        garageCars: 1,
        groundFloorBedroom: GroundFloorBedroomOption.none,
        upperFloorBedrooms: 2,
        upperFloorLivingOrStudy: true,
      );

      notifier.applyMultiStoryBrief(brief);
      final state = container.read(floorEditorProvider);

      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(state.allFloors.length, equals(2));
      for (final f in state.allFloors) {
        expect(uuidRegex.hasMatch(f.id), isTrue);
      }
      expect(state.dirtyFloorIds.length, equals(2));
      expect(state.floorsToSave.length, equals(2));
    });

    testWidgets('EditorScreen Save persists all dirty floors and deletes removed variants', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = _FakeFloorRepository();
      final container = ProviderContainer(
        overrides: [
          floorRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: testLot,
        floor: floor1,
        allFloors: [floor1, floor2],
        project: Project(
          id: testLot.projectId,
          ownerId: '88888888-8888-4888-8888-888888888888',
          name: 'Casa Dos Plantas',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      // 1. Edit Floor 1
      notifier.setModulePosition(floor1.modules.first.id, 2.5, 2.0);
      // 2. Create and delete a temporary variant, then switch to Floor 2 and edit Floor 2 too
      notifier.createDesignVariant('Variante Temporal');
      final tempVariantId = container.read(floorEditorProvider).floor.id;
      notifier.deleteDesignVariant(tempVariantId);
      notifier.switchFloor(floor2.id);
      notifier.setModulePosition(floor2.modules.first.id, 3.0, 2.5);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Guardar Cambios *" while standing on Floor 2
      await tester.tap(find.text('Guardar Cambios *'));
      await tester.pumpAndSettle();

      // BOTH Floor 1 and Floor 2 must have been saved, AND tempVariantId deleted!
      final savedIds = fakeRepo.savedFloors.map((f) => f.id).toSet();
      expect(savedIds, containsAll([floor1.id, floor2.id]));
      expect(fakeRepo.removedFloorIds, contains(tempVariantId));
      expect(container.read(floorEditorProvider).hasUnsavedChanges, isFalse);
      expect(container.read(floorEditorProvider).dirtyFloorIds, isEmpty);
      expect(container.read(floorEditorProvider).deletedFloorIds, isEmpty);
    });
  });
}
