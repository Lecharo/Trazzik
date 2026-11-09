import 'dart:convert';
import 'dart:typed_data';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';

/// Exports a parametric Trazzik [Face3D] scene into a standards-compliant
/// glTF 2.0 (`.gltf`) JSON document with an embedded base64 binary buffer,
/// ready for Blender, SketchUp, Rhino, Three.js, and BIM/AR viewers.
class GltfExporterService {
  /// Generates a complete glTF 2.0 JSON string from [faces].
  ///
  /// Converts Trazzik's Z-up metric coordinates `(x, y, z)` into glTF's
  /// standard Y-up right-handed coordinate system `(x, z, -y)` and packs
  /// `POSITION` (`VEC3`), `NORMAL` (`VEC3`), `COLOR_0` (`VEC4`), and
  /// `INDICES` (`SCALAR` `UNSIGNED_INT`) into a single buffer.
  static String exportToGltfJson({
    required List<Face3D> faces,
    String projectName = 'Trazzik 3D Model',
  }) {
    final exportableFaces = faces
        .where((f) => f.layer != FaceLayer3D.shadow && f.vertices.length >= 3)
        .toList();

    final positions = <double>[];
    final normals = <double>[];
    final colors = <double>[];
    final indices = <int>[];

    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = double.negativeInfinity,
        maxY = double.negativeInfinity,
        maxZ = double.negativeInfinity;

    int vertexCursor = 0;

    for (final face in exportableFaces) {
      final verts = face.vertices;
      final norm = face.normal;
      // Convert Z-up (x, y, z) -> glTF Y-up (x, z, -y)
      final gxNorm = norm.x;
      final gyNorm = norm.z;
      final gzNorm = -norm.y;

      final c = face.baseColor;
      final r = c.r.clamp(0.0, 1.0);
      final g = c.g.clamp(0.0, 1.0);
      final b = c.b.clamp(0.0, 1.0);
      final a = c.a.clamp(0.0, 1.0);

      for (final v in verts) {
        final gx = v.x;
        final gy = v.z;
        final gz = -v.y;

        positions.addAll([gx, gy, gz]);
        normals.addAll([gxNorm, gyNorm, gzNorm]);
        colors.addAll([r, g, b, a]);

        if (gx < minX) minX = gx;
        if (gy < minY) minY = gy;
        if (gz < minZ) minZ = gz;
        if (gx > maxX) maxX = gx;
        if (gy > maxY) maxY = gy;
        if (gz > maxZ) maxZ = gz;
      }

      // Fan triangulation from vertex 0 of the face
      for (int i = 1; i < verts.length - 1; i++) {
        indices.add(vertexCursor);
        indices.add(vertexCursor + i);
        indices.add(vertexCursor + i + 1);
      }

      vertexCursor += verts.length;
    }

    if (vertexCursor == 0) {
      minX = minY = minZ = 0.0;
      maxX = maxY = maxZ = 0.0;
    }

    final posFloats = Float32List.fromList(positions);
    final normFloats = Float32List.fromList(normals);
    final colFloats = Float32List.fromList(colors);
    final idxInts = Uint32List.fromList(indices);

    final posBytes = posFloats.buffer.asUint8List();
    final normBytes = normFloats.buffer.asUint8List();
    final colBytes = colFloats.buffer.asUint8List();
    final idxBytes = idxInts.buffer.asUint8List();

    final posOffset = 0;
    final normOffset = posBytes.length;
    final colOffset = normOffset + normBytes.length;
    final idxOffset = colOffset + colBytes.length;
    final totalByteLength = idxOffset + idxBytes.length;

    final combinedBuffer = Uint8List(totalByteLength);
    combinedBuffer.setRange(posOffset, normOffset, posBytes);
    combinedBuffer.setRange(normOffset, colOffset, normBytes);
    combinedBuffer.setRange(colOffset, idxOffset, colBytes);
    combinedBuffer.setRange(idxOffset, totalByteLength, idxBytes);

    final base64Uri =
        'data:application/octet-stream;base64,${base64Encode(combinedBuffer)}';

    final gltf = <String, dynamic>{
      'asset': {
        'version': '2.0',
        'generator': 'Trazzik Parametric 3D Engine',
        'extras': {
          'projectName': projectName,
          'faceCount': exportableFaces.length,
          'vertexCount': vertexCursor,
          'triangleCount': indices.length ~/ 3,
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
      'materials': [
        {
          'name': 'TrazzikArchitecturalPBR',
          'doubleSided': true,
          'pbrMetallicRoughness': {
            'metallicFactor': 0.05,
            'roughnessFactor': 0.78,
          },
        },
      ],
      'meshes': [
        {
          'name': '$projectName Mesh',
          'primitives': [
            {
              'attributes': {
                'POSITION': 0,
                'NORMAL': 1,
                'COLOR_0': 2,
              },
              'indices': 3,
              'material': 0,
              'mode': 4, // TRIANGLES
            },
          ],
        },
      ],
      'buffers': [
        {
          'uri': base64Uri,
          'byteLength': totalByteLength,
        },
      ],
      'bufferViews': [
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
        {
          'buffer': 0,
          'byteOffset': idxOffset,
          'byteLength': idxBytes.length,
          'target': 34963, // ELEMENT_ARRAY_BUFFER
        },
      ],
      'accessors': [
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
        {
          'bufferView': 3,
          'componentType': 5125, // UNSIGNED_INT
          'count': indices.length,
          'type': 'SCALAR',
        },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(gltf);
  }
}
