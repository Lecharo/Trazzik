import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';

/// Interactive 3D axonometric canvas with 360° orbit, zoom, procedural surface
/// textures, and 3D polygon hit-testing for live finish configuration.
class AxonometricCanvas3D extends StatefulWidget {
  final List<Face3D> faces;
  final double yaw; // Horizontal angle (radians)
  final double pitch; // Vertical angle (radians)
  final double zoom; // Scale in pixels per meter
  final Offset panOffset;
  final int cameraRevision;
  final double orientationDegrees;
  final Function(double newYaw, double newPitch)? onOrbitChanged;
  final Function(double newZoom)? onZoomChanged;
  final Function(Offset newPan)? onPanChanged;
  final void Function(String? moduleId, String? floorId, bool isWallFace)?
      onSurfaceTapped;
  final String? selectedModuleId;
  final bool showLabels;

  const AxonometricCanvas3D({
    super.key,
    required this.faces,
    this.yaw = -0.35,
    this.pitch = 0.70, // ~40° front axonometric tilt
    this.zoom = 48.0,
    this.panOffset = Offset.zero,
    this.cameraRevision = 0,
    this.orientationDegrees = 0.0,
    this.onOrbitChanged,
    this.onZoomChanged,
    this.onPanChanged,
    this.onSurfaceTapped,
    this.selectedModuleId,
    this.showLabels = false,
  });

  @override
  State<AxonometricCanvas3D> createState() => _AxonometricCanvas3DState();
}

class _Viewport3D {
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;

  const _Viewport3D({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
  });

  _Viewport3D copyWith({
    double? yaw,
    double? pitch,
    double? zoom,
    Offset? pan,
  }) {
    return _Viewport3D(
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      zoom: zoom ?? this.zoom,
      pan: pan ?? this.pan,
    );
  }
}

class _AxonometricCanvas3DState extends State<AxonometricCanvas3D> {
  late final ValueNotifier<_Viewport3D> _viewportNotifier;
  late Point3D _sceneCenter;
  double _baseZoom = 48.0;

  static Point3D _computeSceneCenter(List<Face3D> faces) {
    double avgX = 0, avgY = 0, avgZ = 0;
    int pointCount = 0;
    for (final face in faces) {
      for (final v in face.vertices) {
        avgX += v.x;
        avgY += v.y;
        avgZ += v.z;
        pointCount++;
      }
    }
    return pointCount > 0
        ? Point3D(avgX / pointCount, avgY / pointCount, avgZ / pointCount)
        : const Point3D(5, 7.5, 2.5);
  }

  @override
  void initState() {
    super.initState();
    _sceneCenter = _computeSceneCenter(widget.faces);
    _viewportNotifier = ValueNotifier(
      _Viewport3D(
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        pan: widget.panOffset,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AxonometricCanvas3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.faces, oldWidget.faces)) {
      _sceneCenter = _computeSceneCenter(widget.faces);
    }
    final cameraControlledExternally =
        widget.cameraRevision != oldWidget.cameraRevision ||
            widget.yaw != oldWidget.yaw ||
            widget.pitch != oldWidget.pitch ||
            widget.zoom != oldWidget.zoom ||
            widget.panOffset != oldWidget.panOffset;
    if (cameraControlledExternally) {
      _viewportNotifier.value = _Viewport3D(
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        pan: widget.panOffset,
      );
    }
  }

  @override
  void dispose() {
    _viewportNotifier.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details, Size canvasSize) {
    if (widget.onSurfaceTapped == null) return;
    final tapPos = details.localPosition;
    final viewport = _viewportNotifier.value;
    final center = Offset(
      canvasSize.width / 2 + viewport.pan.dx,
      canvasSize.height / 2 + viewport.pan.dy,
    );
    final cosYaw = math.cos(viewport.yaw);
    final sinYaw = math.sin(viewport.yaw);
    final cosPitch = math.cos(viewport.pitch);
    final sinPitch = math.sin(viewport.pitch);

    (Offset, double) project(Point3D p) {
      final rx = p.x - _sceneCenter.x;
      final ry = p.y - _sceneCenter.y;
      final rz = p.z - _sceneCenter.z;
      final x1 = rx * cosYaw - ry * sinYaw;
      final y1 = rx * sinYaw + ry * cosYaw;
      final z1 = rz;
      final sx = center.dx + x1 * viewport.zoom;
      final sy = center.dy + (y1 * cosPitch - z1 * sinPitch) * viewport.zoom;
      final depth = y1 * sinPitch + z1 * cosPitch;
      return (Offset(sx, sy), depth);
    }

    final projected = <({Face3D face, List<Offset> pts, double depth})>[];
    for (final face in widget.faces) {
      if (face.moduleId == null || face.vertices.length < 3) continue;
      double depthSum = 0;
      final pts = <Offset>[];
      for (final v in face.vertices) {
        final (pt, d) = project(v);
        pts.add(pt);
        depthSum += d;
      }
      projected.add((
        face: face,
        pts: pts,
        depth: depthSum / face.vertices.length,
      ));
    }

    // Sort back-to-front, then test front-to-back (last to first)
    projected.sort((a, b) => a.depth.compareTo(b.depth));
    for (int i = projected.length - 1; i >= 0; i--) {
      final item = projected[i];
      if (_pointInPolygon(tapPos, item.pts)) {
        widget.onSurfaceTapped?.call(
          item.face.moduleId,
          item.face.floorId,
          item.face.isWallFace,
        );
        return;
      }
    }

    widget.onSurfaceTapped?.call(null, null, false);
  }

  static bool _pointInPolygon(Offset pt, List<Offset> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final zoomFactor = pointerSignal.scrollDelta.dy < 0 ? 1.12 : 0.88;
              final nextZoom =
                  (_viewportNotifier.value.zoom * zoomFactor).clamp(10.0, 200.0);
              _viewportNotifier.value =
                  _viewportNotifier.value.copyWith(zoom: nextZoom);
              widget.onZoomChanged?.call(nextZoom);
            }
          },
          child: GestureDetector(
            onTapUp: (details) => _handleTapUp(details, canvasSize),
            onScaleStart: (_) {
              _baseZoom = _viewportNotifier.value.zoom;
            },
            onScaleUpdate: (details) {
              final current = _viewportNotifier.value;
              if (details.pointerCount == 1) {
                final nextYaw = current.yaw + details.focalPointDelta.dx * 0.012;
                final nextPitch =
                    (current.pitch - details.focalPointDelta.dy * 0.012)
                        .clamp(0.08, math.pi / 2 - 0.05);
                _viewportNotifier.value = current.copyWith(
                  yaw: nextYaw,
                  pitch: nextPitch,
                );
                widget.onOrbitChanged?.call(nextYaw, nextPitch);
              } else if (details.pointerCount >= 2) {
                final nextZoom = (_baseZoom * details.scale).clamp(10.0, 200.0);
                final nextPan = current.pan + details.focalPointDelta;
                _viewportNotifier.value = current.copyWith(
                  zoom: nextZoom,
                  pan: nextPan,
                );
                widget.onZoomChanged?.call(nextZoom);
                widget.onPanChanged?.call(nextPan);
              }
            },
            child: RepaintBoundary(
              child: ClipRect(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _AxonometricPainter(
                    faces: widget.faces,
                    sceneCenter: _sceneCenter,
                    viewportListenable: _viewportNotifier,
                    showLabels: widget.showLabels,
                    orientationDegrees: widget.orientationDegrees,
                    selectedModuleId: widget.selectedModuleId,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AxonometricPainter extends CustomPainter {
  final List<Face3D> faces;
  final Point3D sceneCenter;
  final ValueNotifier<_Viewport3D> viewportListenable;
  final bool showLabels;
  final double orientationDegrees;
  final String? selectedModuleId;

  _AxonometricPainter({
    required this.faces,
    required this.sceneCenter,
    required this.viewportListenable,
    required this.showLabels,
    required this.orientationDegrees,
    this.selectedModuleId,
  }) : super(repaint: viewportListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = viewportListenable.value;
    final yaw = viewport.yaw;
    final pitch = viewport.pitch;
    final zoom = viewport.zoom;
    final panOffset = viewport.pan;
    final center = Offset(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);

    // 1. Studio radial gradient background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: const [
          Color(0xFF1E2836),
          Color(0xFF0F172A),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    (Offset screenPos, double depth) project(Point3D p) {
      final rx = p.x - sceneCenter.x;
      final ry = p.y - sceneCenter.y;
      final rz = p.z - sceneCenter.z;

      final x1 = rx * cosYaw - ry * sinYaw;
      final y1 = rx * sinYaw + ry * cosYaw;
      final z1 = rz;

      final sx = center.dx + x1 * zoom;
      final sy = center.dy + (y1 * cosPitch - z1 * sinPitch) * zoom;
      final depth = y1 * sinPitch + z1 * cosPitch;

      return (Offset(sx, sy), depth);
    }

    // 3. Project and depth-sort faces (Painter's Algorithm back-to-front)
    final projectedFaces = <_ProjectedFace>[];

    for (final face in faces) {
      if (face.vertices.length < 3) continue;

      double depthSum = 0;
      final screenPoints = <Offset>[];

      for (final v in face.vertices) {
        final (screenPt, depth) = project(v);
        screenPoints.add(screenPt);
        depthSum += depth;
      }

      final avgDepth = depthSum / face.vertices.length;

      projectedFaces.add(
        _ProjectedFace(
          points: screenPoints,
          vertices3D: face.vertices,
          depth: avgDepth,
          color: face.defaultShadedColor,
          isEdgeVisible: face.isEdgeVisible,
          label: face.label,
          moduleId: face.moduleId,
          pattern: face.pattern,
          patternColor: face.patternColor,
          isWallFace: face.isWallFace,
        ),
      );
    }

    projectedFaces.sort((a, b) => a.depth.compareTo(b.depth));

    // 4. Draw projected faces, procedural 3D textures, and selection highlights
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF101924).withValues(alpha: 0.45);
    final selectedFloorBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = const Color(0xFF00E5FF);

    for (final pFace in projectedFaces) {
      final path = Path();
      path.moveTo(pFace.points[0].dx, pFace.points[0].dy);
      for (int i = 1; i < pFace.points.length; i++) {
        path.lineTo(pFace.points[i].dx, pFace.points[i].dy);
      }
      path.close();

      fillPaint.color = pFace.color;
      canvas.drawPath(path, fillPaint);

      if (pFace.pattern != null && pFace.pattern != FinishPatternType.paintedWall) {
        _drawFacePattern3D(canvas, path, pFace, project);
      }

      if (pFace.isEdgeVisible) {
        canvas.drawPath(path, strokePaint);
      }

      if (selectedModuleId != null &&
          pFace.moduleId == selectedModuleId &&
          !pFace.isWallFace) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.14),
        );
        canvas.drawPath(path, selectedFloorBorderPaint);
      }
    }

    // 5. Room labels projected in 3D
    _drawRoomLabels(canvas, projectedFaces);

    // 6. North compass in bottom-left corner
    _drawCompass(canvas, size, yaw);
  }

  void _drawFacePattern3D(
    Canvas canvas,
    Path clipPath,
    _ProjectedFace pFace,
    (Offset, double) Function(Point3D) project,
  ) {
    final verts = pFace.vertices3D;
    if (verts.length < 3) return;

    final accent = (pFace.patternColor ?? Colors.white).withValues(alpha: 0.32);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..color = accent;

    canvas.save();
    canvas.clipPath(clipPath);

    if (!pFace.isWallFace) {
      double minX = verts.first.x, maxX = verts.first.x;
      double minY = verts.first.y, maxY = verts.first.y;
      final z = verts.first.z;
      for (final v in verts) {
        if (v.x < minX) minX = v.x;
        if (v.x > maxX) maxX = v.x;
        if (v.y < minY) minY = v.y;
        if (v.y > maxY) maxY = v.y;
      }

      switch (pFace.pattern!) {
        case FinishPatternType.woodPlanks:
        case FinishPatternType.outdoorDeck:
          final step = pFace.pattern == FinishPatternType.outdoorDeck ? 0.22 : 0.28;
          for (double y = minY + step; y < maxY; y += step) {
            final (p1, _) = project(Point3D(minX, y, z));
            final (p2, _) = project(Point3D(maxX, y, z));
            canvas.drawLine(p1, p2, linePaint);
          }
          break;
        case FinishPatternType.porcelainGrid:
        case FinishPatternType.hydraulicTile:
          final step = pFace.pattern == FinishPatternType.hydraulicTile ? 0.40 : 0.65;
          for (double x = minX + step; x < maxX; x += step) {
            final (p1, _) = project(Point3D(x, minY, z));
            final (p2, _) = project(Point3D(x, maxY, z));
            canvas.drawLine(p1, p2, linePaint);
          }
          for (double y = minY + step; y < maxY; y += step) {
            final (p1, _) = project(Point3D(minX, y, z));
            final (p2, _) = project(Point3D(maxX, y, z));
            canvas.drawLine(p1, p2, linePaint);
          }
          break;
        case FinishPatternType.marbleVeins:
          final step = 0.85;
          for (double d = minX - (maxY - minY); d < maxX; d += step) {
            final (p1, _) = project(Point3D(d, minY, z));
            final (p2, _) = project(Point3D(d + (maxY - minY) * 0.65, maxY, z));
            canvas.drawLine(p1, p2, linePaint);
          }
          for (double x = minX + 0.90; x < maxX; x += 0.90) {
            final (p1, _) = project(Point3D(x, minY, z));
            final (p2, _) = project(Point3D(x, maxY, z));
            canvas.drawLine(
              p1,
              p2,
              Paint()
                ..color = accent.withValues(alpha: 0.16)
                ..strokeWidth = 0.6,
            );
          }
          break;
        case FinishPatternType.naturalGrass:
          const step = 0.75;
          for (double x = minX + 0.35; x < maxX; x += step) {
            for (double y = minY + 0.35; y < maxY; y += step) {
              final (pt, _) = project(Point3D(x, y, z));
              canvas.drawLine(pt, Offset(pt.dx - 2, pt.dy - 4), linePaint);
              canvas.drawLine(pt, Offset(pt.dx + 2, pt.dy - 3), linePaint);
            }
          }
          break;
        case FinishPatternType.polishedConcrete:
        case FinishPatternType.paintedWall:
        case FinishPatternType.exposedBrick:
        case FinishPatternType.travertineStone:
          break;
      }
    } else if (verts.length == 4) {
      // Wall horizontal courses for brick or travertine
      final b0 = verts[0];
      final b1 = verts[1];
      final t0 = verts[3];
      final wallH = (t0.z - b0.z).abs();
      if (wallH > 0.20) {
        final stepZ = pFace.pattern == FinishPatternType.exposedBrick ? 0.18 : 0.35;
        for (double dz = stepZ; dz < wallH; dz += stepZ) {
          final z = math.min(b0.z, t0.z) + dz;
          final (p1, _) = project(Point3D(b0.x, b0.y, z));
          final (p2, _) = project(Point3D(b1.x, b1.y, z));
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    canvas.restore();
  }

  static String _toShortCode(String name) => Module.compactRoomCode(name);

  void _drawRoomLabels(Canvas canvas, List<_ProjectedFace> projectedFaces) {
    if (!showLabels) return;

    for (final pFace in projectedFaces) {
      final label = pFace.label;
      if (label == null ||
          label.isEmpty ||
          label == 'Terreno' ||
          label == 'Muro' ||
          label == 'Muro Exterior' ||
          label == 'Tabique' ||
          label.contains('Losa')) {
        continue;
      }
      if (pFace.points.isEmpty) continue;

      double sumX = 0, sumY = 0;
      for (final pt in pFace.points) {
        sumX += pt.dx;
        sumY += pt.dy;
      }
      final cx = sumX / pFace.points.length;
      final cy = sumY / pFace.points.length;

      final isSelected = selectedModuleId != null && pFace.moduleId == selectedModuleId;
      final shortCode = _toShortCode(label);
      final textSpan = TextSpan(
        text: shortCode,
        style: TextStyle(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      const paddingH = 4.0;
      const paddingV = 2.0;
      final badgeW = textPainter.width + paddingH * 2;
      final badgeH = textPainter.height + paddingV * 2;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: badgeW, height: badgeH),
        const Radius.circular(4),
      );

      final bgPaint = Paint()
        ..color = isSelected ? const Color(0xFF00E5FF) : const Color(0xDD0F172A)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(badgeRect, bgPaint);

      final borderPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: isSelected ? 1.0 : 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.5 : 1.0;
      canvas.drawRRect(badgeRect, borderPaint);

      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
      );
    }
  }

  void _drawCompass(Canvas canvas, Size size, double yaw) {
    final compassCenter = Offset(50, size.height - 50);
    const radius = 24.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(compassCenter, radius, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(compassCenter, radius, borderPaint);

    final northAngle =
        -yaw - math.pi / 2 + (orientationDegrees * math.pi / 180.0);
    final nx = compassCenter.dx + math.cos(northAngle) * 16.0;
    final ny = compassCenter.dy + math.sin(northAngle) * 16.0;

    final northPaint = Paint()
      ..color = const Color(0xFFEF5350)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(compassCenter, Offset(nx, ny), northPaint);

    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFFEF5350),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(nx - 4, ny - 14));
  }

  @override
  bool shouldRepaint(covariant _AxonometricPainter oldDelegate) {
    return !identical(oldDelegate.faces, faces) ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.orientationDegrees != orientationDegrees ||
        oldDelegate.selectedModuleId != selectedModuleId ||
        oldDelegate.viewportListenable != viewportListenable;
  }
}

class _ProjectedFace {
  final List<Offset> points;
  final List<Point3D> vertices3D;
  final double depth;
  final Color color;
  final bool isEdgeVisible;
  final String? label;
  final String? moduleId;
  final FinishPatternType? pattern;
  final Color? patternColor;
  final bool isWallFace;

  _ProjectedFace({
    required this.points,
    required this.vertices3D,
    required this.depth,
    required this.color,
    required this.isEdgeVisible,
    this.label,
    this.moduleId,
    this.pattern,
    this.patternColor,
    this.isWallFace = false,
  });
}
