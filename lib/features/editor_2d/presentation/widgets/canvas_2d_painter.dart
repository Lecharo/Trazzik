import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/cad/cad_symbol_drawer.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/zoning_assistant/domain/zoning_engine.dart';

/// Custom painter responsible for rendering the 2D architectural floor plan,
/// grid, zoning bands, walls, spaces, openings, and interior furniture.
class Canvas2DPainter extends CustomPainter {
  final FloorEditorState state;

  static final Map<Object, TextPainter> _textPainterCache = <Object, TextPainter>{};

  static TextPainter _getCachedTextPainter(
    Object key,
    TextSpan span, {
    TextAlign textAlign = TextAlign.start,
  }) {
    final existing = _textPainterCache[key];
    if (existing != null) return existing;
    if (_textPainterCache.length >= 256) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }
    final tp = TextPainter(
      text: span,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout();
    _textPainterCache[key] = tp;
    return tp;
  }

  Canvas2DPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rawZoom = state.zoom;
    final zoom = (rawZoom.isFinite && rawZoom > 0.01) ? rawZoom : 30.0;
    final pan = (state.panOffset.dx.isFinite && state.panOffset.dy.isFinite)
        ? state.panOffset
        : Offset.zero;

    // 1. Fondo técnico oscuro
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1E222B),
    );

    canvas.save();
    canvas.translate(pan.dx, pan.dy);

    // 2. Cuadrícula métrica
    _drawGrid(canvas, size, zoom, pan);

    // 3. Dibujar Zonas Normativas del Lote
    _drawZoningZones(canvas, zoom);

    // 3.5. Guía Arquitectónica de Zonificación y Asoleamiento
    if (state.showZoningGuide) {
      _drawZoningGuideBands(canvas, zoom);
    }

    // 4. Dibujar Límite del Lote
    _drawPolygonBoundary(
      canvas,
      state.lot.boundary,
      zoom,
      Paint()
        ..color = const Color(0xFF90A4AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
      label: 'LOTE (${state.lot.boundary.area.toStringAsFixed(1)} m²)',
      labelOffsetY: -28,
    );

    // 5. Dibujar Límite del Piso
    _drawPolygonBoundary(
      canvas,
      state.floor.boundary,
      zoom,
      Paint()
        ..color = const Color(0xFF64B5F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
      label: '${state.floor.name.toUpperCase()} (Max: ${state.floor.maxAllowedArea.toStringAsFixed(0)} m²)',
      labelOffsetY: -14,
    );

    // 6. Dibujar Muros del Piso (Estructura base)
    _drawWalls(canvas, zoom);

    // 7. Dibujar Módulos y Aberturas (Recintos y vanos sobre muros)
    for (final module in state.floor.modules) {
      final isSelected = module.id == state.selectedModuleId;
      _drawModule(canvas, module, zoom, isSelected);
    }

    canvas.restore();

    // 8. Brújula / Indicador de Orientación Norte
    _drawNorthCompass(canvas, size, state.lot.orientationDegrees);
  }

  void _drawGrid(Canvas canvas, Size size, double zoom, Offset pan) {
    // 1. Subdivisión de 10 cm (0.10 m) si el zoom lo amerita
    if (zoom >= 25.0) {
      final cmPaint = Paint()
        ..color = const Color(0xFF232836).withValues(alpha: 0.7)
        ..strokeWidth = 0.5;

      final minX10 = ((-pan.dx) / zoom * 10).floor() - 5;
      final maxX10 = (((size.width - pan.dx) / zoom) * 10).ceil() + 5;
      final minY10 = ((-pan.dy) / zoom * 10).floor() - 5;
      final maxY10 = (((size.height - pan.dy) / zoom) * 10).ceil() + 5;

      for (int i = minX10; i <= maxX10; i++) {
        if (i % 10 == 0) continue; // Omitir múltiplos de metro
        final px = (i / 10.0) * zoom;
        canvas.drawLine(Offset(px, (minY10 / 10.0) * zoom), Offset(px, (maxY10 / 10.0) * zoom), cmPaint);
      }
      for (int j = minY10; j <= maxY10; j++) {
        if (j % 10 == 0) continue;
        final py = (j / 10.0) * zoom;
        canvas.drawLine(Offset((minX10 / 10.0) * zoom, py), Offset((maxX10 / 10.0) * zoom, py), cmPaint);
      }
    }

    // 2. Líneas intermedias cada 50 cm (0.50 m)
    final halfMeterPaint = Paint()
      ..color = const Color(0xFF2D3545)
      ..strokeWidth = 0.8;

    final minX2 = ((-pan.dx) / zoom * 2).floor() - 2;
    final maxX2 = (((size.width - pan.dx) / zoom) * 2).ceil() + 2;
    final minY2 = ((-pan.dy) / zoom * 2).floor() - 2;
    final maxY2 = (((size.height - pan.dy) / zoom) * 2).ceil() + 2;

    for (int i = minX2; i <= maxX2; i++) {
      if (i % 2 == 0) continue; // Omitir metros completos
      final px = (i / 2.0) * zoom;
      canvas.drawLine(Offset(px, (minY2 / 2.0) * zoom), Offset(px, (maxY2 / 2.0) * zoom), halfMeterPaint);
    }
    for (int j = minY2; j <= maxY2; j++) {
      if (j % 2 == 0) continue;
      final py = (j / 2.0) * zoom;
      canvas.drawLine(Offset((minX2 / 2.0) * zoom, py), Offset((maxX2 / 2.0) * zoom, py), halfMeterPaint);
    }

    // 3. Líneas de metro completo (1.00 m) y líneas mayores (5.00 m)
    final meterPaint = Paint()
      ..color = const Color(0xFF384355)
      ..strokeWidth = 1.0;

    final majorGridPaint = Paint()
      ..color = const Color(0xFF4C5B72)
      ..strokeWidth = 1.6;

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

      // Cota de metro en eje X
      if (zoom >= 25.0 && (isMajor || zoom >= 38.0)) {
        final tp = _getCachedTextPainter(
          ('grid_x', x, isMajor),
          TextSpan(
            text: '${x}m',
            style: TextStyle(
              color: isMajor ? const Color(0xFF00E5FF).withValues(alpha: 0.7) : Colors.white24,
              fontSize: 9,
              fontWeight: isMajor ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
        tp.paint(canvas, Offset(px + 2, 4));
      }
    }

    for (int y = minY; y <= maxY; y++) {
      final py = y * zoom;
      final isMajor = y % 5 == 0;
      canvas.drawLine(
        Offset(minX * zoom, py),
        Offset(maxX * zoom, py),
        isMajor ? majorGridPaint : meterPaint,
      );

      // Cota de metro en eje Y
      if (zoom >= 25.0 && (isMajor || zoom >= 38.0)) {
        final tp = _getCachedTextPainter(
          ('grid_y', y, isMajor),
          TextSpan(
            text: '${y}m',
            style: TextStyle(
              color: isMajor ? const Color(0xFF00E5FF).withValues(alpha: 0.7) : Colors.white24,
              fontSize: 9,
              fontWeight: isMajor ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
        tp.paint(canvas, Offset(4, py + 2));
      }
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

  void _drawModule(Canvas canvas, Module module, double zoom, bool isSelected) {
    final path = _polygonToPath(module.geometry, zoom);

    Color fillColor;
    Color strokeColor;
    double strokeWidth = 2.0;

    switch (module.status) {
      case ElementStatus.toDemolish:
        fillColor = const Color(0x40E53935); // Rojo demolición
        strokeColor = const Color(0xFFE53935);
        break;
      case ElementStatus.isNew:
        fillColor = const Color(0x4000E5FF); // Cian nueva construcción
        strokeColor = const Color(0xFF00E5FF);
        strokeWidth = 2.5;
        break;
      case ElementStatus.preserved:
        fillColor = const Color(0x304CAF50); // Verde conservado
        strokeColor = const Color(0xFF4CAF50);
        break;
      case ElementStatus.existing:
      default:
        fillColor = const Color(0x2078909C); // Gris pizarra existente
        strokeColor = const Color(0xFF78909C);
        break;
    }

    // Relleno arquitectónico
    if ((state.isRenderedMode || module.floorMaterialId != null) && !module.isOpening) {
      _drawRenderedFloorFinish(canvas, module, zoom, path);
      canvas.drawPath(path, Paint()..color = fillColor.withValues(alpha: 0.16)..style = PaintingStyle.fill);
    } else {
      canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    }

    // Efecto de Iluminación Cenital / Spotlight cuando el recinto está seleccionado o enfocado
    if (isSelected && !module.isOpening) {
      final bb = module.geometry.boundingBox;
      final center = Offset((bb.minX + bb.width / 2) * zoom, (bb.minY + bb.height / 2) * zoom);
      final radius = math.max(bb.width, bb.height) * zoom * 0.75;
      final spotlightPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF9C4).withValues(alpha: 0.35),
            const Color(0xFFFFF9C4).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.save();
      canvas.clipPath(path);
      canvas.drawCircle(center, radius, spotlightPaint);
      canvas.restore();
    }

    // Si es a demoler, dibujar trama diagonal
    if (module.status == ElementStatus.toDemolish) {
      _drawHatchPattern(canvas, module.geometry, zoom, const Color(0x60E53935), path: path);
    }

    // Mobiliario y artefactos interiores
    if (module.subModules.isNotEmpty) {
      _drawFurnitureList(canvas, module.subModules, zoom);
    }

    // Simbología Técnica Arquitectónica
    _drawArchitecturalSymbol(canvas, module, zoom, strokeColor);

    // Borde
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Resaltado de selección
    if (isSelected) {
      if (module.isOpening) {
        // Halo de selección brillante para destacar aberturas en el muro
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
            ..color = const Color(0xFFFFB300).withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );

      // Cotas de ancho y fondo en metros
      final bb = module.geometry.boundingBox;
      final topCenter = Offset((bb.minX + bb.width / 2) * zoom, bb.minY * zoom - 14);
      final leftCenter = Offset(bb.minX * zoom - 16, (bb.minY + bb.height / 2) * zoom);

      // Cota Ancho
      _drawBadgeText(canvas, '${bb.width.toStringAsFixed(2)} m', topCenter, color: Colors.amber);
      // Cota Largo
      _drawBadgeText(canvas, '${bb.height.toStringAsFixed(2)} m', leftCenter, color: Colors.amber, rotateDegrees: -90);
    }

    // Etiqueta de texto con nombre y m²
    _drawModuleLabel(canvas, module, zoom);
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

    switch (finish.pattern) {
      case FinishPatternType.woodPlanks:
      case FinishPatternType.outdoorDeck:
        final plankStep = math.max(6.0, 0.22 * zoom);
        for (double y = top; y <= top + h; y += plankStep) {
          canvas.drawLine(Offset(left, y), Offset(left + w, y), accentPaint);
        }
        break;
      case FinishPatternType.porcelainGrid:
      case FinishPatternType.hydraulicTile:
        final tileStep = finish.pattern == FinishPatternType.hydraulicTile
            ? math.max(8.0, 0.35 * zoom)
            : math.max(10.0, 0.60 * zoom);
        for (double x = left; x <= left + w; x += tileStep) {
          canvas.drawLine(Offset(x, top), Offset(x, top + h), accentPaint);
        }
        for (double y = top; y <= top + h; y += tileStep) {
          canvas.drawLine(Offset(left, y), Offset(left + w, y), accentPaint);
        }
        break;
      case FinishPatternType.marbleVeins:
        final veinStep = math.max(14.0, 0.80 * zoom);
        for (double d = left - h; d <= left + w; d += veinStep) {
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
      ..color = const Color(0x33B0BEC5)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final detailPaint = Paint()
      ..color = const Color(0xFF90A4AE)
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

  void _drawModuleLabel(Canvas canvas, Module module, double zoom) {
    final bb = module.geometry.boundingBox;
    final isCompact = bb.width < 0.6 || bb.height < 0.6 || module.isOpening;

    if (isCompact) {
      final dim = bb.width >= bb.height ? bb.width : bb.height;
      final typePrefix = (module.isDoor || module.isGate)
          ? 'P'
          : (module.isWindow ? 'V' : '');
      final shortLabel = typePrefix.isNotEmpty
          ? '$typePrefix (${dim.toStringAsFixed(2)}m)'
          : (module.name.length > 8 ? '${module.name.substring(0, 8)}...' : module.name);

      final center = Offset(
        (bb.minX + bb.width / 2) * zoom,
        (bb.minY + bb.height / 2) * zoom,
      );

      _drawBadgeText(canvas, shortLabel, center, color: Colors.white);
      return;
    }

    final center = Offset(
      (bb.minX + bb.width / 2) * zoom,
      (bb.minY + bb.height / 2) * zoom,
    );

    final roomPixelW = bb.width * zoom;
    final roomPixelH = bb.height * zoom;

    final statusTag = module.status == ElementStatus.toDemolish
        ? ' [DEMOLER]'
        : (module.status == ElementStatus.isNew ? ' [NUEVO]' : '');

    final lockTag = module.isLocked ? ' 🔒' : '';
    String labelText;
    double fontSize;

    if (roomPixelW < 75.0 || roomPixelH < 45.0) {
      // Recinto angosto/pequeño: código corto y área compacta
      final compactName = _toCompactRoomName(module.name);
      labelText = '$compactName$lockTag\n${module.area.toStringAsFixed(1)}m²';
      fontSize = 8.5;
    } else if (roomPixelW < 130.0 || roomPixelH < 65.0) {
      // Recinto mediano: nombre simplificado sin subtítulos excesivos
      final mediumName = _toMediumRoomName(module.name);
      labelText = '$mediumName$lockTag$statusTag\n${module.area.toStringAsFixed(1)} m²';
      fontSize = 9.5;
    } else {
      // Recinto amplio: nombre completo
      labelText = '${module.name}$lockTag$statusTag\n${module.area.toStringAsFixed(2)} m²';
      fontSize = 11.0;
    }

    final textSpan = TextSpan(
      text: labelText,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
    );

    final maxLabelW = math.max(25.0, roomPixelW - 6.0);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: maxLabelW);

    final textOffset = center - Offset(textPainter.width / 2, textPainter.height / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          textOffset.dx - 3,
          textOffset.dy - 2,
          textPainter.width + 6,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.70),
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

  void _drawBadgeText(Canvas canvas, String text, Offset position, {Color color = Colors.white, double rotateDegrees = 0.0}) {
    final tp = _getCachedTextPainter(
      ('badge', text, color.toARGB32()),
      TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );

    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (rotateDegrees != 0.0) {
      canvas.rotate(rotateDegrees * math.pi / 180.0);
    }
    // Background pill
    final bgRect = Rect.fromCenter(center: Offset.zero, width: tp.width + 6, height: tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3)), Paint()..color = const Color(0xFF13161C).withValues(alpha: 0.9));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawHatchPattern(
      Canvas canvas, Polygon2D polygon, double zoom, Color color, {Path? path}) {
    final bb = polygon.boundingBox;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.clipPath(path ?? _polygonToPath(polygon, zoom));

    final step = 0.5 * zoom;
    final start = (bb.minX + bb.minY) * zoom;
    final end = (bb.maxX + bb.maxY) * zoom;

    for (double d = start; d <= end; d += step) {
      canvas.drawLine(
        Offset(d, bb.minY * zoom),
        Offset(d - bb.height * zoom, bb.maxY * zoom),
        paint,
      );
    }
    canvas.restore();
  }

  void _drawWalls(Canvas canvas, double zoom) {
    for (final wall in state.floor.walls) {
      final isSelected = wall.id == state.selectedWallId;
      final path = _polygonToPath(wall.footprint, zoom);

      Color wallColor;
      switch (wall.status) {
        case ElementStatus.toDemolish:
          wallColor = const Color(0x60E53935);
          break;
        case ElementStatus.isNew:
          wallColor = const Color(0xFFCFD8DC);
          break;
        case ElementStatus.preserved:
        case ElementStatus.existing:
        default:
          wallColor = const Color(0xFFB0BEC5);
          break;
      }

      // Sombra arrojada volumétrica en modo renderizado
      if (state.isRenderedMode) {
        canvas.drawShadow(path, Colors.black.withValues(alpha: 0.55), 4.5, true);
      }

      // Relleno
      canvas.drawPath(
        path,
        Paint()
          ..color = wallColor
          ..style = PaintingStyle.fill,
      );

      // Borde técnico
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF37474F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Resaltado de selección
      if (isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );

        final midX = (wall.startPoint.x + wall.endPoint.x) / 2 * zoom;
        final midY = (wall.startPoint.y + wall.endPoint.y) / 2 * zoom - 12;
        _drawBadgeText(
          canvas,
          'Muro: ${wall.length.toStringAsFixed(2)} m',
          Offset(midX, midY),
          color: Colors.amber,
        );
      }
    }
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
      final bb = polygon.boundingBox;
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: paint.color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(bb.minX * zoom + 4, bb.minY * zoom + labelOffsetY),
      );

      // Indicadores permanentes de orientación para el Lote
      if (label.startsWith('LOTE')) {
        final frontTp = TextPainter(
          text: const TextSpan(
            text: '▲ FRENTE / CALLE / ACCESO ▲',
            style: TextStyle(
              color: Color(0xFFFFB300),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final frontX = (bb.minX + bb.width / 2) * zoom - frontTp.width / 2;
        frontTp.paint(canvas, Offset(frontX, bb.minY * zoom - 42));

        final backTp = TextPainter(
          text: const TextSpan(
            text: '▼ FONDO / PATIO POSTERIOR ▼',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final backX = (bb.minX + bb.width / 2) * zoom - backTp.width / 2;
        backTp.paint(canvas, Offset(backX, bb.maxY * zoom + 4));
      }
    }
  }

  Path _polygonToPath(Polygon2D polygon, double zoom) =>
      CadSymbolDrawer.polygonToPath(polygon, zoom);

  void _drawNorthCompass(Canvas canvas, Size size, double orientationDegrees) {
    final center = Offset(size.width - 55, 45);
    CadSymbolDrawer.drawNorthCompass(
      canvas,
      center,
      22.0,
      orientationDegrees,
      backgroundColor: const Color(0xFF13161C).withValues(alpha: 0.85),
      ringColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
      northColor: const Color(0xFFEF5350),
      southColor: const Color(0xFF90A4AE),
      labelColor: const Color(0xFF00E5FF),
    );
  }

  @override
  bool shouldRepaint(covariant Canvas2DPainter oldDelegate) {
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
        prev.showZoningGuide != state.showZoningGuide;
  }
}
