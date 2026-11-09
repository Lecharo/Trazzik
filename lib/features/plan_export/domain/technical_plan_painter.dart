import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/core/cad/cad_symbol_drawer.dart';
import 'package:trazzik/core/geometry/bounding_box_2d.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/plan_export/domain/plan_export_options.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/axonometric_canvas_3d.dart';
import 'package:trazzik/features/walls/domain/wall.dart';
import 'package:trazzik/features/walls/domain/wall_generation_engine.dart';

/// Painter de alta resolución para renderizado de planos arquitectónicos técnicos ejecutivos.
class TechnicalPlanPainter extends CustomPainter {
  final Floor floor;
  final List<Floor> allFloors;
  final Lot? lot;
  final PlanExportOptions options;

  TechnicalPlanPainter({
    required this.floor,
    this.allFloors = const [],
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

    // Si es Comparativa Levantamiento vs Propuesta, dividir lámina en 2 columnas
    if (options.discipline == PlanDiscipline.comparativeBeforeAfter) {
      _paintComparativeSplit(
        canvas,
        size,
        minX,
        maxX,
        minY,
        maxY,
        rangeX,
        rangeY,
        marginMeters,
      );
      return;
    }

    // Si es Maqueta Axonométrica 3D (PL-3D), renderizar doble vista 3D de alta resolución
    if (options.discipline == PlanDiscipline.axonometric3d) {
      _paintAxonometric3dSplit(canvas, size, rangeX, rangeY);
      return;
    }

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

    // 5. Dibujar Muros Arquitectónicos (explícitos o generados con el motor unificado)
    if (options.includeWalls) {
      final effectiveWalls = floor.walls.isNotEmpty
          ? floor.walls
          : WallGenerationEngine.generateWallsForFloor(floor);
      for (final wall in effectiveWalls) {
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

    // 6b. Capas técnicas por especialidad (Eléctrico, Hidrosanitario, Demolición, Acabados)
    _drawDisciplineLayer(canvas, toCanvas, scale, size);

    // 7. Dibujar Cotas Generales de Arquitectura
    if (options.includeDimensions) {
      _drawDimensions(canvas, toCanvas, scale, minX + marginMeters,
          maxX - marginMeters, minY + marginMeters, maxY - marginMeters);
    }

    // 8. Dibujar Rosa de los Vientos (North Arrow) y Barra de Escala Gráfica
    _drawNorthArrowAndScaleBar(canvas, size, scale);
  }

  /// Renderiza la lámina 3D dual: Maqueta de Corte Interior (1.20m) vs Volumetría Completa en Perspectiva Solar (2.60m).
  void _paintAxonometric3dSplit(
    Canvas canvas,
    Size size,
    double rangeX,
    double rangeY,
  ) {
    final effectiveLot = lot ??
        Lot(
          id: 'fallback-lot',
          projectId: 'p',
          boundary: floor.boundary,
        );
    final halfW = size.width / 2;
    const topBannerH = 38.0;
    const pad = 16.0;
    final viewW = halfW - 2 * pad;
    final viewH = size.height - topBannerH - 2 * pad;
    if (viewW <= 50 || viewH <= 50) return;

    final fitZoom = math
        .min(viewW / math.max(10.0, rangeX * 1.15),
            viewH / math.max(10.0, rangeY * 1.05))
        .clamp(18.0, 95.0);

    // Línea divisoria central
    final dividerPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(halfW, 12),
      Offset(halfW, size.height - 12),
      dividerPaint,
    );

    void renderViewport({
      required double panelLeft,
      required String title,
      required Color badgeColor,
      required List<Floor> targetFloors,
      required double wallHeight,
      required double explodedFactor,
      required double yaw,
      required double pitch,
      required bool isPerspective,
      required SunPreset3D sunPreset,
      required bool showLabels,
    }) {
      final headerRect = Rect.fromLTWH(panelLeft + pad, 10, viewW, 24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(headerRect, const Radius.circular(4)),
        Paint()..color = badgeColor.withValues(alpha: 0.12),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: badgeColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          headerRect.center.dx - tp.width / 2,
          headerRect.center.dy - tp.height / 2,
        ),
      );

      final viewportRect =
          Rect.fromLTWH(panelLeft + pad, topBannerH, viewW, viewH);
      final faces = Building3DBuilder.buildScene(
        floors: targetFloors,
        lot: effectiveLot,
        wallHeight: wallHeight,
        includeShadows: true,
        sunPreset: sunPreset,
      );
      final center3D = AxonometricSceneRenderer.computeSceneCenter(faces);

      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(viewportRect, const Radius.circular(6)),
      );
      canvas.translate(viewportRect.left, viewportRect.top);
      AxonometricSceneRenderer.paintScene(
        canvas: canvas,
        size: Size(viewW, viewH),
        faces: faces,
        sceneCenter: center3D,
        yaw: yaw,
        pitch: pitch,
        zoom: fitZoom,
        explodedFactor: explodedFactor,
        isPerspective: isPerspective,
        sunPreset: sunPreset,
        showLabels: showLabels,
        orientationDegrees: effectiveLot.orientationDegrees,
        isDarkTheme: false,
        drawBackground: true,
        drawCompass: true,
      );
      canvas.restore();

      canvas.drawRRect(
        RRect.fromRectAndRadius(viewportRect, const Radius.circular(6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFFCFD8DC),
      );
    }

    final stackedFloors = allFloors.isNotEmpty ? allFloors : <Floor>[floor];

    renderViewport(
      panelLeft: 0,
      title: '1. MAQUETA AXONOMÉTRICA DE CORTE INTERIOR (H = 1.20 m)',
      badgeColor: const Color(0xFF0284C7),
      targetFloors: [floor],
      wallHeight: 1.20,
      explodedFactor: 0.0,
      yaw: -0.35,
      pitch: 0.70,
      isPerspective: false,
      sunPreset: SunPreset3D.studioNoon,
      showLabels: true,
    );

    renderViewport(
      panelLeft: halfW,
      title: '2. VOLUMETRÍA COMPLETA Y ASOLEAMIENTO EN PERSPECTIVA (H = 2.60 m)',
      badgeColor: const Color(0xFF0F766E),
      targetFloors: stackedFloors,
      wallHeight: 2.60,
      explodedFactor: stackedFloors.length > 1 ? 0.22 : 0.0,
      yaw: 0.42,
      pitch: 0.72,
      isPerspective: true,
      sunPreset: SunPreset3D.goldenHourWest,
      showLabels: false,
    );
  }

  /// Renderiza la lámina comparativa lado a lado: Levantamiento (Izquierda) vs Propuesta (Derecha).
  void _paintComparativeSplit(
    Canvas canvas,
    Size size,
    double minX,
    double maxX,
    double minY,
    double maxY,
    double rangeX,
    double rangeY,
    double marginMeters,
  ) {
    final halfW = size.width / 2;
    final topBannerH = 32.0;
    final paddingPx = 24.0;
    final availW = halfW - 2 * paddingPx;
    final availH = size.height - topBannerH - 2 * paddingPx;

    final scale = math.min(availW / rangeX, availH / rangeY);

    // Línea divisoria central
    final dividerPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(halfW, 12),
      Offset(halfW, size.height - 12),
      dividerPaint,
    );

    void renderHalf({
      required double panelLeft,
      required String title,
      required Color badgeColor,
      required bool isBeforeState,
    }) {
      // Encabezado de columna
      final headerRect = Rect.fromLTWH(panelLeft + 24, 12, halfW - 48, 22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(headerRect, const Radius.circular(4)),
        Paint()..color = badgeColor.withValues(alpha: 0.12),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: badgeColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          headerRect.center.dx - tp.width / 2,
          headerRect.center.dy - tp.height / 2,
        ),
      );

      final offsetX = panelLeft + paddingPx + (availW - (rangeX * scale)) / 2;
      final offsetY = topBannerH + paddingPx + (availH - (rangeY * scale)) / 2;

      Offset toCanvas(double x, double y) => Offset(
            offsetX + (x - minX) * scale,
            offsetY + (y - minY) * scale,
          );

      if (lot != null && lot!.boundary.vertices.isNotEmpty) {
        _drawLot(canvas, lot!, toCanvas, scale);
      }

      for (final module in floor.modules) {
        if (isBeforeState && module.status == ElementStatus.isNew) {
          continue; // En estado actual no existen los recintos nuevos
        }
        if (!isBeforeState && module.status == ElementStatus.toDemolish) {
          continue; // En propuesta ya se demolieron
        }
        _drawModule(canvas, module, toCanvas, scale);
      }

      if (options.includeWalls) {
        final effectiveWalls = floor.walls.isNotEmpty
            ? floor.walls
            : WallGenerationEngine.generateWallsForFloor(floor);
        for (final wall in effectiveWalls) {
          if (isBeforeState && wall.status == ElementStatus.isNew) continue;
          if (!isBeforeState && wall.status == ElementStatus.toDemolish) continue;
          _drawWall(canvas, wall, toCanvas, scale);
        }
      }

      if (options.includeFurniture && !isBeforeState) {
        for (final module in floor.modules) {
          if (module.status == ElementStatus.toDemolish) continue;
          for (final sub in module.subModules) {
            _drawFurniture(canvas, module, sub, toCanvas, scale);
          }
        }
      }

      if (options.includeDimensions) {
        _drawDimensions(
          canvas,
          toCanvas,
          scale,
          minX + marginMeters,
          maxX - marginMeters,
          minY + marginMeters,
          maxY - marginMeters,
        );
      }
    }

    renderHalf(
      panelLeft: 0,
      title: '1. LEVANTAMIENTO ESTADO ACTUAL (EXISTENTE)',
      badgeColor: const Color(0xFF455A64),
      isBeforeState: true,
    );
    renderHalf(
      panelLeft: halfW,
      title: '2. PROPUESTA ARQUITECTÓNICA DE REMODELACIÓN',
      badgeColor: const Color(0xFF1A237E),
      isBeforeState: false,
    );

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
    if (lot.boundary.vertices.isEmpty) return;
    final path = CadSymbolDrawer.polygonToPathTransformed(lot.boundary, toCanvas);

    final lotFill = Paint()
      ..color = const Color(0xFFF9FBE7).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, lotFill);

    final lotBorder = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(path, lotBorder);

    // Retiros / Zonas normativas
    for (final zone in lot.zones) {
      if (zone.boundary.vertices.isEmpty) continue;
      final zPath = CadSymbolDrawer.polygonToPathTransformed(zone.boundary, toCanvas);

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

    final path = CadSymbolDrawer.polygonToPathTransformed(module.geometry, toCanvas);

    final bbox = module.geometry.boundingBox;
    final pMin = toCanvas(bbox.minX, bbox.minY);
    final pMax = toCanvas(bbox.maxX, bbox.maxY);
    final left = math.min(pMin.dx, pMax.dx);
    final top = math.min(pMin.dy, pMax.dy);
    final w = (pMax.dx - pMin.dx).abs();
    final h = (pMax.dy - pMin.dy).abs();

    if (module.isSlidingDoor) {
      CadSymbolDrawer.drawSlidingDoor(
        canvas,
        left,
        top,
        w,
        h,
        scale,
        const Color(0xFF263238),
      );
      return;
    }

    if (module.isGate) {
      CadSymbolDrawer.drawGate(
        canvas,
        left,
        top,
        w,
        h,
        scale,
        const Color(0xFF263238),
      );
      return;
    }

    if (module.isSwingDoor) {
      CadSymbolDrawer.drawSwingDoor(
        canvas,
        left,
        top,
        w,
        h,
        scale,
        const Color(0xFF263238),
        flipX: module.flipX,
        flipY: module.flipY,
        arcColor: const Color(0xFF455A64),
      );
      return;
    }

    if (module.isWindow) {
      CadSymbolDrawer.drawWindow(
        canvas,
        left,
        top,
        w,
        h,
        scale,
        const Color(0xFF263238),
        glassColor: const Color(0xFF0288D1),
        drawOuterFrame: true,
      );
      return;
    }

    if (module.isStairs) {
      CadSymbolDrawer.drawStairs(
        canvas,
        left,
        top,
        w,
        h,
        scale,
        const Color(0xFF37474F),
        flipX: module.flipX,
        flipY: module.flipY,
        backgroundColor: const Color(0xFFF5F5F5),
        arrowColor: const Color(0xFF00838F),
      );
      return;
    }

    // Color de relleno según estado arquitectónico y disciplina
    Color fillColor;
    Color strokeColor;
    if (options.discipline == PlanDiscipline.finishesSchedule) {
      final floorMat = FinishMaterialCatalog.resolveFloorForModule(module);
      fillColor = floorMat.baseColor.withValues(alpha: 0.35);
      strokeColor = const Color(0xFF263238);
    } else if (options.discipline == PlanDiscipline.demolitionMasonry) {
      switch (module.status) {
        case ElementStatus.toDemolish:
          fillColor = const Color(0xFFFFCDD2); // Rojo vivo demolición
          strokeColor = const Color(0xFFB71C1C);
          break;
        case ElementStatus.isNew:
          fillColor = const Color(0xFFE3F2FD); // Azul obra nueva
          strokeColor = const Color(0xFF0D47A1);
          break;
        default:
          fillColor = const Color(0xFFF5F5F5); // Gris neutro existente
          strokeColor = const Color(0xFF616161);
      }
    } else {
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
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // En modo Acabados, dibujar achurado técnico del piso (madera/porcelanato/hidráulico)
    if (options.discipline == PlanDiscipline.finishesSchedule) {
      final floorMat = FinishMaterialCatalog.resolveFloorForModule(module);
      canvas.save();
      canvas.clipPath(path);
      final hatchPaint = Paint()
        ..color = floorMat.accentColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      final step = math.max(8.0, scale * 0.45);
      for (double x = left; x <= left + w; x += step) {
        canvas.drawLine(Offset(x, top), Offset(x, top + h), hatchPaint);
      }
      if (floorMat.pattern != FinishPatternType.woodPlanks) {
        for (double y = top; y <= top + h; y += step) {
          canvas.drawLine(Offset(left, y), Offset(left + w, y), hatchPaint);
        }
      }
      canvas.restore();
    }

    // En modo Demolición, achurado diagonal rojo sobre áreas a demoler
    if (options.discipline == PlanDiscipline.demolitionMasonry &&
        module.status == ElementStatus.toDemolish) {
      canvas.save();
      canvas.clipPath(path);
      final hatchPaint = Paint()
        ..color = const Color(0xFFD32F2F).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      for (double d = -h; d <= w + h; d += 10.0) {
        canvas.drawLine(
          Offset(left + d, top),
          Offset(left + d - h, top + h),
          hatchPaint,
        );
      }
      canvas.restore();
    }

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

    String extraLine = nptText;
    if (options.discipline == PlanDiscipline.finishesSchedule) {
      final floorMat = FinishMaterialCatalog.resolveFloorForModule(module);
      final wallMat = FinishMaterialCatalog.resolveWallForModule(module);
      extraLine = 'Piso: ${floorMat.nameEs}\nMuro: ${wallMat.nameEs}';
    } else if (options.discipline == PlanDiscipline.demolitionMasonry) {
      extraLine = module.status == ElementStatus.toDemolish
          ? 'ESTADO: A DEMOLER'
          : (module.status == ElementStatus.isNew
              ? 'ESTADO: OBRA NUEVA'
              : 'ESTADO: CONSERVADO');
    }

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
          text: extraLine,
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
      Paint()..color = Colors.white.withValues(alpha: 0.92),
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
    final wallPath = CadSymbolDrawer.polygonToPathTransformed(wall.footprint, toCanvas);

    Color wallColor;
    if (wall.status == ElementStatus.toDemolish) {
      wallColor = const Color(0xFFD32F2F);
    } else if (options.discipline == PlanDiscipline.demolitionMasonry &&
        wall.status == ElementStatus.isNew) {
      wallColor = const Color(0xFF1565C0); // Azul intenso mampostería nueva
    } else if (wall.status == ElementStatus.preserved) {
      wallColor = const Color(0xFF546E7A);
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

  /// Dibuja la simbología específica según la especialidad seleccionada (Eléctrico, Hidrosanitario, Demolición, Acabados).
  void _drawDisciplineLayer(
    Canvas canvas,
    Offset Function(double, double) toCanvas,
    double scale,
    Size size,
  ) {
    switch (options.discipline) {
      case PlanDiscipline.electricalLighting:
        _drawElectricalLayer(canvas, toCanvas, scale, size);
        break;
      case PlanDiscipline.plumbingHydro:
        _drawPlumbingLayer(canvas, toCanvas, scale, size);
        break;
      case PlanDiscipline.demolitionMasonry:
        _drawDisciplineLegend(
          canvas,
          size,
          title: 'CONVENCIONES DEMOLICIÓN Y MAMPOSTERÍA',
          items: const [
            (Color(0xFFD32F2F), 'Muro / Elemento a Demoler'),
            (Color(0xFF1565C0), 'Mampostería Nueva a Construir'),
            (Color(0xFF546E7A), 'Estructura / Muro Existente Conservado'),
          ],
        );
        break;
      case PlanDiscipline.finishesSchedule:
        _drawDisciplineLegend(
          canvas,
          size,
          title: 'CUADRO TÉCNICO DE ACABADOS',
          items: const [
            (Color(0xFF1A237E), 'Piso y Muro especificados por recinto'),
            (Color(0xFF546E7A), 'Cantidades sincronizadas con Presupuesto BOQ'),
          ],
        );
        break;
      default:
        break;
    }
  }

  void _drawElectricalLayer(
    Canvas canvas,
    Offset Function(double, double) toCanvas,
    double scale,
    Size size,
  ) {
    final circuitPaint = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final fixturePaint = Paint()
      ..color = const Color(0xFFD84315)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final outletPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.fill;

    for (final module in floor.modules) {
      if (module.isOpening ||
          module.isStairs ||
          module.geometry.vertices.isEmpty ||
          module.status == ElementStatus.toDemolish) {
        continue;
      }
      final bbox = module.geometry.boundingBox;
      final center = toCanvas(
        (bbox.minX + bbox.maxX) / 2,
        (bbox.minY + bbox.maxY) / 2,
      );
      final pMin = toCanvas(bbox.minX, bbox.minY);
      final pMax = toCanvas(bbox.maxX, bbox.maxY);
      final left = math.min(pMin.dx, pMax.dx);
      final top = math.min(pMin.dy, pMax.dy);
      final right = math.max(pMin.dx, pMax.dx);
      final bottom = math.max(pMin.dy, pMax.dy);

      // 1. Luminaria LED central (Símbolo CAD ⊕)
      final lumOffset = Offset(center.dx, center.dy - 24);
      canvas.drawCircle(
        lumOffset,
        7.0,
        Paint()..color = const Color(0xFFFFF3E0),
      );
      canvas.drawCircle(lumOffset, 7.0, fixturePaint);
      canvas.drawLine(
        Offset(lumOffset.dx - 5, lumOffset.dy),
        Offset(lumOffset.dx + 5, lumOffset.dy),
        fixturePaint,
      );
      canvas.drawLine(
        Offset(lumOffset.dx, lumOffset.dy - 5),
        Offset(lumOffset.dx, lumOffset.dy + 5),
        fixturePaint,
      );

      // 2. Interruptor (S) en acceso del recinto y arco de circuito
      final switchPt = Offset(left + 12, bottom - 12);
      final arcPath = Path()
        ..moveTo(switchPt.dx, switchPt.dy)
        ..quadraticBezierTo(
          left + 14,
          lumOffset.dy,
          lumOffset.dx - 7,
          lumOffset.dy,
        );
      canvas.drawPath(arcPath, circuitPaint);

      final sPainter = TextPainter(
        text: const TextSpan(
          text: 'S',
          style: TextStyle(
            color: Color(0xFFE65100),
            fontWeight: FontWeight.w900,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sPainter.paint(canvas, Offset(switchPt.dx - 4, switchPt.dy - 5));

      // 3. Tomacorrientes dobles 110V (GFCI en zonas húmedas)
      final isWet = module.isWetCore;
      final outletPts = [
        Offset(right - 8, (top + bottom) / 2),
        Offset((left + right) / 2, top + 8),
      ];
      for (final pt in outletPts) {
        canvas.drawCircle(pt, 4.0, outletPaint);
        final label = TextPainter(
          text: TextSpan(
            text: isWet ? '110V GFCI' : '110V',
            style: const TextStyle(
              color: Color(0xFF0D47A1),
              fontSize: 6.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(pt.dx - label.width / 2, pt.dy + 5));
      }
    }

    _drawDisciplineLegend(
      canvas,
      size,
      title: 'CONVENCIONES CABLEADO E ILUMINACIÓN',
      items: const [
        (Color(0xFFD84315), '⊕ Luminaria Plafón / Bala LED Techo'),
        (Color(0xFFE65100), 'S Interruptor Simple + Circuito Conmutado'),
        (Color(0xFF1565C0), '● Tomacorriente Doble 110V / GFCI'),
      ],
    );
  }

  void _drawPlumbingLayer(
    Canvas canvas,
    Offset Function(double, double) toCanvas,
    double scale,
    Size size,
  ) {
    final coldPaint = Paint()
      ..color = const Color(0xFF0288D1)
      ..style = PaintingStyle.fill;
    final hotPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;
    final drainPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (final module in floor.modules) {
      if (module.status == ElementStatus.toDemolish) continue;
      for (final sub in module.subModules) {
        final t = sub.type.toUpperCase();
        final isPlumbing = t.contains('TOILET') ||
            t.contains('SINK') ||
            t.contains('VANITY') ||
            t.contains('WASH') ||
            t.contains('SHOWER') ||
            t.contains('BATHTUB');
        if (!isPlumbing) continue;

        final bbox = sub.geometry.boundingBox;
        final center = toCanvas(
          (bbox.minX + bbox.maxX) / 2,
          (bbox.minY + bbox.maxY) / 2,
        );

        // Punto Agua Fría (AF Ø1/2")
        final afPt = Offset(center.dx - 7, center.dy - 7);
        canvas.drawCircle(afPt, 4.0, coldPaint);

        // Punto Agua Caliente (AC Ø1/2") excepto en inodoro
        if (!t.contains('TOILET')) {
          final acPt = Offset(center.dx + 7, center.dy - 7);
          canvas.drawCircle(acPt, 4.0, hotPaint);
        }

        // Desagüe Sanitario (DS Ø4" inodoro / Ø2" resto)
        final dsPt = Offset(center.dx, center.dy + 6);
        canvas.drawCircle(dsPt, 5.0, drainPaint);

        final pipeLabel = TextPainter(
          text: TextSpan(
            text: t.contains('TOILET') ? 'AF + DS Ø4"' : 'AF/AC + DS Ø2"',
            style: const TextStyle(
              color: Color(0xFF1B5E20),
              fontSize: 6.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        pipeLabel.paint(
          canvas,
          Offset(center.dx - pipeLabel.width / 2, dsPt.dy + 6),
        );
      }
    }

    _drawDisciplineLegend(
      canvas,
      size,
      title: 'CONVENCIONES RED HIDROSANITARIA',
      items: const [
        (Color(0xFF0288D1), '● Punto Agua Fría Presurizada (AF Ø1/2" PVC)'),
        (Color(0xFFD32F2F), '● Punto Agua Caliente (AC Ø1/2" CPVC)'),
        (Color(0xFF2E7D32), '○ Desagüe Sanitario (DS Ø2" / Ø4" PVC)'),
      ],
    );
  }

  void _drawDisciplineLegend(
    Canvas canvas,
    Size size, {
    required String title,
    required List<(Color, String)> items,
  }) {
    const boxW = 240.0;
    final boxH = 24.0 + items.length * 15.0;
    final rect = Rect.fromLTWH(size.width - boxW - 20, size.height - boxH - 18, boxW, boxH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFF90A4AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    final titleTp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFF1A237E),
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(rect.left + 8, rect.top + 6));

    for (var i = 0; i < items.length; i++) {
      final y = rect.top + 21 + i * 14.0;
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 8, y + 1, 8, 8),
        Paint()..color = items[i].$1,
      );
      final itemTp = TextPainter(
        text: TextSpan(
          text: items[i].$2,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 7.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      itemTp.paint(canvas, Offset(rect.left + 20, y));
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
    } else if (type.contains('WASHING_MACHINE')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      final drumRadius = math.min(w, h) * 0.32;
      final center = Offset(left + w / 2, top + h / 2);
      canvas.drawCircle(center, drumRadius, linePaint);
      canvas.drawCircle(center, drumRadius * 0.6, linePaint);
    } else if (type.contains('SINK') || type.contains('VANITY') || type.contains('WASH')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      // Bacha interior
      canvas.drawOval(
        Rect.fromLTWH(left + w * 0.15, top + h * 0.15, w * 0.7, h * 0.7),
        linePaint,
      );
    } else if (type.contains('REFRIGERATOR') || type.contains('FRIDGE')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      final doorY = top + h * 0.35;
      canvas.drawLine(Offset(left, doorY), Offset(left + w, doorY), linePaint);
    } else if (type.contains('BATHTUB')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 2, top + 2, math.max(1.0, w - 4), math.max(1.0, h - 4)),
          const Radius.circular(6),
        ),
        linePaint,
      );
    } else if (type.contains('WARDROBE') || type.contains('CLOSET')) {
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), fillPaint);
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), linePaint);
      canvas.drawLine(Offset(left, top), Offset(left + w, top + h), linePaint);
      canvas.drawLine(Offset(left, top + h / 2), Offset(left + w, top + h / 2), linePaint);
    } else if (type == 'CAR') {
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(5));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, linePaint);
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
    final leftPt = Offset(
      northCenter.dx - (arrowRadius * 0.35) * math.cos(rot),
      northCenter.dy - (arrowRadius * 0.35) * math.sin(rot),
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
