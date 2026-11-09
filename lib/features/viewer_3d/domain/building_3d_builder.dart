import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/bounding_box_2d.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/walls/domain/wall.dart';
import 'package:trazzik/features/walls/domain/wall_generation_engine.dart';

/// Constructor paramétrico de volumetría 3D a partir del modelo BIM de pisos y muros
class Building3DBuilder {
  /// Genera todas las caras 3D del proyecto completo o de un piso específico
  static List<Face3D> buildScene({
    required List<Floor> floors,
    required Lot lot,
    double explodedFactor = 0.0, // 0.0 (unido) a 1.0 (máxima separación)
    String? soloFloorId,
    bool showLotGround = true,
    double wallHeight = 1.20, // Altura de corte tipo maqueta arquitectónica (1.20m por defecto, o 2.60m completo)
    bool includeShadows = true,
    SunPreset3D sunPreset = SunPreset3D.studioNoon,
  }) {
    final faces = <Face3D>[];

    // 1. Suelo del Lote (normal hacia +Z garantizada por orientación CCW)
    if (showLotGround) {
      final lotVerts = _ensureCounterClockwiseXY(lot.boundary.vertices);
      if (lotVerts.length >= 3) {
        faces.add(
          Face3D(
            vertices: lotVerts.map((p) => Point3D(p.x, p.y, -0.05)).toList(),
            baseColor: const Color(0xFF1B2A2F),
            label: 'Terreno',
            isEdgeVisible: true,
            layer: FaceLayer3D.terrain,
            floorIndex: -1,
          ),
        );
      }
    }

    final targetFloors = soloFloorId != null
        ? floors.where((f) => f.id == soloFloorId).toList()
        : floors;

    for (int i = 0; i < targetFloors.length; i++) {
      final floor = targetFloors[i];
      // Elevación Z real + desplazamiento opcional pre-aplicado si explodedFactor > 0
      final elevationZ = floor.levelMeters + (i * explodedFactor * 2.50);
      final floorHeight = floor.heightMeters;
      final cutawayHeight = math.min(floorHeight, wallHeight);

      // 2. Losa estructural de entrepiso (0.18m de espesor)
      _buildSlab(faces, floor, elevationZ, floorIndex: i);

      // 3. Pavimentos, carpinterías, escaleras y mobiliario por recinto
      for (final mod in floor.modules) {
        if (mod.isOpening) {
          _buildOpening3D(
            faces,
            mod,
            elevationZ,
            cutawayHeight,
            floorIndex: i,
          );
        } else if (mod.isStairs) {
          _buildStairs3D(
            faces,
            mod,
            elevationZ,
            cutawayHeight,
            floorIndex: i,
          );
        } else {
          _buildRoomFloor(faces, mod, elevationZ, floorIndex: i);
        }

        // 3.1 Mobiliario y artefactos interiores extruidos en 3D
        for (final sub in mod.subModules) {
          if (includeShadows) {
            _buildBoxShadow3D(
              faces,
              minX: sub.geometry.boundingBox.minX,
              minY: sub.geometry.boundingBox.minY,
              maxX: sub.geometry.boundingBox.maxX,
              maxY: sub.geometry.boundingBox.maxY,
              elevationZ: elevationZ,
              objectHeight: math.min(sub.resolvedHeight, cutawayHeight),
              floorBounds: floor.boundary.boundingBox,
              sunPreset: sunPreset,
              floorIndex: i,
            );
          }
          _buildFurniture3D(
            faces,
            sub,
            elevationZ,
            maxCutawayHeight: cutawayHeight,
            floorIndex: i,
          );
        }
      }

      // 3.2 Garajes semicubiertos / pérgolas
      for (final garage
          in floor.modules.where(WallGenerationEngine.isPergolaCarport)) {
        _buildPergolaCarport3D(
          faces,
          garage,
          elevationZ,
          maxHeight: cutawayHeight,
          floorIndex: i,
        );
      }

      // 4. Muros y tabiques (explícitos o generados con el motor unificado)
      final hasExplicitWalls = floor.walls.isNotEmpty;
      final effectiveWalls = hasExplicitWalls
          ? floor.walls
          : WallGenerationEngine.generateWallsForFloor(floor);
      final wallLabel = hasExplicitWalls ? 'Muro' : 'Muro Exterior';
      final roomModules =
          floor.modules.where((m) => !m.isOpening && !m.isStairs).toList();
      for (final wall in effectiveWalls) {
        final effectiveWallH = math.min(wall.height, wallHeight);
        if (includeShadows) {
          _buildWallShadow3D(
            faces,
            wall: wall,
            elevationZ: elevationZ,
            height: effectiveWallH,
            floorBounds: floor.boundary.boundingBox,
            sunPreset: sunPreset,
            floorIndex: i,
          );
        }
        _buildWall3D(
          faces,
          wall,
          elevationZ,
          overrideHeight: effectiveWallH,
          label: wallLabel,
          roomModules: roomModules,
          floorIndex: i,
        );
      }
    }

    return faces;
  }

  /// Ensures a 2D polygon is wound counter-clockwise in XY so its 3D cross-product
  /// normal points strictly upward `(0, 0, +1)`.
  static List<Point2D> _ensureCounterClockwiseXY(List<Point2D> verts) {
    if (verts.length < 3) return verts;
    double signedArea2 = 0;
    for (int i = 0; i < verts.length; i++) {
      final a = verts[i];
      final b = verts[(i + 1) % verts.length];
      signedArea2 += (a.x * b.y) - (b.x * a.y);
    }
    if (signedArea2 < 0) {
      return verts.reversed.toList();
    }
    return verts;
  }

  /// Construye la losa de entrepiso con normales exteriores verificadas
  static void _buildSlab(
    List<Face3D> faces,
    Floor floor,
    double elevationZ, {
    required int floorIndex,
  }) {
    final verts = _ensureCounterClockwiseXY(floor.boundary.vertices);
    if (verts.length < 3) return;

    const slabThickness = 0.18;
    final topZ = elevationZ;
    final botZ = elevationZ - slabThickness;

    // Cara superior de la losa (normal +Z)
    faces.add(
      Face3D(
        vertices: verts.map((p) => Point3D(p.x, p.y, topZ)).toList(),
        baseColor: const Color(0xFF2C3E50),
        label: '${floor.name} - Losa',
        layer: FaceLayer3D.slab,
        floorIndex: floorIndex,
      ),
    );

    // Cantos perimetrales de la losa (normales exteriores en XY)
    for (int i = 0; i < verts.length; i++) {
      final p1 = verts[i];
      final p2 = verts[(i + 1) % verts.length];
      faces.add(
        Face3D(
          vertices: [
            Point3D(p1.x, p1.y, botZ),
            Point3D(p2.x, p2.y, botZ),
            Point3D(p2.x, p2.y, topZ),
            Point3D(p1.x, p1.y, topZ),
          ],
          baseColor: const Color(0xFF1E2B37),
          layer: FaceLayer3D.slab,
          floorIndex: floorIndex,
        ),
      );
    }
  }

  /// Construye el pavimento coloreado y texturizado de un recinto
  static void _buildRoomFloor(
    List<Face3D> faces,
    Module mod,
    double elevationZ, {
    required int floorIndex,
  }) {
    final verts = _ensureCounterClockwiseXY(mod.geometry.vertices);
    if (verts.length < 3) return;

    final finish = FinishMaterialCatalog.resolveFloorForModule(mod);
    final floorColor = mod.floorMaterialId != null
        ? finish.baseColor.withValues(alpha: 0.92)
        : _getColorForModuleType(mod.moduleType);

    faces.add(
      Face3D(
        vertices:
            verts.map((p) => Point3D(p.x, p.y, elevationZ + 0.01)).toList(),
        baseColor: floorColor,
        label: mod.name,
        moduleId: mod.id,
        floorId: mod.floorId,
        pattern: finish.pattern,
        patternColor: finish.accentColor,
        layer: FaceLayer3D.floorFinish,
        floorIndex: floorIndex,
        isRoomLabel: true,
      ),
    );
  }

  static Module? _findRoomContainingPoint(List<Module> rooms, Point2D pt) {
    for (final room in rooms) {
      if (room.geometry.containsPoint(pt)) {
        return room;
      }
    }
    return null;
  }

  /// Construye la sombra proyectada de un muro sobre la losa
  static void _buildWallShadow3D(
    List<Face3D> faces, {
    required Wall wall,
    required double elevationZ,
    required double height,
    required BoundingBox2D floorBounds,
    required SunPreset3D sunPreset,
    required int floorIndex,
  }) {
    final len = wall.startPoint.distanceTo(wall.endPoint);
    if (len < 0.15 || height <= 0.10) return;

    final shadowScale = math.min(height, 1.40) * 0.45;
    final sx = sunPreset.shadowOffsetPerMeter.dx * shadowScale;
    final sy = sunPreset.shadowOffsetPerMeter.dy * shadowScale;

    double clampX(double x) =>
        x.clamp(floorBounds.minX, math.max(floorBounds.minX, floorBounds.maxX));
    double clampY(double y) =>
        y.clamp(floorBounds.minY, math.max(floorBounds.minY, floorBounds.maxY));

    final p1 = wall.startPoint;
    final p2 = wall.endPoint;
    final z = elevationZ + 0.014;

    faces.add(
      Face3D(
        vertices: [
          Point3D(clampX(p1.x), clampY(p1.y), z),
          Point3D(clampX(p2.x), clampY(p2.y), z),
          Point3D(clampX(p2.x + sx), clampY(p2.y + sy), z),
          Point3D(clampX(p1.x + sx), clampY(p1.y + sy), z),
        ],
        baseColor: const Color(0x24070B12),
        isEdgeVisible: false,
        layer: FaceLayer3D.shadow,
        floorIndex: floorIndex,
      ),
    );
  }

  /// Construye la sombra proyectada y oclusión ambiental de una caja (mobiliario)
  static void _buildBoxShadow3D(
    List<Face3D> faces, {
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
    required double elevationZ,
    required double objectHeight,
    required BoundingBox2D floorBounds,
    required SunPreset3D sunPreset,
    required int floorIndex,
  }) {
    if (objectHeight <= 0.08) return;
    final shadowScale = math.min(objectHeight, 1.20) * 0.38;
    final sx = sunPreset.shadowOffsetPerMeter.dx * shadowScale;
    final sy = sunPreset.shadowOffsetPerMeter.dy * shadowScale;

    double clampX(double x) =>
        x.clamp(floorBounds.minX, math.max(floorBounds.minX, floorBounds.maxX));
    double clampY(double y) =>
        y.clamp(floorBounds.minY, math.max(floorBounds.minY, floorBounds.maxY));

    final sMinX = clampX(math.min(minX, minX + sx));
    final sMaxX = clampX(math.max(maxX, maxX + sx));
    final sMinY = clampY(math.min(minY, minY + sy));
    final sMaxY = clampY(math.max(maxY, maxY + sy));
    if (sMaxX - sMinX < 0.05 || sMaxY - sMinY < 0.05) return;

    final z = elevationZ + 0.015;
    faces.add(
      Face3D(
        vertices: [
          Point3D(sMinX, sMinY, z),
          Point3D(sMaxX, sMinY, z),
          Point3D(sMaxX, sMaxY, z),
          Point3D(sMinX, sMaxY, z),
        ],
        baseColor: const Color(0x20070B12),
        isEdgeVisible: false,
        layer: FaceLayer3D.shadow,
        floorIndex: floorIndex,
      ),
    );
  }

  /// Construye un segmento de muro tridimensional con normales exteriores estrictas
  static void _buildWallSegment3D(
    List<Face3D> faces, {
    required Point2D p1,
    required Point2D p2,
    required double elevationZ,
    required double height,
    double thickness = 0.15,
    Color wallColor = const Color(0xFFECEFF1), // Blanco marfil técnico
    Color topCapColor = const Color(0xFFCFD8DC),
    String? label,
    List<Module> roomModules = const [],
    int floorIndex = 0,
    bool emitStartCap = true,
    bool emitEndCap = true,
  }) {
    final len = p1.distanceTo(p2);
    if (len < 0.08) return;

    final halfThick = thickness / 2;
    final ux = (p2.x - p1.x) / len;
    final uy = (p2.y - p1.y) / len;
    final nx = -uy * halfThick;
    final ny = ux * halfThick;

    final midX = (p1.x + p2.x) / 2.0;
    final midY = (p1.y + p2.y) / 2.0;
    const probeScale = 2.2;
    final roomSideA = roomModules.isNotEmpty
        ? _findRoomContainingPoint(
            roomModules,
            Point2D(midX + nx * probeScale, midY + ny * probeScale),
          )
        : null;
    final roomSideB = roomModules.isNotEmpty
        ? _findRoomContainingPoint(
            roomModules,
            Point2D(midX - nx * probeScale, midY - ny * probeScale),
          )
        : null;

    final finishA = roomSideA != null
        ? FinishMaterialCatalog.resolveWallForModule(roomSideA)
        : null;
    final finishB = roomSideB != null
        ? FinishMaterialCatalog.resolveWallForModule(roomSideB)
        : null;

    final colorA = finishA != null ? finishA.baseColor : wallColor;
    final colorB = finishB != null ? finishB.baseColor : wallColor;

    final b0 = Point3D(p1.x + nx, p1.y + ny, elevationZ);
    final b1 = Point3D(p2.x + nx, p2.y + ny, elevationZ);
    final b2 = Point3D(p2.x - nx, p2.y - ny, elevationZ);
    final b3 = Point3D(p1.x - nx, p1.y - ny, elevationZ);

    final topZ = elevationZ + height;
    final t0 = Point3D(b0.x, b0.y, topZ);
    final t1 = Point3D(b1.x, b1.y, topZ);
    final t2 = Point3D(b2.x, b2.y, topZ);
    final t3 = Point3D(b3.x, b3.y, topZ);

    // Side A (+n outward normal: [b1, b0, t0, t1])
    faces.add(
      Face3D(
        vertices: [b1, b0, t0, t1],
        baseColor: colorA,
        label: label,
        moduleId: roomSideA?.id,
        floorId: roomSideA?.floorId,
        pattern: finishA?.pattern,
        patternColor: finishA?.accentColor,
        isWallFace: true,
        layer: FaceLayer3D.structureAndFurniture,
        floorIndex: floorIndex,
      ),
    );
    // Side B (-n outward normal: [b3, b2, t2, t3])
    faces.add(
      Face3D(
        vertices: [b3, b2, t2, t3],
        baseColor: colorB,
        moduleId: roomSideB?.id,
        floorId: roomSideB?.floorId,
        pattern: finishB?.pattern,
        patternColor: finishB?.accentColor,
        isWallFace: true,
        layer: FaceLayer3D.structureAndFurniture,
        floorIndex: floorIndex,
      ),
    );
    // Start cap at p1 (-u outward normal: [b0, b3, t3, t0])
    if (emitStartCap) {
      faces.add(
        Face3D(
          vertices: [b0, b3, t3, t0],
          baseColor: wallColor,
          isWallFace: true,
          layer: FaceLayer3D.structureAndFurniture,
          floorIndex: floorIndex,
        ),
      );
    }
    // End cap at p2 (+u outward normal: [b2, b1, t1, t2])
    if (emitEndCap) {
      faces.add(
        Face3D(
          vertices: [b2, b1, t1, t2],
          baseColor: wallColor,
          isWallFace: true,
          layer: FaceLayer3D.structureAndFurniture,
          floorIndex: floorIndex,
        ),
      );
    }
    // Top cap at topZ (+Z outward normal: [t3, t2, t1, t0])
    faces.add(
      Face3D(
        vertices: [t3, t2, t1, t0],
        baseColor: topCapColor,
        isWallFace: true,
        layer: FaceLayer3D.structureAndFurniture,
        floorIndex: floorIndex,
      ),
    );
  }

  /// Extruye un muro 3D subdividiéndolo exactamente en las transiciones de recintos adyacentes
  /// y fusionando tramos colineales con el mismo par de recintos (sin tapas internas).
  static void _buildWall3D(
    List<Face3D> faces,
    Wall wall,
    double elevationZ, {
    double? overrideHeight,
    String label = 'Muro',
    List<Module> roomModules = const [],
    int floorIndex = 0,
  }) {
    final len = wall.startPoint.distanceTo(wall.endPoint);
    if (len < 0.08) return;
    final h = overrideHeight ?? wall.height;

    if (roomModules.length <= 1 || len <= 0.40) {
      _buildWallSegment3D(
        faces,
        p1: wall.startPoint,
        p2: wall.endPoint,
        elevationZ: elevationZ,
        height: h,
        thickness: wall.thickness,
        label: label,
        roomModules: roomModules,
        floorIndex: floorIndex,
      );
      return;
    }

    // 1. Collect exact parametric split points t in (0, 1) from room polygon vertices near the wall line
    final dx = wall.endPoint.x - wall.startPoint.x;
    final dy = wall.endPoint.y - wall.startPoint.y;
    final lenSq = dx * dx + dy * dy;
    final ux = dx / len;
    final uy = dy / len;
    final halfThick = wall.thickness / 2;
    final nx = -uy * halfThick;
    final ny = ux * halfThick;
    final maxPerpDist = math.max(wall.thickness * 3.0, 0.45);

    final rawSplits = <double>[0.0, 1.0];
    for (final room in roomModules) {
      for (final v in room.geometry.vertices) {
        final vx = v.x - wall.startPoint.x;
        final vy = v.y - wall.startPoint.y;
        final t = (vx * dx + vy * dy) / lenSq;
        if (t <= 0.01 || t >= 0.99) continue;
        final perpDist = (vx * (-uy) + vy * ux).abs();
        if (perpDist <= maxPerpDist) {
          rawSplits.add(t);
        }
      }
    }
    rawSplits.sort();

    // Deduplicate splits closer than 5cm along the wall
    final minDeltaT = (0.05 / len).clamp(0.005, 0.20);
    final uniqueT = <double>[0.0];
    for (final t in rawSplits) {
      if (t - uniqueT.last >= minDeltaT) {
        uniqueT.add(t);
      }
    }
    if (1.0 - uniqueT.last < minDeltaT && uniqueT.length > 1) {
      uniqueT[uniqueT.length - 1] = 1.0;
    } else if (uniqueT.last < 1.0) {
      uniqueT.add(1.0);
    }

    // 2. Coalesce consecutive intervals that resolve to the exact same adjacent rooms
    const probeScale = 2.2;
    final mergedSpans = <({double t0, double t1})>[];
    String? prevKey;

    for (int i = 0; i < uniqueT.length - 1; i++) {
      final t0 = uniqueT[i];
      final t1 = uniqueT[i + 1];
      final tm = (t0 + t1) / 2.0;
      final mx = wall.startPoint.x + dx * tm;
      final my = wall.startPoint.y + dy * tm;
      final roomA = _findRoomContainingPoint(
        roomModules,
        Point2D(mx + nx * probeScale, my + ny * probeScale),
      );
      final roomB = _findRoomContainingPoint(
        roomModules,
        Point2D(mx - nx * probeScale, my - ny * probeScale),
      );
      final key = '${roomA?.id ?? '-'}|${roomB?.id ?? '-'}';
      if (mergedSpans.isNotEmpty && key == prevKey) {
        final last = mergedSpans.removeLast();
        mergedSpans.add((t0: last.t0, t1: t1));
      } else {
        mergedSpans.add((t0: t0, t1: t1));
        prevKey = key;
      }
    }

    for (int i = 0; i < mergedSpans.length; i++) {
      final span = mergedSpans[i];
      final sp = Point2D(
        wall.startPoint.x + dx * span.t0,
        wall.startPoint.y + dy * span.t0,
      );
      final ep = Point2D(
        wall.startPoint.x + dx * span.t1,
        wall.startPoint.y + dy * span.t1,
      );
      _buildWallSegment3D(
        faces,
        p1: sp,
        p2: ep,
        elevationZ: elevationZ,
        height: h,
        thickness: wall.thickness,
        label: i == 0 ? label : null,
        roomModules: roomModules,
        floorIndex: floorIndex,
        emitStartCap: i == 0,
        emitEndCap: i == mergedSpans.length - 1,
      );
    }
  }

  /// Helper for axis-aligned 3D boxes with verified outward normals on all 5 visible faces.
  static void _addAxisAlignedBox3D(
    List<Face3D> faces, {
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
    required double z0,
    required double z1,
    required Color sideColor,
    Color? topColor,
    String? label,
    required int floorIndex,
    FaceLayer3D layer = FaceLayer3D.structureAndFurniture,
  }) {
    if (z1 <= z0 + 1e-4) return;
    final capColor = topColor ?? sideColor;

    // Top (+Z outward normal)
    faces.add(
      Face3D(
        vertices: [
          Point3D(minX, minY, z1),
          Point3D(maxX, minY, z1),
          Point3D(maxX, maxY, z1),
          Point3D(minX, maxY, z1),
        ],
        baseColor: capColor,
        label: label,
        layer: layer,
        floorIndex: floorIndex,
      ),
    );
    // Front at minY (-Y outward normal)
    faces.add(
      Face3D(
        vertices: [
          Point3D(minX, minY, z0),
          Point3D(maxX, minY, z0),
          Point3D(maxX, minY, z1),
          Point3D(minX, minY, z1),
        ],
        baseColor: sideColor,
        layer: layer,
        floorIndex: floorIndex,
      ),
    );
    // Right at maxX (+X outward normal)
    faces.add(
      Face3D(
        vertices: [
          Point3D(maxX, minY, z0),
          Point3D(maxX, maxY, z0),
          Point3D(maxX, maxY, z1),
          Point3D(maxX, minY, z1),
        ],
        baseColor: sideColor,
        layer: layer,
        floorIndex: floorIndex,
      ),
    );
    // Back at maxY (+Y outward normal)
    faces.add(
      Face3D(
        vertices: [
          Point3D(maxX, maxY, z0),
          Point3D(minX, maxY, z0),
          Point3D(minX, maxY, z1),
          Point3D(maxX, maxY, z1),
        ],
        baseColor: sideColor,
        layer: layer,
        floorIndex: floorIndex,
      ),
    );
    // Left at minX (-X outward normal)
    faces.add(
      Face3D(
        vertices: [
          Point3D(minX, maxY, z0),
          Point3D(minX, minY, z0),
          Point3D(minX, minY, z1),
          Point3D(minX, maxY, z1),
        ],
        baseColor: sideColor,
        layer: layer,
        floorIndex: floorIndex,
      ),
    );
  }

  /// Construye paramétricamente una pérgola / cochera semicubierta en 3D
  static void _buildPergolaCarport3D(
    List<Face3D> faces,
    Module garage,
    double elevationZ, {
    required double maxHeight,
    required int floorIndex,
  }) {
    final bb = garage.geometry.boundingBox;
    const colThick = 0.18;
    const beamH = 0.22;
    final pergolaH = math.min(2.40, maxHeight);
    if (pergolaH <= 0.20) return;

    // 4 Columnas esquineras
    final corners = [
      Point2D(bb.minX, bb.minY),
      Point2D(bb.maxX - colThick, bb.minY),
      Point2D(bb.minX, bb.maxY - colThick),
      Point2D(bb.maxX - colThick, bb.maxY - colThick),
    ];

    for (final c in corners) {
      _buildWallSegment3D(
        faces,
        p1: Point2D(c.x, c.y + colThick / 2),
        p2: Point2D(c.x + colThick, c.y + colThick / 2),
        elevationZ: elevationZ,
        height: pergolaH,
        thickness: colThick,
        wallColor: const Color(0xFF5D4037),
        topCapColor: const Color(0xFF4E342E),
        label: 'Columna Cochera',
        floorIndex: floorIndex,
      );
    }

    if (maxHeight < 2.10) return;

    // Vigas superiores perimetrales
    final beamElev = elevationZ + pergolaH - beamH;
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.minX, bb.minY),
      p2: Point2D(bb.maxX, bb.minY),
      elevationZ: beamElev,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
      floorIndex: floorIndex,
    );
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.minX, bb.maxY),
      p2: Point2D(bb.maxX, bb.maxY),
      elevationZ: beamElev,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
      floorIndex: floorIndex,
    );
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.minX, bb.minY),
      p2: Point2D(bb.minX, bb.maxY),
      elevationZ: beamElev,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
      floorIndex: floorIndex,
    );
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.maxX, bb.minY),
      p2: Point2D(bb.maxX, bb.maxY),
      elevationZ: beamElev,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
      floorIndex: floorIndex,
    );

    // Tirantes superiores de pérgola
    const numRafters = 5;
    final spacing = bb.width / (numRafters + 1);
    for (int r = 1; r <= numRafters; r++) {
      final rx = bb.minX + r * spacing;
      _buildWallSegment3D(
        faces,
        p1: Point2D(rx, bb.minY),
        p2: Point2D(rx, bb.maxY),
        elevationZ: elevationZ + pergolaH - 0.12,
        height: 0.12,
        thickness: 0.08,
        wallColor: const Color(0xFF6D4C41),
        topCapColor: const Color(0xFF5D4037),
        label: 'Tirante Pérgola',
        floorIndex: floorIndex,
      );
    }
  }

  /// Construye aberturas (puertas y ventanas) en 3D con dintel estructural, antepecho y marco
  static void _buildOpening3D(
    List<Face3D> faces,
    Module mod,
    double elevationZ,
    double floorHeight, {
    required int floorIndex,
  }) {
    final bb = mod.geometry.boundingBox;
    final isDoor = mod.isDoorOrGate;

    final isHoriz = bb.width >= bb.height;
    final openLen = isHoriz ? bb.width : bb.height;
    const wallThick = 0.15;
    final halfThick = wallThick / 2;

    final cx = bb.minX + bb.width / 2;
    final cy = bb.minY + bb.height / 2;

    final topZ = elevationZ + floorHeight; // Coronación superior (recortada en modo maqueta 1.20m)
    final sillZ = math.min(topZ, elevationZ + (isDoor ? 0.0 : 0.90)); // Antepecho
    final lintelZ = math.min(topZ, elevationZ + 2.10); // Dintel inferior a 2.10m (o topZ si es menor)

    const wallColor = Color(0xFFECEFF1);
    const topCapColor = Color(0xFFCFD8DC);

    final minX = isHoriz ? cx - openLen / 2 : cx - halfThick;
    final maxX = isHoriz ? cx + openLen / 2 : cx + halfThick;
    final minY = isHoriz ? cy - halfThick : cy - openLen / 2;
    final maxY = isHoriz ? cy + halfThick : cy + openLen / 2;

    // 1. Dintel estructural sobre la abertura (de 2.10m a cielo raso) con normales exteriores
    if (topZ > lintelZ + 0.05) {
      _addAxisAlignedBox3D(
        faces,
        minX: minX,
        minY: minY,
        maxX: maxX,
        maxY: maxY,
        z0: lintelZ,
        z1: topZ,
        sideColor: wallColor,
        topColor: topCapColor,
        floorIndex: floorIndex,
      );
    }

    // 2. Antepecho inferior en ventanas (de piso a 0.90m) con normales exteriores
    if (!isDoor && sillZ > elevationZ + 0.05) {
      _addAxisAlignedBox3D(
        faces,
        minX: minX,
        minY: minY,
        maxX: maxX,
        maxY: maxY,
        z0: elevationZ,
        z1: sillZ,
        sideColor: wallColor,
        topColor: topCapColor,
        floorIndex: floorIndex,
      );
    }

    // 3. Hoja de carpintería (panel de madera o vidrio de ventana con iluminación bilateral)
    final panelColor = isDoor
        ? const Color(0xFF8D6E63) // Madera cálida
        : const Color(0xFF4FC3F7).withValues(alpha: 0.65); // Vidrio traslúcido

    if (isHoriz) {
      final x0 = cx - openLen / 2;
      final x1 = cx + openLen / 2;
      faces.add(
        Face3D(
          vertices: [
            Point3D(x0, cy, sillZ),
            Point3D(x1, cy, sillZ),
            Point3D(x1, cy, lintelZ),
            Point3D(x0, cy, lintelZ),
          ],
          baseColor: panelColor,
          label: mod.name,
          layer: FaceLayer3D.openingPanel,
          floorIndex: floorIndex,
          isTwoSided: true,
        ),
      );
    } else {
      final y0 = cy - openLen / 2;
      final y1 = cy + openLen / 2;
      faces.add(
        Face3D(
          vertices: [
            Point3D(cx, y0, sillZ),
            Point3D(cx, y1, sillZ),
            Point3D(cx, y1, lintelZ),
            Point3D(cx, y0, lintelZ),
          ],
          baseColor: panelColor,
          label: mod.name,
          layer: FaceLayer3D.openingPanel,
          floorIndex: floorIndex,
          isTwoSided: true,
        ),
      );
    }
  }

  /// Construye una escalera 3D con peldaños ascendentes respetando el corte de maqueta
  static void _buildStairs3D(
    List<Face3D> faces,
    Module mod,
    double elevationZ,
    double maxStairHeight, {
    required int floorIndex,
  }) {
    final bb = mod.geometry.boundingBox;
    const totalSteps = 14;
    const fullReferenceHeight = 2.70;
    final stepRise = fullReferenceHeight / totalSteps;
    final visibleSteps =
        (maxStairHeight / stepRise).ceil().clamp(1, totalSteps);
    final isLongX = bb.width >= bb.height;
    final flipX = mod.flipX;
    final flipY = mod.flipY;

    for (int s = 0; s < visibleSteps; s++) {
      final stepZ = elevationZ + (s * stepRise);
      final topStepZ = math.min(elevationZ + maxStairHeight, stepZ + stepRise);
      if (topStepZ <= stepZ + 0.01) break;
      double minX, maxX, minY, maxY;

      if (isLongX) {
        final stepW = bb.width / totalSteps;
        final stepIndex = flipX ? (totalSteps - 1 - s) : s;
        minX = bb.minX + (stepIndex * stepW);
        maxX = minX + stepW;
        minY = bb.minY;
        maxY = bb.maxY;
      } else {
        final stepH = bb.height / totalSteps;
        final stepIndex = flipY ? (totalSteps - 1 - s) : s;
        minX = bb.minX;
        maxX = bb.maxX;
        minY = bb.minY + (stepIndex * stepH);
        maxY = minY + stepH;
      }

      _addAxisAlignedBox3D(
        faces,
        minX: minX,
        minY: minY,
        maxX: maxX,
        maxY: maxY,
        z0: stepZ,
        z1: topStepZ,
        sideColor: const Color(0xFF78909C),
        topColor: const Color(0xFFB0BEC5),
        label: s == 0 ? mod.name : null,
        floorIndex: floorIndex,
      );
    }
  }

  static Color _getColorForModuleType(String type) {
    switch (type.toUpperCase()) {
      case 'LIVING_ROOM':
      case 'LIVING_DINING':
        return const Color(0xFF37474F).withValues(alpha: 0.82);
      case 'DINING_ROOM':
        return const Color(0xFF455A64).withValues(alpha: 0.82);
      case 'KITCHEN':
      case 'PANTRY':
        return const Color(0xFF00695C).withValues(alpha: 0.75);
      case 'BEDROOM':
      case 'DRESSING_ROOM':
        return const Color(0xFF283593).withValues(alpha: 0.70);
      case 'BATHROOM':
        return const Color(0xFF0277BD).withValues(alpha: 0.75);
      case 'OFFICE':
      case 'STUDIO':
        return const Color(0xFF4E342E).withValues(alpha: 0.75);
      case 'LAUNDRY':
      case 'STORAGE':
        return const Color(0xFF546E7A).withValues(alpha: 0.75);
      case 'CORRIDOR':
      case 'FOYER':
        return const Color(0xFF607D8B).withValues(alpha: 0.78);
      case 'GARAGE':
        return const Color(0xFF424242).withValues(alpha: 0.85);
      case 'TERRACE':
      case 'GARDEN':
      case 'PATIO':
        return const Color(0xFF2E7D32).withValues(alpha: 0.75);
      default:
        return const Color(0xFF37474F).withValues(alpha: 0.68);
    }
  }

  /// Extruye paramétricamente una pieza de mobiliario o artefacto en la maqueta 3D
  static void _buildFurniture3D(
    List<Face3D> faces,
    SubModule sub,
    double elevationZ, {
    required double maxCutawayHeight,
    required int floorIndex,
  }) {
    final bb = sub.geometry.boundingBox;
    final effectiveSubElevation = sub.resolvedElevation;
    if (effectiveSubElevation >= maxCutawayHeight) return;

    final rawH = sub.resolvedHeight;
    final actualH = math.min(rawH, maxCutawayHeight - effectiveSubElevation);
    if (actualH <= 0.02) return;

    final z0 = elevationZ + effectiveSubElevation + 0.02;
    final z1 = z0 + actualH;
    final color = sub.default3dColor;

    _addAxisAlignedBox3D(
      faces,
      minX: bb.minX,
      minY: bb.minY,
      maxX: bb.maxX,
      maxY: bb.maxY,
      z0: z0,
      z1: z1,
      sideColor: color,
      topColor: color,
      floorIndex: floorIndex,
    );
  }
}
