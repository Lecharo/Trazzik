import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/authentication/data/supabase_auth_repository.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/screens/editor_screen.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/floor_overview_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/module_inspector_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/validation_issues_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/wall_inspector_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties_panel.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_app_bar.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_bottom_bar.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_zoom_controls.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/domain/project_building.dart';
import 'package:trazzik/features/projects/presentation/notifiers/projects_list_notifier.dart';
import 'package:trazzik/features/projects/presentation/screens/projects_list_screen.dart';

class _FakeProjectRepository implements SupabaseProjectRepository {
  final List<Project> _store = [];

  _FakeProjectRepository([List<Project>? initial]) {
    if (initial != null) {
      _store.addAll(initial);
    }
  }

  @override
  Future<List<Project>> listUserProjects() async {
    return List<Project>.unmodifiable(_store);
  }

  @override
  Future<void> saveProject(Project project) async {
    final index = _store.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      _store[index] = project;
    } else {
      _store.insert(0, project);
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    _store.removeWhere((p) => p.id == projectId);
  }

  @override
  Future<Project?> getProjectById(String id) async {
    for (final p in _store) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Lot?> getLotByProjectId(String projectId) async => null;

  @override
  Future<ProjectBuilding?> getPrimaryBuildingByLotId(String lotId) async =>
      null;

  @override
  Future<Lot> saveLot(Lot lot) async => lot;

  @override
  Future<ProjectBuilding> savePrimaryBuilding({
    required String lotId,
    String? preferredBuildingId,
    required String name,
    required int floorsCount,
  }) async {
    return ProjectBuilding(
      id: preferredBuildingId ?? '00000000-0000-4000-8000-000000000001',
      lotId: lotId,
      name: name,
      floorsCount: floorsCount,
    );
  }

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

class _FakeAuthRepository implements SupabaseAuthRepository {
  final User? _user;

  _FakeAuthRepository(this._user);

  @override
  User? get currentUser => _user;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? userType,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('Riverpod .select(...) rebuild granularity in EditorScreen', () {
    testWidgets(
      'Panning canvas causes zero rebuilds in EditorScreen, EditorAppBar, PropertiesPanel, and EditorBottomBar',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          debugOnRebuildDirtyWidget = null;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

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

        final rebuiltTypes = <Type, int>{};
        debugOnRebuildDirtyWidget = (element, _) {
          final type = element.widget.runtimeType;
          rebuiltTypes[type] = (rebuiltTypes[type] ?? 0) + 1;
        };

        final notifier = container.read(floorEditorProvider.notifier);
        // Simulate multiple 60fps pan frames
        notifier.updatePan(const Offset(24, -12));
        await tester.pump();
        notifier.updatePan(const Offset(18, 9));
        await tester.pump();
        notifier.updatePan(const Offset(-10, 15));
        await tester.pump();

        expect(rebuiltTypes[EditorScreen] ?? 0, equals(0));
        expect(rebuiltTypes[EditorAppBar] ?? 0, equals(0));
        expect(rebuiltTypes[PropertiesPanel] ?? 0, equals(0));
        expect(rebuiltTypes[FloorOverviewSection] ?? 0, equals(0));
        expect(rebuiltTypes[ValidationIssuesSection] ?? 0, equals(0));
        expect(rebuiltTypes[EditorBottomBar] ?? 0, equals(0));
        expect(rebuiltTypes[EditorZoomControls] ?? 0, equals(0));

        debugOnRebuildDirtyWidget = null;
      },
    );

    testWidgets(
      'Zooming canvas rebuilds EditorZoomControls without rebuilding PropertiesPanel or EditorBottomBar',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          debugOnRebuildDirtyWidget = null;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

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

        final rebuiltTypes = <Type, int>{};
        debugOnRebuildDirtyWidget = (element, _) {
          final type = element.widget.runtimeType;
          rebuiltTypes[type] = (rebuiltTypes[type] ?? 0) + 1;
        };

        final notifier = container.read(floorEditorProvider.notifier);
        // 70.0 px/m = 200% relative to 35.0 px/m baseline
        notifier.updateZoom(70.0);
        await tester.pump();

        expect(rebuiltTypes[EditorZoomControls] ?? 0, greaterThanOrEqualTo(1));
        expect(find.text('200%'), findsOneWidget);
        expect(rebuiltTypes[EditorScreen] ?? 0, equals(0));
        expect(rebuiltTypes[EditorAppBar] ?? 0, equals(0));
        expect(rebuiltTypes[PropertiesPanel] ?? 0, equals(0));
        expect(rebuiltTypes[EditorBottomBar] ?? 0, equals(0));

        debugOnRebuildDirtyWidget = null;
      },
    );

    testWidgets(
      'PropertiesPanel switches cleanly between FloorOverviewSection, ModuleInspectorSection, and WallInspectorSection',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

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

        final notifier = container.read(floorEditorProvider.notifier);

        // Clear initial default selection -> ModuleInspectorSection disappears
        notifier.selectModule(null);
        await tester.pumpAndSettle();
        expect(container.read(floorEditorProvider).selectedModule, isNull);
        expect(find.byType(FloorOverviewSection), findsOneWidget);
        expect(find.byType(ModuleInspectorSection), findsNothing);
        expect(find.byType(WallInspectorSection), findsNothing);

        final firstModuleId =
            container.read(floorEditorProvider).floor.modules.first.id;
        notifier.selectModule(firstModuleId);
        await tester.pumpAndSettle();

        expect(find.byType(FloorOverviewSection), findsOneWidget);
        expect(find.byType(ModuleInspectorSection), findsOneWidget);
        expect(find.byType(WallInspectorSection), findsNothing);

        notifier.generateWallsFromModules();
        final firstWallId =
            container.read(floorEditorProvider).floor.walls.first.id;
        notifier.selectWall(firstWallId);
        await tester.pumpAndSettle();

        expect(find.byType(FloorOverviewSection), findsOneWidget);
        expect(find.byType(WallInspectorSection), findsOneWidget);
        expect(find.byType(ModuleInspectorSection), findsNothing);
      },
    );
  });

  group('ProjectsListNotifier & ProjectsListScreen', () {
    test('ProjectsListNotifier loads, saves, updates, and deletes projects',
        () async {
      final initialProject = Project(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Casa Los Pinos',
        ownerId: 'user-1',
        city: 'Bogotá',
      );
      final fakeRepo = _FakeProjectRepository([initialProject]);

      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(projectsListProvider.future);
      expect(loaded.length, equals(1));
      expect(loaded.first.name, equals('Casa Los Pinos'));

      final notifier = container.read(projectsListProvider.notifier);
      final secondProject = Project(
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Torre Mirador',
        ownerId: 'user-1',
        city: 'Medellín',
      );
      await notifier.saveProject(secondProject);
      expect(
        container.read(projectsListProvider).value?.length,
        equals(2),
      );

      await notifier.saveProject(
        secondProject.copyWith(name: 'Torre Mirador Fase 2'),
      );
      expect(
        container.read(projectsListProvider).value?.first.name,
        equals('Torre Mirador Fase 2'),
      );

      await notifier.deleteProject(initialProject.id);
      final remaining = container.read(projectsListProvider).value!;
      expect(remaining.length, equals(1));
      expect(remaining.single.id, equals(secondProject.id));
    });

    testWidgets(
      'ProjectsListScreen renders projects from projectsListProvider and creates a project via ProjectFormDialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeUser = User(
          id: 'user-architect-01',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00.000Z',
          email: 'arquitecto@trazzik.app',
        );
        final fakeRepo = _FakeProjectRepository();
        final fakeAuth = _FakeAuthRepository(fakeUser);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              projectRepositoryProvider.overrideWithValue(fakeRepo),
              authRepositoryProvider.overrideWithValue(fakeAuth),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ProjectsListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Empty state shown initially
        expect(find.byIcon(Icons.folder_open), findsOneWidget);

        // Open ProjectFormDialog via FAB
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          'Remodelación Loft Chapinero',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(ElevatedButton),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Remodelación Loft Chapinero'), findsOneWidget);
      },
    );
  });
}
