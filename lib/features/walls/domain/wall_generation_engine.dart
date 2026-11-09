import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

/// Pure domain engine that generates perimeter and partition walls from room
/// modules, merging collinear segments, leaving open transitions between
/// contiguous social spaces, and cutting openings (doors, windows, gates).
class WallGenerationEngine {
  static bool isOpenSocialModule(Module m) {
    final t = m.moduleType.toUpperCase();
    final n = m.name.toUpperCase();
    return t == 'LIVING_ROOM' ||
        t == 'DINING_ROOM' ||
        t == 'LIVING_DINING' ||
        t == 'STUDIO' ||
        t == 'STUDY' ||
        t == 'CORRIDOR' ||
        t == 'HALLWAY' ||
        t == 'FOYER' ||
        t == 'TERRACE' ||
        t == 'BALCONY' ||
        t == 'GALLERY' ||
        t == 'STAIRS' ||
        n.contains('ESCALERA') ||
        n.contains('SALA') ||
        n.contains('COMEDOR') ||
        n.contains('ESTUDIO') ||
        n.contains('PASILLO') ||
        n.contains('HALL') ||
        n.contains('ZAGUAN') ||
        n.contains('ZAGUÁN') ||
        n.contains('VESTIBULO') ||
        n.contains('VESTÍBULO');
  }

  static List<List<Point2D>> cutSegmentAtOpenings(
    Point2D p1,
    Point2D p2,
    List<Module> openings,
  ) {
    final len = p1.distanceTo(p2);
    if (len < 0.20) return [];
    final ux = (p2.x - p1.x) / len;
    final uy = (p2.y - p1.y) / len;

    for (final opening in openings) {
      final obb = opening.geometry.boundingBox;
      final cx = obb.minX + obb.width / 2;
      final cy = obb.minY + obb.height / 2;

      final crossDist = ((cx - p1.x) * uy - (cy - p1.y) * ux).abs();
      if (crossDist <= 0.60) {
        final t = (cx - p1.x) * ux + (cy - p1.y) * uy;
        final openDim = math.max(obb.width, obb.height);
        final half = openDim / 2;

        if (t >= -0.20 && t <= len + 0.20) {
          final t1 = math.max(0.0, t - half);
          final t2 = math.min(len, t + half);

          final pieces = <List<Point2D>>[];
          if (t1 > 0.15) {
            pieces.add([p1, Point2D(p1.x + ux * t1, p1.y + uy * t1)]);
          }
          if (len - t2 > 0.15) {
            pieces.add([Point2D(p1.x + ux * t2, p1.y + uy * t2), p2]);
          }
          return pieces;
        }
      }
    }
    return [
      [p1, p2]
    ];
  }

  static bool isPergolaCarport(Module m) {
    final lowerName = m.name.toLowerCase();
    return m.moduleType.toUpperCase().contains('GARAGE') &&
        (lowerName.contains('semicubierto') || lowerName.contains('pérgola'));
  }

  static List<List<double>> _mergeCollinearIntervals(
    List<List<double>> intervals,
  ) {
    intervals.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<double>>[];
    for (final interval in intervals) {
      if (merged.isEmpty) {
        merged.add(List<double>.from(interval));
      } else {
        final last = merged.last;
        if (interval[0] <= last[1] + 0.05) {
          last[1] = math.max(last[1], interval[1]);
        } else {
          merged.add(List<double>.from(interval));
        }
      }
    }
    return merged;
  }

  /// Generates all perimeter and interior walls for [floor].
  static List<Wall> generateWallsForFloor(
    Floor floor, {
    double defaultThickness = 0.15,
  }) {
    final modules = floor.modules
        .where((m) => !m.isOpening && !isPergolaCarport(m))
        .toList();
    if (modules.isEmpty) return const [];

    final openings = floor.modules.where((m) => m.isOpening).toList();
    final createdWalls = <Wall>[];

    // 1. Recolectar segmentos perimetrales de los recintos
    // Omitiendo automáticamente divisorios interiores entre ambientes sociales abiertos contiguos
    final rawSegments = <List<Point2D>>[];
    for (final mod in modules) {
      final isModOpen = isOpenSocialModule(mod);
      final vertices = mod.geometry.vertices;
      final count = vertices.length;
      final expandedModBox = mod.geometry.boundingBox.inflate(0.15);
      final candidateNeighbors = isModOpen
          ? modules
              .where(
                (other) =>
                    other.id != mod.id &&
                    expandedModBox.overlaps(other.geometry.boundingBox),
              )
              .toList(growable: false)
          : const <Module>[];

      for (int i = 0; i < count; i++) {
        final p1 = vertices[i];
        final p2 = vertices[(i + 1) % count];
        final len = p1.distanceTo(p2);
        if (len < 0.20) continue;

        if (!isModOpen) {
          rawSegments.add([p1, p2]);
          continue;
        }

        final ux = (p2.x - p1.x) / len;
        final uy = (p2.y - p1.y) / len;
        final nx = -uy;
        final ny = ux;

        const sliceStep = 0.10;
        final steps = (len / sliceStep).floor();
        double currentStart = 0.0;
        bool inWallSlice = false;

        for (int s = 0; s < steps; s++) {
          final tMid = (s + 0.5) * sliceStep;
          final midX = p1.x + ux * tMid;
          final midY = p1.y + uy * tMid;

          final pA = Point2D(midX + nx * 0.05, midY + ny * 0.05);
          final pB = Point2D(midX - nx * 0.05, midY - ny * 0.05);
          final isAInside = mod.geometry.containsPoint(pA);
          final testOutside = isAInside ? pB : pA;

          Module? neighbor;
          for (final other in candidateNeighbors) {
            if (other.geometry.boundingBox.containsPoint(testOutside) &&
                other.geometry.containsPoint(testOutside)) {
              neighbor = other;
              break;
            }
          }

          final shouldHaveWall = neighbor == null || !isOpenSocialModule(neighbor);

          if (shouldHaveWall) {
            if (!inWallSlice) {
              inWallSlice = true;
              currentStart = s * sliceStep;
            }
          } else {
            if (inWallSlice) {
              inWallSlice = false;
              final segP1 = Point2D(p1.x + ux * currentStart, p1.y + uy * currentStart);
              final segP2 = Point2D(p1.x + ux * (s * sliceStep), p1.y + uy * (s * sliceStep));
              if (segP1.distanceTo(segP2) >= 0.15) {
                rawSegments.add([segP1, segP2]);
              }
            }
          }
        }

        if (inWallSlice) {
          final segP1 = Point2D(p1.x + ux * currentStart, p1.y + uy * currentStart);
          final segP2 = Point2D(p1.x + ux * len, p1.y + uy * len);
          if (segP1.distanceTo(segP2) >= 0.15) {
            rawSegments.add([segP1, segP2]);
          }
        }
      }
    }

    // 2. Fusionar segmentos colineales que se tocan o superponen
    final unifiedSegments = <List<Point2D>>[];
    final horizGroups = <int, List<List<double>>>{};
    final vertGroups = <int, List<List<double>>>{};

    for (final seg in rawSegments) {
      final p1 = seg[0];
      final p2 = seg[1];
      final isHoriz = (p1.y - p2.y).abs() <= 0.05;
      final isVert = (p1.x - p2.x).abs() <= 0.05;

      if (isHoriz) {
        final avgY = (p1.y + p2.y) / 2;
        final key = (avgY * 20).round();
        final minX = math.min(p1.x, p2.x);
        final maxX = math.max(p1.x, p2.x);
        horizGroups.putIfAbsent(key, () => []).add([minX, maxX, avgY]);
      } else if (isVert) {
        final avgX = (p1.x + p2.x) / 2;
        final key = (avgX * 20).round();
        final minY = math.min(p1.y, p2.y);
        final maxY = math.max(p1.y, p2.y);
        vertGroups.putIfAbsent(key, () => []).add([minY, maxY, avgX]);
      } else {
        unifiedSegments.add(seg);
      }
    }

    for (final entry in horizGroups.entries) {
      for (final m in _mergeCollinearIntervals(entry.value)) {
        unifiedSegments.add([Point2D(m[0], m[2]), Point2D(m[1], m[2])]);
      }
    }

    for (final entry in vertGroups.entries) {
      for (final m in _mergeCollinearIntervals(entry.value)) {
        unifiedSegments.add([Point2D(m[2], m[0]), Point2D(m[2], m[1])]);
      }
    }

    // 3. Descontar vanos de aberturas y crear muros
    const uuid = Uuid();
    for (final seg in unifiedSegments) {
      final wallPieces = cutSegmentAtOpenings(seg[0], seg[1], openings);
      for (final piece in wallPieces) {
        createdWalls.add(
          Wall(
            id: uuid.v4(),
            floorId: floor.id,
            startPoint: piece[0],
            endPoint: piece[1],
            thickness: defaultThickness,
            height: floor.heightMeters,
            status: ElementStatus.isNew,
          ),
        );
      }
    }

    return createdWalls;
  }

  /// Generates non-duplicate boundary walls around a single target module.
  static List<Wall> generateAdditionalWallsForModule({
    required Floor floor,
    required String moduleId,
    double defaultThickness = 0.15,
  }) {
    final mod = floor.modules.firstWhere((m) => m.id == moduleId);
    final openings = floor.modules.where((m) => m.isOpening).toList();
    final vertices = mod.geometry.vertices;
    final count = vertices.length;
    final newWalls = <Wall>[];
    const uuid = Uuid();

    for (int i = 0; i < count; i++) {
      final p1 = vertices[i];
      final p2 = vertices[(i + 1) % count];
      if (p1.distanceTo(p2) < 0.20) continue;

      final pieces = cutSegmentAtOpenings(p1, p2, openings);
      for (final piece in pieces) {
        final exists = floor.walls.any((w) =>
            (w.startPoint.distanceTo(piece[0]) < 0.15 &&
                w.endPoint.distanceTo(piece[1]) < 0.15) ||
            (w.startPoint.distanceTo(piece[1]) < 0.15 &&
                w.endPoint.distanceTo(piece[0]) < 0.15));

        if (!exists) {
          newWalls.add(
            Wall(
              id: uuid.v4(),
              floorId: floor.id,
              startPoint: piece[0],
              endPoint: piece[1],
              thickness: defaultThickness,
              height: floor.heightMeters,
              status: ElementStatus.isNew,
            ),
          );
        }
      }
    }

    return newWalls;
  }
}
