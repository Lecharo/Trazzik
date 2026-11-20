import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';

/// Exports a parametric Trazzik [Face3D] scene into a standards-compliant
/// glTF 2.0 (`.gltf`) JSON document with an embedded base64 binary buffer,
/// ready for Blender, SketchUp, Rhino, Three.js, and BIM/AR viewers.
class GltfExporterService {
  /// Generates a complete glTF 2.0 JSON string from [faces].
  ///
  /// Maps Trazzik's coordinates `(x = East, y = South, z = Up)` into glTF's
  /// right-handed Y-up coordinate system `(x, z, +y)` so the plan orientation
  /// matches 2D without East/West or North/South mirror flips, triangulates
  /// convex and concave faces via 2D ear clipping, aligns triangle winding with
  /// outward face normals, separates opaque and translucent (`BLEND`) meshes,
  /// and computes `POSITION` bounds directly from the quantized `Float32List`.
  static String exportToGltfJson({
    required List<Face3D> faces,
    String projectName = 'Trazzik 3D Model',
  }) {
    final exportableFaces = faces
        .where(
          (f) =>
              f.layer != FaceLayer3D.shadow &&
              f.floorIndex >= -1 &&
              f.vertices.length >= 3,
        )
        .toList();

    if (exportableFaces.isEmpty) {
      final emptyGltf = <String, dynamic>{
        'asset': {
          'version': '2.0',
          'generator': 'Trazzik Parametric 3D Engine',
          'extras': {
            'projectName': projectName,
            'faceCount': 0,
            'vertexCount': 0,
            'triangleCount': 0,
          },
        },
        'scene': 0,
        'scenes': [
          {'name': projectName},
        ],
      };
      return const JsonEncoder.withIndent('  ').convert(emptyGltf);
    }

    final positions = <double>[];
    final normals = <double>[];
    final colors = <double>[];
    final opaqueIndices = <int>[];
    final translucentIndices = <int>[];

    int vertexCursor = 0;

    for (final face in exportableFaces) {
      final verts = face.vertices;
      final norm = face.normal;
      // Map (x, y, z) -> glTF right-handed Y-up (x, z, +y)
      final gxNorm = norm.x;
      final gyNorm = norm.z;
      final gzNorm = norm.y;

      final c = face.baseColor;
      final r = c.r.clamp(0.0, 1.0);
      final g = c.g.clamp(0.0, 1.0);
      final b = c.b.clamp(0.0, 1.0);
      final a = c.a.clamp(0.0, 1.0);
      final isTranslucent =
          face.layer == FaceLayer3D.openingPanel || a <= 0.66;
      final outAlpha = isTranslucent ? a : 1.0;

      final gltfVerts = <Point3D>[];
      for (final v in verts) {
        final gx = v.x.isFinite ? v.x : 0.0;
        final gy = v.z.isFinite ? v.z : 0.0;
        final gz = v.y.isFinite ? v.y : 0.0;

        positions.addAll([gx, gy, gz]);
        normals.addAll([gxNorm, gyNorm, gzNorm]);
        colors.addAll([r, g, b, outAlpha]);
        gltfVerts.add(Point3D(gx, gy, gz));
      }

      final tris = _triangulatePolygon(verts, norm);
      final targetIndices =
          isTranslucent ? translucentIndices : opaqueIndices;
      final gNormVec = Point3D(gxNorm, gyNorm, gzNorm);

      for (final tri in tris) {
        var i0 = tri[0];
        var i1 = tri[1];
        var i2 = tri[2];

        // Enforce right-handed CCW winding matching glTF outward normal
        final p0 = gltfVerts[i0];
        final p1 = gltfVerts[i1];
        final p2 = gltfVerts[i2];
        final cross = _cross3(p1 - p0, p2 - p0);
        if (_dot3(cross, gNormVec) < 0) {
          final tmp = i1;
          i1 = i2;
          i2 = tmp;
        }

        targetIndices.add(vertexCursor + i0);
        targetIndices.add(vertexCursor + i1);
        targetIndices.add(vertexCursor + i2);
      }

      vertexCursor += verts.length;
    }

    final posFloats = Float32List.fromList(positions);
    final normFloats = Float32List.fromList(normals);
    final colFloats = Float32List.fromList(colors);
    final opaqueIdxInts = Uint32List.fromList(opaqueIndices);
    final translucentIdxInts = Uint32List.fromList(translucentIndices);

    // Compute exact bounds from quantized Float32 values (Khronos validator strict)
    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = double.negativeInfinity,
        maxY = double.negativeInfinity,
        maxZ = double.negativeInfinity;
    for (int i = 0; i + 2 < posFloats.length; i += 3) {
      final px = posFloats[i];
      final py = posFloats[i + 1];
      final pz = posFloats[i + 2];
      if (px < minX) minX = px;
      if (py < minY) minY = py;
      if (pz < minZ) minZ = pz;
      if (px > maxX) maxX = px;
      if (py > maxY) maxY = py;
      if (pz > maxZ) maxZ = pz;
    }
    if (!minX.isFinite) {
      minX = minY = minZ = 0.0;
      maxX = maxY = maxZ = 0.0;
    }

    final posBytes = posFloats.buffer.asUint8List();
    final normBytes = normFloats.buffer.asUint8List();
    final colBytes = colFloats.buffer.asUint8List();
    final opaqueIdxBytes = opaqueIdxInts.buffer.asUint8List();
    final translucentIdxBytes = translucentIdxInts.buffer.asUint8List();

    final posOffset = 0;
    final normOffset = posBytes.length;
    final colOffset = normOffset + normBytes.length;
    final opaqueIdxOffset = colOffset + colBytes.length;
    final translucentIdxOffset = opaqueIdxOffset + opaqueIdxBytes.length;
    final totalByteLength =
        translucentIdxOffset + translucentIdxBytes.length;

    final combinedBuffer = Uint8List(totalByteLength);
    combinedBuffer.setRange(posOffset, normOffset, posBytes);
    combinedBuffer.setRange(normOffset, colOffset, normBytes);
    combinedBuffer.setRange(colOffset, opaqueIdxOffset, colBytes);
    if (opaqueIdxBytes.isNotEmpty) {
      combinedBuffer.setRange(
        opaqueIdxOffset,
        translucentIdxOffset,
        opaqueIdxBytes,
      );
    }
    if (translucentIdxBytes.isNotEmpty) {
      combinedBuffer.setRange(
        translucentIdxOffset,
        totalByteLength,
        translucentIdxBytes,
      );
    }

    final base64Uri =
        'data:application/octet-stream;base64,${base64Encode(combinedBuffer)}';

    final materials = <Map<String, dynamic>>[
      {
        'name': 'TrazzikArchitecturalPBR',
        'alphaMode': 'OPAQUE',
        'doubleSided': true,
        'pbrMetallicRoughness': {
          'metallicFactor': 0.05,
          'roughnessFactor': 0.78,
        },
      },
    ];

    final bufferViews = <Map<String, dynamic>>[
      {
        'buffer': 0,
        'byteOffset': posOffset,
        'byteLength': posBytes.length,
        'target': 34962, // ARRAY_BUFFER
      },
      {
        'buffer': 0,
        'byteOffset': normOffset,
        'byteLength': normBytes.length,
        'target': 34962,
      },
      {
        'buffer': 0,
        'byteOffset': colOffset,
        'byteLength': colBytes.length,
        'target': 34962,
      },
    ];

    final accessors = <Map<String, dynamic>>[
      {
        'bufferView': 0,
        'componentType': 5126, // FLOAT
        'count': vertexCursor,
        'type': 'VEC3',
        'min': [minX, minY, minZ],
        'max': [maxX, maxY, maxZ],
      },
      {
        'bufferView': 1,
        'componentType': 5126, // FLOAT
        'count': vertexCursor,
        'type': 'VEC3',
      },
      {
        'bufferView': 2,
        'componentType': 5126, // FLOAT
        'count': vertexCursor,
        'type': 'VEC4',
      },
    ];

    final primitives = <Map<String, dynamic>>[];

    if (opaqueIndices.isNotEmpty) {
      final viewIdx = bufferViews.length;
      final accIdx = accessors.length;
      bufferViews.add({
        'buffer': 0,
        'byteOffset': opaqueIdxOffset,
        'byteLength': opaqueIdxBytes.length,
        'target': 34963, // ELEMENT_ARRAY_BUFFER
      });
      accessors.add({
        'bufferView': viewIdx,
        'componentType': 5125, // UNSIGNED_INT
        'count': opaqueIndices.length,
        'type': 'SCALAR',
      });
      primitives.add({
        'attributes': {'POSITION': 0, 'NORMAL': 1, 'COLOR_0': 2},
        'indices': accIdx,
        'material': 0,
        'mode': 4, // TRIANGLES
      });
    }

    if (translucentIndices.isNotEmpty) {
      final glassMatIdx = materials.length;
      materials.add({
        'name': 'TrazzikGlassPBR',
        'alphaMode': 'BLEND',
        'doubleSided': true,
        'pbrMetallicRoughness': {
          'metallicFactor': 0.10,
          'roughnessFactor': 0.12,
        },
      });
      final viewIdx = bufferViews.length;
      final accIdx = accessors.length;
      bufferViews.add({
        'buffer': 0,
        'byteOffset': translucentIdxOffset,
        'byteLength': translucentIdxBytes.length,
        'target': 34963,
      });
      accessors.add({
        'bufferView': viewIdx,
        'componentType': 5125,
        'count': translucentIndices.length,
        'type': 'SCALAR',
      });
      primitives.add({
        'attributes': {'POSITION': 0, 'NORMAL': 1, 'COLOR_0': 2},
        'indices': accIdx,
        'material': glassMatIdx,
        'mode': 4,
      });
    }

    final totalTris = (opaqueIndices.length + translucentIndices.length) ~/ 3;

    final gltf = <String, dynamic>{
      'asset': {
        'version': '2.0',
        'generator': 'Trazzik Parametric 3D Engine',
        'extras': {
          'projectName': projectName,
          'faceCount': exportableFaces.length,
          'vertexCount': vertexCursor,
          'triangleCount': totalTris,
        },
      },
      'scene': 0,
      'scenes': [
        {
          'name': projectName,
          'nodes': [0],
        },
      ],
      'nodes': [
        {
          'name': projectName,
          'mesh': 0,
        },
      ],
      'materials': materials,
      'meshes': [
        {
          'name': '$projectName Mesh',
          'primitives': primitives,
        },
      ],
      'buffers': [
        {
          'uri': base64Uri,
          'byteLength': totalByteLength,
        },
      ],
      'bufferViews': bufferViews,
      'accessors': accessors,
    };

    return const JsonEncoder.withIndent('  ').convert(gltf);
  }

  /// Ear-clipping triangulation for arbitrary simple (convex or concave) 3D planar polygons.
  static List<List<int>> _triangulatePolygon(
    List<Point3D> verts,
    Point3D normal,
  ) {
    final n = verts.length;
    if (n == 3) return const [[0, 1, 2]];
    if (n < 3) return const [];

    // Orthonormal 2D basis in the plane perpendicular to normal
    final normLen = math.sqrt(
      normal.x * normal.x + normal.y * normal.y + normal.z * normal.z,
    );
    final unitN = normLen > 1e-9
        ? Point3D(normal.x / normLen, normal.y / normLen, normal.z / normLen)
        : const Point3D(0, 0, 1);

    final ref = unitN.x.abs() < 0.9
        ? const Point3D(1, 0, 0)
        : const Point3D(0, 1, 0);
    final uRaw = _cross3(ref, unitN);
    final uLen = math.sqrt(uRaw.x * uRaw.x + uRaw.y * uRaw.y + uRaw.z * uRaw.z);
    if (uLen < 1e-9) return _fanFallback(n);
    final u = Point3D(uRaw.x / uLen, uRaw.y / uLen, uRaw.z / uLen);
    final v = _cross3(unitN, u);

    final origin = verts.first;
    final pts2d = <(double x, double y)>[];
    for (final p in verts) {
      final rel = p - origin;
      pts2d.add((_dot3(rel, u), _dot3(rel, v)));
    }

    double signedArea2 = 0;
    for (int i = 0; i < n; i++) {
      final a = pts2d[i];
      final b = pts2d[(i + 1) % n];
      signedArea2 += a.$1 * b.$2 - b.$1 * a.$2;
    }

    final remaining = signedArea2 >= 0
        ? List<int>.generate(n, (i) => i)
        : List<int>.generate(n, (i) => n - 1 - i);

    final tris = <List<int>>[];
    int guard = 0;
    final maxSteps = n * n * 2;

    while (remaining.length > 3 && guard++ < maxSteps) {
      var clipped = false;
      final m = remaining.length;
      for (int i = 0; i < m; i++) {
        final iPrev = remaining[(i - 1 + m) % m];
        final iCurr = remaining[i];
        final iNext = remaining[(i + 1) % m];

        final a = pts2d[iPrev];
        final b = pts2d[iCurr];
        final c = pts2d[iNext];

        final cross = (b.$1 - a.$1) * (c.$2 - a.$2) -
            (b.$2 - a.$2) * (c.$1 - a.$1);
        if (cross <= 1e-9) continue; // Reflex or collinear

        var containsPoint = false;
        for (int j = 0; j < m; j++) {
          final idx = remaining[j];
          if (idx == iPrev || idx == iCurr || idx == iNext) continue;
          if (_pointInTriangle2d(pts2d[idx], a, b, c)) {
            containsPoint = true;
            break;
          }
        }
        if (containsPoint) continue;

        tris.add([iPrev, iCurr, iNext]);
        remaining.removeAt(i);
        clipped = true;
        break;
      }

      if (!clipped) break;
    }

    if (remaining.length == 3) {
      tris.add([remaining[0], remaining[1], remaining[2]]);
    } else if (remaining.length > 3) {
      // Degenerate self-intersecting fallback for remaining tail
      for (int i = 1; i < remaining.length - 1; i++) {
        tris.add([remaining[0], remaining[i], remaining[i + 1]]);
      }
    }

    return tris.isNotEmpty ? tris : _fanFallback(n);
  }

  static List<List<int>> _fanFallback(int n) {
    return [
      for (int i = 1; i < n - 1; i++) [0, i, i + 1],
    ];
  }

  static bool _pointInTriangle2d(
    (double x, double y) p,
    (double x, double y) a,
    (double x, double y) b,
    (double x, double y) c,
  ) {
    double edge((double x, double y) p0, (double x, double y) p1) {
      return (p1.$1 - p0.$1) * (p.$2 - p0.$2) -
          (p1.$2 - p0.$2) * (p.$1 - p0.$1);
    }

    const eps = -1e-9;
    return edge(a, b) >= eps && edge(b, c) >= eps && edge(c, a) >= eps;
  }

  static Point3D _cross3(Point3D a, Point3D b) {
    return Point3D(
      a.y * b.z - a.z * b.y,
      a.z * b.x - a.x * b.z,
      a.x * b.y - a.y * b.x,
    );
  }

  static double _dot3(Point3D a, Point3D b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;
}
