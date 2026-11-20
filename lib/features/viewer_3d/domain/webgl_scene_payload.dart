import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';

/// Physical PBR material parameters resolved for a 3D architectural surface.
class PbrMaterialSpec {
  final String key;
  final String colorHex;
  final String patternColorHex;
  final String pattern;
  final double alpha;
  final double roughness;
  final double metalness;
  final double bumpScale;
  final double transmission;
  final bool isTwoSided;

  const PbrMaterialSpec({
    required this.key,
    required this.colorHex,
    required this.patternColorHex,
    required this.pattern,
    required this.alpha,
    required this.roughness,
    required this.metalness,
    required this.bumpScale,
    required this.transmission,
    required this.isTwoSided,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'color': colorHex,
        'patternColor': patternColorHex,
        'pattern': pattern,
        'alpha': alpha,
        'roughness': roughness,
        'metalness': metalness,
        'bumpScale': bumpScale,
        'transmission': transmission,
        'doubleSided': isTwoSided,
      };
}

/// Pure-Dart serializer converting Trazzik [Face3D] scenes into a compact,
/// GPU-ready JSON payload for the local Three.js WebGL PBR renderer.
///
/// Coordinate conversion from Trazzik `(X: width, Y: depth, Z: height)` to
/// Three.js right-handed `(X_gl = X, Y_gl = Z, Z_gl = Y)` reverses triangle
/// winding `(i0, i2, i1)` so every outward Trazzik normal remains outward in WebGL.
class WebGlScenePayloadBuilder {
  static String colorToHex(Color c) {
    final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  /// Resolves physically plausible PBR parameters from [Face3D] pattern and layer.
  static PbrMaterialSpec resolveMaterialSpec(Face3D face) {
    final colorHex = colorToHex(face.baseColor);
    final patColorHex = colorToHex(face.patternColor ?? face.baseColor);
    final alpha = face.baseColor.a.clamp(0.05, 1.0);
    final isGlass = face.layer == FaceLayer3D.openingPanel || alpha < 0.72;

    if (isGlass) {
      return PbrMaterialSpec(
        key: 'glass_${colorHex}_${(alpha * 100).round()}',
        colorHex: colorHex,
        patternColorHex: patColorHex,
        pattern: 'glass',
        alpha: alpha.clamp(0.18, 0.55),
        roughness: 0.08,
        metalness: 0.08,
        bumpScale: 0.0,
        transmission: 0.72,
        isTwoSided: true,
      );
    }

    final pat = face.pattern;
    String patName = 'solid';
    double roughness = 0.78;
    double metalness = 0.04;
    double bumpScale = 0.015;

    switch (pat) {
      case FinishPatternType.woodPlanks:
        patName = 'woodPlanks';
        roughness = 0.42;
        metalness = 0.03;
        bumpScale = 0.018;
        break;
      case FinishPatternType.porcelainGrid:
        patName = 'porcelainGrid';
        roughness = 0.24;
        metalness = 0.05;
        bumpScale = 0.012;
        break;
      case FinishPatternType.marbleVeins:
        patName = 'marbleVeins';
        roughness = 0.16;
        metalness = 0.06;
        bumpScale = 0.008;
        break;
      case FinishPatternType.polishedConcrete:
        patName = 'polishedConcrete';
        roughness = 0.48;
        metalness = 0.04;
        bumpScale = 0.018;
        break;
      case FinishPatternType.hydraulicTile:
        patName = 'hydraulicTile';
        roughness = 0.30;
        metalness = 0.05;
        bumpScale = 0.014;
        break;
      case FinishPatternType.outdoorDeck:
        patName = 'outdoorDeck';
        roughness = 0.65;
        metalness = 0.02;
        bumpScale = 0.026;
        break;
      case FinishPatternType.naturalGrass:
        patName = 'naturalGrass';
        roughness = 0.92;
        metalness = 0.0;
        bumpScale = 0.045;
        break;
      case FinishPatternType.exposedBrick:
        patName = 'exposedBrick';
        roughness = 0.86;
        metalness = 0.02;
        bumpScale = 0.042;
        break;
      case FinishPatternType.travertineStone:
        patName = 'travertineStone';
        roughness = 0.46;
        metalness = 0.03;
        bumpScale = 0.022;
        break;
      case FinishPatternType.paintedWall:
        patName = 'paintedWall';
        roughness = 0.84;
        metalness = 0.01;
        bumpScale = 0.010;
        break;
      case null:
        if (face.layer == FaceLayer3D.terrain) {
          patName = 'naturalGrass';
          roughness = 0.90;
          metalness = 0.0;
          bumpScale = 0.035;
        } else if (face.isWallFace) {
          patName = 'paintedWall';
          roughness = 0.82;
          metalness = 0.02;
          bumpScale = 0.012;
        }
        break;
    }

    final key =
        '${patName}_${colorHex}_${patColorHex}_${face.isTwoSided ? 1 : 0}';
    return PbrMaterialSpec(
      key: key,
      colorHex: colorHex,
      patternColorHex: patColorHex,
      pattern: patName,
      alpha: alpha,
      roughness: roughness,
      metalness: metalness,
      bumpScale: bumpScale,
      transmission: 0.0,
      isTwoSided: face.isTwoSided || face.layer == FaceLayer3D.floorFinish,
    );
  }

  /// Builds the full serializable JSON scene payload for Three.js WebGL PBR.
  static Map<String, dynamic> buildPayload({
    required List<Face3D> faces,
    required SunPreset3D sunPreset,
    double explodedFactor = 0.0,
    SectionCutAxis3D sectionCutAxis = SectionCutAxis3D.none,
    double sectionCutRatio = 0.65,
    String? selectedModuleId,
    bool highlightWallSelection = false,
    bool isPerspective = true,
    bool showLabels = true,
    double orientationDegrees = 0.0,
  }) {
    final materialsMap = <String, PbrMaterialSpec>{};
    final batches = <String, _MeshBatch>{};
    final interiorLights = <Map<String, dynamic>>[];
    final roomLabels = <Map<String, dynamic>>[];
    final floorBaseZ = <int, double>{};

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;
    double minZ = double.infinity;
    double maxZ = -double.infinity;

    for (final face in faces) {
      // Skip 2D fake shadow polygons and decorative apron (WebGL generates real GPU shadows + studio floor)
      if (face.layer == FaceLayer3D.shadow || face.floorIndex < -1) continue;
      if (face.vertices.length < 3) continue;

      final spec = resolveMaterialSpec(face);
      materialsMap.putIfAbsent(spec.key, () => spec);

      final batchKey =
          '${face.floorIndex}|${face.moduleId ?? ''}|${face.floorId ?? ''}|${face.isWallFace ? 1 : 0}|${spec.key}';
      final batch = batches.putIfAbsent(
        batchKey,
        () => _MeshBatch(
          floorIndex: face.floorIndex,
          moduleId: face.moduleId,
          floorId: face.floorId,
          isWallFace: face.isWallFace,
          materialKey: spec.key,
          castShadow: face.layer != FaceLayer3D.terrain &&
              face.layer != FaceLayer3D.floorFinish,
          receiveShadow: true,
        ),
      );

      // Compute outward face normal in Trazzik space
      final n = _computeNormal(face.vertices);
      final absNx = n.x.abs();
      final absNy = n.y.abs();
      final absNz = n.z.abs();

      // Track world bounds (excluding huge terrain planes from tight building framing when possible)
      double sumX = 0, sumY = 0, sumZ = 0;
      for (final v in face.vertices) {
        sumX += v.x;
        sumY += v.y;
        sumZ += v.z;
        if (face.floorIndex >= 0) {
          if (v.x < minX) minX = v.x;
          if (v.x > maxX) maxX = v.x;
          if (v.y < minY) minY = v.y;
          if (v.y > maxY) maxY = v.y;
          if (v.z < minZ) minZ = v.z;
          if (v.z > maxZ) maxZ = v.z;
        }
      }

      if (face.floorIndex >= 0 && face.layer == FaceLayer3D.floorFinish) {
        final avgZ = sumZ / face.vertices.length;
        floorBaseZ.putIfAbsent(face.floorIndex, () => avgZ);
      }

      if (face.isRoomLabel && face.label != null && face.label!.isNotEmpty) {
        final cx = sumX / face.vertices.length;
        final cy = sumY / face.vertices.length;
        final cz = sumZ / face.vertices.length;
        interiorLights.add(<String, dynamic>{
          'x': _r3(cx),
          'y': _r3(cz + 2.05), // Three.js Y = height
          'z': _r3(cy), // Three.js Z = depth
          'floorIndex': face.floorIndex,
        });
        roomLabels.add(<String, dynamic>{
          'text': face.label,
          'sub': face.roomDimensionsLabel ?? '',
          'x': _r3(cx),
          'y': _r3(cz + 0.35),
          'z': _r3(cy),
          'floorIndex': face.floorIndex,
          'moduleId': face.moduleId,
        });
      }

      final triIndices = _triangulateFace(face.vertices, n);
      final baseVertexOffset = batch.positions.length ~/ 3;

      // Three.js normal from Trazzik normal: (nx, nz, ny)
      final glNx = _r4(n.x);
      final glNy = _r4(n.z);
      final glNz = _r4(n.y);

      for (final v in face.vertices) {
        // Position in Three.js coordinates: (X, Z, Y)
        batch.positions.add(_r3(v.x));
        batch.positions.add(_r3(v.z));
        batch.positions.add(_r3(v.y));

        batch.normals.add(glNx);
        batch.normals.add(glNy);
        batch.normals.add(glNz);

        // World-space metric UV projection (1 UV unit = 1 meter)
        final double u;
        final double tv;
        if (absNz >= absNx && absNz >= absNy) {
          u = v.x;
          tv = v.y;
        } else if (absNx >= absNy) {
          u = v.y;
          tv = v.z;
        } else {
          u = v.x;
          tv = v.z;
        }
        batch.uvs.add(_r3(u));
        batch.uvs.add(_r3(tv));
      }

      // Reverse winding (i0, i2, i1) to preserve outward normals under (x,z,y) reflection
      for (int i = 0; i + 2 < triIndices.length; i += 3) {
        batch.indices.add(baseVertexOffset + triIndices[i]);
        batch.indices.add(baseVertexOffset + triIndices[i + 2]);
        batch.indices.add(baseVertexOffset + triIndices[i + 1]);
      }
    }

    if (!minX.isFinite) {
      minX = 0;
      maxX = 10;
      minY = 0;
      maxY = 10;
      minZ = 0;
      maxZ = 3;
    }

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final centerZ = (minZ + maxZ) / 2;
    final spanX = math.max(2.0, maxX - minX);
    final spanY = math.max(2.0, maxY - minY);
    final spanZ = math.max(2.0, maxZ - minZ);
    final radius = math.sqrt(spanX * spanX + spanY * spanY + spanZ * spanZ) / 2;

    final sortedFloors = floorBaseZ.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return <String, dynamic>{
      'version': 1,
      'bounds': <String, dynamic>{
        'minX': _r3(minX),
        'maxX': _r3(maxX),
        'minY': _r3(minZ), // Three.js Y = elevation
        'maxY': _r3(maxZ),
        'minZ': _r3(minY), // Three.js Z = depth
        'maxZ': _r3(maxY),
        'centerX': _r3(centerX),
        'centerY': _r3(centerZ),
        'centerZ': _r3(centerY),
        'radius': _r3(radius),
      },
      'floors': sortedFloors
          .map(
            (e) => <String, dynamic>{
              'floorIndex': e.key,
              'elevation': _r3(e.value),
            },
          )
          .toList(),
      'settings': <String, dynamic>{
        'sunPreset': sunPreset.name,
        'explodedFactor': _r3(explodedFactor),
        'sectionCutAxis': sectionCutAxis.name,
        'sectionCutRatio': _r3(sectionCutRatio),
        'selectedModuleId': selectedModuleId,
        'highlightWallSelection': highlightWallSelection,
        'isPerspective': isPerspective,
        'showLabels': showLabels,
        'orientationDegrees': _r3(orientationDegrees),
      },
      'materials': materialsMap.values.map((m) => m.toJson()).toList(),
      'meshes': batches.values.map((b) => b.toJson()).toList(),
      'interiorLights': interiorLights,
      'roomLabels': roomLabels,
    };
  }

  static double _r3(double v) => (v * 1000).round() / 1000.0;
  static double _r4(double v) => (v * 10000).round() / 10000.0;

  static Point3D _computeNormal(List<Point3D> verts) {
    // Newell's method handles concave polygons reliably
    double nx = 0, ny = 0, nz = 0;
    final len = verts.length;
    for (int i = 0; i < len; i++) {
      final curr = verts[i];
      final next = verts[(i + 1) % len];
      nx += (curr.y - next.y) * (curr.z + next.z);
      ny += (curr.z - next.z) * (curr.x + next.x);
      nz += (curr.x - next.x) * (curr.y + next.y);
    }
    final mag = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (mag < 1e-8) return const Point3D(0, 0, 1);
    return Point3D(nx / mag, ny / mag, nz / mag);
  }

  /// Triangulates convex or concave planar polygons via ear-clipping projected
  /// onto the dominant coordinate plane.
  static List<int> _triangulateFace(List<Point3D> verts, Point3D normal) {
    final n = verts.length;
    if (n < 3) return const <int>[];
    if (n == 3) return const <int>[0, 1, 2];
    if (n == 4) return const <int>[0, 1, 2, 0, 2, 3];

    // Project onto 2D plane perpendicular to dominant normal component
    final absNx = normal.x.abs();
    final absNy = normal.y.abs();
    final absNz = normal.z.abs();

    final pts = <({double x, double y})>[];
    for (final v in verts) {
      if (absNz >= absNx && absNz >= absNy) {
        pts.add((x: v.x, y: v.y));
      } else if (absNx >= absNy) {
        pts.add((x: v.y, y: v.z));
      } else {
        pts.add((x: v.x, y: v.z));
      }
    }

    // Compute signed area to determine winding
    double area2 = 0;
    for (int i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % n];
      area2 += a.x * b.y - b.x * a.y;
    }
    final isCcw = area2 >= 0;

    final indices = List<int>.generate(n, (i) => i);
    final result = <int>[];
    int guard = n * n;

    while (indices.length > 3 && guard-- > 0) {
      bool clipped = false;
      final m = indices.length;
      for (int i = 0; i < m; i++) {
        final prevIdx = indices[(i - 1 + m) % m];
        final currIdx = indices[i];
        final nextIdx = indices[(i + 1) % m];
        final a = pts[prevIdx];
        final b = pts[currIdx];
        final c = pts[nextIdx];

        final cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
        if (isCcw ? cross <= 1e-8 : cross >= -1e-8) continue;

        bool hasPointInside = false;
        for (int j = 0; j < m; j++) {
          final testIdx = indices[j];
          if (testIdx == prevIdx || testIdx == currIdx || testIdx == nextIdx) {
            continue;
          }
          if (_pointInTriangle(pts[testIdx], a, b, c)) {
            hasPointInside = true;
            break;
          }
        }
        if (hasPointInside) continue;

        result.addAll([prevIdx, currIdx, nextIdx]);
        indices.removeAt(i);
        clipped = true;
        break;
      }
      if (!clipped) break;
    }

    if (indices.length == 3) {
      result.addAll(indices);
    } else if (result.isEmpty) {
      // Fallback triangle fan for degenerate polygons
      for (int i = 1; i + 1 < n; i++) {
        result.addAll([0, i, i + 1]);
      }
    }
    return result;
  }

  static bool _pointInTriangle(
    ({double x, double y}) p,
    ({double x, double y}) a,
    ({double x, double y}) b,
    ({double x, double y}) c,
  ) {
    double sign(({double x, double y}) p1, ({double x, double y}) p2, ({double x, double y}) p3) =>
        (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
    final d1 = sign(p, a, b);
    final d2 = sign(p, b, c);
    final d3 = sign(p, c, a);
    final hasNeg = (d1 < -1e-7) || (d2 < -1e-7) || (d3 < -1e-7);
    final hasPos = (d1 > 1e-7) || (d2 > 1e-7) || (d3 > 1e-7);
    return !(hasNeg && hasPos);
  }
}

class _MeshBatch {
  final int floorIndex;
  final String? moduleId;
  final String? floorId;
  final bool isWallFace;
  final String materialKey;
  final bool castShadow;
  final bool receiveShadow;
  final List<double> positions = <double>[];
  final List<double> normals = <double>[];
  final List<double> uvs = <double>[];
  final List<int> indices = <int>[];

  _MeshBatch({
    required this.floorIndex,
    required this.moduleId,
    required this.floorId,
    required this.isWallFace,
    required this.materialKey,
    required this.castShadow,
    required this.receiveShadow,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'floorIndex': floorIndex,
        'moduleId': moduleId,
        'floorId': floorId,
        'isWallFace': isWallFace,
        'materialKey': materialKey,
        'castShadow': castShadow,
        'receiveShadow': receiveShadow,
        'positions': positions,
        'normals': normals,
        'uvs': uvs,
        'indices': indices,
      };
}
