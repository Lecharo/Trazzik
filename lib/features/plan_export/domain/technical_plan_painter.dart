import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/bounding_box_2d.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/plan_export/domain/plan_export_options.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

/// Painter de alta resolución para renderizado de planos arquitectónicos técnicos ejecutivos.
class TechnicalPlanPainter extends CustomPainter {
  final Floor floor;
  final Lot? lot;
  final PlanExportOptions options;

  TechnicalPlanPainter({
    required this.floor,
    this.lot,
    required this.options,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fondo blanco puro de lámina técnica
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Calcular límites y encuadre del plano
    final bboxes = <BoundingBox2D>[];
    if (lot != null && lot!.boundary.vertices.isNotEmpty) {
      bboxes.add(lot!.boundary.boundingBox);
    }
    if (floor.boundary.vertices.isNotEmpty) {
      bboxes.add(floor.boundary.boundingBox);
    }
    for (final m in floor.modules) {
      if (m.geometry.vertices.isNotEmpty) {
        bboxes.add(m.geometry.boundingBox);
      }
    }

    if (bboxes.isEmpty) {
      _drawNoDataNotice(canvas, size);
      return;
    }

    double minX = bboxes.map((b) => b.minX).reduce(math.min);
    double minY = bboxes.map((b) => b.minY).reduce(math.min);
    double maxX = bboxes.map((b) => b.maxX).reduce(math.max);
    double maxY = bboxes.map((b) => b.maxY).reduce(math.max);

    // Margen de seguridad en metros para cotas y ejes
    final marginMeters = 1.20;
    minX -= marginMeters;
    minY -= marginMeters;
    maxX += marginMeters;
    maxY += marginMeters;

    final rangeX = math.max(1.0, maxX - minX);
    final rangeY = math.max(1.0, maxY - minY);

    // Margen perimetral en la lámina (px)
    final paddingPx = 36.0;
    final availWidth = size.width - 2 * paddingPx;
    final availHeight = size.height - 2 * paddingPx;

    final scaleX = availWidth / rangeX;
    final scaleY = availHeight / rangeY;
    final scale = math.min(scaleX, scaleY);

    // Centrado de la composición
    final offsetX = paddingPx + (availWidth - (rangeX * scale)) / 2;
    final offsetY = paddingPx + (availHeight - (rangeY * scale)) / 2;

    Offset toCanvas(double x, double y) {
      return Offset(
        offsetX + (x - minX) * scale,
        offsetY + (y - minY) * scale,
      );
    }

    // 3. Dibujar Lote y Retiros Reglamentarios
    if (lot != null && lot!.boundary.vertices.isNotEmpty) {
      _drawLot(canvas, lot!, toCanvas, scale);
    }

    // 4. Dibujar Espacios Arquitectónicos (Recintos)
    for (final module in floor.modules) {
      _drawModule(canvas, module, toCanvas, scale);
    }

    // 5. Dibujar Muros Arquitectónicos
    if (options.includeWalls && floor.walls.isNotEmpty) {
      for (final wall in floor.walls) {
        _drawWall(canvas, wall, toCanvas, scale);
      }
    }

    // 6. Dibujar Mobiliario y Equipamiento Interior
    if (options.includeFurniture) {
      for (final module in floor.modules) {
        for (final sub in module.subModules) {
          _drawFurniture(canvas, module, sub, toCanvas, scale);
        }
      }
    }

    // 7. Dibujar Cotas Generales de Arquitectura
    if (options.includeDimensions) {
      _drawDimensions(canvas, toCanvas, scale, minX + marginMeters,
          maxX - marginMeters, minY + marginMeters, maxY - marginMeters);
    }

    // 8. Dibujar Rosa de los Vientos (North Arrow) y Barra de Escala Gráfica
    _drawNorthArrowAndScaleBar(canvas, size, scale);
  }

  void _drawNoDataNotice(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Sin elementos para proyectar en lámina.',
        style: TextStyle(color: Colors.black54, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2),
    );
  }

  void _drawLot(
      Canvas canvas, Lot lot, Offset Function(double, double) toCanvas, double scale) {
    // Línea Municipal / Límite de Propiedad
    final path = Path();
    final pts = lot.boundary.vertices.map((p) => toCanvas(p.x, p.y)).toList();
    if (pts.isEmpty) return;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    final lotFill = Paint()
      ..color = const Color(0xFFF9FBE7).withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, lotFill);

    final lotBorder = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(path, lotBorder);

    // Retiros / Zonas normativas
    for (final zone in lot.zones) {
      final zPath = Path();
      final zPts = zone.boundary.vertices.map((p) => toCanvas(p.x, p.y)).toList();
      if (zPts.isEmpty) continue;
      zPath.moveTo(zPts.first.dx, zPts.first.dy);
      for (int i = 1; i < zPts.length; i++) {
        zPath.lineTo(zPts[i].dx, zPts[i].dy);
      }
      zPath.close();

      final dashPaint = Paint()
        ..color = const Color(0xFF757575)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(zPath, dashPaint);
    }
  }

  void _drawModule(Canvas canvas, Module module,
      Offset Function(double, double) toCanvas, double scale) {
    if (module.geometry.vertices.isEmpty) return;

    final isDoor = module.moduleType.toUpperCase().contains('DOOR');
    final isWindow = module.moduleType.toUpperCase().contains('WINDOW');
    final isStairs = module.moduleType.toUpperCase().contains('STAIR');

    final pts = module.geometry.vertices.map((p) => toCanvas(p.x, p.y)).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    final bbox = module.geometry.boundingBox;
    final pMin = toCanvas(bbox.minX, bbox.minY);
    final pMax = toCanvas(bbox.maxX, bbox.maxY);
    final left = math.min(pMin.dx, pMax.dx);
    final top = math.min(pMin.dy, pMax.dy);
    final w = (pMax.dx - pMin.dx).abs();
    final h = (pMax.dy - pMin.dy).abs();

    if (isDoor) {
      _drawSwingDoor(canvas, left, top, w, h, scale, module.flipX, module.flipY);
      return;
    }

    if (isWindow) {
      _drawWindow(canvas, left, top, w, h, scale);
      return;
    }

    if (isStairs) {
      _drawStairs(canvas, left, top, w, h, scale, module.flipX, module.flipY);
      return;
    }

    // Color de relleno según estado arquitectónico
    Color fillColor;
    Color strokeColor;
    switch (module.status) {
      case ElementStatus.toDemolish:
        fillColor = const Color(0xFFFFEBEE); // Rojo tenue demolición
        strokeColor = const Color(0xFFC62828);
        break;
      case ElementStatus.preserved:
        fillColor = const Color(0xFFE8F5E9); // Verde tenue existente conservado
        strokeColor = const Color(0xFF2E7D32);
        break;
      default:
        fillColor = const Color(0xFFF5F7FA); // Blanco neutro técnico
        strokeColor = const Color(0xFF263238);
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, strokePaint);

    // Etiqueta del Local (Nombre y Área en m²)
    _drawModuleTag(canvas, module, left + w / 2, top + h / 2, scale);
  }

  void _drawModuleTag(
      Canvas canvas, Module module, double cx, double cy, double scale) {
    final name = module.name.toUpperCase();
    final areaText = '${module.area.toStringAsFixed(2)} m²';
    final nptText = 'N.P.T. +${floor.levelMeters.toStringAsFixed(2)}';

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$name\n',
          style: const TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '$areaText\n',
          style: const TextStyle(
            color: Color(0xFF263238),
            fontWeight: FontWeight.w600,
            fontSize: 9,
          ),
        ),
        TextSpan(
          text: nptText,
          style: const TextStyle(
            color: Color(0xFF546E7A),
            fontSize: 7.5,
          ),
        ),
      ],
    );

    final tp = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    // Fondo blanco protector para legibilidad sobre muebles
    final bgRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: tp.width + 8,
      height: tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
      Paint()
        ..color = const Color(0xFFCFD8DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawWall(Canvas canvas, Wall wall,
      Offset Function(double, double) toCanvas, double scale) {
    final p1 = toCanvas(wall.startPoint.x, wall.startPoint.y);
    final p2 = toCanvas(wall.endPoint.x, wall.endPoint.y);

    final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    final perpAngle = angle + math.pi / 2;
    final halfThickness = (wall.thickness * scale) / 2;

    final dx = math.cos(perpAngle) * halfThickness;
    final dy = math.sin(perpAngle) * halfThickness;

    final wallPath = Path()
      ..moveTo(p1.dx + dx, p1.dy + dy)
      ..lineTo(p2.dx + dx, p2.dy + dy)
      ..lineTo(p2.dx - dx, p2.dy - dy)
      ..lineTo(p1.dx - dx, p1.dy - dy)
      ..close();

    Color wallColor;
    if (wall.status == ElementStatus.toDemolish) {
      wallColor = const Color(0xFFD32F2F);
    } else if (wall.status == ElementStatus.preserved) {
      wallColor = const Color(0xFF37474F);
    } else {
      wallColor = const Color(0xFF1A1A1A); // Negro puro muro cortado CAD
    }

    final fillPaint = Paint()
      ..color = wallColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(wallPath, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(wallPath, strokePaint);
  }

  void _drawSwingDoor(Canvas canvas, double left, double top, double w,
      double h, double scale, bool flipX, bool flipY) {
    final isHorizontal = w >= h;
    final arcPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final leafPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 0.04 * scale);

    final jambPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;

    if (isHorizontal) {
      final jambW = math.min(w * 0.08, math.max(2.5, 0.05 * scale));
      canvas.drawRect(Rect.fromLTWH(left, top, jambW, h), jambPaint);
      canvas.drawRect(Rect.fromLTWH(left + w - jambW, top, jambW, h), jambPaint);

      final hingeX = flipX ? (left + w - jambW) : (left + jambW);
      final hingeY = flipY ? top : (top + h);
      final doorLength = w - 2 * jambW;
      final targetY = flipY ? (hingeY + doorLength) : (hingeY - doorLength);

      canvas.drawLine(Offset(hingeX, hingeY), Offset(hingeX, targetY), leafPaint);

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
      final jambH = math.min(h * 0.08, math.max(2.5, 0.05 * scale));
      canvas.drawRect(Rect.fromLTWH(left, top, w, jambH), jambPaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - jambH, w, jambH), jambPaint);

      final hingeX = flipX ? left : (left + w);
      final hingeY = flipY ? (top + h - jambH) : (top + jambH);
      final doorLength = h - 2 * jambH;
      final targetX = flipX ? (hingeX + doorLength) : (hingeX - doorLength);

      canvas.drawLine(Offset(hingeX, hingeY), Offset(targetX, hingeY), leafPaint);

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

  void _drawWindow(Canvas canvas, double left, double top, double w, double h,
      double scale) {
    final isHorizontal = w >= h;
    final wallCapPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;
    final glassPaint = Paint()
      ..color = const Color(0xFF0288D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final framePaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    if (isHorizontal) {
      final capW = math.max(3.0, 0.05 * scale);
      canvas.drawRect(Rect.fromLTWH(left, top, capW, h), wallCapPaint);
      canvas.drawRect(Rect.fromLTWH(left + w - capW, top, capW, h), wallCapPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), framePaint);

      final midY1 = top + h * 0.35;
      final midY2 = top + h * 0.65;
      canvas.drawLine(Offset(left + capW, midY1), Offset(left + w - capW, midY1), glassPaint);
      canvas.drawLine(Offset(left + capW, midY2), Offset(left + w - capW, midY2), glassPaint);
    } else {
      final capH = math.max(3.0, 0.05 * scale);
      canvas.drawRect(Rect.fromLTWH(left, top, w, capH), wallCapPaint);
      canvas.drawRect(Rect.fromLTWH(left, top + h - capH, w, capH), wallCapPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), framePaint);

      final midX1 = left + w * 0.35;
      final midX2 = left + w * 0.65;
      canvas.drawLine(Offset(midX1, top + capH), Offset(midX1, top + h - capH), glassPaint);
      canvas.drawLine(Offset(midX2, top + capH), Offset(midX2, top + h - capH), glassPaint);
    }
  }

  void _drawStairs(Canvas canvas, double left, double top, double w, double h,
      double scale, bool flipX, bool flipY) {
    final bgPaint = Paint()..color = const Color(0xFFF5F5F5);
    final borderPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final treadPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final arrowPaint = Paint()
      ..color = const Color(0xFF00838F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawRect(Rect.fromLTWH(left, top, w, h), bgPaint);
    canvas.drawRect(Rect.fromLTWH(left, top, w, h), borderPaint);

    final isHorizontal = w >= h;
    const numSteps = 10;

    if (isHorizontal) {
      final stepW = w / numSteps;
      for (int i = 1; i < numSteps; i++) {
        final x = left + i * stepW;
        canvas.drawLine(Offset(x, top), Offset(x, top + h), treadPaint);
      }
      final midY = top + h / 2;
      final startX = flipX ? (left + w * 0.85) : (left + w * 0.15);
      final endX = flipX ? (left + w * 0.15) : (left + w * 0.85);

      canvas.drawLine(Offset(startX, midY), Offset(endX, midY), arrowPaint);
      final arrowHeadSize = math.min(10.0, stepW * 0.8);
      final headDir = flipX ? 1.0 : -1.0;
      canvas.drawLine(
        Offset(endX, midY),
        Offset(endX + headDir * arrowHeadSize, midY - arrowHeadSize * 0.6),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(endX, midY),
        Offset(endX + headDir * arrowHeadSize, midY + arrowHeadSize * 0.6),
        arrowPaint,
      );
    } else {
      final stepH = h / numSteps;
      for (int i = 1; i < numSteps; i++) {
        final y = top + i * stepH;
        canvas.drawLine(Offset(left, y), Offset(left + w, y), treadPaint);
      }
      final midX = left + w / 2;
      final startY = flipY ? (top + h * 0.15) : (top + h * 0.85);
      final endY = flipY ? (top + h * 0.85) : (top + h * 0.15);

      canvas.drawLine(Offset(midX, startY), Offset(midX, endY), arrowPaint);
      final arrowHeadSize = math.min(10.0, stepH * 0.8);
      final headDir = flipY ? -1.0 : 1.0;
      canvas.drawLine(
        Offset(midX, endY),
        Offset(midX - arrowHeadSize * 0.6, endY + headDir * arrowHeadSize),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(midX, endY),
        Offset(midX + arrowHeadSize * 0.6, endY + headDir * arrowHeadSize),
        arrowPaint,
      );
    }
  }

  void _drawFurniture(Canvas canvas, Module module, SubModule sub,
      Offset Function(double, double) toCanvas, double scale) {
    final bbox = sub.geometry.boundingBox;
    final pMin = toCanvas(bbox.minX, bbox.minY);
    final pMax = toCanvas(bbox.maxX, bbox.maxY);
    final left = math.min(pMin.dx, pMax.dx);
    final top = math.min(pMin.dy, pMax.dy);
    final w = (pMax.dx - pMin.dx).abs();
    final h = (pMax.dy - pMin.dy).abs();

    final linePaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final fillPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..style = PaintingStyle.fill;

    final type = sub.type.toUpperCase();

    if (type.contains('BED')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(3)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(3)),
        linePaint,
      );
      // Almohadas y dobladillo
      final isVertical = h >= w;
      if (isVertical) {
        final pillowH = h * 0.22;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + w * 0.1, top + h * 0.05, w * 0.8, pillowH),
            const Radius.circular(2),
          ),
          linePaint,
        );
        canvas.drawLine(Offset(left, top + h * 0.35), Offset(left + w, top + h * 0.35), linePaint);
      } else {
        final pillowW = w * 0.22;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + w * 0.05, top + h * 0.1, pillowW, h * 0.8),
            const Radius.circular(2),
          ),
          linePaint,
        );
        canvas.drawLine(Offset(left + w * 0.35, top), Offset(left + w * 0.35, top + h), linePaint);
      }
    } else if (type.contains('SOFA')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(3)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(3)),
        linePaint,
      );
      // Respaldo y apoyabrazos
      final isHoriz = w >= h;
      if (isHoriz) {
        canvas.drawRect(Rect.fromLTWH(left, top, w, h * 0.25), linePaint);
        canvas.drawRect(Rect.fromLTWH(left, top, w * 0.15, h), linePaint);
        canvas.drawRect(Rect.fromLTWH(left + w * 0.85, top, w * 0.15, h), linePaint);
      } else {
        canvas.drawRect(Rect.fromLTWH(left, top, w * 0.25, h), linePaint);
        canvas.drawRect(Rect.fromLTWH(left, top, w, h * 0.15), linePaint);
        canvas.drawRect(Rect.fromLTWH(left, top + h * 0.85, w, h * 0.15), linePaint);
      }
    } else if (type.contains('TABLE') || type.contains('DINING')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(4)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(4)),
        linePaint,
      );
      // Sillas esquemáticas alrededor
      final chairPaint = Paint()
        ..color = const Color(0xFF607D8B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      final cSize = math.min(w, h) * 0.25;
      canvas.drawCircle(Offset(left + w / 2, top - cSize / 2), cSize / 2, chairPaint);
      canvas.drawCircle(Offset(left + w / 2, top + h + cSize / 2), cSize / 2, chairPaint);
    } else if (type.contains('TOILET')) {
      // Inodoro con cisterna y taza elíptica
      final tankH = h * 0.3;
      canvas.drawRect(Rect.fromLTWH(left, top, w, tankH), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, tankH), linePaint);
      canvas.drawOval(
        Rect.fromLTWH(left + w * 0.1, top + tankH, w * 0.8, h - tankH),
        fillPaint,
      );
      canvas.drawOval(
        Rect.fromLTWH(left + w * 0.1, top + tankH, w * 0.8, h - tankH),
        linePaint,
      );
    } else if (type.contains('SINK') || type.contains('WASH')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      // Bacha interior
      canvas.drawOval(
        Rect.fromLTWH(left + w * 0.15, top + h * 0.15, w * 0.7, h * 0.7),
        linePaint,
      );
    } else if (type.contains('STOVE')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      // 4 quemadores
      final r = math.min(w, h) * 0.15;
      canvas.drawCircle(Offset(left + w * 0.3, top + h * 0.3), r, linePaint);
      canvas.drawCircle(Offset(left + w * 0.7, top + h * 0.3), r, linePaint);
      canvas.drawCircle(Offset(left + w * 0.3, top + h * 0.7), r, linePaint);
      canvas.drawCircle(Offset(left + w * 0.7, top + h * 0.7), r, linePaint);
    } else if (type.contains('SHOWER')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      // Cruz de caída de pendiente
      canvas.drawLine(Offset(left, top), Offset(left + w, top + h), linePaint);
      canvas.drawLine(Offset(left + w, top), Offset(left, top + h), linePaint);
      canvas.drawCircle(Offset(left + w / 2, top + h / 2), 3.0, linePaint);
    } else {
      // Artefacto / mueble genérico
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      canvas.drawLine(Offset(left, top), Offset(left + w, top + h), linePaint);
      canvas.drawLine(Offset(left + w, top), Offset(left, top + h), linePaint);
    }
  }

  void _drawDimensions(
      Canvas canvas,
      Offset Function(double, double) toCanvas,
      double scale,
      double minX,
      double maxX,
      double minY,
      double maxY) {
    final dimPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    void drawDimLine(
        Offset start, Offset end, String text, bool isHoriz) {
      canvas.drawLine(start, end, dimPaint);

      // Ticks arquitectónicos a 45°
      final tickLen = 4.0;
      canvas.drawLine(
        Offset(start.dx - tickLen, start.dy + tickLen),
        Offset(start.dx + tickLen, start.dy - tickLen),
        dimPaint,
      );
      canvas.drawLine(
        Offset(end.dx - tickLen, end.dy + tickLen),
        Offset(end.dx + tickLen, end.dy - tickLen),
        dimPaint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      if (isHoriz) {
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height - 2));
      } else {
        tp.paint(canvas, Offset(mid.dx + 4, mid.dy - tp.height / 2));
      }
    }

    // Cota horizontal general (ancho total)
    final widthM = (maxX - minX);
    final pBotLeft = toCanvas(minX, maxY + 0.40);
    final pBotRight = toCanvas(maxX, maxY + 0.40);
    drawDimLine(pBotLeft, pBotRight, '${widthM.toStringAsFixed(2)} m', true);

    // Cota vertical general (largo total)
    final heightM = (maxY - minY);
    final pRightTop = toCanvas(maxX + 0.40, minY);
    final pRightBottom = toCanvas(maxX + 0.40, maxY);
    drawDimLine(pRightTop, pRightBottom, '${heightM.toStringAsFixed(2)} m', false);
  }

  void _drawNorthArrowAndScaleBar(Canvas canvas, Size size, double scale) {
    // 1. Rosa de los vientos (Norte) en esquina superior derecha
    final northCenter = Offset(size.width - 45, 45);
    final arrowRadius = 22.0;

    final circlePaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(northCenter, arrowRadius, circlePaint);

    final rot = (lot?.orientationDegrees ?? 0.0) * math.pi / 180.0;
    final topPt = Offset(
      northCenter.dx + arrowRadius * 0.9 * math.sin(rot),
      northCenter.dy - arrowRadius * 0.9 * math.cos(rot),
    );
    final botPt = Offset(
      northCenter.dx - arrowRadius * 0.9 * math.sin(rot),
      northCenter.dy + arrowRadius * 0.9 * math.cos(rot),
    );
    final leftPt = Offset(
      northCenter.dx - (arrowRadius * 0.35) * math.cos(rot),
      northCenter.dy - (arrowRadius * 0.35) * math.sin(rot),
    );
    final rightPt = Offset(
      northCenter.dx + (arrowRadius * 0.35) * math.cos(rot),
      northCenter.dy + (arrowRadius * 0.35) * math.sin(rot),
    );

    // Triángulo negro apuntando al norte
    final northPath = Path()
      ..moveTo(topPt.dx, topPt.dy)
      ..lineTo(leftPt.dx, leftPt.dy)
      ..lineTo(northCenter.dx, northCenter.dy)
      ..close();
    canvas.drawPath(northPath, Paint()..color = const Color(0xFF263238));

    // Letra N
    final nPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFF1A237E),
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nPainter.paint(
      canvas,
      Offset(topPt.dx - nPainter.width / 2, topPt.dy - nPainter.height - 2),
    );

    // 2. Escala Gráfica en esquina inferior izquierda (0 a 5 metros)
    final barLeft = 45.0;
    final barBottom = size.height - 20.0;
    final oneMeterPx = scale; // 1 metro en escala visual
    final fiveMetersPx = oneMeterPx * 5.0;

    if (fiveMetersPx > 20 && fiveMetersPx < size.width * 0.4) {
      final barPaint = Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawRect(Rect.fromLTWH(barLeft, barBottom, fiveMetersPx, 4), strokePaint);

      // Alternar segmentos blanco/negro de 1m
      for (int i = 0; i < 5; i++) {
        if (i % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(barLeft + i * oneMeterPx, barBottom, oneMeterPx, 4),
            barPaint,
          );
        }
      }

      final scaleText = TextPainter(
        text: TextSpan(
          text: '0    1m        ${options.scaleLabel}        5m',
          style: const TextStyle(
            color: Color(0xFF37474F),
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      scaleText.paint(canvas, Offset(barLeft, barBottom - scaleText.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant TechnicalPlanPainter oldDelegate) {
    return oldDelegate.floor != floor ||
        oldDelegate.lot != lot ||
        oldDelegate.options != options;
  }
}
