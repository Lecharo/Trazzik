import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/cad/cad_symbol_drawer.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/zoning_assistant/domain/zoning_engine.dart';

/// Interactive edge/corner resize handles for a selected rectangular room.
enum ResizeHandle2D {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

/// Visual smart-snap alignment guide line in floor meters.
class SnapGuide2D {
  final bool isVertical;
  final double coordinate;
  final double start;
  final double end;

  const SnapGuide2D({
    required this.isVertical,
    required this.coordinate,
    required this.start,
    required this.end,
  });

  @override
  bool operator ==(Object other) =>
      other is SnapGuide2D &&
      other.isVertical == isVertical &&
      (other.coordinate - coordinate).abs() < 1e-6 &&
      (other.start - start).abs() < 1e-6 &&
      (other.end - end).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(
        isVertical,
        (coordinate * 1000).round(),
        (start * 1000).round(),
        (end * 1000).round(),
      );
}

/// Snapped origin and active visual alignment guides computed during a drag.
class SmartSnapResult {
  final double x;
  final double y;
  final List<SnapGuide2D> guides;

  const SmartSnapResult({
    required this.x,
    required this.y,
    required this.guides,
  });
}

/// Computes the 8 interactive resize handle positions (in meters) for an
/// unlocked rectangular room module. Returns an empty map for locked, opening,
/// or non-rectangular modules.
Map<ResizeHandle2D, Point2D> computeModuleResizeHandles(Module module) {
  if (module.isLocked || module.isOpening || module.geometry.vertices.length != 4) {
    return const <ResizeHandle2D, Point2D>{};
  }
  final bb = module.geometry.boundingBox;
  final midX = bb.minX + bb.width / 2;
  final midY = bb.minY + bb.height / 2;
  return <ResizeHandle2D, Point2D>{
    ResizeHandle2D.topLeft: Point2D(bb.minX, bb.minY),
    ResizeHandle2D.top: Point2D(midX, bb.minY),
    ResizeHandle2D.topRight: Point2D(bb.maxX, bb.minY),
    ResizeHandle2D.right: Point2D(bb.maxX, midY),
    ResizeHandle2D.bottomRight: Point2D(bb.maxX, bb.maxY),
    ResizeHandle2D.bottom: Point2D(midX, bb.maxY),
    ResizeHandle2D.bottomLeft: Point2D(bb.minX, bb.maxY),
    ResizeHandle2D.left: Point2D(bb.minX, midY),
  };
}

/// Computes magnetic smart-snap alignment for a dragged room box against
/// sibling rooms, floor walls, and the floor boundary.
SmartSnapResult computeSmartSnapGuides({
  required double candidateX,
  required double candidateY,
  required double width,
  required double height,
  required Floor floor,
  required String excludeModuleId,
  double thresholdMeters = 0.12,
}) {
  final refX = <({double coord, double minSpan, double maxSpan})>[];
  final refY = <({double coord, double minSpan, double maxSpan})>[];

  final floorBb = floor.boundary.boundingBox;
  refX.add((coord: floorBb.minX, minSpan: floorBb.minY, maxSpan: floorBb.maxY));
  refX.add((coord: floorBb.maxX, minSpan: floorBb.minY, maxSpan: floorBb.maxY));
  refY.add((coord: floorBb.minY, minSpan: floorBb.minX, maxSpan: floorBb.maxX));
  refY.add((coord: floorBb.maxY, minSpan: floorBb.minX, maxSpan: floorBb.maxX));

  for (final other in floor.modules) {
    if (other.id == excludeModuleId || other.isOpening) continue;
    final obb = other.geometry.boundingBox;
    refX.add((coord: obb.minX, minSpan: obb.minY, maxSpan: obb.maxY));
    refX.add((coord: obb.maxX, minSpan: obb.minY, maxSpan: obb.maxY));
    refX.add((coord: obb.minX + obb.width / 2, minSpan: obb.minY, maxSpan: obb.maxY));

    refY.add((coord: obb.minY, minSpan: obb.minX, maxSpan: obb.maxX));
    refY.add((coord: obb.maxY, minSpan: obb.minX, maxSpan: obb.maxX));
    refY.add((coord: obb.minY + obb.height / 2, minSpan: obb.minX, maxSpan: obb.maxX));
  }

  for (final wall in floor.walls) {
    final minWy = math.min(wall.startPoint.y, wall.endPoint.y);
    final maxWy = math.max(wall.startPoint.y, wall.endPoint.y);
    final minWx = math.min(wall.startPoint.x, wall.endPoint.x);
    final maxWx = math.max(wall.startPoint.x, wall.endPoint.x);
    refX.add((coord: wall.startPoint.x, minSpan: minWy, maxSpan: maxWy));
    refX.add((coord: wall.endPoint.x, minSpan: minWy, maxSpan: maxWy));
    refY.add((coord: wall.startPoint.y, minSpan: minWx, maxSpan: maxWx));
    refY.add((coord: wall.endPoint.y, minSpan: minWx, maxSpan: maxWx));
  }

  double snappedX = candidateX;
  double bestDx = thresholdMeters + 1e-6;
  SnapGuide2D? verticalGuide;
  final xAnchors = <double>[candidateX, candidateX + width, candidateX + width / 2];

  for (final anchor in xAnchors) {
    for (final ref in refX) {
      final delta = ref.coord - anchor;
      final absDelta = delta.abs();
      if (absDelta <= thresholdMeters && absDelta < bestDx) {
        bestDx = absDelta;
        snappedX = candidateX + delta;
        verticalGuide = SnapGuide2D(
          isVertical: true,
          coordinate: ref.coord,
          start: math.min(candidateY, ref.minSpan) - 0.35,
          end: math.max(candidateY + height, ref.maxSpan) + 0.35,
        );
      }
    }
  }

  double snappedY = candidateY;
  double bestDy = thresholdMeters + 1e-6;
  SnapGuide2D? horizontalGuide;
  final yAnchors = <double>[candidateY, candidateY + height, candidateY + height / 2];

  for (final anchor in yAnchors) {
    for (final ref in refY) {
      final delta = ref.coord - anchor;
      final absDelta = delta.abs();
      if (absDelta <= thresholdMeters && absDelta < bestDy) {
        bestDy = absDelta;
        snappedY = candidateY + delta;
        horizontalGuide = SnapGuide2D(
          isVertical: false,
          coordinate: ref.coord,
          start: math.min(snappedX, ref.minSpan) - 0.35,
          end: math.max(snappedX + width, ref.maxSpan) + 0.35,
        );
      }
    }
  }

  final guides = <SnapGuide2D>[
    ?verticalGuide,
    ?horizontalGuide,
  ];
  return SmartSnapResult(x: snappedX, y: snappedY, guides: guides);
}

/// Ordered exterior architectural chain dimension breakpoints (in meters)
/// computed along the X and Y axes of a floor plan.
class ExteriorChainDimensions {
  final List<double> xStops;
  final List<double> yStops;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const ExteriorChainDimensions({
    required this.xStops,
    required this.yStops,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  double get totalWidth => math.max(0.0, maxX - minX);
  double get totalDepth => math.max(0.0, maxY - minY);
}

/// Computes clustered exterior chain dimension stops along X and Y from all
/// non-opening modules (excluding demolished ones) and the floor envelope.
ExteriorChainDimensions computeExteriorChainDimensions(
  Floor floor, {
  double mergeToleranceMeters = 0.08,
}) {
  final rawX = <double>[];
  final rawY = <double>[];

  final activeModules = floor.modules
      .where((m) => !m.isOpening && m.status != ElementStatus.toDemolish)
      .toList();

  if (activeModules.isEmpty) {
    final bb = floor.boundary.boundingBox;
    return ExteriorChainDimensions(
      xStops: [bb.minX, bb.maxX],
      yStops: [bb.minY, bb.maxY],
      minX: bb.minX,
      maxX: bb.maxX,
      minY: bb.minY,
      maxY: bb.maxY,
    );
  }

  for (final mod in activeModules) {
    final bb = mod.geometry.boundingBox;
    rawX.add(bb.minX);
    rawX.add(bb.maxX);
    rawY.add(bb.minY);
    rawY.add(bb.maxY);
  }

  List<double> clusterStops(List<double> values) {
    values.sort();
    final clustered = <double>[];
    for (final v in values) {
      if (clustered.isEmpty || (v - clustered.last).abs() > mergeToleranceMeters) {
        clustered.add(v);
      }
    }
    return clustered;
  }

  final xStops = clusterStops(rawX);
  final yStops = clusterStops(rawY);
  return ExteriorChainDimensions(
    xStops: xStops,
    yStops: yStops,
    minX: xStops.first,
    maxX: xStops.last,
    minY: yStops.first,
    maxY: yStops.last,
  );
}

/// Custom painter responsible for rendering the 2D architectural floor plan,
/// grid, zoning bands, walls, spaces, openings, and interior furniture.
class Canvas2DPainter extends CustomPainter {
  final FloorEditorState state;
  final String lang;
  final bool isDarkTheme;
  final String? hoveredModuleId;
  final String? hoveredWallId;
  final ResizeHandle2D? hoveredHandle;
  final ResizeHandle2D? activeHandle;
  final Point2D? cursorMeters;
  final List<SnapGuide2D> snapGuides;

  static final Map<Object, TextPainter> _textPainterCache = <Object, TextPainter>{};

  @visibleForTesting
  static void clearTextCache() {
    for (final tp in _textPainterCache.values) {
      tp.dispose();
    }
    _textPainterCache.clear();
  }

  static TextPainter _getCachedTextPainter(
    Object key,
    TextSpan span, {
    TextAlign textAlign = TextAlign.start,
    double maxWidth = double.infinity,
    int? maxLines,
  }) {
    final existing = _textPainterCache[key];
    if (existing != null) return existing;
    if (_textPainterCache.length >= 384) {
      _textPainterCache.remove(_textPainterCache.keys.first)?.dispose();
    }
    final tp = TextPainter(
      text: span,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    _textPainterCache[key] = tp;
    return tp;
  }

  Canvas2DPainter(
    this.state, {
    this.lang = 'es',
    this.isDarkTheme = true,
    this.hoveredModuleId,
    this.hoveredWallId,
    this.hoveredHandle,
    this.activeHandle,
    this.cursorMeters,
    this.snapGuides = const <SnapGuide2D>[],
  });

  Color get _canvasBg =>
      isDarkTheme ? const Color(0xFF161A22) : const Color(0xFFF8FAFC);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rawZoom = state.zoom;
    final zoom = (rawZoom.isFinite && rawZoom > 0.01) ? rawZoom : 30.0;
    final pan = (state.panOffset.dx.isFinite && state.panOffset.dy.isFinite)
        ? state.panOffset
        : Offset.zero;

    // 1. Theme-aware architectural drafting surface (Dark Blueprint / Light Technical Paper)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _canvasBg,
    );

    canvas.save();
    canvas.translate(pan.dx, pan.dy);

    // 2. Metric grid
    _drawGrid(canvas, size, zoom, pan);

    // 2.5. Calibrated Blueprint Underlay
    if (state.blueprintUnderlay.isEnabled) {
      _drawBlueprintUnderlay(canvas, zoom);
    }

    // 3. Normative Zoning Zones
    _drawZoningZones(canvas, zoom);

    // 3.5. Zoning & Solar Orientation Guide Bands
    if (state.showZoningGuide) {
      _drawZoningGuideBands(canvas, zoom);
    }

    // 4. Lot Boundary (stroke pass; label renders above walls so openings never clip it)
    final lotBoundaryColor =
        isDarkTheme ? const Color(0xFF90A4AE) : const Color(0xFF64748B);
    _drawPolygonBoundary(
      canvas,
      state.lot.boundary,
      zoom,
      Paint()
        ..color = lotBoundaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 5. Floor Boundary (stroke pass)
    final floorBoundaryColor =
        isDarkTheme ? const Color(0xFF64B5F6) : const Color(0xFF0284C7);
    _drawPolygonBoundary(
      canvas,
      state.floor.boundary,
      zoom,
      Paint()
        ..color = floorBoundaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 6. Non-opening Room Modules (floor finishes, furniture & symbols under walls)
    Module? selectedModule;
    for (final module in state.floor.modules) {
      final isSelected = module.id == state.selectedModuleId;
      if (isSelected) selectedModule = module;
      if (!module.isOpening) {
        _drawModuleBase(
          canvas,
          module,
          zoom,
          isSelected: isSelected,
          isHovered: module.id == hoveredModuleId && !isSelected,
        );
      }
    }

    // 6.5. Onion-Skin Ghost Reference of Floor Immediately Below (above floor fills, under active walls)
    if (state.showFloorGhost) {
      final ghostFloor = state.ghostReferenceFloor;
      if (ghostFloor != null) {
        _drawGhostFloorUnderlay(canvas, ghostFloor, zoom);
      }
    }

    // 7. Structural & Partition Walls (with remodeling poché on top of room floors)
    _drawWalls(canvas, zoom);

    // 8. Opening Modules (doors, windows, gates mounted cleanly over walls)
    for (final module in state.floor.modules) {
      if (module.isOpening) {
        final isSelected = module.id == state.selectedModuleId;
        _drawModuleBase(
          canvas,
          module,
          zoom,
          isSelected: isSelected,
          isHovered: module.id == hoveredModuleId && !isSelected,
        );
      }
    }

    // 9. Clean Cached Architectural Room & Opening Labels
    for (final module in state.floor.modules) {
      _drawModuleLabel(
        canvas,
        module,
        zoom,
        isSelected: module.id == state.selectedModuleId,
      );
    }

    // 9.2. Lot & Floor Boundary Header Labels (painted above walls & windows with clean clearance)
    final headerClearancePx = math.max(10.0, 0.14 * zoom);
    _drawBoundaryLabel(
      canvas,
      state.floor.boundary,
      zoom,
      label:
          '${state.floor.name.toUpperCase()} (Max: ${state.floor.maxAllowedArea.toStringAsFixed(0)} m²)',
      color: floorBoundaryColor,
      labelOffsetY: -headerClearancePx - 20.0,
      fontSize: 11.5,
      withBackdrop: true,
    );
    _drawBoundaryLabel(
      canvas,
      state.lot.boundary,
      zoom,
      label: 'LOTE (${state.lot.boundary.area.toStringAsFixed(1)} m²)',
      color: lotBoundaryColor,
      labelOffsetY: -headerClearancePx - 42.0,
      fontSize: 10.5,
      showLotOrientation: true,
    );

    // 9.5. Automatic Exterior Architectural Chain Dimensions (bottom & right perimeter)
    if (state.showPerimeterDimensions && zoom >= 16.0) {
      _drawExteriorChainDimensions(canvas, zoom);
    }

    // 10. Selected Module Architectural 45°-Tick Dimensions & Resize Handles
    if (selectedModule != null) {
      _drawSelectedModuleOverlay(canvas, selectedModule, zoom);
    }

    // 11. Smart Snap Alignment Guides (active during drag)
    if (snapGuides.isNotEmpty) {
      _drawSnapGuides(canvas, zoom);
    }

    // 12. Interactive 2D Laser Tape Measure
    if (state.isLaserMeasureActive &&
        state.laserStart != null &&
        state.laserEnd != null) {
      _drawLaserMeasureOverlay(canvas, zoom);
    }

    // 13. Manual 2D Wall Draft Preview
    if (state.isDrawWallMode &&
        state.draftWallStart != null &&
        state.draftWallEnd != null) {
      _drawDraftWallOverlay(canvas, zoom);
    }

    canvas.restore();

    // 14. Screen-space Fixed Metric Rulers (Top & Left)
    if (size.width >= 120 && size.height >= 120) {
      _drawMetricRulers(canvas, size, zoom, pan);
      // 15. North Compass (positioned below top ruler)
      _drawNorthCompass(canvas, size, state.lot.orientationDegrees);
    }

    // 16. Live Cursor Coordinate Badge (Desktop Web hover)
    if (cursorMeters != null && size.width >= 160 && size.height >= 120) {
      _drawCursorCoordinateBadge(canvas, size, cursorMeters!);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double zoom, Offset pan) {
    // 1. Subdivisión de 10 cm (0.10 m) si el zoom lo amerita
    if (zoom >= 25.0) {
      final cmPaint = Paint()
        ..color = isDarkTheme
            ? const Color(0xFF212735).withValues(alpha: 0.72)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.65)
        ..strokeWidth = 0.5;

      final minX10 = ((-pan.dx) / zoom * 10).floor() - 5;
      final maxX10 = (((size.width - pan.dx) / zoom) * 10).ceil() + 5;
      final minY10 = ((-pan.dy) / zoom * 10).floor() - 5;
      final maxY10 = (((size.height - pan.dy) / zoom) * 10).ceil() + 5;

      for (int i = minX10; i <= maxX10; i++) {
        if (i % 10 == 0) continue; // Omitir múltiplos de metro
        final px = (i / 10.0) * zoom;
        canvas.drawLine(
          Offset(px, (minY10 / 10.0) * zoom),
          Offset(px, (maxY10 / 10.0) * zoom),
          cmPaint,
        );
      }
      for (int j = minY10; j <= maxY10; j++) {
        if (j % 10 == 0) continue;
        final py = (j / 10.0) * zoom;
        canvas.drawLine(
          Offset((minX10 / 10.0) * zoom, py),
          Offset((maxX10 / 10.0) * zoom, py),
          cmPaint,
        );
      }
    }

    // 2. Líneas intermedias cada 50 cm (0.50 m)
    final halfMeterPaint = Paint()
      ..color = isDarkTheme
          ? const Color(0xFF283040)
          : const Color(0xFFCBD5E1).withValues(alpha: 0.55)
      ..strokeWidth = 0.75;

    final minX2 = ((-pan.dx) / zoom * 2).floor() - 2;
    final maxX2 = (((size.width - pan.dx) / zoom) * 2).ceil() + 2;
    final minY2 = ((-pan.dy) / zoom * 2).floor() - 2;
    final maxY2 = (((size.height - pan.dy) / zoom) * 2).ceil() + 2;

    for (int i = minX2; i <= maxX2; i++) {
      if (i % 2 == 0) continue; // Omitir metros completos
      final px = (i / 2.0) * zoom;
      canvas.drawLine(
        Offset(px, (minY2 / 2.0) * zoom),
        Offset(px, (maxY2 / 2.0) * zoom),
        halfMeterPaint,
      );
    }
    for (int j = minY2; j <= maxY2; j++) {
      if (j % 2 == 0) continue;
      final py = (j / 2.0) * zoom;
      canvas.drawLine(
        Offset((minX2 / 2.0) * zoom, py),
        Offset((maxX2 / 2.0) * zoom, py),
        halfMeterPaint,
      );
    }

    // 3. Líneas de metro completo (1.00 m) y líneas mayores (5.00 m)
    final meterPaint = Paint()
      ..color = isDarkTheme ? const Color(0xFF333E52) : const Color(0xFFCBD5E1)
      ..strokeWidth = 0.95;

    final majorGridPaint = Paint()
      ..color = isDarkTheme ? const Color(0xFF475770) : const Color(0xFF94A3B8)
      ..strokeWidth = 1.4;

    final minX = ((-pan.dx) / zoom).floor() - 2;
    final maxX = ((size.width - pan.dx) / zoom).ceil() + 2;
    final minY = ((-pan.dy) / zoom).floor() - 2;
    final maxY = ((size.height - pan.dy) / zoom).ceil() + 2;

    for (int x = minX; x <= maxX; x++) {
      final px = x * zoom;
      final isMajor = x % 5 == 0;
      canvas.drawLine(
        Offset(px, minY * zoom),
        Offset(px, maxY * zoom),
        isMajor ? majorGridPaint : meterPaint,
      );
    }

    for (int y = minY; y <= maxY; y++) {
      final py = y * zoom;
      final isMajor = y % 5 == 0;
      canvas.drawLine(
        Offset(minX * zoom, py),
        Offset(maxX * zoom, py),
        isMajor ? majorGridPaint : meterPaint,
      );
    }
  }

  void _drawZoningZones(Canvas canvas, double zoom) {
    for (final zone in state.lot.zones) {
      final path = _polygonToPath(zone.boundary, zoom);
      final isNonBuildable = zone.type == ZoningType.nonBuildable;

      final fillPaint = Paint()
        ..color = isNonBuildable
            ? const Color(0x33EF5350)
            : const Color(0x1F66BB6A)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, fillPaint);

      final strokePaint = Paint()
        ..color = isNonBuildable
            ? const Color(0xFFEF5350).withValues(alpha: 0.6)
            : const Color(0xFF66BB6A).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawPath(path, strokePaint);
    }
  }

  void _drawZoningGuideBands(Canvas canvas, double zoom) {
    final bands = ZoningEngine.calculateZoningBands(state.lot);
    if (bands.isEmpty) return;

    for (final band in bands) {
      final path = _polygonToPath(band.boundary, zoom);
      final bbox = band.boundary.boundingBox;

      // Fondo translúcido sutil
      final fillPaint = Paint()
        ..color = band.baseColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Borde continuo/sutil
      final strokePaint = Paint()
        ..color = band.baseColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawPath(path, strokePaint);

      // Cartela con información arquitectónica y sugerencias
      final leftPx = bbox.minX * zoom + 10.0;
      final topPx = bbox.minY * zoom + 8.0;

      final textSpan = TextSpan(
        children: [
          TextSpan(
            text: '${band.title}: ${band.subtitle.toUpperCase()}\n',
            style: TextStyle(
              color: band.baseColor,
              fontWeight: FontWeight.w900,
              fontSize: 10.5,
              letterSpacing: 0.6,
            ),
          ),
          TextSpan(
            text: 'Espacios recomendados: ${band.recommendedSpaces.join(', ')}\n',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontWeight: FontWeight.w600,
              fontSize: 9.0,
            ),
          ),
          TextSpan(
            text: 'Criterio: ${band.architecturalReason}',
            style: const TextStyle(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
              fontSize: 8.0,
            ),
          ),
        ],
      );

      final maxW = math.max(120.0, bbox.width * zoom - 20.0);
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 4,
      )..layout(maxWidth: maxW);

      final bgRect = Rect.fromLTWH(
        leftPx - 6,
        topPx - 4,
        tp.width + 12,
        tp.height + 8,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.85),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
        Paint()
          ..color = band.baseColor.withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      tp.paint(canvas, Offset(leftPx, topPx));
    }

    // Indicador visual de Calle / Frente Municipal en el límite frontal
    final lotBbox = state.lot.boundary.boundingBox;
    final streetX = lotBbox.minX * zoom + (lotBbox.width * zoom) / 2;
    final streetY = lotBbox.minY * zoom - 18.0;

    final streetTp = TextPainter(
      text: const TextSpan(
        text: '◄ FRENTE DEL LOTE — LÍNEA MUNICIPAL / CALLE ►',
        style: TextStyle(
          color: Color(0xFFFFB300),
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    streetTp.paint(canvas, Offset(streetX - streetTp.width / 2, streetY));
  }

  void _drawModuleBase(
    Canvas canvas,
    Module module,
    double zoom, {
    required bool isSelected,
    required bool isHovered,
  }) {
    final path = _polygonToPath(module.geometry, zoom);

    Color fillColor;
    Color strokeColor;
    double strokeWidth = module.isOpening ? 1.8 : 1.5;

    switch (module.status) {
      case ElementStatus.toDemolish:
        fillColor = isDarkTheme
            ? const Color(0x36EF4444)
            : const Color(0x28DC2626);
        strokeColor = isDarkTheme
            ? const Color(0xFFEF4444)
            : const Color(0xFFDC2626);
        break;
      case ElementStatus.isNew:
        fillColor = isDarkTheme
            ? const Color(0x2E14B8A6)
            : const Color(0x240D9488);
        strokeColor = isDarkTheme
            ? const Color(0xFF2DD4BF)
            : const Color(0xFF0F766E);
        strokeWidth = module.isOpening ? 2.0 : 1.9;
        break;
      case ElementStatus.preserved:
        fillColor = isDarkTheme
            ? const Color(0x264CAF50)
            : const Color(0x1E16A34A);
        strokeColor = isDarkTheme
            ? const Color(0xFF4CAF50)
            : const Color(0xFF15803D);
        break;
      case ElementStatus.existing:
      default:
        fillColor = isDarkTheme
            ? const Color(0x2264748B)
            : const Color(0x1C94A3B8);
        strokeColor = isDarkTheme
            ? const Color(0xFF64748B)
            : const Color(0xFF475569);
        break;
    }

    // Room floor finish / fill
    if ((state.isRenderedMode || module.floorMaterialId != null) && !module.isOpening) {
      _drawRenderedFloorFinish(canvas, module, zoom, path);
      canvas.drawPath(
        path,
        Paint()
          ..color = fillColor.withValues(alpha: isDarkTheme ? 0.16 : 0.12)
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
    }

    // Subtle hover highlight
    if (isHovered) {
      canvas.drawPath(
        path,
        Paint()
          ..color = (isDarkTheme
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF0284C7))
              .withValues(alpha: 0.14)
          ..style = PaintingStyle.fill,
      );
    }

    // Soft spotlight when selected
    if (isSelected && !module.isOpening) {
      final bb = module.geometry.boundingBox;
      final center = Offset((bb.minX + bb.width / 2) * zoom, (bb.minY + bb.height / 2) * zoom);
      final radius = math.max(bb.width, bb.height) * zoom * 0.75;
      final spotlightPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            (isDarkTheme
                    ? const Color(0xFFFFF9C4)
                    : const Color(0xFFFEF08A))
                .withValues(alpha: isDarkTheme ? 0.24 : 0.32),
            const Color(0x00FFF9C4),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.save();
      canvas.clipPath(path);
      canvas.drawCircle(center, radius, spotlightPaint);
      canvas.restore();
    }

    // Diagonal hatch for rooms marked to demolish
    if (module.status == ElementStatus.toDemolish) {
      _drawHatchPattern(
        canvas,
        module.geometry,
        zoom,
        isDarkTheme ? const Color(0x60EF4444) : const Color(0x55DC2626),
        path: path,
      );
    }

    // Interior furniture and sanitary fixtures
    if (module.subModules.isNotEmpty) {
      _drawFurnitureList(canvas, module.subModules, zoom);
    }

    // Architectural symbols (doors, windows, stairs, pools, decks)
    _drawArchitecturalSymbol(canvas, module, zoom, strokeColor);

    // Room / opening outline
    canvas.drawPath(
      path,
      Paint()
        ..color = isHovered
            ? (isDarkTheme ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
            : strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? strokeWidth + 0.8 : strokeWidth,
    );

    if (isSelected && module.isOpening) {
      final bb = module.geometry.boundingBox;
      final haloRect = Rect.fromLTWH(
        (bb.minX - 0.10) * zoom,
        (bb.minY - 0.10) * zoom,
        (bb.width + 0.20) * zoom,
        (bb.height + 0.20) * zoom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(haloRect, const Radius.circular(5)),
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.32)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawSelectedModuleOverlay(Canvas canvas, Module module, double zoom) {
    final path = _polygonToPath(module.geometry, zoom);
    final accent = isDarkTheme ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    // Crisp selection outline
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );

    // Architectural 45°-tick dimension lines (width along top, depth along left)
    final bb = module.geometry.boundingBox;
    final leftPx = bb.minX * zoom;
    final rightPx = bb.maxX * zoom;
    final topPx = bb.minY * zoom;
    final bottomPx = bb.maxY * zoom;

    _drawArchitecturalDimensionLine(
      canvas,
      Offset(leftPx, topPx),
      Offset(rightPx, topPx),
      offsetVector: const Offset(0, -18),
      label: '${bb.width.toStringAsFixed(2)} m',
      color: accent,
    );

    _drawArchitecturalDimensionLine(
      canvas,
      Offset(leftPx, topPx),
      Offset(leftPx, bottomPx),
      offsetVector: const Offset(-18, 0),
      label: '${bb.height.toStringAsFixed(2)} m',
      color: accent,
      rotateLabelDegrees: -90,
    );

    // Direct drag-resize handles (unlocked rectangular rooms only)
    final handles = computeModuleResizeHandles(module);
    if (handles.isNotEmpty) {
      for (final entry in handles.entries) {
        final handle = entry.key;
        final pt = entry.value;
        final center = Offset(pt.x * zoom, pt.y * zoom);
        final isCorner = handle == ResizeHandle2D.topLeft ||
            handle == ResizeHandle2D.topRight ||
            handle == ResizeHandle2D.bottomRight ||
            handle == ResizeHandle2D.bottomLeft;
        final isHighlighted = handle == hoveredHandle || handle == activeHandle;
        final halfSize = (isCorner ? 4.5 : 3.8) + (isHighlighted ? 1.4 : 0.0);
        final handleRect = Rect.fromCenter(
          center: center,
          width: halfSize * 2,
          height: halfSize * 2,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(handleRect, const Radius.circular(2)),
          Paint()
            ..color = isHighlighted
                ? (isDarkTheme ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                : (isDarkTheme ? const Color(0xFFF8FAFC) : Colors.white)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(handleRect, const Radius.circular(2)),
          Paint()
            ..color = isHighlighted ? Colors.white : accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
  }

  void _drawArchitecturalDimensionLine(
    Canvas canvas,
    Offset startAnchor,
    Offset endAnchor, {
    required Offset offsetVector,
    required String label,
    required Color color,
    double rotateLabelDegrees = 0.0,
  }) {
    final dimStart = startAnchor + offsetVector;
    final dimEnd = endAnchor + offsetVector;
    final extExtra = Offset(
      offsetVector.dx.sign * 4.5,
      offsetVector.dy.sign * 4.5,
    );

    final extPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    // Extension lines projecting outward from room corners
    canvas.drawLine(startAnchor, dimStart + extExtra, extPaint);
    canvas.drawLine(endAnchor, dimEnd + extExtra, extPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Main dimension line
    canvas.drawLine(dimStart, dimEnd, linePaint);

    // Architectural 45° tick slashes at both endpoints
    const tickRadius = 4.2;
    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(dimStart.dx - tickRadius, dimStart.dy + tickRadius),
      Offset(dimStart.dx + tickRadius, dimStart.dy - tickRadius),
      tickPaint,
    );
    canvas.drawLine(
      Offset(dimEnd.dx - tickRadius, dimEnd.dy + tickRadius),
      Offset(dimEnd.dx + tickRadius, dimEnd.dy - tickRadius),
      tickPaint,
    );

    final mid = Offset(
      (dimStart.dx + dimEnd.dx) / 2,
      (dimStart.dy + dimEnd.dy) / 2,
    );
    _drawBadgeText(
      canvas,
      label,
      mid,
      color: color,
      rotateDegrees: rotateLabelDegrees,
    );
  }

  void _drawRenderedFloorFinish(
    Canvas canvas,
    Module module,
    double zoom,
    Path path,
  ) {
    final finish = FinishMaterialCatalog.resolveFloorForModule(module);
    final bb = module.geometry.boundingBox;
    final left = bb.minX * zoom;
    final top = bb.minY * zoom;
    final w = bb.width * zoom;
    final h = bb.height * zoom;

    canvas.save();
    canvas.clipPath(path);

    final basePaint = Paint()
      ..color = finish.baseColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(left, top, w, h), basePaint);

    final accentPaint = Paint()
      ..color = finish.accentColor.withValues(alpha: 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;

    const int maxPatternLines = 120;
    switch (finish.pattern) {
      case FinishPatternType.woodPlanks:
      case FinishPatternType.outdoorDeck:
        final plankStep = math.max(6.0, math.max(0.22 * zoom, h / maxPatternLines));
        int count = 0;
        for (double y = top; y <= top + h && count < maxPatternLines; y += plankStep, count++) {
          canvas.drawLine(Offset(left, y), Offset(left + w, y), accentPaint);
        }
        break;
      case FinishPatternType.porcelainGrid:
      case FinishPatternType.hydraulicTile:
        final rawTileStep = finish.pattern == FinishPatternType.hydraulicTile
            ? math.max(8.0, 0.35 * zoom)
            : math.max(10.0, 0.60 * zoom);
        final tileStepX = math.max(rawTileStep, w / maxPatternLines);
        final tileStepY = math.max(rawTileStep, h / maxPatternLines);
        int cx = 0;
        for (double x = left; x <= left + w && cx < maxPatternLines; x += tileStepX, cx++) {
          canvas.drawLine(Offset(x, top), Offset(x, top + h), accentPaint);
        }
        int cy = 0;
        for (double y = top; y <= top + h && cy < maxPatternLines; y += tileStepY, cy++) {
          canvas.drawLine(Offset(left, y), Offset(left + w, y), accentPaint);
        }
        break;
      case FinishPatternType.marbleVeins:
        final veinStep = math.max(14.0, math.max(0.80 * zoom, (w + h) / maxPatternLines));
        int cv = 0;
        for (double d = left - h; d <= left + w && cv < maxPatternLines; d += veinStep, cv++) {
          canvas.drawLine(
            Offset(d, top),
            Offset(d + h * 0.65, top + h),
            accentPaint,
          );
        }
        break;
      case FinishPatternType.naturalGrass:
        _drawGarden(canvas, left, top, w, h, zoom);
        break;
      case FinishPatternType.polishedConcrete:
      case FinishPatternType.paintedWall:
      case FinishPatternType.exposedBrick:
      case FinishPatternType.travertineStone:
        break;
    }

    canvas.restore();
  }

  void _drawArchitecturalSymbol(
      Canvas canvas, Module module, double zoom, Color strokeColor) {
    final type = module.moduleType.toUpperCase();
    final bb = module.geometry.boundingBox;
    final left = bb.minX * zoom;
    final top = bb.minY * zoom;
    final w = bb.width * zoom;
    final h = bb.height * zoom;

    if (module.isSwingDoor) {
      CadSymbolDrawer.drawSwingDoor(
        canvas,
        left,
        top,
        w,
        h,
        zoom,
        strokeColor,
        flipX: module.flipX,
        flipY: module.flipY,
      );
    } else if (module.isSlidingDoor) {
      CadSymbolDrawer.drawSlidingDoor(canvas, left, top, w, h, zoom, strokeColor);
    } else if (module.isWindow) {
      CadSymbolDrawer.drawWindow(canvas, left, top, w, h, zoom, strokeColor);
    } else if (module.isGate) {
      CadSymbolDrawer.drawGate(canvas, left, top, w, h, zoom, strokeColor);
    } else if (module.isStairs) {
      CadSymbolDrawer.drawStairs(
        canvas,
        left,
        top,
        w,
        h,
        zoom,
        strokeColor,
        flipX: module.flipX,
        flipY: module.flipY,
      );
    } else if (type.contains('POOL')) {
      _drawPool(canvas, left, top, w, h, zoom);
    } else if (type.contains('DECK')) {
      _drawDeck(canvas, left, top, w, h, zoom);
    } else if (type.contains('GARDEN') || type.contains('PATIO')) {
      _drawGarden(canvas, left, top, w, h, zoom);
    }
  }

  void _drawPool(Canvas canvas, double left, double top, double w, double h, double zoom) {
    final poolRect = Rect.fromLTWH(left, top, w, h);
    final waterPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x550091EA), Color(0x6600E5FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(poolRect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(poolRect, waterPaint);

    final curbInset = math.min(10.0, 0.20 * zoom);
    final curbRect = Rect.fromLTWH(
      left + curbInset,
      top + curbInset,
      math.max(1.0, w - 2 * curbInset),
      math.max(1.0, h - 2 * curbInset),
    );
    canvas.drawRect(
      curbRect,
      Paint()
        ..color = const Color(0x8080D8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final wavePaint = Paint()
      ..color = const Color(0x70FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final centerX = left + w / 2;
    final centerY = top + h / 2;
    final waveWidth = math.min(w * 0.4, 25.0);
    final wavePath = Path()
      ..moveTo(centerX - waveWidth, centerY - 4)
      ..quadraticBezierTo(centerX - waveWidth / 2, centerY - 8, centerX, centerY - 4)
      ..quadraticBezierTo(centerX + waveWidth / 2, centerY, centerX + waveWidth, centerY - 4)
      ..moveTo(centerX - waveWidth * 0.7, centerY + 6)
      ..quadraticBezierTo(centerX - waveWidth * 0.2, centerY + 2, centerX + waveWidth * 0.3, centerY + 6);
    canvas.drawPath(wavePath, wavePaint);

    final ladderX = left + curbInset + 4;
    final ladderY = top + curbInset + 4;
    final ladderW = math.min(12.0, w * 0.2);
    final ladderH = math.min(16.0, h * 0.2);
    final railPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(ladderX, ladderY), Offset(ladderX, ladderY + ladderH), railPaint);
    canvas.drawLine(Offset(ladderX + ladderW, ladderY), Offset(ladderX + ladderW, ladderY + ladderH), railPaint);
    canvas.drawLine(Offset(ladderX, ladderY + ladderH * 0.35), Offset(ladderX + ladderW, ladderY + ladderH * 0.35), railPaint);
    canvas.drawLine(Offset(ladderX, ladderY + ladderH * 0.7), Offset(ladderX + ladderW, ladderY + ladderH * 0.7), railPaint);
  }

  void _drawDeck(Canvas canvas, double left, double top, double w, double h, double zoom) {
    final plankPaint = Paint()
      ..color = const Color(0xFFD7CCC8).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final plankStep = math.max(6.0, 0.18 * zoom);
    final isHorizontalPlanks = w >= h;

    if (isHorizontalPlanks) {
      for (double y = top + plankStep; y < top + h; y += plankStep) {
        canvas.drawLine(Offset(left, y), Offset(left + w, y), plankPaint);
      }
    } else {
      for (double x = left + plankStep; x < left + w; x += plankStep) {
        canvas.drawLine(Offset(x, top), Offset(x, top + h), plankPaint);
      }
    }
  }

  void _drawGarden(Canvas canvas, double left, double top, double w, double h, double zoom) {
    final grassPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final step = math.max(16.0, 0.8 * zoom);
    for (double x = left + step / 2; x < left + w - 8; x += step) {
      for (double y = top + step / 2; y < top + h - 8; y += step) {
        final tuftPath = Path()
          ..moveTo(x - 3, y + 3)
          ..lineTo(x - 2, y - 2)
          ..moveTo(x, y + 3)
          ..lineTo(x, y - 4)
          ..moveTo(x + 3, y + 3)
          ..lineTo(x + 2, y - 2);
        canvas.drawPath(tuftPath, grassPaint);
      }
    }
  }

  // -------------------------------------------------------------
  // SIMBOLOGÍA ARQUITECTÓNICA DE MOBILIARIO Y ARTEFACTOS INTERIORES
  // -------------------------------------------------------------
  void _drawFurnitureList(Canvas canvas, List<SubModule> subModules, double zoom) {
    for (final sub in subModules) {
      _drawFurnitureItem(canvas, sub, zoom);
    }
  }

  void _drawFurnitureItem(Canvas canvas, SubModule sub, double zoom) {
    final bb = sub.geometry.boundingBox;
    final left = bb.minX * zoom;
    final top = bb.minY * zoom;
    final w = bb.width * zoom;
    final h = bb.height * zoom;
    final rect = Rect.fromLTWH(left, top, w, h);

    if (state.isRenderedMode) {
      canvas.drawShadow(
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3))),
        Colors.black.withValues(alpha: 0.32),
        2.2,
        true,
      );
    }

    final bgPaint = Paint()
      ..color = isDarkTheme
          ? const Color(0x33B0BEC5)
          : const Color(0x2264748B)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isDarkTheme
          ? const Color(0xFFCFD8DC)
          : const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final detailPaint = Paint()
      ..color = isDarkTheme
          ? const Color(0xFF90A4AE)
          : const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final type = sub.type.toUpperCase();

    if (type == 'BED' || type.contains('BED')) {
      _drawBedSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'SOFA' || type == 'ARMCHAIR' || type.contains('SOFA')) {
      _drawSofaSymbol(canvas, rect, borderPaint, detailPaint, bgPaint, isArmchair: type == 'ARMCHAIR');
    } else if (type == 'DINING_TABLE' ||
        type == 'ROUND_TABLE' ||
        type == 'COFFEE_TABLE' ||
        type == 'TABLE' ||
        type == 'DESK' ||
        type.contains('TABLE')) {
      _drawTableSymbol(canvas, rect, borderPaint, detailPaint, bgPaint, isRound: type == 'ROUND_TABLE');
    } else if (type == 'SINK_COUNTER' ||
        type == 'SINK' ||
        type == 'LAUNDRY_SINK') {
      _drawSinkCounterSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'STOVE' || type.contains('STOVE')) {
      _drawStoveSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'REFRIGERATOR' || type == 'FRIDGE') {
      _drawFridgeSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'TOILET' || type.contains('TOILET')) {
      _drawToiletSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'VANITY' || type == 'WASHBASIN') {
      _drawVanitySymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'SHOWER' || type.contains('SHOWER')) {
      _drawShowerSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'BATHTUB') {
      _drawBathtubSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'WARDROBE' || type == 'CLOSET') {
      _drawWardrobeSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'WASHING_MACHINE') {
      _drawWasherSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'CAR') {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, borderPaint);
      canvas.drawRect(rect.deflate(math.min(rect.width, rect.height) * 0.22), detailPaint);
    } else {
      // Genérico
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), bgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), borderPaint);
    }

    // Resaltado de selección para mobiliario activo
    if (sub.id == state.selectedSubModuleId) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(2.0), const Radius.circular(4)),
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      _drawBadgeText(
        canvas,
        '${bb.width.toStringAsFixed(2)} × ${bb.height.toStringAsFixed(2)} m',
        Offset(rect.center.dx, rect.top - 10),
        color: Colors.amber,
      );
    }

    // Indicador de bloqueo si el mueble está fijo
    if (sub.isLocked) {
      final lockTp = TextPainter(
        text: const TextSpan(
          text: '🔒',
          style: TextStyle(fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lockTp.paint(canvas, Offset(rect.right - 12, rect.top + 2));
    }
  }

  void _drawBedSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(rrect, border);

    // Cabecero en la parte superior
    final headH = math.max(3.0, r.height * 0.14);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, headH), border);

    // Almohadas
    final isDouble = r.width >= 40.0;
    final pillowTop = r.top + headH + 2.0;
    final pillowH = math.max(4.0, r.height * 0.22);
    if (isDouble) {
      final pillowW = (r.width - 8.0) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 2.0, pillowTop, pillowW, pillowH), const Radius.circular(2)), detail);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 4.0 + pillowW, pillowTop, pillowW, pillowH), const Radius.circular(2)), detail);
    } else {
      final pillowW = r.width - 6.0;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 3.0, pillowTop, pillowW, pillowH), const Radius.circular(2)), detail);
    }

    // Línea de doblez del cubrecama
    final duvetY = r.top + r.height * 0.48;
    canvas.drawLine(Offset(r.left + 2, duvetY), Offset(r.right - 2, duvetY), detail);
  }

  void _drawSofaSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg, {bool isArmchair = false}) {
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(rrect, border);

    // Respaldo
    final backH = math.max(4.0, r.height * 0.24);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, backH), detail);

    // Apoyabrazos
    final armW = math.max(3.0, r.width * 0.16);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + backH, armW, r.height - backH), detail);
    canvas.drawRect(Rect.fromLTWH(r.right - armW, r.top + backH, armW, r.height - backH), detail);

    // Cojines
    if (!isArmchair) {
      final seatW = r.width - 2 * armW;
      final midSeatX = r.left + armW + seatW / 2;
      canvas.drawLine(Offset(midSeatX, r.top + backH), Offset(midSeatX, r.bottom), detail);
    }
  }

  void _drawTableSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg, {bool isRound = false}) {
    if (isRound) {
      canvas.drawOval(r, bg);
      canvas.drawOval(r, border);
      // 4 Sillas alrededor
      final cx = r.center.dx;
      final cy = r.center.dy;
      final rad = math.min(r.width, r.height) / 2;
      canvas.drawCircle(Offset(cx, cy - rad + 4), 3.0, detail);
      canvas.drawCircle(Offset(cx, cy + rad - 4), 3.0, detail);
      canvas.drawCircle(Offset(cx - rad + 4, cy), 3.0, detail);
      canvas.drawCircle(Offset(cx + rad - 4, cy), 3.0, detail);
    } else {
      final rrect = RRect.fromRectAndRadius(r, const Radius.circular(3));
      canvas.drawRRect(rrect, bg);
      canvas.drawRRect(rrect, border);
      // Sillas esquemáticas metidas bajo la mesa
      if (r.width >= 40) {
        final chairW = math.max(6.0, r.width * 0.20);
        canvas.drawRect(Rect.fromLTWH(r.left + r.width * 0.20, r.top + 2, chairW, 3), detail);
        canvas.drawRect(Rect.fromLTWH(r.left + r.width * 0.60, r.top + 2, chairW, 3), detail);
        canvas.drawRect(Rect.fromLTWH(r.left + r.width * 0.20, r.bottom - 5, chairW, 3), detail);
        canvas.drawRect(Rect.fromLTWH(r.left + r.width * 0.60, r.bottom - 5, chairW, 3), detail);
      }
    }
  }

  void _drawSinkCounterSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // Bacha / Fregadero inset
    final sinkW = math.min(r.width * 0.50, math.max(12.0, r.width - 8.0));
    final sinkH = math.max(8.0, r.height - 6.0);
    final sinkRect = Rect.fromCenter(center: r.center, width: sinkW, height: sinkH);
    canvas.drawRRect(RRect.fromRectAndRadius(sinkRect, const Radius.circular(3)), detail);

    // Desagüe y grifería
    canvas.drawCircle(sinkRect.center, 2.0, detail);
    canvas.drawLine(Offset(sinkRect.center.dx, r.top + 1), Offset(sinkRect.center.dx, r.top + 4), border);
  }

  void _drawStoveSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // 4 Hornallas circulares
    final burnerRadius = math.min(r.width, r.height) * 0.16;
    final quarterW = r.width / 4;
    final quarterH = r.height / 4;

    canvas.drawCircle(Offset(r.left + quarterW, r.top + quarterH), burnerRadius, detail);
    canvas.drawCircle(Offset(r.right - quarterW, r.top + quarterH), burnerRadius * 0.85, detail);
    canvas.drawCircle(Offset(r.left + quarterW, r.bottom - quarterH), burnerRadius * 0.85, detail);
    canvas.drawCircle(Offset(r.right - quarterW, r.bottom - quarterH), burnerRadius * 1.1, detail);
  }

  void _drawFridgeSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // Línea de puerta y tirador
    final doorY = r.top + r.height * 0.35;
    canvas.drawLine(Offset(r.left, doorY), Offset(r.right, doorY), detail);
    canvas.drawLine(Offset(r.left + 3, r.top + 4), Offset(r.left + 3, doorY - 4), border);
    canvas.drawLine(Offset(r.left + 3, doorY + 4), Offset(r.left + 3, r.bottom - 4), border);
  }

  void _drawToiletSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    // Mochila / Tanque de agua rectangular
    final tankH = math.max(5.0, r.height * 0.28);
    final tankRect = Rect.fromLTWH(r.left, r.top, r.width, tankH);
    canvas.drawRect(tankRect, bg);
    canvas.drawRect(tankRect, border);

    // Taza / Inodoro ovalado
    final bowlRect = Rect.fromLTWH(r.left + 2, r.top + tankH, r.width - 4, r.height - tankH);
    canvas.drawOval(bowlRect, bg);
    canvas.drawOval(bowlRect, border);
    // Interior de la taza
    canvas.drawOval(bowlRect.deflate(math.max(2.0, bowlRect.width * 0.18)), detail);
  }

  void _drawVanitySymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // Bacha ovalada
    final basinRect = Rect.fromCenter(
      center: r.center,
      width: math.max(6.0, r.width * 0.65),
      height: math.max(6.0, r.height * 0.65),
    );
    canvas.drawOval(basinRect, detail);
    canvas.drawCircle(basinRect.center, 1.5, detail);
  }

  void _drawShowerSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // Cruz diagonal de pendiente de desagüe
    canvas.drawLine(r.topLeft, r.bottomRight, detail);
    canvas.drawLine(r.topRight, r.bottomLeft, detail);

    // Desagüe circular central
    final drainPaint = Paint()..color = const Color(0xFFCFD8DC)..style = PaintingStyle.fill;
    canvas.drawCircle(r.center, 3.5, drainPaint);
    canvas.drawCircle(r.center, 3.5, border);
  }

  void _drawBathtubSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // Interior curvado de la bañera
    final tubRect = Rect.fromLTWH(r.left + 2, r.top + 2, r.width - 4, r.height - 4);
    canvas.drawRRect(RRect.fromRectAndRadius(tubRect, const Radius.circular(8)), detail);
    // Desagüe en un extremo
    canvas.drawCircle(Offset(r.left + 8, r.center.dy), 2.5, detail);
  }

  void _drawWardrobeSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // Línea de rieles y perchas
    canvas.drawLine(r.topLeft, r.bottomRight, detail);
    canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), detail);
  }

  void _drawWasherSymbol(Canvas canvas, Rect r, Paint border, Paint detail, Paint bg) {
    canvas.drawRect(r, bg);
    canvas.drawRect(r, border);

    // Puerta redonda de carga frontal
    final drumRadius = math.min(r.width, r.height) * 0.32;
    canvas.drawCircle(r.center, drumRadius, detail);
    canvas.drawCircle(r.center, drumRadius * 0.6, detail);
  }

  void _drawModuleLabel(
    Canvas canvas,
    Module module,
    double zoom, {
    bool isSelected = false,
  }) {
    final bb = module.geometry.boundingBox;
    final isCompact = bb.width < 0.6 || bb.height < 0.6 || module.isOpening;

    if (isCompact) {
      final dim = bb.width >= bb.height ? bb.width : bb.height;
      final typePrefix = (module.isDoor || module.isGate)
          ? (lang == 'en' ? 'D' : 'P')
          : (module.isWindow ? (lang == 'en' ? 'W' : 'V') : '');
      final shortLabel = typePrefix.isNotEmpty
          ? '$typePrefix (${dim.toStringAsFixed(2)}m)'
          : (module.name.length > 8 ? '${module.name.substring(0, 8)}...' : module.name);

      final center = Offset(
        (bb.minX + bb.width / 2) * zoom,
        (bb.minY + bb.height / 2) * zoom,
      );

      _drawBadgeText(
        canvas,
        shortLabel,
        center,
        color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
      );
      return;
    }

    final center = Offset(
      (bb.minX + bb.width / 2) * zoom,
      (bb.minY + bb.height / 2) * zoom,
    );

    final roomPixelW = bb.width * zoom;
    final roomPixelH = bb.height * zoom;
    if (roomPixelW < 22 || roomPixelH < 16) return;

    final statusTag = module.status == ElementStatus.toDemolish
        ? (lang == 'en' ? ' [DEMO]' : ' [DEMOLER]')
        : (module.status == ElementStatus.isNew
            ? (lang == 'en' ? ' [NEW]' : ' [NUEVO]')
            : '');

    final lockTag = module.isLocked ? ' 🔒' : '';
    final String titleText;
    final String subtitleText;
    final double titleFontSize;
    final double subFontSize;

    if (roomPixelW < 78.0 || roomPixelH < 46.0) {
      titleText = '${_toCompactRoomName(module.name)}$lockTag';
      subtitleText = '${module.area.toStringAsFixed(1)}m²';
      titleFontSize = 9.2;
      subFontSize = 8.4;
    } else if (roomPixelW < 138.0 || roomPixelH < 68.0) {
      titleText = '${_toMediumRoomName(module.name)}$lockTag$statusTag';
      subtitleText = '${module.area.toStringAsFixed(1)} m²';
      titleFontSize = 10.5;
      subFontSize = 9.2;
    } else {
      titleText = '${module.name}$lockTag$statusTag';
      subtitleText =
          '${bb.width.toStringAsFixed(2)}×${bb.height.toStringAsFixed(2)}m · ${module.area.toStringAsFixed(2)} m²';
      titleFontSize = 11.8;
      subFontSize = 10.0;
    }

    final titleColor = isDarkTheme ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subColor = isSelected
        ? (isDarkTheme ? const Color(0xFFFBBF24) : const Color(0xFFB45309))
        : (isDarkTheme ? const Color(0xFF94A3B8) : const Color(0xFF475569));

    final maxLabelW = math.max(28.0, roomPixelW - 8.0);
    final widthBucket = (maxLabelW / 12.0).floor() * 12;

    final textPainter = _getCachedTextPainter(
      (
        'room_lbl',
        titleText,
        subtitleText,
        titleFontSize,
        widthBucket,
        isDarkTheme,
        isSelected,
      ),
      TextSpan(
        children: [
          TextSpan(
            text: '$titleText\n',
            style: TextStyle(
              color: titleColor,
              fontSize: titleFontSize,
              fontWeight: FontWeight.w700,
              height: 1.18,
              letterSpacing: 0.15,
            ),
          ),
          TextSpan(
            text: subtitleText,
            style: TextStyle(
              color: subColor,
              fontSize: subFontSize,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxWidth: math.max(28.0, widthBucket.toDouble()),
      maxLines: 3,
    );

    final textOffset =
        center - Offset(textPainter.width / 2, textPainter.height / 2);

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        textOffset.dx - 5,
        textOffset.dy - 2.5,
        textPainter.width + 10,
        textPainter.height + 5,
      ),
      const Radius.circular(5),
    );

    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = isDarkTheme
            ? const Color(0xFF0F172A).withValues(alpha: 0.58)
            : Colors.white.withValues(alpha: 0.80),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = isSelected
            ? (isDarkTheme
                ? const Color(0xFFFBBF24).withValues(alpha: 0.65)
                : const Color(0xFFD97706).withValues(alpha: 0.65))
            : (isDarkTheme
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.85))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    textPainter.paint(canvas, textOffset);
  }

  static String _toCompactRoomName(String name) => Module.compactRoomCode(name);

  static String _toMediumRoomName(String name) {
    final clean = name
        .replaceAll(' / Medio Baño', '')
        .replaceAll(' / Pasillo', '')
        .replaceAll(' / Ropas', '')
        .replaceAll(' / Desayunador', '')
        .replaceAll(' / Home Office', '')
        .replaceAll(' Principal', '')
        .replaceAll(' Semicubierto', '')
        .replaceAll(' Recta', '');
    return clean.length > 14 ? '${clean.substring(0, 13)}.' : clean;
  }

  void _drawBadgeText(
    Canvas canvas,
    String text,
    Offset position, {
    Color color = Colors.white,
    double rotateDegrees = 0.0,
  }) {
    final tp = _getCachedTextPainter(
      ('badge', text, color.toARGB32(), isDarkTheme),
      TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );

    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (rotateDegrees != 0.0) {
      canvas.rotate(rotateDegrees * math.pi / 180.0);
    }
    final bgRect = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + 8,
      height: tp.height + 4,
    );
    final pill = RRect.fromRectAndRadius(bgRect, const Radius.circular(3.5));
    canvas.drawRRect(
      pill,
      Paint()
        ..color = isDarkTheme
            ? const Color(0xFF0F172A).withValues(alpha: 0.90)
            : Colors.white.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = color.withValues(alpha: isDarkTheme ? 0.32 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawHatchPattern(
    Canvas canvas,
    Polygon2D polygon,
    double zoom,
    Color color, {
    Path? path,
    double stepMeters = 0.5,
    bool crossHatch = false,
  }) {
    final bb = polygon.boundingBox;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.clipPath(path ?? _polygonToPath(polygon, zoom));

    final step = math.max(4.0, stepMeters * zoom);
    final start = (bb.minX + bb.minY) * zoom;
    final end = (bb.maxX + bb.maxY) * zoom;

    for (double d = start; d <= end; d += step) {
      canvas.drawLine(
        Offset(d, bb.minY * zoom),
        Offset(d - bb.height * zoom, bb.maxY * zoom),
        paint,
      );
    }
    if (crossHatch) {
      final minXpx = bb.minX * zoom;
      final maxXpx = bb.maxX * zoom;
      final minYpx = bb.minY * zoom;
      final maxYpx = bb.maxY * zoom;
      final hPx = bb.height * zoom;
      for (double x = minXpx - hPx; x <= maxXpx + hPx; x += step) {
        canvas.drawLine(
          Offset(x, minYpx),
          Offset(x + hPx, maxYpx),
          paint,
        );
      }
    }
    canvas.restore();
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dashLength = 6.0,
    double gapLength = 4.0,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  void _drawWalls(Canvas canvas, double zoom) {
    for (final wall in state.floor.walls) {
      final isSelected = wall.id == state.selectedWallId;
      final isHovered = wall.id == hoveredWallId && !isSelected;
      final path = _polygonToPath(wall.footprint, zoom);

      Color wallFill;
      Color wallStroke;
      double strokeWidth = 1.2;

      switch (wall.status) {
        case ElementStatus.toDemolish:
          wallFill = isDarkTheme
              ? const Color(0x42EF4444)
              : const Color(0x36DC2626);
          wallStroke = isDarkTheme
              ? const Color(0xFFF87171)
              : const Color(0xFFDC2626);
          strokeWidth = 1.4;
          break;
        case ElementStatus.isNew:
          wallFill = isDarkTheme
              ? const Color(0xFF0F766E)
              : const Color(0xFF0D9488);
          wallStroke = isDarkTheme
              ? const Color(0xFF2DD4BF)
              : const Color(0xFF115E59);
          strokeWidth = 1.4;
          break;
        case ElementStatus.preserved:
        case ElementStatus.existing:
        default:
          wallFill = isDarkTheme
              ? const Color(0xFF334155)
              : const Color(0xFF1E293B);
          wallStroke = isDarkTheme
              ? const Color(0xFF94A3B8)
              : const Color(0xFF0F172A);
          strokeWidth = 1.25;
          break;
      }

      // Soft drop shadow in rendered mode (skip demolished walls)
      if (state.isRenderedMode && wall.status != ElementStatus.toDemolish) {
        canvas.drawShadow(
          path,
          Colors.black.withValues(alpha: isDarkTheme ? 0.55 : 0.28),
          4.0,
          true,
        );
      }

      // 1. Architectural wall poché fill
      canvas.drawPath(
        path,
        Paint()
          ..color = wallFill
          ..style = PaintingStyle.fill,
      );

      // 2. Remodeling poché hatch distinction
      if (wall.status == ElementStatus.toDemolish) {
        _drawHatchPattern(
          canvas,
          wall.footprint,
          zoom,
          isDarkTheme ? const Color(0x99F87171) : const Color(0x99DC2626),
          path: path,
          stepMeters: 0.18,
          crossHatch: true,
        );
      } else if (wall.status == ElementStatus.isNew) {
        _drawHatchPattern(
          canvas,
          wall.footprint,
          zoom,
          isDarkTheme
              ? const Color(0x555EEAD4)
              : const Color(0x55CCFBF1),
          path: path,
          stepMeters: 0.22,
        );
      } else if (zoom >= 24.0) {
        _drawHatchPattern(
          canvas,
          wall.footprint,
          zoom,
          isDarkTheme
              ? const Color(0x40CBD5E1)
              : const Color(0x28F8FAFC),
          path: path,
          stepMeters: 0.28,
        );
      }

      // 3. Technical wall outline (dashed for demolition, crisp solid otherwise)
      final outlinePaint = Paint()
        ..color = wallStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      if (wall.status == ElementStatus.toDemolish) {
        _drawDashedPath(canvas, path, outlinePaint, dashLength: 5.5, gapLength: 3.5);
      } else {
        canvas.drawPath(path, outlinePaint);
      }

      // 4. Hover highlight
      if (isHovered) {
        canvas.drawPath(
          path,
          Paint()
            ..color = isDarkTheme
                ? const Color(0xFF38BDF8)
                : const Color(0xFF0284C7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }

      // 5. Selection highlight & length pill
      if (isSelected) {
        final accent = isDarkTheme ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        canvas.drawPath(
          path,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8,
        );

        final midX = (wall.startPoint.x + wall.endPoint.x) / 2 * zoom;
        final midY = (wall.startPoint.y + wall.endPoint.y) / 2 * zoom - 13;
        final wallLabel = lang == 'en'
            ? 'Wall: ${wall.length.toStringAsFixed(2)} m'
            : 'Muro: ${wall.length.toStringAsFixed(2)} m';
        _drawBadgeText(
          canvas,
          wallLabel,
          Offset(midX, midY),
          color: accent,
        );
      }
    }
  }

  void _drawGhostFloorUnderlay(Canvas canvas, Floor ghostFloor, double zoom) {
    final ghostAccent =
        isDarkTheme ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);
    final ghostFillPaint = Paint()
      ..color = ghostAccent.withValues(alpha: isDarkTheme ? 0.08 : 0.06)
      ..style = PaintingStyle.fill;
    final ghostStrokePaint = Paint()
      ..color = ghostAccent.withValues(alpha: isDarkTheme ? 0.68 : 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    for (final mod in ghostFloor.modules) {
      if (mod.isOpening || mod.status == ElementStatus.toDemolish) continue;
      final path = _polygonToPath(mod.geometry, zoom);
      canvas.drawPath(path, ghostFillPaint);
      _drawDashedPath(canvas, path, ghostStrokePaint, dashLength: 5.5, gapLength: 3.5);

      if (mod.isStairs || mod.isWetCore) {
        final bb = mod.geometry.boundingBox;
        final tag = mod.isStairs
            ? (lang == 'en' ? 'STAIR F${ghostFloor.floorNumber}' : 'ESC P${ghostFloor.floorNumber}')
            : (lang == 'en' ? 'WET F${ghostFloor.floorNumber}' : 'HÚM P${ghostFloor.floorNumber}');
        final tp = _getCachedTextPainter(
          ('ghost_tag', tag, isDarkTheme),
          TextSpan(
            text: tag,
            style: TextStyle(
              color: ghostAccent.withValues(alpha: 0.90),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        );
        tp.paint(
          canvas,
          Offset(
            (bb.minX + bb.width / 2) * zoom - tp.width / 2,
            bb.minY * zoom + 5,
          ),
        );
      }
    }

    final ghostWallPaint = Paint()
      ..color = ghostAccent.withValues(alpha: isDarkTheme ? 0.30 : 0.22)
      ..style = PaintingStyle.fill;
    for (final wall in ghostFloor.walls) {
      if (wall.status == ElementStatus.toDemolish) continue;
      canvas.drawPath(_polygonToPath(wall.footprint, zoom), ghostWallPaint);
    }
  }

  void _drawExteriorChainDimensions(Canvas canvas, double zoom) {
    final chain = computeExteriorChainDimensions(state.floor);
    if (chain.totalWidth < 0.25 && chain.totalDepth < 0.25) return;

    final chainColor =
        isDarkTheme ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final totalColor =
        isDarkTheme ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);

    final bottomEdgePx = chain.maxY * zoom;
    final rightEdgePx = chain.maxX * zoom;
    final leftEdgePx = chain.minX * zoom;
    final topEdgePx = chain.minY * zoom;

    void drawChainSegment(
      Offset p1,
      Offset p2,
      Offset anchor1,
      Offset anchor2,
      String text,
      Color color, {
      double rotateDegrees = 0.0,
      double fontSize = 11.5,
    }) {
      final extPaint = Paint()
        ..color = color.withValues(alpha: 0.38)
        ..strokeWidth = 0.85;
      canvas.drawLine(anchor1, p1, extPaint);
      canvas.drawLine(anchor2, p2, extPaint);

      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1.15;
      canvas.drawLine(p1, p2, linePaint);

      const tick = 4.0;
      final tickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(p1.dx - tick, p1.dy + tick),
        Offset(p1.dx + tick, p1.dy - tick),
        tickPaint,
      );
      canvas.drawLine(
        Offset(p2.dx - tick, p2.dy + tick),
        Offset(p2.dx + tick, p2.dy - tick),
        tickPaint,
      );

      final segPx = (p2 - p1).distance;
      if (segPx >= 24.0) {
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final tp = _getCachedTextPainter(
          ('chain_dim', text, color.toARGB32(), fontSize),
          TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
        canvas.save();
        canvas.translate(mid.dx, mid.dy);
        if (rotateDegrees != 0.0) {
          canvas.rotate(rotateDegrees * math.pi / 180.0);
        }
        final pill = Rect.fromCenter(
          center: Offset.zero,
          width: tp.width + 8,
          height: tp.height + 4,
        );
        canvas.drawRect(pill, Paint()..color = _canvasBg.withValues(alpha: 0.92));
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }

    // Bottom horizontal partial chain (+28px) & total (+54px)
    if (chain.xStops.length >= 2) {
      final chainY = bottomEdgePx + 28.0;
      if (chain.xStops.length > 2) {
        for (int i = 0; i < chain.xStops.length - 1; i++) {
          final x1 = chain.xStops[i];
          final x2 = chain.xStops[i + 1];
          final len = x2 - x1;
          if (len < 0.15) continue;
          drawChainSegment(
            Offset(x1 * zoom, chainY),
            Offset(x2 * zoom, chainY),
            Offset(x1 * zoom, bottomEdgePx + 4),
            Offset(x2 * zoom, bottomEdgePx + 4),
            len.toStringAsFixed(2),
            chainColor,
            fontSize: 11.5,
          );
        }
      }
      final totalY = bottomEdgePx + (chain.xStops.length > 2 ? 54.0 : 28.0);
      drawChainSegment(
        Offset(leftEdgePx, totalY),
        Offset(rightEdgePx, totalY),
        Offset(leftEdgePx, bottomEdgePx + 4),
        Offset(rightEdgePx, bottomEdgePx + 4),
        '${chain.totalWidth.toStringAsFixed(2)} m',
        totalColor,
        fontSize: 12.5,
      );
    }

    // Right vertical partial chain (+28px) & total (+54px)
    if (chain.yStops.length >= 2) {
      final chainX = rightEdgePx + 28.0;
      if (chain.yStops.length > 2) {
        for (int i = 0; i < chain.yStops.length - 1; i++) {
          final y1 = chain.yStops[i];
          final y2 = chain.yStops[i + 1];
          final len = y2 - y1;
          if (len < 0.15) continue;
          drawChainSegment(
            Offset(chainX, y1 * zoom),
            Offset(chainX, y2 * zoom),
            Offset(rightEdgePx + 4, y1 * zoom),
            Offset(rightEdgePx + 4, y2 * zoom),
            len.toStringAsFixed(2),
            chainColor,
            rotateDegrees: 90,
            fontSize: 11.5,
          );
        }
      }
      final totalX = rightEdgePx + (chain.yStops.length > 2 ? 54.0 : 28.0);
      drawChainSegment(
        Offset(totalX, topEdgePx),
        Offset(totalX, bottomEdgePx),
        Offset(rightEdgePx + 4, topEdgePx),
        Offset(rightEdgePx + 4, bottomEdgePx),
        '${chain.totalDepth.toStringAsFixed(2)} m',
        totalColor,
        rotateDegrees: 90,
        fontSize: 12.5,
      );
    }
  }

  void _drawSnapGuides(Canvas canvas, double zoom) {
    final guideColor =
        isDarkTheme ? const Color(0xFFEC4899) : const Color(0xFFDB2777);
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    final markerPaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.fill;

    for (final guide in snapGuides) {
      final p1 = guide.isVertical
          ? Offset(guide.coordinate * zoom, guide.start * zoom)
          : Offset(guide.start * zoom, guide.coordinate * zoom);
      final p2 = guide.isVertical
          ? Offset(guide.coordinate * zoom, guide.end * zoom)
          : Offset(guide.end * zoom, guide.coordinate * zoom);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy);
      _drawDashedPath(canvas, path, guidePaint, dashLength: 5.0, gapLength: 4.0);

      canvas.drawCircle(p1, 2.5, markerPaint);
      canvas.drawCircle(p2, 2.5, markerPaint);
    }
  }

  void _drawMetricRulers(Canvas canvas, Size size, double zoom, Offset pan) {
    const topBarH = 24.0;
    const leftBarW = 32.0;

    final barBg = isDarkTheme
        ? const Color(0xFF0F131B).withValues(alpha: 0.94)
        : const Color(0xFFF1F5F9).withValues(alpha: 0.96);
    final borderColor =
        isDarkTheme ? const Color(0xFF2B3548) : const Color(0xFFCBD5E1);
    final tickColor =
        isDarkTheme ? const Color(0xFF64748B) : const Color(0xFF64748B);
    final majorTextColor =
        isDarkTheme ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);
    final minorTextColor =
        isDarkTheme ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    final bgPaint = Paint()..color = barBg;
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.0;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.0;

    // Top ruler strip
    canvas.drawRect(Rect.fromLTWH(leftBarW, 0, size.width - leftBarW, topBarH), bgPaint);
    // Left ruler strip
    canvas.drawRect(Rect.fromLTWH(0, topBarH, leftBarW, size.height - topBarH), bgPaint);

    // Choose adaptive label step (in meters) so ruler numbers never overlap
    final double labelStepMeters;
    if (zoom >= 68.0) {
      labelStepMeters = 0.5;
    } else if (zoom >= 34.0) {
      labelStepMeters = 1.0;
    } else if (zoom >= 16.0) {
      labelStepMeters = 2.0;
    } else {
      labelStepMeters = 5.0;
    }
    final minorStepMeters = labelStepMeters / 2.0;

    // Top horizontal ticks
    final startMeterX = ((leftBarW - pan.dx) / zoom / minorStepMeters).floor() * minorStepMeters;
    final endMeterX = ((size.width - pan.dx) / zoom / minorStepMeters).ceil() * minorStepMeters;
    for (double m = startMeterX; m <= endMeterX + 1e-6; m += minorStepMeters) {
      final sx = pan.dx + m * zoom;
      if (sx < leftBarW || sx > size.width) continue;
      final isLabelTick = ((m / labelStepMeters) - (m / labelStepMeters).round()).abs() < 1e-3;
      final tickLen = isLabelTick ? 8.0 : 4.0;
      canvas.drawLine(Offset(sx, topBarH - tickLen), Offset(sx, topBarH), tickPaint);
      if (isLabelTick) {
        final isMajor = (m.round() % 5 == 0) && (m - m.round()).abs() < 1e-3;
        final label = (m - m.round()).abs() < 1e-3
            ? '${m.round()}m'
            : '${m.toStringAsFixed(1)}m';
        final tp = _getCachedTextPainter(
          ('ruler_x', label, isMajor, isDarkTheme),
          TextSpan(
            text: label,
            style: TextStyle(
              color: isMajor ? majorTextColor : minorTextColor,
              fontSize: 10.0,
              fontWeight: isMajor ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        );
        if (sx + 3 + tp.width < size.width) {
          tp.paint(canvas, Offset(sx + 3, 2.5));
        }
      }
    }

    // Left vertical ticks
    final startMeterY = ((topBarH - pan.dy) / zoom / minorStepMeters).floor() * minorStepMeters;
    final endMeterY = ((size.height - pan.dy) / zoom / minorStepMeters).ceil() * minorStepMeters;
    for (double m = startMeterY; m <= endMeterY + 1e-6; m += minorStepMeters) {
      final sy = pan.dy + m * zoom;
      if (sy < topBarH || sy > size.height) continue;
      final isLabelTick = ((m / labelStepMeters) - (m / labelStepMeters).round()).abs() < 1e-3;
      final tickLen = isLabelTick ? 7.0 : 3.5;
      canvas.drawLine(Offset(leftBarW - tickLen, sy), Offset(leftBarW, sy), tickPaint);
      if (isLabelTick) {
        final isMajor = (m.round() % 5 == 0) && (m - m.round()).abs() < 1e-3;
        final label = (m - m.round()).abs() < 1e-3
            ? '${m.round()}'
            : m.toStringAsFixed(1);
        final tp = _getCachedTextPainter(
          ('ruler_y', label, isMajor, isDarkTheme),
          TextSpan(
            text: label,
            style: TextStyle(
              color: isMajor ? majorTextColor : minorTextColor,
              fontSize: 9.5,
              fontWeight: isMajor ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        );
        if (sy + tp.height < size.height) {
          tp.paint(canvas, Offset(3.0, sy + 1.5));
        }
      }
    }

    // Live cursor marker ticks on top & left rulers
    if (cursorMeters != null) {
      final cursorPaint = Paint()
        ..color = isDarkTheme ? const Color(0xFFFBBF24) : const Color(0xFFD97706)
        ..strokeWidth = 2.0;
      final cx = pan.dx + cursorMeters!.x * zoom;
      final cy = pan.dy + cursorMeters!.y * zoom;
      if (cx >= leftBarW && cx <= size.width) {
        canvas.drawLine(Offset(cx, 0), Offset(cx, topBarH), cursorPaint);
      }
      if (cy >= topBarH && cy <= size.height) {
        canvas.drawLine(Offset(0, cy), Offset(leftBarW, cy), cursorPaint);
      }
    }

    // Corner origin square ("m")
    canvas.drawRect(const Rect.fromLTWH(0, 0, leftBarW, topBarH), bgPaint);
    final unitTp = _getCachedTextPainter(
      ('ruler_unit', isDarkTheme),
      TextSpan(
        text: 'm',
        style: TextStyle(
          color: majorTextColor,
          fontSize: 10.0,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    unitTp.paint(
      canvas,
      Offset((leftBarW - unitTp.width) / 2, (topBarH - unitTp.height) / 2),
    );

    // Ruler divider borders
    canvas.drawLine(Offset(0, topBarH), Offset(size.width, topBarH), borderPaint);
    canvas.drawLine(Offset(leftBarW, 0), Offset(leftBarW, size.height), borderPaint);
  }

  void _drawCursorCoordinateBadge(
    Canvas canvas,
    Size size,
    Point2D cursor,
  ) {
    final text = 'X: ${cursor.x.toStringAsFixed(2)} m   Y: ${cursor.y.toStringAsFixed(2)} m';
    final tp = _getCachedTextPainter(
      ('cursor_coord', text, isDarkTheme),
      TextSpan(
        text: text,
        style: TextStyle(
          color: isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final badgeW = tp.width + 18;
    final badgeH = tp.height + 10;
    final rect = Rect.fromLTWH(
      size.width - badgeW - 12,
      size.height - badgeH - 12,
      badgeW,
      badgeH,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isDarkTheme
            ? const Color(0xFF0F172A).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isDarkTheme
            ? const Color(0xFF334155)
            : const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    tp.paint(canvas, Offset(rect.left + 9, rect.top + 5));
  }

  void _drawPolygonBoundary(
    Canvas canvas,
    Polygon2D polygon,
    double zoom,
    Paint paint, {
    String? label,
    double labelOffsetY = -14,
  }) {
    final path = _polygonToPath(polygon, zoom);
    canvas.drawPath(path, paint);

    if (label != null) {
      _drawBoundaryLabel(
        canvas,
        polygon,
        zoom,
        label: label,
        color: paint.color,
        labelOffsetY: labelOffsetY,
        showLotOrientation: label.startsWith('LOTE'),
      );
    }
  }

  void _drawBoundaryLabel(
    Canvas canvas,
    Polygon2D polygon,
    double zoom, {
    required String label,
    required Color color,
    required double labelOffsetY,
    double fontSize = 11.0,
    bool withBackdrop = false,
    bool showLotOrientation = false,
  }) {
    final bb = polygon.boundingBox;
    final textPainter = _getCachedTextPainter(
      ('poly_lbl', label, color.toARGB32(), fontSize),
      TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
        ),
      ),
    );
    final labelPos = Offset(bb.minX * zoom + 4, bb.minY * zoom + labelOffsetY);
    if (withBackdrop) {
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelPos.dx - 5,
          labelPos.dy - 2,
          textPainter.width + 10,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        pill,
        Paint()..color = _canvasBg.withValues(alpha: 0.88),
      );
    }
    textPainter.paint(canvas, labelPos);

    if (showLotOrientation) {
      final frontColor =
          isDarkTheme ? const Color(0xFFFFB300) : const Color(0xFFB45309);
      final backColor =
          isDarkTheme ? Colors.white54 : const Color(0xFF64748B);
      final frontTp = _getCachedTextPainter(
        ('lot_front', lang, isDarkTheme),
        TextSpan(
          text: lang == 'en'
              ? '▲ FRONT / STREET / ACCESS ▲'
              : '▲ FRENTE / CALLE / ACCESO ▲',
          style: TextStyle(
            color: frontColor,
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      );
      final frontX = (bb.minX + bb.width / 2) * zoom - frontTp.width / 2;
      frontTp.paint(canvas, Offset(frontX, bb.minY * zoom + labelOffsetY - 18));

      final backTp = _getCachedTextPainter(
        ('lot_back', lang, isDarkTheme),
        TextSpan(
          text: lang == 'en'
              ? '▼ REAR / BACKYARD ▼'
              : '▼ FONDO / PATIO POSTERIOR ▼',
          style: TextStyle(
            color: backColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );
      final backX = (bb.minX + bb.width / 2) * zoom - backTp.width / 2;
      backTp.paint(canvas, Offset(backX, bb.maxY * zoom + 6));
    }
  }

  Path _polygonToPath(Polygon2D polygon, double zoom) =>
      CadSymbolDrawer.polygonToPath(polygon, zoom);

  void _drawNorthCompass(Canvas canvas, Size size, double orientationDegrees) {
    final center = Offset(size.width - 42, 54);
    CadSymbolDrawer.drawNorthCompass(
      canvas,
      center,
      20.0,
      orientationDegrees,
      backgroundColor: isDarkTheme
          ? const Color(0xFF13161C).withValues(alpha: 0.88)
          : Colors.white.withValues(alpha: 0.92),
      ringColor: isDarkTheme
          ? const Color(0xFF00E5FF).withValues(alpha: 0.45)
          : const Color(0xFF0284C7).withValues(alpha: 0.45),
      northColor: const Color(0xFFEF5350),
      southColor: isDarkTheme ? const Color(0xFF90A4AE) : const Color(0xFF64748B),
      labelColor: isDarkTheme ? const Color(0xFF00E5FF) : const Color(0xFF0369A1),
    );
  }

  void _drawBlueprintUnderlay(Canvas canvas, double zoom) {
    final cfg = state.blueprintUnderlay;
    final alpha = cfg.opacity.clamp(0.08, 0.92);
    final left = cfg.offsetX * zoom;
    final top = cfg.offsetY * zoom;
    final widthPx = math.max(1.0, cfg.widthMeters) * zoom;
    final heightPx = math.max(1.0, cfg.heightMeters) * zoom;
    final rect = Rect.fromLTWH(left, top, widthPx, heightPx);

    // 1. Blueprint cyan sheet background
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF0D47A1).withValues(alpha: alpha * 0.42),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // 2. Structural reference grid bays (Ejes A..Z, AA... & 1, 2, 3...)
    final bayMeters = math.max(1.0, cfg.structuralBayMeters);
    final bayPx = bayMeters * zoom;
    final axisLinePaint = Paint()
      ..color = const Color(0xFF80D8FF).withValues(alpha: alpha * 0.85)
      ..strokeWidth = 1.0;

    int colIdx = 0;
    for (double x = left; x <= left + widthPx + 0.5 && colIdx < 64; x += bayPx) {
      canvas.drawLine(Offset(x, top - 16), Offset(x, top + heightPx), axisLinePaint);
      final letter = _excelColumnLabel(colIdx);
      final bubbleCenter = Offset(x, top - 24);
      canvas.drawCircle(
        bubbleCenter,
        8.5,
        Paint()..color = const Color(0xFF0A192F).withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        bubbleCenter,
        8.5,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final tp = _getCachedTextPainter(
        'bp_col_$letter',
        TextSpan(
          text: letter,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      tp.paint(
        canvas,
        Offset(bubbleCenter.dx - tp.width / 2, bubbleCenter.dy - tp.height / 2),
      );
      colIdx++;
    }

    int rowIdx = 1;
    for (double y = top; y <= top + heightPx + 0.5 && rowIdx <= 64; y += bayPx) {
      canvas.drawLine(Offset(left - 16, y), Offset(left + widthPx, y), axisLinePaint);
      final bubbleCenter = Offset(left - 24, y);
      canvas.drawCircle(
        bubbleCenter,
        8.5,
        Paint()..color = const Color(0xFF0A192F).withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        bubbleCenter,
        8.5,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final tp = _getCachedTextPainter(
        'bp_row_$rowIdx',
        TextSpan(
          text: '$rowIdx',
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      tp.paint(
        canvas,
        Offset(bubbleCenter.dx - tp.width / 2, bubbleCenter.dy - tp.height / 2),
      );
      rowIdx++;
    }

    // 3. Calibrated scale stamp
    final stampTp = TextPainter(
      text: TextSpan(
        text:
            '${cfg.label} • ${cfg.widthMeters.toStringAsFixed(2)}m × ${cfg.heightMeters.toStringAsFixed(2)}m (Modulación Ejes: ${bayMeters.toStringAsFixed(2)}m)',
        style: TextStyle(
          color: const Color(0xFF80D8FF).withValues(alpha: math.min(1.0, alpha + 0.25)),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stampTp.paint(canvas, Offset(left + 8, top + heightPx - stampTp.height - 6));
  }

  static String _excelColumnLabel(int index) {
    var n = index;
    var label = '';
    while (n >= 0) {
      label = String.fromCharCode(65 + (n % 26)) + label;
      n = (n ~/ 26) - 1;
    }
    return label;
  }

  void _drawLaserMeasureOverlay(Canvas canvas, double zoom) {
    final p1 = state.laserStart!;
    final p2 = state.laserEnd!;
    final startPx = Offset(p1.x * zoom, p1.y * zoom);
    final endPx = Offset(p2.x * zoom, p2.y * zoom);

    final dx = (p2.x - p1.x).abs();
    final dy = (p2.y - p1.y).abs();
    final dist = p1.distanceTo(p2);
    final angleDeg = (math.atan2(p2.y - p1.y, p2.x - p1.x) * 180.0 / math.pi).abs();

    // Orthogonal projection legs (ΔX / ΔY)
    final legPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final cornerPx = Offset(endPx.dx, startPx.dy);
    canvas.drawLine(startPx, cornerPx, legPaint);
    canvas.drawLine(cornerPx, endPx, legPaint);

    // Main laser beam
    final beamGlow = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    final beamCore = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawLine(startPx, endPx, beamGlow);
    canvas.drawLine(startPx, endPx, beamCore);

    // Endpoint snap rings
    for (final pt in [startPx, endPx]) {
      canvas.drawCircle(pt, 5.5, Paint()..color = const Color(0xFF0A192F));
      canvas.drawCircle(
        pt,
        5.5,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Ergonomic passage clearance evaluation (only certify near-orthogonal spans)
    final isEn = lang == 'en';
    final isNearOrtho = dx <= 0.12 || dy <= 0.12 || dist < 0.01;
    final String verdict;
    final Color verdictColor;
    if (!isNearOrtho) {
      verdict = isEn
          ? '⟋ DIAGONAL MEASURE • Draw straight to verify clearance'
          : '⟋ MEDICIÓN DIAGONAL • Trace en línea recta para verificar paso';
      verdictColor = const Color(0xFF38BDF8);
    } else if (dist >= 0.90) {
      verdict = isEn
          ? '✓ ACCESSIBLE / CODE CLEARANCE (≥ 0.90 m)'
          : '✓ PASO NORMATIVO / ACCESIBLE (≥ 0.90 m)';
      verdictColor = const Color(0xFF00E676);
    } else if (dist >= 0.60) {
      verdict = isEn
          ? '⚠ NARROW SECONDARY PASSAGE (0.60–0.89 m)'
          : '⚠ PASO SECUNDARIO AJUSTADO (0.60–0.89 m)';
      verdictColor = const Color(0xFFFFB300);
    } else {
      verdict = isEn
          ? '✗ OBSTRUCTION / INSUFFICIENT CLEARANCE (< 0.60 m)'
          : '✗ OBSTRUCCIÓN / PASO INSUFICIENTE (< 0.60 m)';
      verdictColor = const Color(0xFFFF5252);
    }

    final midPx = Offset(
      (startPx.dx + endPx.dx) / 2,
      (startPx.dy + endPx.dy) / 2 - 26,
    );

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${isEn ? 'LASER' : 'LÁSER'}: ${dist.toStringAsFixed(2)} m  ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: '(ΔX: ${dx.toStringAsFixed(2)}m • ΔY: ${dy.toStringAsFixed(2)}m • ${angleDeg.toStringAsFixed(0)}°)\n',
            style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: verdict,
            style: TextStyle(
              color: verdictColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromCenter(
      center: midPx,
      width: tp.width + 18,
      height: tp.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF0A192F).withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(8)),
      Paint()
        ..color = verdictColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    tp.paint(
      canvas,
      Offset(badgeRect.left + 9, badgeRect.top + 5),
    );
  }

  void _drawDraftWallOverlay(Canvas canvas, double zoom) {
    final p1 = state.draftWallStart!;
    final p2 = state.draftWallEnd!;
    final o1 = Offset(p1.x * zoom, p1.y * zoom);
    final o2 = Offset(p2.x * zoom, p2.y * zoom);
    final len = p1.distanceTo(p2);

    final wallPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = math.max(4.0, 0.12 * zoom)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(o1, o2, wallPaint);

    final nodePaint = Paint()..color = const Color(0xFF34D399);
    canvas.drawCircle(o1, 4.5, nodePaint);
    canvas.drawCircle(o2, 4.5, nodePaint);

    if (len >= 0.10) {
      final mid = Offset((o1.dx + o2.dx) / 2, (o1.dy + o2.dy) / 2 - 14);
      final tp = TextPainter(
        text: TextSpan(
          text: '${len.toStringAsFixed(2)} m',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xCC065F46),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    }
  }

  static bool _snapGuidesDiffer(List<SnapGuide2D> a, List<SnapGuide2D> b) {
    if (identical(a, b)) return false;
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant Canvas2DPainter oldDelegate) {
    if (oldDelegate.lang != lang ||
        oldDelegate.isDarkTheme != isDarkTheme ||
        oldDelegate.hoveredModuleId != hoveredModuleId ||
        oldDelegate.hoveredWallId != hoveredWallId ||
        oldDelegate.hoveredHandle != hoveredHandle ||
        oldDelegate.activeHandle != activeHandle ||
        oldDelegate.cursorMeters != cursorMeters ||
        _snapGuidesDiffer(oldDelegate.snapGuides, snapGuides)) {
      return true;
    }
    final prev = oldDelegate.state;
    if (identical(prev, state)) return false;
    return !identical(prev.floor, state.floor) ||
        !identical(prev.lot, state.lot) ||
        prev.zoom != state.zoom ||
        prev.panOffset != state.panOffset ||
        prev.selectedModuleId != state.selectedModuleId ||
        prev.selectedSubModuleId != state.selectedSubModuleId ||
        prev.selectedWallId != state.selectedWallId ||
        prev.isRenderedMode != state.isRenderedMode ||
        prev.showZoningGuide != state.showZoningGuide ||
        prev.showFloorGhost != state.showFloorGhost ||
        prev.showPerimeterDimensions != state.showPerimeterDimensions ||
        !identical(prev.allFloors, state.allFloors) ||
        prev.isLaserMeasureActive != state.isLaserMeasureActive ||
        prev.laserStart != state.laserStart ||
        prev.laserEnd != state.laserEnd ||
        prev.isDrawWallMode != state.isDrawWallMode ||
        prev.draftWallStart != state.draftWallStart ||
        prev.draftWallEnd != state.draftWallEnd ||
        prev.blueprintUnderlay != state.blueprintUnderlay;
  }
}
