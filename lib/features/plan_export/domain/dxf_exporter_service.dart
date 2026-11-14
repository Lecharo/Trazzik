import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/walls/domain/wall_generation_engine.dart';

/// Standards-compliant AutoCAD R12 (`AC1009`) ASCII `.dxf` vector CAD exporter.
///
/// Exports metric architectural geometry (lot boundary, structural walls by
/// remodeling status, room polygons, doors/windows/stairs, interior furniture,
/// and centered room area/dimension callouts) organized into AIA-standard CAD
/// layers, including an R12 `LTYPE` table for `CONTINUOUS` linetypes.
class DxfExporterService {
  static const String layerLot = 'A-LOT';
  static const String layerWallExist = 'A-WALL-EXIST';
  static const String layerWallDemo = 'A-WALL-DEMO';
  static const String layerWallNew = 'A-WALL-NEW';
  static const String layerRoom = 'A-ROOM';
  static const String layerRoomDemo = 'A-ROOM-DEMO';
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
    final maxY = (lotBb.maxY.isFinite && lotBb.maxY > 0) ? lotBb.maxY : 15.0;

    // Flip Y so +Y points North in AutoCAD/Revit/ArchiCAD/Rayon
    double cadY(double screenY) =>
        screenY.isFinite ? (maxY - screenY) : 0.0;

    // 1. HEADER SECTION (strict R12 AC1009)
    sb
      ..writeln('0')
      ..writeln('SECTION')
      ..writeln('2')
      ..writeln('HEADER')
      ..writeln('9')
      ..writeln('\$ACADVER')
      ..writeln('1')
      ..writeln('AC1009')
      ..writeln('0')
      ..writeln('ENDSEC');

    // 2. TABLES SECTION (LTYPE CONTINUOUS + AIA CAD Layers)
    final layers = <(String name, int aciColor)>[
      (layerLot, 8),
      (layerWallExist, 7),
      (layerWallDemo, 1),
      (layerWallNew, 5),
      (layerRoom, 3),
      (layerRoomDemo, 1),
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
      ..writeln('LTYPE')
      ..writeln('70')
      ..writeln('1')
      ..writeln('0')
      ..writeln('LTYPE')
      ..writeln('2')
      ..writeln('CONTINUOUS')
      ..writeln('70')
      ..writeln('0')
      ..writeln('3')
      ..writeln('Solid line')
      ..writeln('72')
      ..writeln('65')
      ..writeln('73')
      ..writeln('0')
      ..writeln('40')
      ..writeln('0.0')
      ..writeln('0')
      ..writeln('ENDTAB')
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

    // 3b. Walls (auto-generate via WallGenerationEngine when floor has modules but empty walls)
    final wallsToExport = (floor.walls.isEmpty && floor.modules.isNotEmpty)
        ? WallGenerationEngine.generateWallsForFloor(floor)
        : floor.walls;
    for (final wall in wallsToExport) {
      final wallLayer = switch (wall.status) {
        ElementStatus.toDemolish => layerWallDemo,
        ElementStatus.isNew => layerWallNew,
        _ => layerWallExist,
      };
      _writeClosedPolygonLines(sb, wall.footprint.vertices, wallLayer, cadY);
    }

    // 3c. Modules (Rooms, Openings, Stairs) + SubModules (Furniture) + Centered Text Tags
    for (final mod in floor.modules) {
      final verts = mod.geometry.vertices;
      if (verts.length < 3) continue;

      final isOpeningOrStair = mod.isOpening || mod.isStairs;
      final isDemolish = mod.status == ElementStatus.toDemolish;
      final modLayer = isOpeningOrStair
          ? layerOpening
          : (isDemolish ? layerRoomDemo : layerRoom);
      _writeClosedPolygonLines(sb, verts, modLayer, cadY);

      if (!isOpeningOrStair) {
        final bb = mod.geometry.boundingBox;
        final cx = bb.minX + bb.width / 2.0;
        final cy = cadY(bb.minY + bb.height / 2.0);
        final cleanName = _sanitizeAscii(mod.name.toUpperCase());
        final dimText = _sanitizeAscii(
          '${bb.width.toStringAsFixed(2)}x${bb.height.toStringAsFixed(2)}m (${mod.area.toStringAsFixed(2)}m2)',
        );
        final textLayer = isDemolish ? layerRoomDemo : layerAnnotation;

        _writeTextEntity(
          sb,
          x: cx,
          y: cy + 0.14,
          height: 0.18,
          text: cleanName,
          layer: textLayer,
        );
        _writeTextEntity(
          sb,
          x: cx,
          y: cy - 0.14,
          height: 0.13,
          text: dimText,
          layer: textLayer,
        );
      }

      for (final sub in mod.subModules) {
        if (sub.geometry.vertices.length >= 3) {
          final subLayer = sub.status == ElementStatus.toDemolish || isDemolish
              ? layerRoomDemo
              : layerFurniture;
          _writeClosedPolygonLines(
            sb,
            sub.geometry.vertices,
            subLayer,
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
        ..writeln(_safeCoord(a.x))
        ..writeln('20')
        ..writeln(_safeCoord(cadY(a.y)))
        ..writeln('30')
        ..writeln('0.0')
        ..writeln('11')
        ..writeln(_safeCoord(b.x))
        ..writeln('21')
        ..writeln(_safeCoord(cadY(b.y)))
        ..writeln('31')
        ..writeln('0.0');
    }
  }

  static String _safeCoord(double v) =>
      v.isFinite ? v.toStringAsFixed(4) : '0.0000';

  static void _writeTextEntity(
    StringBuffer sb, {
    required double x,
    required double y,
    required double height,
    required String text,
    required String layer,
  }) {
    final safeX = _safeCoord(x);
    final safeY = _safeCoord(y);
    final safeH = height.isFinite ? height.toStringAsFixed(3) : '0.150';
    final safeText = _sanitizeAscii(text);
    sb
      ..writeln('0')
      ..writeln('TEXT')
      ..writeln('8')
      ..writeln(layer)
      ..writeln('10')
      ..writeln(safeX)
      ..writeln('20')
      ..writeln(safeY)
      ..writeln('30')
      ..writeln('0.0')
      ..writeln('40')
      ..writeln(safeH)
      ..writeln('1')
      ..writeln(safeText)
      ..writeln('72')
      ..writeln('1') // Center horizontal justification
      ..writeln('11')
      ..writeln(safeX)
      ..writeln('21')
      ..writeln(safeY)
      ..writeln('31')
      ..writeln('0.0')
      ..writeln('73')
      ..writeln('2'); // Middle vertical justification
  }

  static String _sanitizeAscii(String input) {
    final mapped = input
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
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll('²', '2')
        .replaceAll('³', '3')
        .replaceAll('°', 'deg')
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    final cleaned = StringBuffer();
    for (final code in mapped.codeUnits) {
      if (code >= 0x20 && code <= 0x7E) {
        cleaned.writeCharCode(code);
      } else {
        cleaned.write('?');
      }
    }
    return cleaned.toString().trim();
  }
}
