import 'dart:convert';
import 'dart:typed_data';
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
import 'package:trazzik/features/projects/data/supabase_project_repository.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/domain/project_building.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/domain/gltf_exporter_service.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart';
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
      expect(
        find.textContaining('Proyecto local sin guardar en la nube'),
        findsOneWidget,
      );
      expect(find.textContaining('https://trazzik.app/?share=tz_'), findsNothing);
      expect(find.text('Probar Vista Cliente'), findsOneWidget);

      await tester.tap(find.text('Probar Vista Cliente'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('VISTA CLIENTE (60d) • Acabados interactivos'),
        findsOneWidget,
      );
    });

    testWidgets('Proyecto UUID muestra token cloud real y sesión cliente independiente oculta Render Studio', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cloudProject = Project(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Casa Cloud 60d',
        ownerId: 'owner-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            floorEditorProvider.overrideWith(
              () => _Test3DFloorEditorNotifier(lot, floor1, allFloors, cloudProject),
            ),
            projectRepositoryProvider.overrideWithValue(_FakeCloudShareRepo()),
          ],
          child: const MaterialApp(
            home: Viewer3dScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('https://trazzik.app/?share=realcloudtoken998877'),
        findsOneWidget,
      );
      expect(find.textContaining('vence el 14/05/2027'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            floorEditorProvider.overrideWith(
              () => _Test3DFloorEditorNotifier(lot, floor1, allFloors, cloudProject),
            ),
            projectRepositoryProvider.overrideWithValue(_FakeCloudShareRepo()),
          ],
          child: const MaterialApp(
            home: Viewer3dScreen(
              isStandaloneClientSession: true,
              initialShareToken: 'realcloudtoken998877',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_enhance_outlined), findsNothing);
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

    test('GltfExporterService exporta malla glTF 2.0 válida con buffer embebido y atributos PBR', () {
      final faces = Building3DBuilder.buildScene(
        floors: allFloors,
        lot: lot,
        wallHeight: 2.60,
      );
      final gltfString = GltfExporterService.exportToGltfJson(
        faces: faces,
        projectName: 'Casa Valentina 3D',
      );
      final decoded = jsonDecode(gltfString) as Map<String, dynamic>;
      expect((decoded['asset'] as Map<String, dynamic>)['version'], equals('2.0'));
      final buffers = decoded['buffers'] as List<dynamic>;
      expect(buffers, hasLength(1));
      final uri = (buffers.first as Map<String, dynamic>)['uri'] as String;
      expect(uri, startsWith('data:application/octet-stream;base64,'));
      final accessors = decoded['accessors'] as List<dynamic>;
      expect(accessors, hasLength(4)); // POSITION, NORMAL, COLOR_0, INDICES
      expect((accessors[0] as Map<String, dynamic>)['count'], greaterThan(20));

      // Verify right-handed (x, z, +y) orientation, exact Float32 bounds, and CCW outward winding
      final b64 = uri.split(',').last;
      final bytes = base64Decode(b64);
      final bufferViews = decoded['bufferViews'] as List<dynamic>;
      final posView = bufferViews[0] as Map<String, dynamic>;
      final normView = bufferViews[1] as Map<String, dynamic>;
      final idxView = bufferViews[3] as Map<String, dynamic>;

      final bd = ByteData.sublistView(bytes);
      final posOff = posView['byteOffset'] as int;
      final normOff = normView['byteOffset'] as int;
      final idxOff = idxView['byteOffset'] as int;
      final idxCount = (accessors[3] as Map<String, dynamic>)['count'] as int;
      final vertCount = (accessors[0] as Map<String, dynamic>)['count'] as int;

      Point3D readVec3(int baseOff, int idx) {
        final o = baseOff + idx * 12;
        return Point3D(
          bd.getFloat32(o, Endian.little),
          bd.getFloat32(o + 4, Endian.little),
          bd.getFloat32(o + 8, Endian.little),
        );
      }

      double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity, maxZ = double.negativeInfinity;
      for (int i = 0; i < vertCount; i++) {
        final p = readVec3(posOff, i);
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.z < minZ) minZ = p.z;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
        if (p.z > maxZ) maxZ = p.z;
      }
      final accMin = ((accessors[0] as Map<String, dynamic>)['min'] as List<dynamic>)
          .cast<num>()
          .map((n) => n.toDouble())
          .toList();
      final accMax = ((accessors[0] as Map<String, dynamic>)['max'] as List<dynamic>)
          .cast<num>()
          .map((n) => n.toDouble())
          .toList();
      expect(accMin[0], closeTo(minX, 1e-6));
      expect(accMin[1], closeTo(minY, 1e-6));
      expect(accMin[2], closeTo(minZ, 1e-6));
      expect(accMax[0], closeTo(maxX, 1e-6));
      expect(accMax[1], closeTo(maxY, 1e-6));
      expect(accMax[2], closeTo(maxZ, 1e-6));
      // South (+Y in 2D = 20m lot) stays +Z in glTF (no chiral mirror flip)
      expect(accMax[2], closeTo(20.0, 1e-4));

      for (int t = 0; t + 2 < idxCount; t += 3) {
        final i0 = bd.getUint32(idxOff + t * 4, Endian.little);
        final i1 = bd.getUint32(idxOff + (t + 1) * 4, Endian.little);
        final i2 = bd.getUint32(idxOff + (t + 2) * 4, Endian.little);
        final p0 = readVec3(posOff, i0);
        final p1 = readVec3(posOff, i1);
        final p2 = readVec3(posOff, i2);
        final n0 = readVec3(normOff, i0);
        final e1 = p1 - p0;
        final e2 = p2 - p0;
        final cx = e1.y * e2.z - e1.z * e2.y;
        final cy = e1.z * e2.x - e1.x * e2.z;
        final cz = e1.x * e2.y - e1.y * e2.x;
        final dot = cx * n0.x + cy * n0.y + cz * n0.z;
        expect(dot, greaterThan(0.0));
      }
    });

    test('GltfExporterService triangula polígonos cóncavos en L, separa BLEND para vidrio y maneja escena vacía', () {
      // Concave L-shape polygon on top plane z=0 (notch in top-right [3..6] x [3..6])
      final lFace = Face3D(
        vertices: const [
          Point3D(0, 0, 0),
          Point3D(6, 0, 0),
          Point3D(6, 3, 0),
          Point3D(3, 3, 0),
          Point3D(3, 6, 0),
          Point3D(0, 6, 0),
        ],
        baseColor: Colors.white,
        layer: FaceLayer3D.floorFinish,
      );
      final glassFace = Face3D(
        vertices: const [
          Point3D(1, 1, 0),
          Point3D(2, 1, 0),
          Point3D(2, 1, 2),
          Point3D(1, 1, 2),
        ],
        baseColor: const Color(0x8899DDFF),
        layer: FaceLayer3D.openingPanel,
      );

      final gltf = jsonDecode(
        GltfExporterService.exportToGltfJson(
          faces: [lFace, glassFace],
          projectName: 'Concave & Glass',
        ),
      ) as Map<String, dynamic>;

      final materials = gltf['materials'] as List<dynamic>;
      expect(materials, hasLength(2));
      expect((materials[1] as Map<String, dynamic>)['alphaMode'], equals('BLEND'));

      // Check L-shape triangles never bridge inside the concave notch (gx>3.1 && gz>3.1)
      final uri = ((gltf['buffers'] as List<dynamic>).first as Map<String, dynamic>)['uri'] as String;
      final bytes = base64Decode(uri.split(',').last);
      final bd = ByteData.sublistView(bytes);
      final bvs = gltf['bufferViews'] as List<dynamic>;
      final posOff = (bvs[0] as Map<String, dynamic>)['byteOffset'] as int;
      final opaqueIdxOff = (bvs[3] as Map<String, dynamic>)['byteOffset'] as int;
      final opaqueIdxCount = ((gltf['accessors'] as List<dynamic>)[3] as Map<String, dynamic>)['count'] as int;
      expect(opaqueIdxCount, equals(12)); // 4 triangles for 6-vertex L polygon
      for (int t = 0; t < opaqueIdxCount; t += 3) {
        final i0 = bd.getUint32(opaqueIdxOff + t * 4, Endian.little);
        final i1 = bd.getUint32(opaqueIdxOff + (t + 1) * 4, Endian.little);
        final i2 = bd.getUint32(opaqueIdxOff + (t + 2) * 4, Endian.little);
        final cx = (bd.getFloat32(posOff + i0 * 12, Endian.little) +
                bd.getFloat32(posOff + i1 * 12, Endian.little) +
                bd.getFloat32(posOff + i2 * 12, Endian.little)) /
            3.0;
        final cz = (bd.getFloat32(posOff + i0 * 12 + 8, Endian.little) +
                bd.getFloat32(posOff + i1 * 12 + 8, Endian.little) +
                bd.getFloat32(posOff + i2 * 12 + 8, Endian.little)) /
            3.0;
        expect(cx > 3.05 && cz > 3.05, isFalse);
      }

      // Empty scene still produces valid glTF 2.0 root without empty accessors
      final emptyGltf = jsonDecode(
        GltfExporterService.exportToGltfJson(faces: const []),
      ) as Map<String, dynamic>;
      expect((emptyGltf['asset'] as Map<String, dynamic>)['version'], equals('2.0'));
      expect(emptyGltf.containsKey('accessors'), isFalse);
    });

    test('Building3DBuilder genera mobiliario multi-pieza (patas de mesa, mampara de ducha, respaldo de cama), cotas 3D y modo nocturno 2700K', () {
      final floorWithMultiFurniture = floor1.copyWith(
        modules: [
          floor1.modules.first.copyWith(
            subModules: [
              SubModule(
                id: 'table-1',
                moduleId: 'm1',
                name: 'Comedor 6p',
                type: 'DINING_TABLE',
                geometry: Polygon2D.fromRect(1.2, 1.2, 1.6, 0.9),
                status: ElementStatus.isNew,
              ),
              SubModule(
                id: 'shower-1',
                moduleId: 'm1',
                name: 'Ducha',
                type: 'SHOWER',
                geometry: Polygon2D.fromRect(3.2, 1.2, 0.9, 0.9),
                status: ElementStatus.isNew,
              ),
              SubModule(
                id: 'toilet-1',
                moduleId: 'm1',
                name: 'Inodoro',
                type: 'TOILET',
                geometry: Polygon2D.fromRect(3.2, 2.4, 0.45, 0.70),
                status: ElementStatus.isNew,
              ),
            ],
          ),
        ],
      );

      final faces = Building3DBuilder.buildScene(
        floors: [floorWithMultiFurniture],
        lot: lot,
        wallHeight: 2.60,
      );

      // 1. Verificar sub-etiqueta de dimensiones y área en piso 3D (4.0x5.0m • 20.0m²)
      final roomFloorFace = faces.firstWhere(
        (f) => f.moduleId == 'm1' && f.layer == FaceLayer3D.floorFinish,
      );
      expect(roomFloorFace.roomDimensionsLabel, equals('4.0×5.0m • 20.0m²'));

      // 2. Verificar que la ducha incluye mampara de vidrio translúcido en FaceLayer3D.openingPanel
      final glassScreens = faces.where(
        (f) => f.layer == FaceLayer3D.openingPanel && f.baseColor.a < 0.6,
      );
      expect(glassScreens.length, greaterThanOrEqualTo(2));

      // 3. Verificar modo nocturno 2700K (SunPreset3D.nightInterior) ilumina el piso interior más cálido que la losa exterior
      final slabFace = faces.firstWhere((f) => f.layer == FaceLayer3D.slab);
      final nightFloorColor = roomFloorFace.computeNightShadedColor(
        SunPreset3D.nightInterior.lightDirection,
      );
      final nightSlabColor = slabFace.computeNightShadedColor(
        SunPreset3D.nightInterior.lightDirection,
      );
      expect(nightFloorColor.r, greaterThan(nightSlabColor.r));
      expect(SunPreset3D.nightInterior.label('es'), contains('2700K'));
    });

    test('Corte Seccional 3D (SectionCutAxis3D) y Roomstyles 1-Clic aplican acabados coordinados por tipología', () {
      final faces = Building3DBuilder.buildScene(
        floors: [floor1],
        lot: lot,
        wallHeight: 2.60,
      );

      final cutX = AxonometricSceneRenderer.resolveSectionCutLimit(
        faces,
        SectionCutAxis3D.axisX,
        0.50,
      );
      expect(cutX, isNotNull);
      final culledCountX = faces
          .where(
            (f) => AxonometricSceneRenderer.isFaceCulledBySection(
              f,
              SectionCutAxis3D.axisX,
              cutX!,
            ),
          )
          .length;
      expect(culledCountX, greaterThan(0));
      expect(culledCountX, lessThan(faces.length));

      // Verificar resolución de ArchitecturalStylePack (Japandi vs Loft Industrial)
      final japandi = FinishMaterialCatalog.stylePacks.firstWhere(
        (p) => p.id == 'style_japandi',
      );
      final bathModule = Module(
        id: 'bath-1',
        floorId: 'f1',
        name: 'Baño Principal',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(0, 0, 2, 2),
        status: ElementStatus.preserved,
      );
      final livingModule = floor1.modules.first;

      final (livingFloor, livingWall) = japandi.resolveForModule(livingModule);
      final (bathFloor, bathWall) = japandi.resolveForModule(bathModule);
      expect(livingFloor, equals('floor_oak_wood'));
      expect(livingWall, equals('wall_japandi_sand'));
      expect(bathFloor, equals('floor_grey_porcelain'));
      expect(bathWall, equals('wall_travertine'));

      // Sutherland-Hodgman clip en plano de sección corta polígonos largos justo en el límite
      final wallSpanFace = Face3D(
        vertices: const [
          Point3D(0.0, 0.0, 0.0),
          Point3D(6.0, 0.0, 0.0),
          Point3D(6.0, 0.0, 2.6),
          Point3D(0.0, 0.0, 2.6),
        ],
        baseColor: Color(0xFFFFFFFF),
        isWallFace: true,
      );
      final clipped = AxonometricSceneRenderer.clipFaceVerticesToSectionPlane(
        wallSpanFace,
        SectionCutAxis3D.axisX,
        3.5,
      );
      expect(clipped.length, equals(4));
      for (final v in clipped) {
        expect(v.x, lessThanOrEqualTo(3.5 + 1e-6));
      }
      expect(clipped.any((v) => (v.x - 3.5).abs() < 1e-6), isTrue);
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

class _FakeCloudShareRepo extends Fake implements SupabaseProjectRepository {
  @override
  Future<({String token, DateTime expiresAt, bool allowFinishSelection})>
      createOrGetProjectShareLinkDetails({
    required String projectId,
    bool allowFinishSelection = true,
  }) async {
    return (
      token: 'realcloudtoken998877',
      expiresAt: DateTime(2027, 5, 14),
      allowFinishSelection: true,
    );
  }

  @override
  Future<ProjectBuilding?> getPrimaryBuildingByLotId(String lotId) async => null;
}
