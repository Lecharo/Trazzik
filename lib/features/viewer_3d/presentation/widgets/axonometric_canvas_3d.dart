import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';

/// Interactive 3D axonometric & perspective canvas with 360° orbit, zoom,
/// multi-layered procedural surface textures, solar lighting presets,
/// zero-rebuild exploded floor projection, and 3D polygon hit-testing.
class AxonometricCanvas3D extends StatefulWidget {
  final List<Face3D> faces;
  final double yaw; // Horizontal angle (radians)
  final double pitch; // Vertical angle (radians)
  final double zoom; // Scale in pixels per meter
  final Offset panOffset;
  final double explodedFactor; // 0.0 to 1.0 (applied at projection time)
  final bool isPerspective;
  final SunPreset3D sunPreset;
  final SectionCutAxis3D sectionCutAxis;
  final double sectionCutRatio; // 0.15 to 1.0
  final int cameraRevision;
  final double orientationDegrees;
  final Function(double newYaw, double newPitch)? onOrbitChanged;
  final Function(double newZoom)? onZoomChanged;
  final Function(Offset newPan)? onPanChanged;
  final void Function(String? moduleId, String? floorId, bool isWallFace)?
      onSurfaceTapped;
  final String? selectedModuleId;
  final bool highlightWallSelection;
  final bool showLabels;

  const AxonometricCanvas3D({
    super.key,
    required this.faces,
    this.yaw = -0.35,
    this.pitch = 0.70, // ~40° front axonometric tilt
    this.zoom = 48.0,
    this.panOffset = Offset.zero,
    this.explodedFactor = 0.0,
    this.isPerspective = false,
    this.sunPreset = SunPreset3D.studioNoon,
    this.sectionCutAxis = SectionCutAxis3D.none,
    this.sectionCutRatio = 1.0,
    this.cameraRevision = 0,
    this.orientationDegrees = 0.0,
    this.onOrbitChanged,
    this.onZoomChanged,
    this.onPanChanged,
    this.onSurfaceTapped,
    this.selectedModuleId,
    this.highlightWallSelection = false,
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
  final double explodedFactor;
  final bool isPerspective;
  final SunPreset3D sunPreset;
  final SectionCutAxis3D sectionCutAxis;
  final double sectionCutRatio;

  const _Viewport3D({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    this.explodedFactor = 0.0,
    this.isPerspective = false,
    this.sunPreset = SunPreset3D.studioNoon,
    this.sectionCutAxis = SectionCutAxis3D.none,
    this.sectionCutRatio = 1.0,
  });

  _Viewport3D copyWith({
    double? yaw,
    double? pitch,
    double? zoom,
    Offset? pan,
    double? explodedFactor,
    bool? isPerspective,
    SunPreset3D? sunPreset,
    SectionCutAxis3D? sectionCutAxis,
    double? sectionCutRatio,
  }) {
    return _Viewport3D(
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      zoom: zoom ?? this.zoom,
      pan: pan ?? this.pan,
      explodedFactor: explodedFactor ?? this.explodedFactor,
      isPerspective: isPerspective ?? this.isPerspective,
      sunPreset: sunPreset ?? this.sunPreset,
      sectionCutAxis: sectionCutAxis ?? this.sectionCutAxis,
      sectionCutRatio: sectionCutRatio ?? this.sectionCutRatio,
    );
  }

  /// Shared 3D-to-2D projection used by both hit-testing and rendering.
  (Offset screenPos, double depth) projectPoint(
    Point3D p,
    Point3D sceneCenter,
    Offset screenCenter,
    double cosYaw,
    double sinYaw,
    double cosPitch,
    double sinPitch, {
    int floorIndex = 0,
  }) {
    final effectiveZ =
        p.z + (floorIndex > 0 ? floorIndex * explodedFactor * 2.50 : 0.0);
    final rx = p.x - sceneCenter.x;
    final ry = p.y - sceneCenter.y;
    final rz = effectiveZ - sceneCenter.z;

    final x1 = rx * cosYaw - ry * sinYaw;
    final y1 = rx * sinYaw + ry * cosYaw;
    final z1 = rz;

    final depth = y1 * sinPitch + z1 * cosPitch;
    final perspScale = isPerspective
        ? (42.0 / (42.0 - depth.clamp(-24.0, 26.0))).clamp(0.68, 1.52)
        : 1.0;
    final effZoom = zoom * perspScale;

    final sx = screenCenter.dx + x1 * effZoom;
    final sy = screenCenter.dy + (y1 * cosPitch - z1 * sinPitch) * effZoom;

    return (Offset(sx, sy), depth);
  }
}

class _AxonometricCanvas3DState extends State<AxonometricCanvas3D> {
  late final ValueNotifier<_Viewport3D> _viewportNotifier;
  late Point3D _sceneCenter;
  double _baseZoom = 48.0;

  static Point3D computeSceneCenter(List<Face3D> faces) =>
      AxonometricSceneRenderer.computeSceneCenter(faces);

  @override
  void initState() {
    super.initState();
    _sceneCenter = computeSceneCenter(widget.faces);
    _viewportNotifier = ValueNotifier(
      _Viewport3D(
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        pan: widget.panOffset,
        explodedFactor: widget.explodedFactor,
        isPerspective: widget.isPerspective,
        sunPreset: widget.sunPreset,
        sectionCutAxis: widget.sectionCutAxis,
        sectionCutRatio: widget.sectionCutRatio,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AxonometricCanvas3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.faces, oldWidget.faces)) {
      _sceneCenter = computeSceneCenter(widget.faces);
    }
    final cameraControlledExternally =
        widget.cameraRevision != oldWidget.cameraRevision ||
            widget.yaw != oldWidget.yaw ||
            widget.pitch != oldWidget.pitch ||
            widget.zoom != oldWidget.zoom ||
            widget.panOffset != oldWidget.panOffset ||
            widget.explodedFactor != oldWidget.explodedFactor ||
            widget.isPerspective != oldWidget.isPerspective ||
            widget.sunPreset != oldWidget.sunPreset ||
            widget.sectionCutAxis != oldWidget.sectionCutAxis ||
            widget.sectionCutRatio != oldWidget.sectionCutRatio;
    if (cameraControlledExternally) {
      final current = _viewportNotifier.value;
      final useWidgetPose = widget.cameraRevision != oldWidget.cameraRevision ||
          widget.yaw != oldWidget.yaw ||
          widget.pitch != oldWidget.pitch ||
          widget.zoom != oldWidget.zoom ||
          widget.panOffset != oldWidget.panOffset;
      _viewportNotifier.value = _Viewport3D(
        yaw: useWidgetPose ? widget.yaw : current.yaw,
        pitch: useWidgetPose ? widget.pitch : current.pitch,
        zoom: useWidgetPose ? widget.zoom : current.zoom,
        pan: useWidgetPose ? widget.panOffset : current.pan,
        explodedFactor: widget.explodedFactor,
        isPerspective: widget.isPerspective,
        sunPreset: widget.sunPreset,
        sectionCutAxis: widget.sectionCutAxis,
        sectionCutRatio: widget.sectionCutRatio,
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

    final cutLimit = AxonometricSceneRenderer.resolveSectionCutLimit(
      widget.faces,
      viewport.sectionCutAxis,
      viewport.sectionCutRatio,
    );

    final projected = <({
      Face3D face,
      List<Offset> pts,
      double depth,
      double maxDepth,
    })>[];
    for (final face in widget.faces) {
      if (face.moduleId == null || face.vertices.length < 3) continue;
      if (cutLimit != null &&
          AxonometricSceneRenderer.isFaceCulledBySection(
            face,
            viewport.sectionCutAxis,
            cutLimit,
          )) {
        continue;
      }
      double depthSum = 0;
      double maxD = double.negativeInfinity;
      final pts = <Offset>[];
      for (final v in face.vertices) {
        final (pt, d) = viewport.projectPoint(
          v,
          _sceneCenter,
          center,
          cosYaw,
          sinYaw,
          cosPitch,
          sinPitch,
          floorIndex: face.floorIndex,
        );
        pts.add(pt);
        depthSum += d;
        if (d > maxD) maxD = d;
      }
      projected.add((
        face: face,
        pts: pts,
        depth: depthSum / face.vertices.length,
        maxDepth: maxD,
      ));
    }

    // Sort with exact same stratified order as the painter, then test front-to-back
    projected.sort((a, b) {
      final floorCmp = a.face.floorIndex.compareTo(b.face.floorIndex);
      if (floorCmp != 0) return floorCmp;
      final layerCmp = a.face.layer.index.compareTo(b.face.layer.index);
      if (layerCmp != 0) return layerCmp;
      final depthCmp = a.depth.compareTo(b.depth);
      if (depthCmp != 0) return depthCmp;
      return a.maxDepth.compareTo(b.maxDepth);
    });

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
          (pt.dx <
              (xj - xi) *
                      (pt.dy - yi) /
                      ((yj - yi) == 0 ? 1e-9 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
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
                    highlightWallSelection: widget.highlightWallSelection,
                    isDarkTheme: isDarkTheme,
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

/// Shared offscreen & onscreen 3D scene rendering utilities.
class AxonometricSceneRenderer {
  /// Computes the geometric 3D bounding-box center of [faces], excluding shadow
  /// polygons so furniture density or shadow planes never skew the 360° orbit pivot.
  static Point3D computeSceneCenter(List<Face3D> faces) {
    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = double.negativeInfinity,
        maxY = double.negativeInfinity,
        maxZ = double.negativeInfinity;
    int count = 0;

    for (final face in faces) {
      if (face.layer == FaceLayer3D.shadow) continue;
      for (final v in face.vertices) {
        if (v.x < minX) minX = v.x;
        if (v.y < minY) minY = v.y;
        if (v.z < minZ) minZ = v.z;
        if (v.x > maxX) maxX = v.x;
        if (v.y > maxY) maxY = v.y;
        if (v.z > maxZ) maxZ = v.z;
        count++;
      }
    }

    if (count == 0) {
      return const Point3D(5.0, 7.5, 1.5);
    }
    return Point3D(
      (minX + maxX) / 2.0,
      (minY + maxY) / 2.0,
      (minZ + maxZ) / 2.0,
    );
  }

  /// Computes the active world-space X or Y section cut threshold (`null` when inactive).
  static double? resolveSectionCutLimit(
    List<Face3D> faces,
    SectionCutAxis3D axis,
    double ratio,
  ) {
    if (axis == SectionCutAxis3D.none || ratio >= 0.995) return null;
    double minC = double.infinity;
    double maxC = double.negativeInfinity;
    int count = 0;

    for (final face in faces) {
      if (face.layer == FaceLayer3D.shadow || face.layer == FaceLayer3D.terrain) {
        continue;
      }
      for (final v in face.vertices) {
        final coord = axis == SectionCutAxis3D.axisX ? v.x : v.y;
        if (coord < minC) minC = coord;
        if (coord > maxC) maxC = coord;
        count++;
      }
    }
    if (count == 0 || maxC <= minC) return null;
    return minC + (maxC - minC) * ratio.clamp(0.10, 1.0);
  }

  /// Returns true when [face] lies beyond the active vertical section plane.
  static bool isFaceCulledBySection(
    Face3D face,
    SectionCutAxis3D axis,
    double cutLimit,
  ) {
    if (face.layer == FaceLayer3D.terrain) return false;
    final c = face.centroid;
    return axis == SectionCutAxis3D.axisX ? c.x > cutLimit : c.y > cutLimit;
  }

  static Size? _cachedBgSize;
  static bool? _cachedBgDark;
  static bool? _cachedBgNight;
  static Shader? _cachedBgShader;

  static final Map<String, TextPainter> _labelPainterCache = {};

  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _selectedFloorFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.14);
  static final Paint _selectedFloorBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..color = const Color(0xFF00E5FF);
  static final Paint _selectedWallFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFF38BDF8).withValues(alpha: 0.16);
  static final Paint _selectedWallBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = const Color(0xFF38BDF8);
  static final Paint _textureLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.85;
  static final Paint _glassHighlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.15
    ..color = Colors.white.withValues(alpha: 0.38);

  /// Renders a complete 3D scene onto [canvas] for interactive viewports,
  /// high-resolution PNG exports, and PDF technical sheets (`PL-3D`).
  static void paintScene({
    required Canvas canvas,
    required Size size,
    required List<Face3D> faces,
    required Point3D sceneCenter,
    required double yaw,
    required double pitch,
    required double zoom,
    Offset panOffset = Offset.zero,
    double explodedFactor = 0.0,
    bool isPerspective = false,
    SunPreset3D sunPreset = SunPreset3D.studioNoon,
    SectionCutAxis3D sectionCutAxis = SectionCutAxis3D.none,
    double sectionCutRatio = 1.0,
    bool showLabels = true,
    double orientationDegrees = 0.0,
    String? selectedModuleId,
    bool highlightWallSelection = false,
    bool isDarkTheme = true,
    bool drawBackground = true,
    bool drawCompass = true,
  }) {
    final viewport = _Viewport3D(
      yaw: yaw,
      pitch: pitch,
      zoom: zoom,
      pan: panOffset,
      explodedFactor: explodedFactor,
      isPerspective: isPerspective,
      sunPreset: sunPreset,
      sectionCutAxis: sectionCutAxis,
      sectionCutRatio: sectionCutRatio,
    );
    final center = Offset(
      size.width / 2 + panOffset.dx,
      size.height / 2 + panOffset.dy,
    );

    // 1. Studio radial gradient background (cached by size, theme brightness, and night mode)
    final isNight = sunPreset == SunPreset3D.nightInterior;
    if (drawBackground) {
      if (_cachedBgShader == null ||
          _cachedBgSize != size ||
          _cachedBgDark != isDarkTheme ||
          _cachedBgNight != isNight) {
        _cachedBgSize = size;
        _cachedBgDark = isDarkTheme;
        _cachedBgNight = isNight;
        _cachedBgShader = RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: isNight
              ? const [Color(0xFF10192D), Color(0xFF060A13)]
              : (isDarkTheme
                  ? const [Color(0xFF1E2836), Color(0xFF0F172A)]
                  : const [Color(0xFFF1F5F9), Color(0xFFDCE5F0)]),
        ).createShader(Offset.zero & size);
      }
      final bgPaint = Paint()..shader = _cachedBgShader;
      canvas.drawRect(Offset.zero & size, bgPaint);
    }

    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    (Offset screenPos, double depth) project(Point3D p, int floorIdx) =>
        viewport.projectPoint(
          p,
          sceneCenter,
          center,
          cosYaw,
          sinYaw,
          cosPitch,
          sinPitch,
          floorIndex: floorIdx,
        );

    // 2. Project and stratify-sort faces (Floor -> Semantic Layer -> Depth)
    final projectedFaces = <_ProjectedFace>[];
    final lightDir = sunPreset.lightDirection;
    final useDefaultSun = sunPreset == SunPreset3D.studioNoon;
    final cutLimit = resolveSectionCutLimit(
      faces,
      sectionCutAxis,
      sectionCutRatio,
    );

    for (final face in faces) {
      if (face.vertices.length < 3) continue;
      if (cutLimit != null &&
          isFaceCulledBySection(face, sectionCutAxis, cutLimit)) {
        continue;
      }

      double depthSum = 0;
      double maxD = double.negativeInfinity;
      final screenPoints = <Offset>[];

      for (final v in face.vertices) {
        final (screenPt, depth) = project(v, face.floorIndex);
        screenPoints.add(screenPt);
        depthSum += depth;
        if (depth > maxD) maxD = depth;
      }

      final avgDepth = depthSum / face.vertices.length;
      final shadedColor = isNight
          ? face.computeNightShadedColor(lightDir)
          : (useDefaultSun
              ? face.defaultShadedColor
              : face.computeShadedColor(lightDir));

      projectedFaces.add(
        _ProjectedFace(
          points: screenPoints,
          vertices3D: face.vertices,
          depth: avgDepth,
          maxDepth: maxD,
          color: shadedColor,
          isEdgeVisible: face.isEdgeVisible,
          label: face.label,
          roomDimensionsLabel: face.roomDimensionsLabel,
          moduleId: face.moduleId,
          pattern: face.pattern,
          patternColor: face.patternColor,
          isWallFace: face.isWallFace,
          layer: face.layer,
          floorIndex: face.floorIndex,
          isRoomLabel: face.isRoomLabel,
          isAxisAlignedQuad: face.isAxisAlignedQuad,
        ),
      );
    }

    projectedFaces.sort((a, b) {
      final floorCmp = a.floorIndex.compareTo(b.floorIndex);
      if (floorCmp != 0) return floorCmp;
      final layerCmp = a.layer.index.compareTo(b.layer.index);
      if (layerCmp != 0) return layerCmp;
      final depthCmp = a.depth.compareTo(b.depth);
      if (depthCmp != 0) return depthCmp;
      return a.maxDepth.compareTo(b.maxDepth);
    });

    // 3. Draw projected faces, multi-layered procedural 3D textures, and selection highlights
    _strokePaint.color = isDarkTheme
        ? const Color(0xFF101924).withValues(alpha: 0.45)
        : const Color(0xFF334155).withValues(alpha: 0.35);

    final enableTextures = zoom >= 18.0;
    final lodFactor = zoom < 30.0 ? 1.8 : 1.0;

    for (final pFace in projectedFaces) {
      final path = Path();
      path.moveTo(pFace.points[0].dx, pFace.points[0].dy);
      for (int i = 1; i < pFace.points.length; i++) {
        path.lineTo(pFace.points[i].dx, pFace.points[i].dy);
      }
      path.close();

      _fillPaint.color = pFace.color;
      canvas.drawPath(path, _fillPaint);

      if (enableTextures &&
          pFace.pattern != null &&
          pFace.pattern != FinishPatternType.paintedWall) {
        _drawFacePattern3D(canvas, path, pFace, project, lodFactor);
      }

      // Subtle diagonal glass specular reflection on window panels
      if (pFace.layer == FaceLayer3D.openingPanel &&
          pFace.points.length == 4 &&
          pFace.color.a < 0.85) {
        final p0 = pFace.points[0];
        final p1 = pFace.points[1];
        final p2 = pFace.points[2];
        final p3 = pFace.points[3];
        final s1 = Offset.lerp(p0, p3, 0.25)!;
        final e1 = Offset.lerp(p1, p2, 0.65)!;
        final s2 = Offset.lerp(p0, p3, 0.45)!;
        final e2 = Offset.lerp(p1, p2, 0.82)!;
        canvas.drawLine(s1, e1, _glassHighlightPaint);
        canvas.drawLine(s2, e2, _glassHighlightPaint);
      }

      if (pFace.isEdgeVisible) {
        canvas.drawPath(path, _strokePaint);
      }

      if (selectedModuleId != null && pFace.moduleId == selectedModuleId) {
        if (!pFace.isWallFace) {
          canvas.drawPath(path, _selectedFloorFillPaint);
          canvas.drawPath(path, _selectedFloorBorderPaint);
        } else if (highlightWallSelection) {
          canvas.drawPath(path, _selectedWallFillPaint);
          canvas.drawPath(path, _selectedWallBorderPaint);
        }
      }
    }

    // 4. Room labels projected in 3D (cached TextPainters)
    if (showLabels) {
      _drawRoomLabels(
        canvas,
        projectedFaces,
        selectedModuleId: selectedModuleId,
        isDarkTheme: isDarkTheme || isNight,
        showDimensions: zoom >= 26.0,
      );
    }

    // 5. North compass in bottom-left corner
    if (drawCompass) {
      _drawCompass(
        canvas,
        size,
        yaw,
        orientationDegrees: orientationDegrees,
        isDarkTheme: isDarkTheme,
      );
    }
  }

  static void _drawFacePattern3D(
    Canvas canvas,
    Path clipPath,
    _ProjectedFace pFace,
    (Offset, double) Function(Point3D, int) project,
    double lodFactor,
  ) {
    final verts = pFace.vertices3D;
    if (verts.length < 3) return;

    final accent = (pFace.patternColor ?? Colors.white).withValues(alpha: 0.34);
    _textureLinePaint.color = accent;

    // Fast path for 4-vertex wall faces: bilinear 2D edge interpolation without GPU clipPath
    if (pFace.isWallFace) {
      if (verts.length == 4 && pFace.points.length == 4) {
        // Notice: outward-wound wall side faces have vertices [b_start, b_end, t_end, t_start]
        final b0 = verts[0];
        final t0 = verts[3];
        final wallH = (t0.z - b0.z).abs();
        if (wallH > 0.20) {
          final isBrick = pFace.pattern == FinishPatternType.exposedBrick;
          final baseStep = isBrick ? 0.18 : 0.35;
          final stepZ = baseStep * lodFactor;
          final pB0 = pFace.points[0];
          final pB1 = pFace.points[1];
          final pT1 = pFace.points[2];
          final pT0 = pFace.points[3];
          int row = 0;
          for (double dz = stepZ; dz < wallH; dz += stepZ) {
            final t = (dz / wallH).clamp(0.0, 1.0);
            final start = Offset.lerp(pB0, pT0, t)!;
            final end = Offset.lerp(pB1, pT1, t)!;
            canvas.drawLine(start, end, _textureLinePaint);

            // Staggered vertical brick joints for exposedBrick
            if (isBrick && lodFactor <= 1.2) {
              final prevT = ((dz - stepZ) / wallH).clamp(0.0, 1.0);
              final prevStart = Offset.lerp(pB0, pT0, prevT)!;
              final prevEnd = Offset.lerp(pB1, pT1, prevT)!;
              final offsetPhase = (row.isEven ? 0.15 : 0.35);
              for (double u = offsetPhase; u < 0.92; u += 0.38) {
                final jBot = Offset.lerp(prevStart, prevEnd, u)!;
                final jTop = Offset.lerp(start, end, u)!;
                canvas.drawLine(jBot, jTop, _textureLinePaint);
              }
            }
            row++;
          }
        }
      }
      return;
    }

    double minX = verts.first.x, maxX = verts.first.x;
    double minY = verts.first.y, maxY = verts.first.y;
    final z = verts.first.z;
    for (final v in verts) {
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
    }
    final spanX = maxX - minX;
    final spanY = maxY - minY;
    if (spanX <= 0.05 || spanY <= 0.05) return;

    // Only skip clipPath when the polygon is a verified axis-aligned rectangle
    final canSkipClip = pFace.isAxisAlignedQuad &&
        pFace.pattern != FinishPatternType.marbleVeins &&
        pFace.pattern != FinishPatternType.naturalGrass;

    if (!canSkipClip) {
      canvas.save();
      canvas.clipPath(clipPath);
    }

    final fIdx = pFace.floorIndex;

    switch (pFace.pattern!) {
      case FinishPatternType.woodPlanks:
      case FinishPatternType.outdoorDeck:
        final baseStep =
            pFace.pattern == FinishPatternType.outdoorDeck ? 0.22 : 0.28;
        final step = baseStep * lodFactor;
        int plankRow = 0;
        for (double y = minY + step; y < maxY; y += step) {
          final (p1, _) = project(Point3D(minX, y, z), fIdx);
          final (p2, _) = project(Point3D(maxX, y, z), fIdx);
          canvas.drawLine(p1, p2, _textureLinePaint);

          // Staggered plank butt-joints
          if (lodFactor <= 1.2 && spanX > 1.20) {
            final prevY = y - step;
            final jointX = minX +
                ((plankRow.isEven ? 0.32 : 0.68) * spanX).clamp(0.25, spanX - 0.25);
            final (j1, _) = project(Point3D(jointX, prevY, z), fIdx);
            final (j2, _) = project(Point3D(jointX, y, z), fIdx);
            canvas.drawLine(j1, j2, _textureLinePaint);
          }
          plankRow++;
        }
        break;
      case FinishPatternType.porcelainGrid:
      case FinishPatternType.hydraulicTile:
        final baseStep =
            pFace.pattern == FinishPatternType.hydraulicTile ? 0.40 : 0.65;
        final step = baseStep * lodFactor;
        for (double x = minX + step; x < maxX; x += step) {
          final (p1, _) = project(Point3D(x, minY, z), fIdx);
          final (p2, _) = project(Point3D(x, maxY, z), fIdx);
          canvas.drawLine(p1, p2, _textureLinePaint);
        }
        for (double y = minY + step; y < maxY; y += step) {
          final (p1, _) = project(Point3D(minX, y, z), fIdx);
          final (p2, _) = project(Point3D(maxX, y, z), fIdx);
          canvas.drawLine(p1, p2, _textureLinePaint);
        }
        break;
      case FinishPatternType.marbleVeins:
        final step = 0.85 * lodFactor;
        for (double d = minX - spanY; d < maxX; d += step) {
          final (p1, _) = project(Point3D(d, minY, z), fIdx);
          final (p2, _) = project(Point3D(d + spanY * 0.65, maxY, z), fIdx);
          canvas.drawLine(p1, p2, _textureLinePaint);
          if (lodFactor <= 1.2) {
            final (s1, _) = project(Point3D(d + 0.22, minY, z), fIdx);
            final (s2, _) =
                project(Point3D(d + spanY * 0.48, maxY * 0.85 + minY * 0.15, z), fIdx);
            canvas.drawLine(s1, s2, _textureLinePaint);
          }
        }
        break;
      case FinishPatternType.naturalGrass:
        final step = 0.75 * lodFactor;
        for (double x = minX + 0.35; x < maxX; x += step) {
          for (double y = minY + 0.35; y < maxY; y += step) {
            final (pt, _) = project(Point3D(x, y, z), fIdx);
            canvas.drawLine(
                pt, Offset(pt.dx - 2, pt.dy - 4), _textureLinePaint);
            canvas.drawLine(
                pt, Offset(pt.dx + 2, pt.dy - 3), _textureLinePaint);
          }
        }
        break;
      case FinishPatternType.polishedConcrete:
      case FinishPatternType.paintedWall:
      case FinishPatternType.exposedBrick:
      case FinishPatternType.travertineStone:
        break;
    }

    if (!canSkipClip) {
      canvas.restore();
    }
  }

  static TextPainter _resolveLabelPainter(
    String shortCode,
    bool isSelected,
    bool isDarkTheme, {
    String? subLine,
  }) {
    final key = '$shortCode|${subLine ?? ''}|$isSelected|$isDarkTheme';
    final cached = _labelPainterCache[key];
    if (cached != null) return cached;

    if (_labelPainterCache.length > 256) {
      _labelPainterCache.clear();
    }

    final textColor = isSelected
        ? const Color(0xFF0F172A)
        : (isDarkTheme ? Colors.white : const Color(0xFF0F172A));
    final subColor = isSelected
        ? const Color(0xFF1E293B)
        : (isDarkTheme ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: shortCode,
            style: TextStyle(
              color: textColor,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          if (subLine != null && subLine.isNotEmpty)
            TextSpan(
              text: '\n$subLine',
              style: TextStyle(
                color: subColor,
                fontSize: 6.8,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    _labelPainterCache[key] = tp;
    return tp;
  }

  static void _drawRoomLabels(
    Canvas canvas,
    List<_ProjectedFace> projectedFaces, {
    required String? selectedModuleId,
    required bool isDarkTheme,
    bool showDimensions = true,
  }) {
    for (final pFace in projectedFaces) {
      final label = pFace.label;
      if (label == null || label.isEmpty) continue;
      if (!pFace.isRoomLabel) continue;
      if (pFace.points.isEmpty) continue;

      double sumX = 0, sumY = 0;
      for (final pt in pFace.points) {
        sumX += pt.dx;
        sumY += pt.dy;
      }
      final cx = sumX / pFace.points.length;
      final cy = sumY / pFace.points.length;

      final isSelected =
          selectedModuleId != null && pFace.moduleId == selectedModuleId;
      final shortCode = Module.compactRoomCode(label);
      final textPainter = _resolveLabelPainter(
        shortCode,
        isSelected,
        isDarkTheme,
        subLine: showDimensions ? pFace.roomDimensionsLabel : null,
      );

      const paddingH = 4.5;
      const paddingV = 2.0;
      final badgeW = textPainter.width + paddingH * 2;
      final badgeH = textPainter.height + paddingV * 2;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: badgeW, height: badgeH),
        const Radius.circular(4),
      );

      final bgPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : (isDarkTheme
                ? const Color(0xDD0F172A)
                : const Color(0xEEFFFFFF))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(badgeRect, bgPaint);

      final borderPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : (isDarkTheme
                ? const Color(0xFF00E5FF).withValues(alpha: 0.50)
                : const Color(0xFF0284C7).withValues(alpha: 0.65))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.5 : 1.0;
      canvas.drawRRect(badgeRect, borderPaint);

      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
      );
    }
  }

  static void _drawCompass(
    Canvas canvas,
    Size size,
    double yaw, {
    required double orientationDegrees,
    required bool isDarkTheme,
  }) {
    final compassCenter = Offset(50, size.height - 50);
    const radius = 24.0;

    final bgPaint = Paint()
      ..color = isDarkTheme
          ? const Color(0xFF0F172A).withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(compassCenter, radius, bgPaint);

    final borderPaint = Paint()
      ..color = isDarkTheme
          ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
          : const Color(0xFF0284C7).withValues(alpha: 0.5)
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

    final tp = _resolveLabelPainter('N', false, true);
    tp.paint(canvas, Offset(nx - 4, ny - 14));
  }
}

class _AxonometricPainter extends CustomPainter {
  final List<Face3D> faces;
  final Point3D sceneCenter;
  final ValueNotifier<_Viewport3D> viewportListenable;
  final bool showLabels;
  final double orientationDegrees;
  final String? selectedModuleId;
  final bool highlightWallSelection;
  final bool isDarkTheme;

  _AxonometricPainter({
    required this.faces,
    required this.sceneCenter,
    required this.viewportListenable,
    required this.showLabels,
    required this.orientationDegrees,
    this.selectedModuleId,
    this.highlightWallSelection = false,
    this.isDarkTheme = true,
  }) : super(repaint: viewportListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = viewportListenable.value;
    AxonometricSceneRenderer.paintScene(
      canvas: canvas,
      size: size,
      faces: faces,
      sceneCenter: sceneCenter,
      yaw: viewport.yaw,
      pitch: viewport.pitch,
      zoom: viewport.zoom,
      panOffset: viewport.pan,
      explodedFactor: viewport.explodedFactor,
      isPerspective: viewport.isPerspective,
      sunPreset: viewport.sunPreset,
      sectionCutAxis: viewport.sectionCutAxis,
      sectionCutRatio: viewport.sectionCutRatio,
      showLabels: showLabels,
      orientationDegrees: orientationDegrees,
      selectedModuleId: selectedModuleId,
      highlightWallSelection: highlightWallSelection,
      isDarkTheme: isDarkTheme,
    );
  }

  @override
  bool shouldRepaint(covariant _AxonometricPainter oldDelegate) {
    return !identical(oldDelegate.faces, faces) ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.orientationDegrees != orientationDegrees ||
        oldDelegate.selectedModuleId != selectedModuleId ||
        oldDelegate.highlightWallSelection != highlightWallSelection ||
        oldDelegate.isDarkTheme != isDarkTheme ||
        oldDelegate.viewportListenable != viewportListenable;
  }
}

class _ProjectedFace {
  final List<Offset> points;
  final List<Point3D> vertices3D;
  final double depth;
  final double maxDepth;
  final Color color;
  final bool isEdgeVisible;
  final String? label;
  final String? roomDimensionsLabel;
  final String? moduleId;
  final FinishPatternType? pattern;
  final Color? patternColor;
  final bool isWallFace;
  final FaceLayer3D layer;
  final int floorIndex;
  final bool isRoomLabel;
  final bool isAxisAlignedQuad;

  _ProjectedFace({
    required this.points,
    required this.vertices3D,
    required this.depth,
    required this.maxDepth,
    required this.color,
    required this.isEdgeVisible,
    this.label,
    this.roomDimensionsLabel,
    this.moduleId,
    this.pattern,
    this.patternColor,
    this.isWallFace = false,
    this.layer = FaceLayer3D.structureAndFurniture,
    this.floorIndex = 0,
    this.isRoomLabel = false,
    this.isAxisAlignedQuad = false,
  });
}
