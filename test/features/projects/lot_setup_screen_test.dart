import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/floors/data/supabase_floor_repository.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/domain/project_building.dart';
import 'package:trazzik/features/projects/presentation/screens/lot_setup_screen.dart';

class _InMemoryProjectRepo implements SupabaseProjectRepository {
  Lot? savedLot;
  ProjectBuilding? savedBuilding;

  @override
  Future<Lot?> getLotByProjectId(String projectId) async => savedLot;

  @override
  Future<ProjectBuilding?> getPrimaryBuildingByLotId(String lotId) async =>
      savedBuilding;

  @override
  Future<Lot> saveLot(Lot lot) async {
    savedLot = lot;
    return lot;
  }

  @override
  Future<ProjectBuilding> savePrimaryBuilding({
    required String lotId,
    String? preferredBuildingId,
    required String name,
    required int floorsCount,
  }) async {
    final building = ProjectBuilding(
      id: preferredBuildingId ?? '44444444-4444-4444-8444-444444444444',
      lotId: lotId,
      name: name,
      floorsCount: floorsCount,
    );
    savedBuilding = building;
    return building;
  }

  @override
  Future<void> saveProject(Project project) async {}

  @override
  Future<Project?> getProjectById(String id) async => null;

  @override
  Future<List<Project>> listUserProjects() async => const [];

  @override
  Future<void> deleteProject(String projectId) async {}

  @override
  Future<void> saveFeeProposalConfig({
    required String projectId,
    required Map<String, dynamic> config,
  }) async {}

  @override
  Future<Map<String, dynamic>?> getFeeProposalConfig(String projectId) async =>
      null;

  @override
  Future<String> createOrGetProjectShareLink({
    required String projectId,
    bool allowFinishSelection = true,
  }) async =>
      'test-share-token';

  @override
  Future<bool?> getProjectShareLinkAllowFinishes(String projectId) async =>
      true;

  @override
  Future<void> updateProjectShareLinkPermission({
    required String projectId,
    required String token,
    required bool allowFinishSelection,
  }) async {}

  @override
  Future<Map<String, dynamic>?> getSharedProjectByToken(String token) async =>
      null;

  @override
  Future<bool> updateSharedModuleFinishes({
    required String token,
    required String moduleId,
    String? floorMaterialId,
    String? wallFinishId,
    bool clearFinishes = false,
  }) async =>
      true;
}

class _InMemoryFloorRepo implements SupabaseFloorRepository {
  final List<Floor> savedFloors = [];

  @override
  Future<List<Floor>> getFloorsByBuildingId(String buildingId) async {
    return savedFloors.where((f) => f.buildingId == buildingId).toList();
  }

  @override
  Future<Floor?> getFloorById(String floorId) async {
    for (final f in savedFloors) {
      if (f.id == floorId) return f;
    }
    return null;
  }

  @override
  Future<void> saveFloor(Floor floor) async {
    savedFloors.removeWhere((f) => f.id == floor.id);
    savedFloors.add(floor);
  }

  @override
  Future<void> saveProjectFloors({
    required Iterable<Floor> dirtyFloors,
    Iterable<String> deletedFloorIds = const [],
  }) async {
    savedFloors.removeWhere((f) => deletedFloorIds.contains(f.id));
    for (final floor in dirtyFloors) {
      await saveFloor(floor);
    }
  }

  @override
  Future<void> deleteFloors(Iterable<String> floorIds) async {
    savedFloors.removeWhere((f) => floorIds.contains(f.id));
  }
}

void main() {
  final sampleProject = Project(
    id: '99999999-9999-4999-8999-999999999999',
    name: 'Vivienda El Retiro',
    ownerId: 'user-architect-1',
    city: 'Medellín',
    country: 'Colombia',
  );

  group('LotSetupScreen normative geometry & multi-floor initialization', () {
    testWidgets(
      'Blocks invalid 0x0 lot dimensions with validation error without saving',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final projectRepo = _InMemoryProjectRepo();
        final floorRepo = _InMemoryFloorRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              projectRepositoryProvider.overrideWithValue(projectRepo),
              floorRepositoryProvider.overrideWithValue(floorRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: LotSetupScreen(project: sampleProject),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final saveLabel = AppStrings.tr('save_and_open_editor', 'es');
        await tester.ensureVisible(find.text(saveLabel));
        await tester.tap(find.text(saveLabel));
        await tester.pumpAndSettle();

        expect(projectRepo.savedLot, isNull);
        expect(floorRepo.savedFloors, isEmpty);
        expect(find.byType(EditorScreen), findsNothing);
        expect(find.textContaining('mayores a 0 metros'), findsOneWidget);
      },
    );

    testWidgets(
      'Computes buildable area, creates normative setback zones & multi-story floors, and opens EditorScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final projectRepo = _InMemoryProjectRepo();
        final floorRepo = _InMemoryFloorRepo();
        final container = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(projectRepo),
            floorRepositoryProvider.overrideWithValue(floorRepo),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: LotSetupScreen(project: sampleProject),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fields order:
        // 0: width, 1: depth, 2: orientation,
        // 3: frontSetback, 4: rearSetback, 5: leftSetback, 6: rightSetback,
        // 7: buildingName, 8: floorsCount, 9: height, 10: clearHeight, 11: maxArea
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), '10');
        await tester.enterText(fields.at(1), '20');
        await tester.enterText(fields.at(2), '90');
        await tester.enterText(fields.at(3), '3.0');
        await tester.enterText(fields.at(4), '2.5');
        await tester.enterText(fields.at(5), '1.0');
        await tester.enterText(fields.at(7), 'Casa Principal');
        await tester.enterText(fields.at(8), '2');
        await tester.pump();

        // Total lot: 10 * 20 = 200.0 m²
        // Buildable: (10 - 1.0) * (20 - 3.0 - 2.5) = 9.0 * 14.5 = 130.5 m²
        // Setbacks: 200.0 - 130.5 = 69.5 m²
        expect(find.text('200.0 m²'), findsOneWidget);
        expect(find.text('130.5 m²'), findsOneWidget);
        expect(find.text('69.5 m²'), findsOneWidget);

        final saveLabel = AppStrings.tr('save_and_open_editor', 'es');
        await tester.ensureVisible(find.text(saveLabel));
        await tester.tap(find.text(saveLabel));
        await tester.pumpAndSettle();

        // Verify persisted Lot & ZoningZones
        final savedLot = projectRepo.savedLot!;
        expect(savedLot.orientationDegrees, equals(90.0));
        expect(savedLot.boundary.boundingBox.width, closeTo(10.0, 1e-6));
        expect(savedLot.boundary.boundingBox.height, closeTo(20.0, 1e-6));
        expect(savedLot.zones.length, equals(4));
        expect(
          savedLot.zones
              .where((z) => z.type == ZoningType.buildableUnoccupied)
              .single
              .area,
          closeTo(130.5, 1e-6),
        );
        expect(
          savedLot.zones.where((z) => z.type == ZoningType.nonBuildable).length,
          equals(3),
        );

        // Verify Building & 2 initialized Floors
        expect(projectRepo.savedBuilding?.name, equals('Casa Principal'));
        expect(projectRepo.savedBuilding?.floorsCount, equals(2));
        expect(floorRepo.savedFloors.length, equals(2));
        expect(floorRepo.savedFloors[0].levelMeters, closeTo(0.0, 1e-6));
        expect(floorRepo.savedFloors[1].levelMeters, closeTo(2.60, 1e-6));

        // Verify transition into EditorScreen with loaded multi-floor state
        expect(find.byType(EditorScreen), findsOneWidget);
        final editorState = container.read(floorEditorProvider);
        expect(editorState.allFloors.length, equals(2));
        expect(editorState.lot.id, equals(savedLot.id));
      },
    );

    testWidgets(
      'Hydrates existing Lot, setbacks, and Building fields when reopening LotSetupScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final projectRepo = _InMemoryProjectRepo();
        final floorRepo = _InMemoryFloorRepo();

        // First configure via screen
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              projectRepositoryProvider.overrideWithValue(projectRepo),
              floorRepositoryProvider.overrideWithValue(floorRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: LotSetupScreen(project: sampleProject),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), '12');
        await tester.enterText(fields.at(1), '18');
        await tester.enterText(fields.at(3), '2.5');
        await tester.enterText(fields.at(8), '2');
        final saveLabel = AppStrings.tr('save_and_open_editor', 'es');
        await tester.ensureVisible(find.text(saveLabel));
        await tester.tap(find.text(saveLabel));
        await tester.pumpAndSettle();

        // Re-mount LotSetupScreen against the same repositories
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              projectRepositoryProvider.overrideWithValue(projectRepo),
              floorRepositoryProvider.overrideWithValue(floorRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: LotSetupScreen(project: sampleProject),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Hydrated summary: 12 * 18 = 216.0 m², buildable: 12 * 15.5 = 186.0 m²
        expect(find.text('216.0 m²'), findsOneWidget);
        expect(find.text('186.0 m²'), findsOneWidget);
      },
    );
  });
}
