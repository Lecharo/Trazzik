import 'dart:math' as math;
import 'package:flutter/material.dart';
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
  }) {
    final faces = <Face3D>[];

    // 1. Suelo del Lote
    if (showLotGround) {
      final lotVerts = lot.boundary.vertices;
      if (lotVerts.isNotEmpty) {
        faces.add(
          Face3D(
            vertices: lotVerts.map((p) => Point3D(p.x, p.y, -0.05)).toList(),
            baseColor: const Color(0xFF1B2A2F),
            label: 'Terreno',
            isEdgeVisible: true,
          ),
        );
      }
    }

    final targetFloors = soloFloorId != null
        ? floors.where((f) => f.id == soloFloorId).toList()
        : floors;

    for (int i = 0; i < targetFloors.length; i++) {
      final floor = targetFloors[i];
      // Elevación Z real + desplazamiento por maqueta explotada
      final elevationZ = floor.levelMeters + (i * explodedFactor * 2.50);
      final floorHeight = floor.heightMeters;

      // 2. Losa estructural de entrepiso (0.20m de espesor)
      _buildSlab(faces, floor, elevationZ);

      // 3. Pavimentos y acabados por recinto
      final effectiveOpeningTopHeight = math.min(floorHeight, wallHeight);
      for (final mod in floor.modules) {
        if (mod.isOpening) {
          _buildOpening3D(faces, mod, elevationZ, effectiveOpeningTopHeight);
        } else if (mod.isStairs) {
          _buildStairs3D(faces, mod, elevationZ, floorHeight);
        } else {
          _buildRoomFloor(faces, mod, elevationZ);
        }

        // 3.1 Mobiliario y artefactos interiores extruidos en 3D
        for (final sub in mod.subModules) {
          _buildFurniture3D(faces, sub, elevationZ);
        }
      }

      // 3.2 Garajes semicubiertos / pérgolas
      for (final garage in floor.modules.where(WallGenerationEngine.isPergolaCarport)) {
        _buildPergolaCarport3D(faces, garage, elevationZ);
      }

      // 4. Muros y tabiques (explícitos o generados con el motor unificado)
      final hasExplicitWalls = floor.walls.isNotEmpty;
      final effectiveWalls = hasExplicitWalls
          ? floor.walls
          : WallGenerationEngine.generateWallsForFloor(floor);
      final wallLabel = hasExplicitWalls ? 'Muro' : 'Muro Exterior';
      final roomModules = floor.modules.where((m) => !m.isOpening && !m.isStairs).toList();
      for (final wall in effectiveWalls) {
        _buildWall3D(
          faces,
          wall,
          elevationZ,
          overrideHeight: math.min(wall.height, wallHeight),
          label: wallLabel,
          roomModules: roomModules,
        );
      }
    }

    return faces;
  }

  /// Construye la losa de entrepiso
  static void _buildSlab(List<Face3D> faces, Floor floor, double elevationZ) {
    final verts = floor.boundary.vertices;
    if (verts.length < 3) return;

    const slabThickness = 0.18;
    final topZ = elevationZ;
    final botZ = elevationZ - slabThickness;

    // Cara superior de la losa
    faces.add(
      Face3D(
        vertices: verts.map((p) => Point3D(p.x, p.y, topZ)).toList(),
        baseColor: const Color(0xFF2C3E50),
        label: '${floor.name} - Losa',
      ),
    );

    // Cantos perimetrales de la losa
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
        ),
      );
    }
  }

  /// Construye el pavimento coloreado y texturizado de un recinto
  static void _buildRoomFloor(List<Face3D> faces, Module mod, double elevationZ) {
    final verts = mod.geometry.vertices;
    if (verts.length < 3) return;

    final finish = FinishMaterialCatalog.resolveFloorForModule(mod);
    final floorColor = mod.floorMaterialId != null
        ? finish.baseColor.withValues(alpha: 0.90)
        : _getColorForModuleType(mod.moduleType);

    faces.add(
      Face3D(
        vertices: verts.map((p) => Point3D(p.x, p.y, elevationZ + 0.01)).toList(),
        baseColor: floorColor,
        label: mod.name,
        moduleId: mod.id,
        floorId: mod.floorId,
        pattern: finish.pattern,
        patternColor: finish.accentColor,
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

  /// Construye un segmento de muro tridimensional
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
  }) {
    final len = p1.distanceTo(p2);
    if (len < 0.10) return;

    final halfThick = thickness / 2;
    final ux = (p2.x - p1.x) / len;
    final uy = (p2.y - p1.y) / len;
    final nx = -uy * halfThick;
    final ny = ux * halfThick;

    final midX = (p1.x + p2.x) / 2.0;
    final midY = (p1.y + p2.y) / 2.0;
    final probeScale = 2.2;
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

    faces.add(
      Face3D(
        vertices: [b0, b1, t1, t0],
        baseColor: colorA,
        label: label,
        moduleId: roomSideA?.id,
        floorId: roomSideA?.floorId,
        pattern: finishA?.pattern,
        patternColor: finishA?.accentColor,
        isWallFace: true,
      ),
    );
    faces.add(
      Face3D(
        vertices: [b2, b3, t3, t2],
        baseColor: colorB,
        moduleId: roomSideB?.id,
        floorId: roomSideB?.floorId,
        pattern: finishB?.pattern,
        patternColor: finishB?.accentColor,
        isWallFace: true,
      ),
    );
    faces.add(Face3D(vertices: [b3, b0, t0, t3], baseColor: wallColor, isWallFace: true));
    faces.add(Face3D(vertices: [b1, b2, t2, t1], baseColor: wallColor, isWallFace: true));
    faces.add(Face3D(vertices: [t0, t1, t2, t3], baseColor: topCapColor, isWallFace: true));
  }

  /// Extruye un muro 3D completo con sus 6 caras, subdividiendo tramos que cruzan múltiples ambientes
  static void _buildWall3D(
    List<Face3D> faces,
    Wall wall,
    double elevationZ, {
    double? overrideHeight,
    String label = 'Muro',
    List<Module> roomModules = const [],
  }) {
    final len = wall.startPoint.distanceTo(wall.endPoint);
    final h = overrideHeight ?? wall.height;
    if (roomModules.length > 1 && len > 2.20) {
      final subCount = (len / 1.50).ceil().clamp(2, 8);
      for (int i = 0; i < subCount; i++) {
        final t0 = i / subCount;
        final t1 = (i + 1) / subCount;
        final sp = Point2D(
          wall.startPoint.x + (wall.endPoint.x - wall.startPoint.x) * t0,
          wall.startPoint.y + (wall.endPoint.y - wall.startPoint.y) * t0,
        );
        final ep = Point2D(
          wall.startPoint.x + (wall.endPoint.x - wall.startPoint.x) * t1,
          wall.startPoint.y + (wall.endPoint.y - wall.startPoint.y) * t1,
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
        );
      }
      return;
    }

    _buildWallSegment3D(
      faces,
      p1: wall.startPoint,
      p2: wall.endPoint,
      elevationZ: elevationZ,
      height: h,
      thickness: wall.thickness,
      label: label,
      roomModules: roomModules,
    );
  }

  /// Construye paramétricamente una pérgola / cochera semicubierta en 3D
  static void _buildPergolaCarport3D(
    List<Face3D> faces,
    Module garage,
    double elevationZ,
  ) {
    final bb = garage.geometry.boundingBox;
    const colThick = 0.18;
    const beamH = 0.22;
    const pergolaH = 2.40;

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
      );
    }

    // Vigas superiores perimetrales
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.minX, bb.minY),
      p2: Point2D(bb.maxX, bb.minY),
      elevationZ: elevationZ + pergolaH - beamH,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
    );
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.minX, bb.maxY),
      p2: Point2D(bb.maxX, bb.maxY),
      elevationZ: elevationZ + pergolaH - beamH,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
    );
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.minX, bb.minY),
      p2: Point2D(bb.minX, bb.maxY),
      elevationZ: elevationZ + pergolaH - beamH,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
    );
    _buildWallSegment3D(
      faces,
      p1: Point2D(bb.maxX, bb.minY),
      p2: Point2D(bb.maxX, bb.maxY),
      elevationZ: elevationZ + pergolaH - beamH,
      height: beamH,
      thickness: 0.12,
      wallColor: const Color(0xFF5D4037),
      topCapColor: const Color(0xFF4E342E),
      label: 'Viga Cochera',
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
      );
    }
  }

  /// Construye aberturas (puertas y ventanas) en 3D con dintel estructural, antepecho y marco
  static void _buildOpening3D(
    List<Face3D> faces,
    Module mod,
    double elevationZ,
    double floorHeight,
  ) {
    final bb = mod.geometry.boundingBox;
    final isDoor = mod.moduleType.toUpperCase().contains('DOOR') ||
        mod.moduleType.toUpperCase().contains('GATE');

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

    // 1. Dintel estructural sobre la abertura (de 2.10m a cielo raso)
    if (topZ > lintelZ + 0.05) {
      if (isHoriz) {
        final x0 = cx - openLen / 2;
        final x1 = cx + openLen / 2;
        final y0 = cy - halfThick;
        final y1 = cy + halfThick;

        // Frontal y trasera del dintel
        faces.add(Face3D(
          vertices: [
            Point3D(x0, y0, lintelZ),
            Point3D(x1, y0, lintelZ),
            Point3D(x1, y0, topZ),
            Point3D(x0, y0, topZ),
          ],
          baseColor: wallColor,
        ));
        faces.add(Face3D(
          vertices: [
            Point3D(x1, y1, lintelZ),
            Point3D(x0, y1, lintelZ),
            Point3D(x0, y1, topZ),
            Point3D(x1, y1, topZ),
          ],
          baseColor: wallColor,
        ));
        // Tapa superior del dintel
        faces.add(Face3D(
          vertices: [
            Point3D(x0, y0, topZ),
            Point3D(x1, y0, topZ),
            Point3D(x1, y1, topZ),
            Point3D(x0, y1, topZ),
          ],
          baseColor: topCapColor,
        ));
      } else {
        final x0 = cx - halfThick;
        final x1 = cx + halfThick;
        final y0 = cy - openLen / 2;
        final y1 = cy + openLen / 2;

        faces.add(Face3D(
          vertices: [
            Point3D(x0, y0, lintelZ),
            Point3D(x0, y1, lintelZ),
            Point3D(x0, y1, topZ),
            Point3D(x0, y0, topZ),
          ],
          baseColor: wallColor,
        ));
        faces.add(Face3D(
          vertices: [
            Point3D(x1, y1, lintelZ),
            Point3D(x1, y0, lintelZ),
            Point3D(x1, y0, topZ),
            Point3D(x1, y1, topZ),
          ],
          baseColor: wallColor,
        ));
        faces.add(Face3D(
          vertices: [
            Point3D(x0, y0, topZ),
            Point3D(x1, y0, topZ),
            Point3D(x1, y1, topZ),
            Point3D(x0, y1, topZ),
          ],
          baseColor: topCapColor,
        ));
      }
    }

    // 2. Antepecho inferior en ventanas (de piso a 0.90m)
    if (!isDoor) {
      if (isHoriz) {
        final x0 = cx - openLen / 2;
        final x1 = cx + openLen / 2;
        final y0 = cy - halfThick;
        final y1 = cy + halfThick;

        faces.add(Face3D(
          vertices: [
            Point3D(x0, y0, elevationZ),
            Point3D(x1, y0, elevationZ),
            Point3D(x1, y0, sillZ),
            Point3D(x0, y0, sillZ),
          ],
          baseColor: wallColor,
        ));
        faces.add(Face3D(
          vertices: [
            Point3D(x1, y1, elevationZ),
            Point3D(x0, y1, elevationZ),
            Point3D(x0, y1, sillZ),
            Point3D(x1, y1, sillZ),
          ],
          baseColor: wallColor,
        ));
      } else {
        final x0 = cx - halfThick;
        final x1 = cx + halfThick;
        final y0 = cy - openLen / 2;
        final y1 = cy + openLen / 2;

        faces.add(Face3D(
          vertices: [
            Point3D(x0, y0, elevationZ),
            Point3D(x0, y1, elevationZ),
            Point3D(x0, y1, sillZ),
            Point3D(x0, y0, sillZ),
          ],
          baseColor: wallColor,
        ));
        faces.add(Face3D(
          vertices: [
            Point3D(x1, y1, elevationZ),
            Point3D(x1, y0, elevationZ),
            Point3D(x1, y0, sillZ),
            Point3D(x1, y1, sillZ),
          ],
          baseColor: wallColor,
        ));
      }
    }

    // 3. Hoja de carpintería (panel de madera o vidrio de ventana)
    final panelColor = isDoor
        ? const Color(0xFF8D6E63) // Madera cálida
        : const Color(0xFF4FC3F7).withValues(alpha: 0.65); // Vidrio traslúcido

    if (isHoriz) {
      final x0 = cx - openLen / 2;
      final x1 = cx + openLen / 2;
      faces.add(Face3D(
        vertices: [
          Point3D(x0, cy, sillZ),
          Point3D(x1, cy, sillZ),
          Point3D(x1, cy, lintelZ),
          Point3D(x0, cy, lintelZ),
        ],
        baseColor: panelColor,
        label: mod.name,
      ));
    } else {
      final y0 = cy - openLen / 2;
      final y1 = cy + openLen / 2;
      faces.add(Face3D(
        vertices: [
          Point3D(cx, y0, sillZ),
          Point3D(cx, y1, sillZ),
          Point3D(cx, y1, lintelZ),
          Point3D(cx, y0, lintelZ),
        ],
        baseColor: panelColor,
        label: mod.name,
      ));
    }
  }

  /// Construye una escalera 3D con peldaños ascendentes
  static void _buildStairs3D(
    List<Face3D> faces,
    Module mod,
    double elevationZ,
    double totalHeight,
  ) {
    final bb = mod.geometry.boundingBox;
    const numSteps = 14;
    final stepRise = totalHeight / numSteps;
    final isLongX = bb.width >= bb.height;
    final flipX = mod.flipX;
    final flipY = mod.flipY;

    for (int s = 0; s < numSteps; s++) {
      final stepZ = elevationZ + (s * stepRise);
      double minX, maxX, minY, maxY;

      if (isLongX) {
        final stepW = bb.width / numSteps;
        final stepIndex = flipX ? (numSteps - 1 - s) : s;
        minX = bb.minX + (stepIndex * stepW);
        maxX = minX + stepW;
        minY = bb.minY;
        maxY = bb.maxY;
      } else {
        final stepH = bb.height / numSteps;
        // La escalera asciende desde la puerta (minY) hacia el fondo/interior (maxY)
        final stepIndex = flipY ? (numSteps - 1 - s) : s;
        minX = bb.minX;
        maxX = bb.maxX;
        minY = bb.minY + (stepIndex * stepH);
        maxY = minY + stepH;
      }

      // Huella del peldaño (cara superior horizontal)
      faces.add(
        Face3D(
          vertices: [
            Point3D(minX, minY, stepZ + stepRise),
            Point3D(maxX, minY, stepZ + stepRise),
            Point3D(maxX, maxY, stepZ + stepRise),
            Point3D(minX, maxY, stepZ + stepRise),
          ],
          baseColor: const Color(0xFFB0BEC5),
          label: s == 0 ? mod.name : null,
        ),
      );

      // Contrahuella (cara vertical frontal del peldaño)
      if (isLongX) {
        final faceX = flipX ? maxX : minX;
        faces.add(
          Face3D(
            vertices: [
              Point3D(faceX, minY, stepZ),
              Point3D(faceX, maxY, stepZ),
              Point3D(faceX, maxY, stepZ + stepRise),
              Point3D(faceX, minY, stepZ + stepRise),
            ],
            baseColor: const Color(0xFF78909C),
          ),
        );
      } else {
        final faceY = flipY ? maxY : minY;
        faces.add(
          Face3D(
            vertices: [
              Point3D(minX, faceY, stepZ),
              Point3D(maxX, faceY, stepZ),
              Point3D(maxX, faceY, stepZ + stepRise),
              Point3D(minX, faceY, stepZ + stepRise),
            ],
            baseColor: const Color(0xFF78909C),
          ),
        );
      }
    }
  }

  static Color _getColorForModuleType(String type) {
    switch (type.toUpperCase()) {
      case 'LIVING_ROOM':
      case 'LIVING_DINING':
        return const Color(0xFF37474F).withValues(alpha: 0.8);
      case 'DINING_ROOM':
        return const Color(0xFF455A64).withValues(alpha: 0.8);
      case 'KITCHEN':
      case 'PANTRY':
        return const Color(0xFF00695C).withValues(alpha: 0.7);
      case 'BEDROOM':
      case 'DRESSING_ROOM':
        return const Color(0xFF283593).withValues(alpha: 0.65);
      case 'BATHROOM':
        return const Color(0xFF0277BD).withValues(alpha: 0.7);
      case 'OFFICE':
      case 'STUDIO':
        return const Color(0xFF4E342E).withValues(alpha: 0.7);
      case 'LAUNDRY':
      case 'STORAGE':
        return const Color(0xFF546E7A).withValues(alpha: 0.7);
      case 'CORRIDOR':
      case 'FOYER':
        return const Color(0xFF607D8B).withValues(alpha: 0.75);
      case 'GARAGE':
        return const Color(0xFF424242).withValues(alpha: 0.85);
      case 'TERRACE':
      case 'GARDEN':
      case 'PATIO':
        return const Color(0xFF2E7D32).withValues(alpha: 0.7);
      default:
        return const Color(0xFF37474F).withValues(alpha: 0.6);
    }
  }

  /// Extruye paramétricamente una pieza de mobiliario o artefacto en la maqueta 3D
  static void _buildFurniture3D(List<Face3D> faces, SubModule sub, double elevationZ) {
    final bb = sub.geometry.boundingBox;
    final type = sub.type.toUpperCase();

    double h;
    Color color;
    if (type == 'BED') {
      h = 0.50;
      color = const Color(0xFF90A4AE);
    } else if (type == 'SOFA' || type == 'ARMCHAIR') {
      h = 0.75;
      color = const Color(0xFF546E7A);
    } else if (type == 'DINING_TABLE' || type == 'ROUND_TABLE' || type == 'DESK' || type == 'TABLE') {
      h = 0.75;
      color = const Color(0xFF8D6E63);
    } else if (type == 'COFFEE_TABLE' || type == 'SIDE_TABLE') {
      h = 0.45;
      color = const Color(0xFFA1887F);
    } else if (type == 'CHAIR') {
      h = 0.85;
      color = const Color(0xFF795548);
    } else if (type == 'CABINET') {
      h = 0.90;
      color = const Color(0xFF6D4C41);
    } else if (type == 'BOOKSHELF') {
      h = 1.80;
      color = const Color(0xFF5D4037);
    } else if (type == 'WALL_CABINET') {
      h = 0.60;
      color = const Color(0xFF8D6E63);
    } else if (type == 'SINK_COUNTER' || type == 'KITCHEN_ISLAND' || type == 'VANITY') {
      h = 0.88;
      color = const Color(0xFF78909C);
    } else if (type == 'STOVE') {
      h = 0.88;
      color = const Color(0xFF37474F);
    } else if (type == 'REFRIGERATOR') {
      h = 1.85;
      color = const Color(0xFFB0BEC5);
    } else if (type == 'WARDROBE') {
      h = 2.15;
      color = const Color(0xFF6D4C41);
    } else if (type == 'TOILET') {
      h = 0.45;
      color = const Color(0xFFECEFF1);
    } else if (type == 'SHOWER') {
      h = 0.10;
      color = const Color(0xFFB0BEC5);
    } else if (type == 'BATHTUB') {
      h = 0.50;
      color = const Color(0xFFECEFF1);
    } else if (type == 'WASHING_MACHINE') {
      h = 0.85;
      color = const Color(0xFFCFD8DC);
    } else {
      h = 0.70;
      color = const Color(0xFF78909C);
    }

    final actualH = sub.height ?? h;
    final effectiveSubElevation =
        (type == 'WALL_CABINET' && sub.elevation <= 0.01)
            ? 1.50
            : sub.elevation;

    final minX = bb.minX;
    final maxX = bb.maxX;
    final minY = bb.minY;
    final maxY = bb.maxY;
    final z0 = elevationZ + effectiveSubElevation + 0.02;
    final z1 = z0 + actualH;

    // Cara superior horizontal
    faces.add(Face3D(
      vertices: [
        Point3D(minX, minY, z1),
        Point3D(maxX, minY, z1),
        Point3D(maxX, maxY, z1),
        Point3D(minX, maxY, z1),
      ],
      baseColor: color,
    ));

    // Caras laterales verticales
    faces.add(Face3D(vertices: [Point3D(minX, minY, z0), Point3D(maxX, minY, z0), Point3D(maxX, minY, z1), Point3D(minX, minY, z1)], baseColor: color));
    faces.add(Face3D(vertices: [Point3D(maxX, minY, z0), Point3D(maxX, maxY, z0), Point3D(maxX, maxY, z1), Point3D(maxX, minY, z1)], baseColor: color));
    faces.add(Face3D(vertices: [Point3D(maxX, maxY, z0), Point3D(minX, maxY, z0), Point3D(minX, maxY, z1), Point3D(maxX, maxY, z1)], baseColor: color));
    faces.add(Face3D(vertices: [Point3D(minX, maxY, z0), Point3D(minX, minY, z0), Point3D(minX, minY, z1), Point3D(minX, maxY, z1)], baseColor: color));
  }
}
