import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

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
      for (final mod in floor.modules) {
        final t = mod.moduleType.toUpperCase();
        if (t.contains('DOOR') || t.contains('WINDOW') || t.contains('GATE')) {
          _buildOpening3D(faces, mod, elevationZ, floorHeight);
        } else if (t.contains('STAIR')) {
          _buildStairs3D(faces, mod, elevationZ, floorHeight);
        } else {
          _buildRoomFloor(faces, mod, elevationZ);
        }

        // 3.1 Mobiliario y artefactos interiores extruidos en 3D
        for (final sub in mod.subModules) {
          _buildFurniture3D(faces, sub, elevationZ);
        }
      }

      // 4. Muros y tabiques
      if (floor.walls.isNotEmpty) {
        // Muros explícitos definidos en el piso
        for (final wall in floor.walls) {
          _buildWall3D(faces, wall, elevationZ, overrideHeight: math.min(wall.height, wallHeight));
        }
      } else {
        // Generación paramétrica automática de muros y tabiques a partir de los recintos
        _buildAutoWallsFromModules(faces, floor, elevationZ, wallHeight);
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

  /// Construye el pavimento coloreado de un recinto
  static void _buildRoomFloor(List<Face3D> faces, Module mod, double elevationZ) {
    final verts = mod.geometry.vertices;
    if (verts.length < 3) return;

    final floorColor = _getColorForModuleType(mod.moduleType);

    faces.add(
      Face3D(
        vertices: verts.map((p) => Point3D(p.x, p.y, elevationZ + 0.01)).toList(),
        baseColor: floorColor,
        label: mod.name,
      ),
    );
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
  }) {
    final len = p1.distanceTo(p2);
    if (len < 0.10) return;

    final halfThick = thickness / 2;
    final ux = (p2.x - p1.x) / len;
    final uy = (p2.y - p1.y) / len;
    final nx = -uy * halfThick;
    final ny = ux * halfThick;

    final b0 = Point3D(p1.x + nx, p1.y + ny, elevationZ);
    final b1 = Point3D(p2.x + nx, p2.y + ny, elevationZ);
    final b2 = Point3D(p2.x - nx, p2.y - ny, elevationZ);
    final b3 = Point3D(p1.x - nx, p1.y - ny, elevationZ);

    final topZ = elevationZ + height;
    final t0 = Point3D(b0.x, b0.y, topZ);
    final t1 = Point3D(b1.x, b1.y, topZ);
    final t2 = Point3D(b2.x, b2.y, topZ);
    final t3 = Point3D(b3.x, b3.y, topZ);

    faces.add(Face3D(vertices: [b0, b1, t1, t0], baseColor: wallColor, label: label));
    faces.add(Face3D(vertices: [b2, b3, t3, t2], baseColor: wallColor));
    faces.add(Face3D(vertices: [b3, b0, t0, t3], baseColor: wallColor));
    faces.add(Face3D(vertices: [b1, b2, t2, t1], baseColor: wallColor));
    faces.add(Face3D(vertices: [t0, t1, t2, t3], baseColor: topCapColor));
  }

  /// Extruye un muro 3D completo con sus 6 caras
  static void _buildWall3D(
    List<Face3D> faces,
    Wall wall,
    double elevationZ, {
    double? overrideHeight,
  }) {
    _buildWallSegment3D(
      faces,
      p1: wall.startPoint,
      p2: wall.endPoint,
      elevationZ: elevationZ,
      height: overrideHeight ?? wall.height,
      thickness: wall.thickness,
      label: 'Muro',
    );
  }

  /// Genera automáticamente muros y tabiques 3D a partir de los límites de los recintos
  static void _buildAutoWallsFromModules(
    List<Face3D> faces,
    Floor floor,
    double elevationZ,
    double wallHeight,
  ) {
    final roomModules = floor.modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return !t.contains('DOOR') &&
          !t.contains('WINDOW') &&
          !t.contains('GATE') &&
          !t.contains('STAIR') &&
          !t.contains('GARDEN') &&
          !t.contains('PATIO') &&
          !t.contains('TERRACE');
    }).toList();

    if (roomModules.isEmpty) return;

    // A. Garajes semicubiertos (Pérgola con columnas y vigas)
    final pergolaGarages = roomModules.where((m) =>
        m.moduleType.toUpperCase().contains('GARAGE') &&
        (m.name.toLowerCase().contains('semicubierto') ||
            m.name.toLowerCase().contains('pérgola'))).toList();

    for (final garage in pergolaGarages) {
      _buildPergolaCarport3D(faces, garage, elevationZ);
    }

    // B. Recintos estándar
    final standardRooms = roomModules.where((m) => !pergolaGarages.contains(m)).toList();
    if (standardRooms.isEmpty) return;

    // Recolectar intervalos horizontales (por Y) y verticales (por X)
    final horizSegments = <double, List<math.Point<double>>>{};
    final vertSegments = <double, List<math.Point<double>>>{};

    for (final mod in standardRooms) {
      final bb = mod.geometry.boundingBox;
      final x1 = (bb.minX * 100).round() / 100.0;
      final x2 = (bb.maxX * 100).round() / 100.0;
      final y1 = (bb.minY * 100).round() / 100.0;
      final y2 = (bb.maxY * 100).round() / 100.0;

      horizSegments.putIfAbsent(y1, () => []).add(math.Point(x1, x2));
      horizSegments.putIfAbsent(y2, () => []).add(math.Point(x1, x2));

      vertSegments.putIfAbsent(x1, () => []).add(math.Point(y1, y2));
      vertSegments.putIfAbsent(x2, () => []).add(math.Point(y1, y2));
    }

    // Muros Horizontales
    horizSegments.forEach((y, intervals) {
      final points = <double>{};
      for (final inv in intervals) {
        points.add(inv.x);
        points.add(inv.y);
      }
      final sortedPts = points.toList()..sort();
      for (int i = 0; i < sortedPts.length - 1; i++) {
        final sx = sortedPts[i];
        final ex = sortedPts[i + 1];
        if (ex - sx < 0.20) continue;

        final mid = (sx + ex) / 2.0;
        int count = 0;
        for (final inv in intervals) {
          if (inv.x <= mid && mid <= inv.y) count++;
        }

        if (count == 0) continue;
        final isExterior = count == 1;
        final thickness = isExterior ? 0.18 : 0.12;
        final wallLen = ex - sx;

        if (!isExterior && wallLen >= 2.40) {
          final solidLen = wallLen - 0.85;
          _buildWallSegment3D(
            faces,
            p1: Point2D(sx, y),
            p2: Point2D(sx + solidLen, y),
            elevationZ: elevationZ,
            height: wallHeight,
            thickness: thickness,
            label: 'Tabique',
          );
        } else {
          _buildWallSegment3D(
            faces,
            p1: Point2D(sx, y),
            p2: Point2D(ex, y),
            elevationZ: elevationZ,
            height: wallHeight,
            thickness: thickness,
            label: isExterior ? 'Muro Exterior' : 'Tabique',
          );
        }
      }
    });

    // Muros Verticales
    vertSegments.forEach((x, intervals) {
      final points = <double>{};
      for (final inv in intervals) {
        points.add(inv.x);
        points.add(inv.y);
      }
      final sortedPts = points.toList()..sort();
      for (int i = 0; i < sortedPts.length - 1; i++) {
        final sy = sortedPts[i];
        final ey = sortedPts[i + 1];
        if (ey - sy < 0.20) continue;

        final mid = (sy + ey) / 2.0;
        int count = 0;
        for (final inv in intervals) {
          if (inv.x <= mid && mid <= inv.y) count++;
        }

        if (count == 0) continue;
        final isExterior = count == 1;
        final thickness = isExterior ? 0.18 : 0.12;
        final wallLen = ey - sy;

        if (!isExterior && wallLen >= 2.40) {
          final solidLen = wallLen - 0.85;
          _buildWallSegment3D(
            faces,
            p1: Point2D(x, sy),
            p2: Point2D(x, sy + solidLen),
            elevationZ: elevationZ,
            height: wallHeight,
            thickness: thickness,
            label: 'Tabique',
          );
        } else {
          _buildWallSegment3D(
            faces,
            p1: Point2D(x, sy),
            p2: Point2D(x, ey),
            elevationZ: elevationZ,
            height: wallHeight,
            thickness: thickness,
            label: isExterior ? 'Muro Exterior' : 'Tabique',
          );
        }
      }
    });
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

    final sillZ = elevationZ + (isDoor ? 0.0 : 0.90); // Antepecho
    final lintelZ = elevationZ + 2.10; // Dintel inferior a 2.10m
    final topZ = elevationZ + floorHeight; // Coronación superior de losa

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
        : const Color(0xFF4FC3F7).withOpacity(0.65); // Vidrio traslúcido

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
        return const Color(0xFF37474F).withOpacity(0.8);
      case 'DINING_ROOM':
        return const Color(0xFF455A64).withOpacity(0.8);
      case 'KITCHEN':
        return const Color(0xFF00695C).withOpacity(0.7);
      case 'BEDROOM':
        return const Color(0xFF283593).withOpacity(0.65);
      case 'BATHROOM':
        return const Color(0xFF0277BD).withOpacity(0.7);
      case 'OFFICE':
        return const Color(0xFF4E342E).withOpacity(0.7);
      case 'LAUNDRY':
        return const Color(0xFF546E7A).withOpacity(0.7);
      case 'GARAGE':
        return const Color(0xFF424242).withOpacity(0.85);
      case 'TERRACE':
      case 'GARDEN':
        return const Color(0xFF2E7D32).withOpacity(0.7);
      default:
        return const Color(0xFF37474F).withOpacity(0.6);
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

    final minX = bb.minX;
    final maxX = bb.maxX;
    final minY = bb.minY;
    final maxY = bb.maxY;
    final z0 = elevationZ + sub.elevation + 0.02;
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
