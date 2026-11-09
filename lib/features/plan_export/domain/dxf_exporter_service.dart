import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';

/// Standards-compliant AutoCAD R12/2000 ASCII `.dxf` vector CAD exporter.
///
/// Exports metric architectural geometry (lot boundary, structural walls by
/// remodeling status, room polygons, doors/windows/stairs, interior furniture,
/// and room area/dimension callouts) organized into AIA-standard CAD layers.
class DxfExporterService {
  static const String layerLot = 'A-LOT';
  static const String layerWallExist = 'A-WALL-EXIST';
  static const String layerWallDemo = 'A-WALL-DEMO';
  static const String layerWallNew = 'A-WALL-NEW';
  static const String layerRoom = 'A-ROOM';
  static const String layerOpening = 'A-OPENING';
  static const String layerFurniture = 'A-FURN';
  static const String layerAnnotation = 'A-ANNO-TEXT';

  /// Generates a complete ASCII `.dxf` document for [floor] and [lot].
  static String exportFloorToDxf({
    required Floor floor,
    required Lot lot,
    String projectName = 'Trazzik Architectural Plan',
  }) {
    final sb = StringBuffer();
    final lotBb = lot.boundary.boundingBox;
    final maxY = lotBb.maxY > 0 ? lotBb.maxY : 15.0;

    // Flip Y so +Y points North in AutoCAD/Revit/ArchiCAD/Rayon
    double cadY(double screenY) => maxY - screenY;

    // 1. HEADER SECTION (Metric units: 6 = Meters)
    sb
      ..writeln('0')
      ..writeln('SECTION')
      ..writeln('2')
      ..writeln('HEADER')
      ..writeln('9')
      ..writeln('\$ACADVER')
      ..writeln('1')
      ..writeln('AC1009')
      ..writeln('9')
      ..writeln('\$INSUNITS')
      ..writeln('70')
      ..writeln('6')
      ..writeln('0')
      ..writeln('ENDSEC');

    // 2. TABLES SECTION (AIA CAD Layers + AutoCAD Color Index)
    final layers = <(String name, int aciColor)>[
      (layerLot, 8),
      (layerWallExist, 7),
      (layerWallDemo, 1),
      (layerWallNew, 5),
      (layerRoom, 3),
      (layerOpening, 4),
      (layerFurniture, 6),
      (layerAnnotation, 2),
    ];

    sb
      ..writeln('0')
      ..writeln('SECTION')
      ..writeln('2')
      ..writeln('TABLES')
      ..writeln('0')
      ..writeln('TABLE')
      ..writeln('2')
      ..writeln('LAYER')
      ..writeln('70')
      ..writeln('${layers.length}');

    for (final (name, color) in layers) {
      sb
        ..writeln('0')
        ..writeln('LAYER')
        ..writeln('2')
        ..writeln(name)
        ..writeln('70')
        ..writeln('0')
        ..writeln('62')
        ..writeln('$color')
        ..writeln('6')
        ..writeln('CONTINUOUS');
    }

    sb
      ..writeln('0')
      ..writeln('ENDTAB')
      ..writeln('0')
      ..writeln('ENDSEC');

    // 3. ENTITIES SECTION
    sb
      ..writeln('0')
      ..writeln('SECTION')
      ..writeln('2')
      ..writeln('ENTITIES');

    // 3a. Lot boundary polygon
    _writeClosedPolygonLines(sb, lot.boundary.vertices, layerLot, cadY);

    // 3b. Walls by remodeling status (Preserved / Demolish / New)
    for (final wall in floor.walls) {
      final wallLayer = switch (wall.status) {
        ElementStatus.toDemolish => layerWallDemo,
        ElementStatus.isNew => layerWallNew,
        _ => layerWallExist,
      };
      _writeClosedPolygonLines(sb, wall.footprint.vertices, wallLayer, cadY);
    }

    // 3c. Modules (Rooms, Openings, Stairs) + SubModules (Furniture) + Room Text Tags
    for (final mod in floor.modules) {
      final verts = mod.geometry.vertices;
      if (verts.length < 3) continue;

      final isOpeningOrStair = mod.isOpening || mod.isStairs;
      final modLayer = isOpeningOrStair ? layerOpening : layerRoom;
      _writeClosedPolygonLines(sb, verts, modLayer, cadY);

      if (!isOpeningOrStair) {
        final bb = mod.geometry.boundingBox;
        final cx = bb.minX + bb.width / 2.0;
        final cy = cadY(bb.minY + bb.height / 2.0);
        final cleanName = _sanitizeAscii(mod.name.toUpperCase());
        final dimText =
            '${bb.width.toStringAsFixed(2)}x${bb.height.toStringAsFixed(2)}m (${mod.area.toStringAsFixed(2)}m2)';

        _writeTextEntity(
          sb,
          x: cx,
          y: cy + 0.12,
          height: 0.18,
          text: cleanName,
          layer: layerAnnotation,
        );
        _writeTextEntity(
          sb,
          x: cx,
          y: cy - 0.14,
          height: 0.13,
          text: dimText,
          layer: layerAnnotation,
        );
      }

      for (final sub in mod.subModules) {
        if (sub.geometry.vertices.length >= 3) {
          _writeClosedPolygonLines(
            sb,
            sub.geometry.vertices,
            layerFurniture,
            cadY,
          );
        }
      }
    }

    sb
      ..writeln('0')
      ..writeln('ENDSEC')
      ..writeln('0')
      ..writeln('EOF');

    return sb.toString();
  }

  static void _writeClosedPolygonLines(
    StringBuffer sb,
    List<Point2D> vertices,
    String layer,
    double Function(double) cadY,
  ) {
    if (vertices.length < 2) return;
    for (int i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      sb
        ..writeln('0')
        ..writeln('LINE')
        ..writeln('8')
        ..writeln(layer)
        ..writeln('10')
        ..writeln(a.x.toStringAsFixed(4))
        ..writeln('20')
        ..writeln(cadY(a.y).toStringAsFixed(4))
        ..writeln('30')
        ..writeln('0.0')
        ..writeln('11')
        ..writeln(b.x.toStringAsFixed(4))
        ..writeln('21')
        ..writeln(cadY(b.y).toStringAsFixed(4))
        ..writeln('31')
        ..writeln('0.0');
    }
  }

  static void _writeTextEntity(
    StringBuffer sb, {
    required double x,
    required double y,
    required double height,
    required String text,
    required String layer,
  }) {
    sb
      ..writeln('0')
      ..writeln('TEXT')
      ..writeln('8')
      ..writeln(layer)
      ..writeln('10')
      ..writeln(x.toStringAsFixed(4))
      ..writeln('20')
      ..writeln(y.toStringAsFixed(4))
      ..writeln('30')
      ..writeln('0.0')
      ..writeln('40')
      ..writeln(height.toStringAsFixed(3))
      ..writeln('1')
      ..writeln(text);
  }

  static String _sanitizeAscii(String input) {
    return input
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll('Ü', 'U')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }
}
