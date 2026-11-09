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
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/open_shared_link_dialog.dart';
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

    test('Building3DBuilder recorta puertas/ventanas a 1.20m en modo maqueta y no asigna moduleId interior a fachadas exteriores', () {
      final floorWithDoor = floor1.copyWith(
        modules: [
          ...floor1.modules,
          Module(
            id: 'door-1',
            floorId: 'f1',
            name: 'Puerta Principal',
            moduleType: 'DOOR',
            geometry: Polygon2D.fromRect(2.0, 0.92, 0.90, 0.16),
            status: ElementStatus.isNew,
          ),
        ],
      );

      final facesCutaway = Building3DBuilder.buildScene(
        floors: [floorWithDoor],
        lot: lot,
        wallHeight: 1.20,
      );

      final doorFaces = facesCutaway.where((f) => f.label == 'Puerta Principal').toList();
      expect(doorFaces, isNotEmpty);
      for (final df in doorFaces) {
        for (final v in df.vertices) {
          expect(v.z, lessThanOrEqualTo(1.201));
        }
      }

      // Exterior wall faces (facing outside room m1 at y < 1) must have null moduleId
      final wallSideFaces = facesCutaway.where((f) => f.isWallFace && f.vertices.any((v) => v.z > 0.5 && v.z <= 1.201)).toList();
      expect(wallSideFaces.any((f) => f.moduleId == 'm1'), isTrue);
      expect(wallSideFaces.any((f) => f.moduleId == null), isTrue);
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

    testWidgets('Botón Compartir en Viewer3dScreen abre ClientShareLinkDialog y activa Vista Cliente 60d', (tester) async {
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

      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Compartir Maqueta 3D con Cliente'), findsOneWidget);
      expect(find.textContaining('https://trazzik.app/?share='), findsOneWidget);
      expect(find.text('Probar Vista Cliente'), findsOneWidget);

      await tester.tap(find.text('Probar Vista Cliente'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('VISTA CLIENTE (60d) • Acabados interactivos'),
        findsOneWidget,
      );
    });

    test('SharedProjectOpener.extractToken extrae token desde URL completa o código directo', () {
      expect(
        SharedProjectOpener.extractToken('https://trazzik.app/?share=abc123456789'),
        equals('abc123456789'),
      );
      expect(
        SharedProjectOpener.extractToken('  tz_demo_token_998877  '),
        equals('tz_demo_token_998877'),
      );
    });

    test('Building3DBuilder genera normales exteriores hacia +Z en tapas de muros y ordena mobiliario sobre el piso', () {
      final floorWithBed = floor1.copyWith(
        modules: [
          floor1.modules.first.copyWith(
            subModules: [
              SubModule(
                id: 'bed-1',
                moduleId: 'm1',
                name: 'Cama Queen',
                type: 'BED',
                geometry: Polygon2D.fromRect(2.0, 1.2, 1.6, 2.0),
                status: ElementStatus.isNew,
              ),
            ],
          ),
        ],
      );

      final faces = Building3DBuilder.buildScene(
        floors: [floorWithBed],
        lot: lot,
        wallHeight: 2.60,
      );

      final wallTopCap = faces.firstWhere(
        (f) => f.isWallFace && f.vertices.every((v) => (v.z - 2.60).abs() < 1e-3),
      );
      expect(wallTopCap.normal.z, closeTo(1.0, 1e-4));

      final roomFloorFace = faces.firstWhere((f) => f.moduleId == 'm1' && !f.isWallFace);
      final bedFaces = faces.where(
        (f) => !f.isWallFace && f.layer == FaceLayer3D.structureAndFurniture,
      );
      expect(roomFloorFace.layer, equals(FaceLayer3D.floorFinish));
      expect(bedFaces, isNotEmpty);
      for (final bf in bedFaces) {
        expect(bf.layer.index, greaterThan(roomFloorFace.layer.index));
      }
    });

    test('Face3D.isAxisAlignedQuad distingue rectángulos ortogonales de trapecios rotados', () {
      final orthoFace = Face3D(
        vertices: const [
          Point3D(0, 0, 0),
          Point3D(4, 0, 0),
          Point3D(4, 3, 0),
          Point3D(0, 3, 0),
        ],
        baseColor: Colors.white,
      );
      final rotatedFace = Face3D(
        vertices: const [
          Point3D(0, 0, 0),
          Point3D(4, 0.8, 0),
          Point3D(3.2, 3.8, 0),
          Point3D(-0.8, 3.0, 0),
        ],
        baseColor: Colors.white,
      );

      expect(orthoFace.isAxisAlignedQuad, isTrue);
      expect(rotatedFace.isAxisAlignedQuad, isFalse);
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
