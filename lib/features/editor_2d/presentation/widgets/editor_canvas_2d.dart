import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/zoning_assistant/domain/zoning_engine.dart';
import 'package:trazzik/features/zoning_assistant/domain/zoning_guide_band.dart';

class EditorCanvas2D extends ConsumerStatefulWidget {
  const EditorCanvas2D({super.key});

  @override
  ConsumerState<EditorCanvas2D> createState() => _EditorCanvas2DState();
}

class _EditorCanvas2DState extends ConsumerState<EditorCanvas2D> {
  String? _draggingModuleId;
  String? _draggingSubModuleId;
  String? _draggingParentModuleId;
  Point2D? _dragStartMeters;
  Point2D? _moduleInitialOrigin;
  Point2D? _subModuleInitialOrigin;

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);

    return GestureDetector(
      onPanStart: (details) {
        final localPos = details.localPosition;
        final metersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
        final metersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
        final clickPoint = Point2D(metersX, metersY);

        // 0. Probar PRIMERO si se tocó una abertura (puerta, ventana, portón)
        // Se prioriza porque van montadas sobre muros y bordes de recintos
        String? hitOpeningId;
        Point2D? openingOrigin;
        for (final module in editorState.floor.modules.reversed) {
          if (_isOpeningModule(module) && _isPointNearOpening(clickPoint, module, editorState.zoom)) {
            hitOpeningId = module.id;
            openingOrigin = Point2D(
              module.geometry.boundingBox.minX,
              module.geometry.boundingBox.minY,
            );
            break;
          }
        }

        if (hitOpeningId != null) {
          final hitMod = editorState.floor.modules.firstWhere((m) => m.id == hitOpeningId);
          setState(() {
            _draggingModuleId = hitMod.isLocked ? null : hitOpeningId;
            _dragStartMeters = hitMod.isLocked ? null : clickPoint;
            _moduleInitialOrigin = hitMod.isLocked ? null : openingOrigin;
            _draggingSubModuleId = null;
            _draggingParentModuleId = null;
            _subModuleInitialOrigin = null;
          });
          notifier.selectModule(hitOpeningId);
          return;
        }

        // 1. Probar si se tocó una pieza de mobiliario (submódulo)
        String? hitSubId;
        String? hitParentId;
        Point2D? subOrigin;
        for (final module in editorState.floor.modules.reversed) {
          for (final sub in module.subModules.reversed) {
            if (sub.geometry.containsPoint(clickPoint)) {
              hitSubId = sub.id;
              hitParentId = module.id;
              subOrigin = Point2D(
                sub.geometry.boundingBox.minX,
                sub.geometry.boundingBox.minY,
              );
              break;
            }
          }
          if (hitSubId != null) break;
        }

        if (hitSubId != null) {
          final parentMod = editorState.floor.modules.firstWhere((m) => m.id == hitParentId);
          final hitSub = parentMod.subModules.firstWhere((s) => s.id == hitSubId);
          setState(() {
            _draggingSubModuleId = hitSub.isLocked ? null : hitSubId;
            _draggingParentModuleId = hitSub.isLocked ? null : hitParentId;
            _subModuleInitialOrigin = hitSub.isLocked ? null : subOrigin;
            _dragStartMeters = hitSub.isLocked ? null : clickPoint;
            _draggingModuleId = null;
            _moduleInitialOrigin = null;
          });
          notifier.selectSubModule(hitParentId, hitSubId);
          return;
        }

        // 2. Probar si se tocó un muro con tolerancia táctil cómoda
        String? hitWallId;
        final wallToleranceMeters = math.max(0.25, 12.0 / editorState.zoom);
        for (final wall in editorState.floor.walls.reversed) {
          if (wall.footprint.containsPoint(clickPoint) ||
              _distanceToSegment(clickPoint, wall.startPoint, wall.endPoint) <= wallToleranceMeters) {
            hitWallId = wall.id;
            break;
          }
        }

        if (hitWallId != null) {
          notifier.selectWall(hitWallId);
          setState(() {
            _draggingModuleId = null;
            _dragStartMeters = null;
            _moduleInitialOrigin = null;
            _draggingSubModuleId = null;
            _draggingParentModuleId = null;
            _subModuleInitialOrigin = null;
          });
          return;
        }

        // 3. Si no es abertura, mueble ni muro, probar recintos regulares
        String? hitModuleId;
        Point2D? origin;
        for (final module in editorState.floor.modules.reversed) {
          if (!_isOpeningModule(module) && module.geometry.containsPoint(clickPoint)) {
            hitModuleId = module.id;
            origin = Point2D(
              module.geometry.boundingBox.minX,
              module.geometry.boundingBox.minY,
            );
            break;
          }
        }

        if (hitModuleId != null) {
          final hitMod = editorState.floor.modules.firstWhere((m) => m.id == hitModuleId);
          setState(() {
            _draggingModuleId = hitMod.isLocked ? null : hitModuleId;
            _dragStartMeters = hitMod.isLocked ? null : clickPoint;
            _moduleInitialOrigin = hitMod.isLocked ? null : origin;
            _draggingSubModuleId = null;
            _draggingParentModuleId = null;
            _subModuleInitialOrigin = null;
          });
          notifier.selectModule(hitModuleId);
        } else {
          setState(() {
            _draggingModuleId = null;
            _dragStartMeters = null;
            _moduleInitialOrigin = null;
            _draggingSubModuleId = null;
            _draggingParentModuleId = null;
            _subModuleInitialOrigin = null;
          });
        }
      },
      onPanUpdate: (details) {
        if (_draggingSubModuleId != null &&
            _draggingParentModuleId != null &&
            _dragStartMeters != null &&
            _subModuleInitialOrigin != null) {
          // Arrastrar pieza de mobiliario dentro del recinto
          final localPos = details.localPosition;
          final curMetersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
          final curMetersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
          final deltaX = curMetersX - _dragStartMeters!.x;
          final deltaY = curMetersY - _dragStartMeters!.y;

          final targetX = FloorEditorNotifier.snapToGrid(_subModuleInitialOrigin!.x + deltaX, 0.05);
          final targetY = FloorEditorNotifier.snapToGrid(_subModuleInitialOrigin!.y + deltaY, 0.05);

          notifier.setSubModulePosition(_draggingParentModuleId!, _draggingSubModuleId!, targetX, targetY);
        } else if (_draggingModuleId != null && _dragStartMeters != null && _moduleInitialOrigin != null) {
          // Arrastrar recinto completo
          final localPos = details.localPosition;
          final curMetersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
          final curMetersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
          final deltaX = curMetersX - _dragStartMeters!.x;
          final deltaY = curMetersY - _dragStartMeters!.y;

          final targetX = FloorEditorNotifier.snapToGrid(_moduleInitialOrigin!.x + deltaX, 0.05);
          final targetY = FloorEditorNotifier.snapToGrid(_moduleInitialOrigin!.y + deltaY, 0.05);

          notifier.setModulePosition(_draggingModuleId!, targetX, targetY);
        } else {
          notifier.updatePan(details.delta);
        }
      },
      onPanEnd: (_) {
        setState(() {
          _draggingModuleId = null;
          _draggingSubModuleId = null;
          _draggingParentModuleId = null;
          _dragStartMeters = null;
          _moduleInitialOrigin = null;
          _subModuleInitialOrigin = null;
        });
      },
      onTapUp: (details) {
        final localPos = details.localPosition;
        final metersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
        final metersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
        final clickPoint = Point2D(metersX, metersY);

        // 0. Probar PRIMERO si se tocó una abertura (puerta, ventana, portón)
        String? foundOpeningId;
        for (final module in editorState.floor.modules.reversed) {
          if (_isOpeningModule(module) && _isPointNearOpening(clickPoint, module, editorState.zoom)) {
            foundOpeningId = module.id;
            break;
          }
        }
        if (foundOpeningId != null) {
          notifier.selectModule(foundOpeningId);
          return;
        }

        // 1. Probar si se tocó una pieza de mobiliario (submódulo)
        String? foundSubId;
        String? foundParentId;
        for (final module in editorState.floor.modules.reversed) {
          for (final sub in module.subModules.reversed) {
            if (sub.geometry.containsPoint(clickPoint)) {
              foundSubId = sub.id;
              foundParentId = module.id;
              break;
            }
          }
          if (foundSubId != null) break;
        }
        if (foundSubId != null) {
          notifier.selectSubModule(foundParentId, foundSubId);
          return;
        }

        // 2. Probar si se tocó un muro con tolerancia táctil cómoda (mínimo 14 píxeles en pantalla o 0.28m)
        String? foundWallId;
        final hitToleranceMeters = math.max(0.28, 14.0 / editorState.zoom);
        for (final wall in editorState.floor.walls.reversed) {
          if (wall.footprint.containsPoint(clickPoint) ||
              _distanceToSegment(clickPoint, wall.startPoint, wall.endPoint) <= hitToleranceMeters) {
            foundWallId = wall.id;
            break;
          }
        }
        if (foundWallId != null) {
          notifier.selectWall(foundWallId);
          return;
        }

        // 3. Probar si se tocó un módulo regular (recinto habitable)
        String? foundId;
        for (final module in editorState.floor.modules.reversed) {
          if (!_isOpeningModule(module) && module.geometry.containsPoint(clickPoint)) {
            foundId = module.id;
            break;
          }
        }
        notifier.selectModule(foundId);
      },
      child: ClipRect(
        child: CustomPaint(
          size: Size.infinite,
          painter: _Canvas2DPainter(editorState),
        ),
      ),
    );
  }

  static bool _isOpeningModule(Module module) {
    final t = module.moduleType.toUpperCase();
    return t.contains('DOOR') || t.contains('WINDOW') || t.contains('GATE');
  }

  static bool _isPointNearOpening(Point2D p, Module module, double zoom) {
    if (module.geometry.containsPoint(p)) return true;

    final bb = module.geometry.boundingBox;
    // Tolerancia táctil generosa: mínimo 0.35m o 18 píxeles en pantalla
    final tol = math.max(0.35, 18.0 / zoom);

    // 1. Caja delimitadora inflada
    if (p.x >= bb.minX - tol &&
        p.x <= bb.maxX + tol &&
        p.y >= bb.minY - tol &&
        p.y <= bb.maxY + tol) {
      return true;
    }

    // 2. Si es puerta batiente, incluir el cuadrante del arco y hoja de apertura
    final type = module.moduleType.toUpperCase();
    if (type.contains('DOOR') && !type.contains('SLIDING')) {
      final isHorizontal = bb.width >= bb.height;
      final doorLength = isHorizontal ? bb.width : bb.height;
      final hingeX = module.flipX ? bb.maxX : bb.minX;
      final hingeY = module.flipY ? bb.minY : bb.maxY;
      final hinge = Point2D(hingeX, hingeY);
      final dist = p.distanceTo(hinge);
      if (dist <= doorLength + tol) {
        final dx = p.x - hingeX;
        final dy = p.y - hingeY;
        if (isHorizontal) {
          final isCorrectY = module.flipY ? dy >= -tol : dy <= tol;
          final isCorrectX = module.flipX ? dx <= tol : dx >= -tol;
          if (isCorrectY && isCorrectX) return true;
        } else {
          final isCorrectX = module.flipX ? dx >= -tol : dx <= tol;
          final isCorrectY = module.flipY ? dy <= tol : dy >= -tol;
          if (isCorrectX && isCorrectY) return true;
        }
      }
    }

    return false;
  }

  static double _distanceToSegment(Point2D p, Point2D a, Point2D b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return p.distanceTo(a);
    final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq;
    final clampedT = t.clamp(0.0, 1.0);
    final proj = Point2D(a.x + clampedT * dx, a.y + clampedT * dy);
    return p.distanceTo(proj);
  }
}


class _Canvas2DPainter extends CustomPainter {
  final FloorEditorState state;

  _Canvas2DPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = state.zoom;
    final pan = state.panOffset;

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
        ..color = const Color(0xFF232836).withOpacity(0.7)
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
        final tp = TextPainter(
          text: TextSpan(
            text: '${x}m',
            style: TextStyle(
              color: isMajor ? const Color(0xFF00E5FF).withOpacity(0.7) : Colors.white24,
              fontSize: 9,
              fontWeight: isMajor ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
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
        final tp = TextPainter(
          text: TextSpan(
            text: '${y}m',
            style: TextStyle(
              color: isMajor ? const Color(0xFF00E5FF).withOpacity(0.7) : Colors.white24,
              fontSize: 9,
              fontWeight: isMajor ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
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
            ? const Color(0xFFEF5350).withOpacity(0.6)
            : const Color(0xFF66BB6A).withOpacity(0.5)
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
        ..color = band.baseColor.withOpacity(0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Borde continuo/sutil
      final strokePaint = Paint()
        ..color = band.baseColor.withOpacity(0.65)
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
              color: Colors.white.withOpacity(0.90),
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
        Paint()..color = const Color(0xFF0F172A).withOpacity(0.85),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
        Paint()
          ..color = band.baseColor.withOpacity(0.40)
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

    // Relleno
    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);

    // Si es a demoler, dibujar trama diagonal
    if (module.status == ElementStatus.toDemolish) {
      _drawHatchPattern(canvas, module.geometry, zoom, const Color(0x60E53935));
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
      final isOpening = module.moduleType.toUpperCase().contains('DOOR') ||
          module.moduleType.toUpperCase().contains('WINDOW') ||
          module.moduleType.toUpperCase().contains('GATE');

      if (isOpening) {
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
            ..color = const Color(0xFFFFB300).withOpacity(0.35)
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

  void _drawArchitecturalSymbol(
      Canvas canvas, Module module, double zoom, Color strokeColor) {
    final type = module.moduleType.toUpperCase();
    final bb = module.geometry.boundingBox;
    final left = bb.minX * zoom;
    final top = bb.minY * zoom;
    final w = bb.width * zoom;
    final h = bb.height * zoom;

    if (type.contains('DOOR') && !type.contains('SLIDING')) {
      _drawSwingDoor(canvas, left, top, w, h, zoom, strokeColor, module.flipX, module.flipY);
    } else if (type.contains('SLIDING')) {
      _drawSlidingDoor(canvas, left, top, w, h, zoom, strokeColor);
    } else if (type.contains('WINDOW')) {
      _drawWindow(canvas, left, top, w, h, zoom, strokeColor);
    } else if (type.contains('GATE')) {
      _drawGate(canvas, left, top, w, h, zoom, strokeColor);
    } else if (type.contains('STAIRS')) {
      _drawStairs(canvas, left, top, w, h, zoom, strokeColor, flipX: module.flipX, flipY: module.flipY);
    } else if (type.contains('POOL')) {
      _drawPool(canvas, left, top, w, h, zoom);
    } else if (type.contains('DECK')) {
      _drawDeck(canvas, left, top, w, h, zoom);
    } else if (type.contains('GARDEN') || type.contains('PATIO')) {
      _drawGarden(canvas, left, top, w, h, zoom);
    }
  }

  void _drawSwingDoor(Canvas canvas, double left, double top, double w, double h,
      double zoom, Color strokeColor, bool flipX, bool flipY) {
    final isHorizontal = w >= h;
    final arcPaint = Paint()
      ..color = strokeColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final leafPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, 0.04 * zoom);

    final jambPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    if (isHorizontal) {
      final jambW = math.min(w * 0.10, math.max(3.0, 0.06 * zoom));
      canvas.drawRect(Rect.fromLTWH(left, top, jambW, h), jambPaint);
      canvas.drawRect(Rect.fromLTWH(left + w - jambW, top, jambW, h), jambPaint);

      final hingeX = flipX ? (left + w - jambW) : (left + jambW);
      final hingeY = flipY ? top : (top + h);
      final doorLength = w - 2 * jambW;
      final targetY = flipY ? (hingeY + doorLength) : (hingeY - doorLength);

      canvas.drawLine(
        Offset(hingeX, hingeY),
        Offset(hingeX, targetY),
        leafPaint,
      );

      final arcRect = Rect.fromCircle(
        center: Offset(hingeX, hingeY),
        radius: doorLength,
      );

      double startAngle;
      double sweepAngle;
      if (!flipY) {
        if (!flipX) {
          startAngle = 0.0;
          sweepAngle = -math.pi / 2;
        } else {
          startAngle = -math.pi;
          sweepAngle = math.pi / 2;
        }
      } else {
        if (!flipX) {
          startAngle = 0.0;
          sweepAngle = math.pi / 2;
        } else {
          startAngle = math.pi;
          sweepAngle = -math.pi / 2;
        }
      }

      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
    } else {
      final jambH = math.min(h * 0.10, math.max(3.0, 0.06 * zoom));
      canvas.drawRect(Rect.fromLTWH(left, top, w, jambH), jambPaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - jambH, w, jambH), jambPaint);

      final hingeX = flipX ? left : (left + w);
      final hingeY = flipY ? (top + h - jambH) : (top + jambH);
      final doorLength = h - 2 * jambH;
      final targetX = flipX ? (hingeX + doorLength) : (hingeX - doorLength);

      canvas.drawLine(
        Offset(hingeX, hingeY),
        Offset(targetX, hingeY),
        leafPaint,
      );

      final arcRect = Rect.fromCircle(
        center: Offset(hingeX, hingeY),
        radius: doorLength,
      );

      double startAngle;
      double sweepAngle;
      if (!flipX) {
        if (!flipY) {
          startAngle = math.pi / 2;
          sweepAngle = math.pi / 2;
        } else {
          startAngle = -math.pi / 2;
          sweepAngle = -math.pi / 2;
        }
      } else {
        if (!flipY) {
          startAngle = math.pi / 2;
          sweepAngle = -math.pi / 2;
        } else {
          startAngle = -math.pi / 2;
          sweepAngle = math.pi / 2;
        }
      }

      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  void _drawSlidingDoor(Canvas canvas, double left, double top, double w,
      double h, double zoom, Color strokeColor) {
    final isHorizontal = w >= h;
    final glassPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 0.03 * zoom);

    final trackPaint = Paint()
      ..color = strokeColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (isHorizontal) {
      final midY = top + h / 2;
      final offsetTrack = math.max(2.0, h * 0.22);
      canvas.drawLine(
        Offset(left, midY - offsetTrack),
        Offset(left + w * 0.55, midY - offsetTrack),
        glassPaint,
      );
      canvas.drawLine(
        Offset(left + w * 0.45, midY + offsetTrack),
        Offset(left + w, midY + offsetTrack),
        glassPaint,
      );
      canvas.drawLine(Offset(left, midY), Offset(left + w, midY), trackPaint);
    } else {
      final midX = left + w / 2;
      final offsetTrack = math.max(2.0, w * 0.22);
      canvas.drawLine(
        Offset(midX - offsetTrack, top),
        Offset(midX - offsetTrack, top + h * 0.55),
        glassPaint,
      );
      canvas.drawLine(
        Offset(midX + offsetTrack, top + h * 0.45),
        Offset(midX + offsetTrack, top + h),
        glassPaint,
      );
      canvas.drawLine(Offset(midX, top), Offset(midX, top + h), trackPaint);
    }
  }

  void _drawWindow(Canvas canvas, double left, double top, double w, double h,
      double zoom, Color strokeColor) {
    final isHorizontal = w >= h;
    final glassPaint = Paint()
      ..color = const Color(0xFF80D8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 0.025 * zoom);

    final framePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    if (isHorizontal) {
      final jambW = math.min(w * 0.08, math.max(2.5, 0.05 * zoom));
      canvas.drawRect(Rect.fromLTWH(left, top, jambW, h), framePaint);
      canvas.drawRect(Rect.fromLTWH(left + w - jambW, top, jambW, h), framePaint);

      final glassY1 = top + h * 0.35;
      final glassY2 = top + h * 0.65;
      canvas.drawLine(Offset(left + jambW, glassY1), Offset(left + w - jambW, glassY1), glassPaint);
      canvas.drawLine(Offset(left + jambW, glassY2), Offset(left + w - jambW, glassY2), glassPaint);
    } else {
      final jambH = math.min(h * 0.08, math.max(2.5, 0.05 * zoom));
      canvas.drawRect(Rect.fromLTWH(left, top, w, jambH), framePaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - jambH, w, jambH), framePaint);

      final glassX1 = left + w * 0.35;
      final glassX2 = left + w * 0.65;
      canvas.drawLine(Offset(glassX1, top + jambH), Offset(glassX1, top + h - jambH), glassPaint);
      canvas.drawLine(Offset(glassX2, top + jambH), Offset(glassX2, top + h - jambH), glassPaint);
    }
  }

  void _drawGate(Canvas canvas, double left, double top, double w, double h,
      double zoom, Color strokeColor) {
    final isHorizontal = w >= h;
    final postPaint = Paint()..color = strokeColor..style = PaintingStyle.fill;
    final dashPaint = Paint()
      ..color = strokeColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isHorizontal) {
      final postW = math.min(w * 0.12, 0.25 * zoom);
      canvas.drawRect(Rect.fromLTWH(left, top, postW, h), postPaint);
      canvas.drawRect(Rect.fromLTWH(left + w - postW, top, postW, h), postPaint);

      canvas.drawLine(Offset(left + postW, top), Offset(left + w - postW, top + h), dashPaint);
      canvas.drawLine(Offset(left + postW, top + h), Offset(left + w - postW, top), dashPaint);
    } else {
      final postH = math.min(h * 0.12, 0.25 * zoom);
      canvas.drawRect(Rect.fromLTWH(left, top, w, postH), postPaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - postH, w, postH), postPaint);

      canvas.drawLine(Offset(left, top + postH), Offset(left + w, top + h - postH), dashPaint);
      canvas.drawLine(Offset(left + w, top + postH), Offset(left, top + h - postH), dashPaint);
    }
  }

  void _drawStairs(Canvas canvas, double left, double top, double w, double h,
      double zoom, Color strokeColor, {bool flipX = false, bool flipY = false}) {
    final isHorizontal = w >= h;
    final stepPaint = Paint()
      ..color = strokeColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final arrowPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final stepSizeMeters = 0.28;
    final stepPx = stepSizeMeters * zoom;

    if (isHorizontal) {
      final stepCount = math.max(4, (w / stepPx).round());
      final dx = w / stepCount;
      for (int i = 1; i < stepCount; i++) {
        canvas.drawLine(
          Offset(left + i * dx, top),
          Offset(left + i * dx, top + h),
          stepPaint,
        );
      }

      final midY = top + h / 2;
      if (!flipX) {
        canvas.drawCircle(Offset(left + 8, midY), 3.0, Paint()..color = strokeColor);
        canvas.drawLine(Offset(left + 8, midY), Offset(left + w - 12, midY), arrowPaint);
        final arrowPath = Path()
          ..moveTo(left + w - 18, midY - 5)
          ..lineTo(left + w - 10, midY)
          ..lineTo(left + w - 18, midY + 5);
        canvas.drawPath(arrowPath, arrowPaint);
      } else {
        canvas.drawCircle(Offset(left + w - 8, midY), 3.0, Paint()..color = strokeColor);
        canvas.drawLine(Offset(left + w - 8, midY), Offset(left + 12, midY), arrowPaint);
        final arrowPath = Path()
          ..moveTo(left + 18, midY - 5)
          ..lineTo(left + 10, midY)
          ..lineTo(left + 18, midY + 5);
        canvas.drawPath(arrowPath, arrowPaint);
      }
    } else {
      final stepCount = math.max(4, (h / stepPx).round());
      final dy = h / stepCount;
      for (int i = 1; i < stepCount; i++) {
        canvas.drawLine(
          Offset(left, top + i * dy),
          Offset(left + w, top + i * dy),
          stepPaint,
        );
      }

      final midX = left + w / 2;
      // En arquitectura: la escalera asciende desde la puerta (frente = top) hacia adentro (fondo = top + h)
      if (!flipY) {
        canvas.drawCircle(Offset(midX, top + 8), 3.0, Paint()..color = strokeColor);
        canvas.drawLine(Offset(midX, top + 8), Offset(midX, top + h - 12), arrowPaint);
        final arrowPath = Path()
          ..moveTo(midX - 5, top + h - 18)
          ..lineTo(midX, top + h - 10)
          ..lineTo(midX + 5, top + h - 18);
        canvas.drawPath(arrowPath, arrowPaint);
      } else {
        canvas.drawCircle(Offset(midX, top + h - 8), 3.0, Paint()..color = strokeColor);
        canvas.drawLine(Offset(midX, top + h - 8), Offset(midX, top + 12), arrowPaint);
        final arrowPath = Path()
          ..moveTo(midX - 5, top + 18)
          ..lineTo(midX, top + 10)
          ..lineTo(midX + 5, top + 18);
        canvas.drawPath(arrowPath, arrowPaint);
      }
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
      ..color = const Color(0xFFD7CCC8).withOpacity(0.4)
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
      ..color = const Color(0xFF81C784).withOpacity(0.5)
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

    if (type == 'BED') {
      _drawBedSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'SOFA' || type == 'ARMCHAIR') {
      _drawSofaSymbol(canvas, rect, borderPaint, detailPaint, bgPaint, isArmchair: type == 'ARMCHAIR');
    } else if (type == 'DINING_TABLE' || type == 'ROUND_TABLE' || type == 'COFFEE_TABLE') {
      _drawTableSymbol(canvas, rect, borderPaint, detailPaint, bgPaint, isRound: type == 'ROUND_TABLE');
    } else if (type == 'SINK_COUNTER') {
      _drawSinkCounterSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'STOVE') {
      _drawStoveSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'REFRIGERATOR') {
      _drawFridgeSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'TOILET') {
      _drawToiletSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'VANITY') {
      _drawVanitySymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'SHOWER') {
      _drawShowerSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'BATHTUB') {
      _drawBathtubSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'WARDROBE') {
      _drawWardrobeSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
    } else if (type == 'WASHING_MACHINE') {
      _drawWasherSymbol(canvas, rect, borderPaint, detailPaint, bgPaint);
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
    final isCompact = bb.width < 0.6 || bb.height < 0.6 ||
        module.moduleType.toUpperCase().contains('DOOR') ||
        module.moduleType.toUpperCase().contains('WINDOW');

    if (isCompact) {
      final dim = bb.width >= bb.height ? bb.width : bb.height;
      final typePrefix = module.moduleType.toUpperCase().contains('DOOR')
          ? 'P'
          : (module.moduleType.toUpperCase().contains('WINDOW') ? 'V' : '');
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
      Paint()..color = Colors.black.withOpacity(0.70),
    );

    textPainter.paint(canvas, textOffset);
  }

  static String _toCompactRoomName(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('LAVAD') || upper.contains('ROPAS')) return 'LAV.';
    if (upper.contains('BAÑO')) return 'BAÑO';
    if (upper.contains('COCINA')) return 'COCINA';
    if (upper.contains('ESCALERA')) return 'ESC.';
    if (upper.contains('ESTAR') || upper.contains('LIVING')) return 'ESTAR';
    if (upper.contains('COMEDOR')) return 'COMEDOR';
    if (upper.contains('DORMITORIO') || upper.contains('HABITACIÓN')) return 'DORM.';
    if (upper.contains('GARAJE') || upper.contains('COCHERA')) return 'GAR.';
    if (upper.contains('ESTUDIO') || upper.contains('OFICINA')) return 'ESTUDIO';
    if (upper.contains('PATIO') || upper.contains('JARDÍN')) return 'PATIO';
    if (upper.contains('TERRAZA') || upper.contains('BALCÓN')) return 'BALCÓN';
    return name.length > 7 ? '${name.substring(0, 6)}.' : name;
  }

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
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (rotateDegrees != 0.0) {
      canvas.rotate(rotateDegrees * math.pi / 180.0);
    }
    // Background pill
    final bgRect = Rect.fromCenter(center: Offset.zero, width: tp.width + 6, height: tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3)), Paint()..color = const Color(0xFF13161C).withOpacity(0.9));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawHatchPattern(
      Canvas canvas, Polygon2D polygon, double zoom, Color color) {
    final bb = polygon.boundingBox;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.clipPath(_polygonToPath(polygon, zoom));

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

  Path _polygonToPath(Polygon2D polygon, double zoom) {
    final path = Path();
    if (polygon.vertices.isEmpty) return path;

    final first = polygon.vertices.first;
    path.moveTo(first.x * zoom, first.y * zoom);

    for (int i = 1; i < polygon.vertices.length; i++) {
      final pt = polygon.vertices[i];
      path.lineTo(pt.x * zoom, pt.y * zoom);
    }
    path.close();
    return path;
  }

  void _drawNorthCompass(Canvas canvas, Size size, double orientationDegrees) {
    final center = Offset(size.width - 55, 45);
    const radius = 22.0;

    // Fondo circular translúcido
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF13161C).withOpacity(0.85),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Flecha girada según los grados de orientación al Norte
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final radians = (orientationDegrees - 90) * math.pi / 180.0;
    canvas.rotate(radians);

    // Triángulo rojo apuntando al norte
    final northPath = Path()
      ..moveTo(radius - 5, 0)
      ..lineTo(0, -4)
      ..lineTo(0, 4)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()..color = const Color(0xFFEF5350)..style = PaintingStyle.fill,
    );

    // Triángulo gris apuntando al sur
    final southPath = Path()
      ..moveTo(-radius + 5, 0)
      ..lineTo(0, -4)
      ..lineTo(0, 4)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()..color = const Color(0xFF90A4AE)..style = PaintingStyle.fill,
    );

    canvas.restore();

    // Etiqueta 'N'
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - radius - 14),
    );
  }

  @override
  bool shouldRepaint(covariant _Canvas2DPainter oldDelegate) => true;
}
