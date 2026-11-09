import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('Visor 3D y Maqueta Axonométrica', () {
    late Lot lot;
    late Floor floor1;
    late Floor floor2;
    late List<Floor> allFloors;

    setUp(() {
      lot = Lot(
        id: 'lot-1',
        projectId: 'p1',
        boundary: Polygon2D.fromRect(0, 0, 10, 20),
      );

      floor1 = Floor(
        id: 'f1',
        buildingId: 'b1',
        floorNumber: 1,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 0, 8, 12),
        maxAllowedArea: 150.0,
        levelMeters: 0.0,
        heightMeters: 2.80,
        modules: [
          Module(
            id: 'm1',
            floorId: 'f1',
            name: 'Sala de Estar',
            moduleType: 'LIVING_ROOM',
            geometry: Polygon2D.fromRect(1, 1, 4, 5),
            status: ElementStatus.isNew,
          ),
          Module(
            id: 'm2',
            floorId: 'f1',
            name: 'Escalera Principal',
            moduleType: 'STAIRS',
            geometry: Polygon2D.fromRect(5, 1, 2, 4),
            status: ElementStatus.isNew,
          ),
        ],
        walls: [
          Wall(
            id: 'w1',
            floorId: 'f1',
            startPoint: Point2D(1, 1),
            endPoint: Point2D(5, 1),
            thickness: 0.15,
            height: 2.80,
            status: ElementStatus.isNew,
          ),
        ],
      );

      floor2 = Floor(
        id: 'f2',
        buildingId: 'b1',
        floorNumber: 2,
        name: 'Planta Alta',
        boundary: Polygon2D.fromRect(0, 0, 8, 12),
        maxAllowedArea: 150.0,
        levelMeters: 2.80,
        heightMeters: 2.60,
        modules: [
          Module(
            id: 'm3',
            floorId: 'f2',
            name: 'Dormitorio 1',
            moduleType: 'BEDROOM',
            geometry: Polygon2D.fromRect(1, 1, 4, 4),
            status: ElementStatus.isNew,
          ),
        ],
      );

      allFloors = [floor1, floor2];
    });

    test('Building3DBuilder genera caras de losa, muros, recintos y escaleras', () {
      final faces = Building3DBuilder.buildScene(
        floors: allFloors,
        lot: lot,
        explodedFactor: 0.0,
      );

      expect(faces, isNotEmpty);
      // Debe haber caras de terreno, losas, recintos y escaleras rotuladas
      expect(faces.any((f) => f.label == 'Terreno'), isTrue);
      expect(faces.any((f) => f.label == 'Sala de Estar'), isTrue);
      expect(faces.any((f) => f.label == 'Escalera Principal'), isTrue);
      expect(faces.any((f) => f.label?.contains('Losa') ?? false), isTrue);
      // Debe haber muros automáticos generados para la Planta Alta (que no tenía muros explícitos)
      expect(faces.any((f) => f.label == 'Muro Exterior' || f.label == 'Tabique'), isTrue);
    });

    testWidgets('Viewer3dScreen se renderiza con slider de maqueta explotada y selector de pisos', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final project = Project(
        id: 'p1',
        name: 'Casa Moderna 2 Plantas',
        ownerId: 'owner-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            floorEditorProvider.overrideWith(
              () => _Test3DFloorEditorNotifier(lot, floor1, allFloors, project),
            ),
          ],
          child: const MaterialApp(
            home: Viewer3dScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar Título del visor
      expect(find.text('Maqueta Axonométrica 3D'), findsOneWidget);
      expect(find.textContaining('Casa Moderna 2 Plantas'), findsOneWidget);

      // Verificar Control Flotante de Despiece / Maqueta Explotada
      expect(find.text('Maqueta Explotada (Despiece)'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Verificar Controles Flotantes de Zoom (+ / - / Ajustar)
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen), findsOneWidget);

      // Botón de alternancia de altura de muros (Maqueta 1.20m / Muros 2.60m)
      expect(find.byIcon(Icons.view_compact_alt), findsOneWidget);
      await tester.tap(find.byIcon(Icons.view_compact_alt));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.apartment), findsOneWidget);

      // Mover el Slider de maqueta explotada
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pumpAndSettle();

      // Botón de restablecer cámara
      expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    });

    testWidgets('Viewer3dScreen se renderiza de forma compacta en viewport móvil sin desbordamientos', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final project = Project(
        id: 'p1',
        name: 'Casa Moderna 2 Plantas',
        ownerId: 'owner-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            floorEditorProvider.overrideWith(
              () => _Test3DFloorEditorNotifier(lot, floor1, allFloors, project),
            ),
          ],
          child: const MaterialApp(
            home: Viewer3dScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar Título compacto en móvil
      expect(find.text('Maqueta 3D'), findsOneWidget);

      // Verificar PopupMenuButton para presets de cámara en móvil
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

      // No debe haber excepciones de overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Configurador 3D cambia acabado de piso y muro en tiempo real y sincroniza con presupuesto', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final project = Project(
        id: 'p1',
        name: 'Casa Moderna 2 Plantas',
        ownerId: 'owner-1',
        createdAt: DateTime.now(),
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            floorEditorProvider.overrideWith(
              () => _Test3DFloorEditorNotifier(lot, floor1, allFloors, project),
            ),
          ],
          child: Builder(
            builder: (ctx) {
              container = ProviderScope.containerOf(ctx);
              return const MaterialApp(
                home: Viewer3dScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleccionar el recinto "Sala de Estar" desde el selector rápido 3D
      expect(find.text('Sala de Estar'), findsOneWidget);
      await tester.tap(find.text('Sala de Estar'));
      await tester.pumpAndSettle();

      // Debe abrirse el dock configurador mostrando el nombre y m² de la sala (4x5 = 20.0 m²)
      expect(find.textContaining('Sala de Estar (20.0 m²)'), findsOneWidget);

      // Cambiar piso a "Mármol Calacatta"
      expect(find.text('Mármol Calacatta'), findsOneWidget);
      await tester.tap(find.text('Mármol Calacatta'));
      await tester.pumpAndSettle();

      final updatedMod = container
          .read(floorEditorProvider)
          .floor
          .modules
          .firstWhere((m) => m.id == 'm1');
      expect(updatedMod.floorMaterialId, equals('floor_calacatta_marble'));
      expect(
        FinishMaterialCatalog.resolveFloorForModule(updatedMod).id,
        equals('floor_calacatta_marble'),
      );

      // Cambiar a pestaña "Muros" y elegir "Verde Salvia Botánico"
      await tester.tap(find.text('Muros'));
      await tester.pumpAndSettle();
      expect(find.text('Verde Salvia Botánico'), findsOneWidget);
      await tester.tap(find.text('Verde Salvia Botánico'));
      await tester.pumpAndSettle();

      final updatedModAfterWall = container
          .read(floorEditorProvider)
          .floor
          .modules
          .firstWhere((m) => m.id == 'm1');
      expect(updatedModAfterWall.wallFinishId, equals('wall_sage_green'));

      // Verificar que RenovationPlannerEngine refleje el acabado elegido en el presupuesto
      final plan = RenovationPlannerEngine.generatePlan(
        allRooms: container.read(floorEditorProvider).floor.modules,
        renovateFloors: true,
      );
      expect(
        plan.materials.any((m) => m.id == 'mat_custom_floor_floor_calacatta_marble'),
        isTrue,
      );
    });
  });
}

class _Test3DFloorEditorNotifier extends FloorEditorNotifier {
  final Lot _testLot;
  final Floor _testFloor;
  final List<Floor> _testAllFloors;
  final Project? _testProject;

  _Test3DFloorEditorNotifier(
    this._testLot,
    this._testFloor,
    this._testAllFloors,
    this._testProject,
  );

  @override
  FloorEditorState build() {
    return FloorEditorState(
      lot: _testLot,
      floor: _testFloor,
      allFloors: _testAllFloors,
      project: _testProject,
    );
  }
}
