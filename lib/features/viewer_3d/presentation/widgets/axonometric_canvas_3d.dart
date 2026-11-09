import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';

/// Canvas interactivo para renderizado axonométrico 3D con órbita 360°, zoom y proyección isométrica
class AxonometricCanvas3D extends StatefulWidget {
  final List<Face3D> faces;
  final double yaw; // Ángulo horizontal (radianes)
  final double pitch; // Ángulo vertical (radianes)
  final double zoom; // Escala en píxeles por metro
  final Offset panOffset;
  final int cameraRevision;
  final double orientationDegrees;
  final Function(double newYaw, double newPitch)? onOrbitChanged;
  final Function(double newZoom)? onZoomChanged;
  final Function(Offset newPan)? onPanChanged;
  final bool showLabels;

  const AxonometricCanvas3D({
    super.key,
    required this.faces,
    this.yaw = -0.35,
    this.pitch = 0.70, // ~40° inclinación axonométrica frontal
    this.zoom = 48.0,
    this.panOffset = Offset.zero,
    this.cameraRevision = 0,
    this.orientationDegrees = 0.0,
    this.onOrbitChanged,
    this.onZoomChanged,
    this.onPanChanged,
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

  @override
  Widget build(BuildContext context) {
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
        onScaleStart: (_) {
          _baseZoom = _viewportNotifier.value.zoom;
        },
        onScaleUpdate: (details) {
          final current = _viewportNotifier.value;
          if (details.pointerCount == 1) {
            // Órbita con 1 dedo o arrastre con mouse (sin reconstruir árbol de widgets)
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
            // Zoom y paneo con 2 dedos
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AxonometricPainter extends CustomPainter {
  final List<Face3D> faces;
  final Point3D sceneCenter;
  final ValueNotifier<_Viewport3D> viewportListenable;
  final bool showLabels;
  final double orientationDegrees;

  _AxonometricPainter({
    required this.faces,
    required this.sceneCenter,
    required this.viewportListenable,
    required this.showLabels,
    required this.orientationDegrees,
  }) : super(repaint: viewportListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = viewportListenable.value;
    final yaw = viewport.yaw;
    final pitch = viewport.pitch;
    final zoom = viewport.zoom;
    final panOffset = viewport.pan;
    final center = Offset(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);

    // 1. Fondo degradado de estudio de arquitectura
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          const Color(0xFF1E2836),
          const Color(0xFF0F172A),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    // Función de rotación y proyección de un punto 3D
    (Offset screenPos, double depth) project(Point3D p) {
      // Trasladar al origen relativo al centroide del edificio
      final rx = p.x - sceneCenter.x;
      final ry = p.y - sceneCenter.y;
      final rz = p.z - sceneCenter.z;

      // 1. Rotación de Azimut / Órbita horizontal (Yaw)
      final x1 = rx * cosYaw - ry * sinYaw;
      final y1 = rx * sinYaw + ry * cosYaw;
      final z1 = rz;

      // 2. Inclinación 3D (Pitch: 0.0 es vista plana superior idéntica al editor 2D, >0 inclina hacia 3D)
      // En vista superior (pitch = 0): sx = rx, sy = ry (sin efecto espejo, orientación 1:1 con 2D)
      // Al inclinar en 3D (pitch > 0): la altura z1 se proyecta hacia arriba (-z1 * sinPitch)
      final sx = center.dx + x1 * zoom;
      final sy = center.dy + (y1 * cosPitch - z1 * sinPitch) * zoom;
      final depth = y1 * sinPitch + z1 * cosPitch;

      return (Offset(sx, sy), depth);
    }

    // 3. Proyectar y ordenar caras con Algoritmo del Pintor (Painter's Algorithm de atrás hacia adelante)
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
          depth: avgDepth,
          color: face.defaultShadedColor,
          isEdgeVisible: face.isEdgeVisible,
          label: face.label,
        ),
      );
    }

    // Ordenar de mayor profundidad a menor (back to front)
    projectedFaces.sort((a, b) => a.depth.compareTo(b.depth));

    // 4. Dibujar las caras proyectadas
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF101924).withValues(alpha: 0.45);

    for (final pFace in projectedFaces) {
      final path = Path();
      path.moveTo(pFace.points[0].dx, pFace.points[0].dy);
      for (int i = 1; i < pFace.points.length; i++) {
        path.lineTo(pFace.points[i].dx, pFace.points[i].dy);
      }
      path.close();

      fillPaint.color = pFace.color;
      canvas.drawPath(path, fillPaint);

      if (pFace.isEdgeVisible) {
        canvas.drawPath(path, strokePaint);
      }
    }

    // 5. Etiquetas de recintos/espacios proyectadas en 3D
    _drawRoomLabels(canvas, projectedFaces);

    // 6. Brújula / Rosa de los vientos en esquina inferior izquierda
    _drawCompass(canvas, size, yaw);
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

      final shortCode = _toShortCode(label);
      final textSpan = TextSpan(
        text: shortCode,
        style: const TextStyle(
          color: Colors.white,
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
        ..color = const Color(0xDD0F172A)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(badgeRect, bgPaint);

      final borderPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
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

    // Vector apuntando al Norte rotado con Yaw y orientación del lote
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
        oldDelegate.viewportListenable != viewportListenable;
  }
}

class _ProjectedFace {
  final List<Offset> points;
  final double depth;
  final Color color;
  final bool isEdgeVisible;
  final String? label;

  _ProjectedFace({
    required this.points,
    required this.depth,
    required this.color,
    required this.isEdgeVisible,
    this.label,
  });
}
