import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/domain/gltf_exporter_service.dart';
import 'package:trazzik/features/viewer_3d/domain/webgl_scene_payload.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/webgl_canvas_3d.dart';

void main() {
  group('WebGlScenePayloadBuilder — PBR Materials, Coordinate Winding & Scene Data', () {
    test('resolveMaterialSpec maps finishes to physically distinct PBR roughness/transmission', () {
      final marble = WebGlScenePayloadBuilder.resolveMaterialSpec(
        Face3D(
          vertices: const [Point3D(0, 0, 0), Point3D(1, 0, 0), Point3D(1, 1, 0)],
          baseColor: const Color(0xFFF5F5F4),
          pattern: FinishPatternType.marbleVeins,
        ),
      );
      final wood = WebGlScenePayloadBuilder.resolveMaterialSpec(
        Face3D(
          vertices: const [Point3D(0, 0, 0), Point3D(1, 0, 0), Point3D(1, 1, 0)],
          baseColor: const Color(0xFFC8A075),
          pattern: FinishPatternType.woodPlanks,
        ),
      );
      final brick = WebGlScenePayloadBuilder.resolveMaterialSpec(
        Face3D(
          vertices: const [Point3D(0, 0, 0), Point3D(1, 0, 0), Point3D(1, 0, 2)],
          baseColor: const Color(0xFFA04B36),
          pattern: FinishPatternType.exposedBrick,
          isWallFace: true,
        ),
      );
      final glass = WebGlScenePayloadBuilder.resolveMaterialSpec(
        Face3D(
          vertices: const [Point3D(0, 0, 0), Point3D(1, 0, 0), Point3D(1, 0, 2)],
          baseColor: const Color(0x6680D8FF),
          layer: FaceLayer3D.openingPanel,
        ),
      );

      expect(marble.roughness, lessThan(wood.roughness));
      expect(wood.roughness, lessThan(brick.roughness));
      expect(brick.bumpScale, greaterThan(0.03));
      expect(glass.pattern, 'glass');
      expect(glass.transmission, greaterThan(0.5));
      expect(glass.roughness, lessThan(0.15));
    });

    test('buildPayload preserves outward +Y_gl winding, skips fake shadows, and emits room lights', () {
      final topCap = Face3D(
        vertices: const [
          Point3D(0, 0, 2.6),
          Point3D(2, 0, 2.6),
          Point3D(2, 3, 2.6),
          Point3D(0, 3, 2.6),
        ],
        baseColor: const Color(0xFFC8A075),
        pattern: FinishPatternType.woodPlanks,
        layer: FaceLayer3D.floorFinish,
        floorIndex: 0,
        moduleId: 'room-1',
        floorId: 'f-1',
        label: 'Sala',
        roomDimensionsLabel: '2.0×3.0m · 6.0m²',
        isRoomLabel: true,
      );
      final fakeShadow = Face3D(
        vertices: const [
          Point3D(0, 0, 0),
          Point3D(2, 0, 0),
          Point3D(2, 2, 0),
        ],
        baseColor: const Color(0x55000000),
        layer: FaceLayer3D.shadow,
        floorIndex: -1,
      );
      final lShapedRoom = Face3D(
        vertices: const [
          Point3D(3, 0, 0),
          Point3D(6, 0, 0),
          Point3D(6, 1, 0),
          Point3D(4.5, 1, 0),
          Point3D(4.5, 3, 0),
          Point3D(3, 3, 0),
        ],
        baseColor: const Color(0xFFE2E8F0),
        pattern: FinishPatternType.porcelainGrid,
        layer: FaceLayer3D.floorFinish,
        floorIndex: 0,
        moduleId: 'room-l',
        floorId: 'f-1',
      );

      final payload = WebGlScenePayloadBuilder.buildPayload(
        faces: [topCap, fakeShadow, lShapedRoom],
        sunPreset: SunPreset3D.nightInterior,
        explodedFactor: 0.3,
        sectionCutAxis: SectionCutAxis3D.axisX,
        sectionCutRatio: 0.5,
      );

      final meshes = payload['meshes'] as List<dynamic>;
      expect(meshes.length, 2); // fakeShadow excluded!

      final capMesh = meshes.firstWhere(
        (m) => (m as Map<String, dynamic>)['moduleId'] == 'room-1',
      ) as Map<String, dynamic>;
      final pos = (capMesh['positions'] as List<dynamic>).cast<double>();
      final idx = (capMesh['indices'] as List<dynamic>).cast<int>();
      final uvs = (capMesh['uvs'] as List<dynamic>).cast<double>();
      expect(uvs.length, (pos.length ~/ 3) * 2);

      // Verify first triangle cross product points strictly +Y_gl (upward)
      Point3D vAt(int vi) => Point3D(pos[vi * 3], pos[vi * 3 + 1], pos[vi * 3 + 2]);
      final a = vAt(idx[0]);
      final b = vAt(idx[1]);
      final c = vAt(idx[2]);
      final ab = b - a;
      final ac = c - a;
      final crossY = ab.z * ac.x - ab.x * ac.z;
      expect(crossY, greaterThan(0.0));

      final lights = payload['interiorLights'] as List<dynamic>;
      expect(lights, hasLength(1));
      expect((lights.first as Map<String, dynamic>)['y'], closeTo(4.65, 0.01));

      final lMesh = meshes.firstWhere(
        (m) => (m as Map<String, dynamic>)['moduleId'] == 'room-l',
      ) as Map<String, dynamic>;
      // 6-vertex concave L-shape triangulates into 4 triangles (12 indices)
      expect((lMesh['indices'] as List<dynamic>).length, 12);
    });
  });

  group('GltfExporterService — Multi-Material PBR Upgrade', () {
    test('emits distinct named PBR materials for wood, marble, brick, and glass', () {
      final lot = Lot(
        id: 'lot-pbr',
        projectId: 'proj-pbr',
        boundary: Polygon2D.fromRect(0, 0, 8, 8),
      );
      final floor = Floor(
        id: 'f1-pbr',
        buildingId: 'b-pbr',
        floorNumber: 1,
        name: 'Piso 1',
        boundary: Polygon2D.fromRect(0, 0, 8, 8),
        maxAllowedArea: 64,
        modules: [
          Module(
            id: 'm-wood',
            floorId: 'f1-pbr',
            name: 'Sala',
            moduleType: 'LIVING_ROOM',
            geometry: Polygon2D.fromRect(0.5, 0.5, 3.5, 3.5),
            status: ElementStatus.existing,
            floorMaterialId: 'floor_oak_wood',
            wallFinishId: 'wall_exposed_brick',
          ),
          Module(
            id: 'm-marble',
            floorId: 'f1-pbr',
            name: 'Baño',
            moduleType: 'BATHROOM',
            geometry: Polygon2D.fromRect(4.0, 0.5, 2.5, 2.5),
            status: ElementStatus.isNew,
            floorMaterialId: 'floor_calacatta_marble',
          ),
          Module(
            id: 'm-win',
            floorId: 'f1-pbr',
            name: 'Ventana',
            moduleType: 'WINDOW',
            geometry: Polygon2D.fromRect(1.5, 0.42, 1.5, 0.16),
            status: ElementStatus.isNew,
          ),
        ],
      );

      final faces = Building3DBuilder.buildScene(
        floors: [floor],
        lot: lot,
        wallHeight: 2.60,
      );
      final gltf = jsonDecode(
        GltfExporterService.exportToGltfJson(faces: faces),
      ) as Map<String, dynamic>;

      final materials = (gltf['materials'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final matNames = materials.map((m) => m['name'] as String).toSet();

      expect(matNames, contains('Trazzik_woodPlanks_PBR'));
      expect(matNames, contains('Trazzik_marbleVeins_PBR'));
      expect(matNames, contains('TrazzikGlassPBR'));

      final glassMat = materials.firstWhere((m) => m['name'] == 'TrazzikGlassPBR');
      expect(glassMat['alphaMode'], 'BLEND');
    });
  });

  group('WebGlCanvas3D — Platform Stub & Controller Safety', () {
    testWidgets('renders gracefully in non-Web test VM and controller dispatches cleanly', (tester) async {
      String? lastPreset;
      double? lastZoom;
      bool? lastWalk;
      String? lastFile;

      final ctrl = WebGlViewerController();
      ctrl.attach(
        onSetCameraPreset: (p, _) => lastPreset = p,
        onZoomStep: (z) => lastZoom = z,
        onSetWalkMode: (e, _) => lastWalk = e,
        onCaptureSnapshot: (f) => lastFile = f,
      );

      ctrl.setCameraPreset('front');
      ctrl.zoomStep(0.8);
      ctrl.setWalkMode(true, floorElevation: 2.6);
      ctrl.captureSnapshot(filename: 'shot.png');

      expect(lastPreset, 'front');
      expect(lastZoom, 0.8);
      expect(lastWalk, isTrue);
      expect(lastFile, 'shot.png');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebGlCanvas3D(
              faces: const [],
              sunPreset: SunPreset3D.studioNoon,
              controller: ctrl,
            ),
          ),
        ),
      );
      expect(isWebGlViewerSupported, isFalse);
      expect(find.byType(WebGlCanvas3D), findsOneWidget);
      ctrl.detach();
    });
  });
}
