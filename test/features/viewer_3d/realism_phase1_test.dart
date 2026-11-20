import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('3D Realism Phase 1 — Block 2A: Architectural Geometry', () {
    test(
      'Stacked multi-story floors keep lower walls at real floorHeight (no floating slabs) while cutting top floor at 1.20m',
      () {
        final lot = Lot(
          id: 'lot_3p',
          projectId: 'p1',
          boundary: Polygon2D.fromRect(0, 0, 7, 10),
        );
        final p1 = Floor(
          id: 'p1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          levelMeters: 0.0,
          heightMeters: 2.34,
          boundary: lot.boundary,
          maxAllowedArea: 70,
          walls: [
            Wall(
              id: 'w_p1',
              floorId: 'p1',
              startPoint: const Point2D(0, 0),
              endPoint: const Point2D(7, 0),
              height: 2.34,
              status: ElementStatus.existing,
            ),
          ],
        );
        final p2 = Floor(
          id: 'p2',
          buildingId: 'b1',
          floorNumber: 2,
          name: 'Piso 2',
          levelMeters: 2.34,
          heightMeters: 2.20,
          boundary: lot.boundary,
          maxAllowedArea: 70,
          walls: [
            Wall(
              id: 'w_p2',
              floorId: 'p2',
              startPoint: const Point2D(0, 0),
              endPoint: const Point2D(7, 0),
              height: 2.20,
              status: ElementStatus.existing,
            ),
          ],
        );

        final faces = Building3DBuilder.buildScene(
          floors: [p1, p2],
          lot: lot,
          wallHeight: 1.20,
          explodedFactor: 0.0,
        );

        final p1WallMaxZ = faces
            .where((f) => f.floorIndex == 0 && f.isWallFace)
            .expand((f) => f.vertices)
            .map((v) => v.z)
            .reduce(math.max);
        final p2WallMaxZ = faces
            .where((f) => f.floorIndex == 1 && f.isWallFace)
            .expand((f) => f.vertices)
            .map((v) => v.z)
            .reduce(math.max);

        // P1 (lower floor) reaches full 2.34m to meet P2 slab solidly
        expect(p1WallMaxZ, closeTo(2.34, 0.02));
        // P2 (top floor) stays cut at 1.20m maquette height (2.34 + 1.20 = 3.54)
        expect(p2WallMaxZ, closeTo(2.34 + 1.20, 0.02));
      },
    );

    test(
      'Wall segments carve real gaps where window/door openings intersect them',
      () {
        final lot = Lot(
          id: 'lot_open',
          projectId: 'p1',
          boundary: Polygon2D.fromRect(0, 0, 6, 6),
        );
        final floor = Floor(
          id: 'p1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.40,
          boundary: lot.boundary,
          maxAllowedArea: 36,
          modules: [
            Module(
              id: 'win_1',
              floorId: 'p1',
              name: 'Ventana Frontal',
              moduleType: 'WINDOW',
              geometry: Polygon2D.fromRect(2.0, -0.075, 2.0, 0.15),
              status: ElementStatus.existing,
            ),
          ],
          walls: [
            Wall(
              id: 'w_front',
              floorId: 'p1',
              startPoint: const Point2D(0, 0),
              endPoint: const Point2D(6, 0),
              height: 2.40,
              status: ElementStatus.existing,
            ),
          ],
        );

        final faces = Building3DBuilder.buildScene(
          floors: [floor],
          lot: lot,
          wallHeight: 2.40,
        );

        // Solid wall faces must NOT span continuously across x = 3.0 (window center)
        final continuousAcrossWindow = faces.where((f) {
          if (!f.isWallFace) return false;
          final xs = f.vertices.map((v) => v.x);
          return xs.reduce(math.min) < 2.1 && xs.reduce(math.max) > 3.9;
        });
        expect(continuousAcrossWindow, isEmpty);

        // Opening translucent panel IS present in the carved gap
        final glassPanels =
            faces.where((f) => f.layer == FaceLayer3D.openingPanel);
        expect(glassPanels, isNotEmpty);
      },
    );

    test(
      'Upper floor slab carves a real stairwell void above lower-floor stairs and showRoof adds roof + parapet',
      () {
        final lot = Lot(
          id: 'lot_stair',
          projectId: 'p1',
          boundary: Polygon2D.fromRect(0, 0, 8, 10),
        );
        final p1 = Floor(
          id: 'p1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          levelMeters: 0.0,
          heightMeters: 2.34,
          boundary: lot.boundary,
          maxAllowedArea: 80,
          modules: [
            Module(
              id: 'stairs_1',
              floorId: 'p1',
              name: 'Escalera',
              moduleType: 'STAIRS',
              geometry: Polygon2D.fromRect(2.0, 2.0, 2.0, 3.0),
              status: ElementStatus.existing,
            ),
          ],
        );
        final p2 = Floor(
          id: 'p2',
          buildingId: 'b1',
          floorNumber: 2,
          name: 'Piso 2',
          levelMeters: 2.34,
          heightMeters: 2.20,
          boundary: lot.boundary,
          maxAllowedArea: 80,
        );

        final faces = Building3DBuilder.buildScene(
          floors: [p1, p2],
          lot: lot,
          wallHeight: 2.34,
          showRoof: true,
        );

        // P2 slab top faces (z ~= 2.34) must NOT cover the stairwell center (3.0, 3.5)
        final p2SlabTopFaces = faces.where(
          (f) =>
              f.floorIndex == 1 &&
              f.layer == FaceLayer3D.slab &&
              f.vertices.every((v) => (v.z - 2.34).abs() < 0.02),
        );
        expect(p2SlabTopFaces.length, greaterThan(1));
        for (final slabFace in p2SlabTopFaces) {
          final poly = Polygon2D(
            slabFace.vertices.map((v) => Point2D(v.x, v.y)).toList(),
          );
          expect(poly.containsPoint(const Point2D(3.0, 3.5)), isFalse);
        }

        // Roof + parapet faces exist above P2 ceiling (2.34 + 2.20 = 4.54m)
        final roofFaces = faces.where(
          (f) => f.vertices.any((v) => v.z >= 4.54 + 0.30),
        );
        expect(roofFaces, isNotEmpty);
      },
    );
  });
}
