import 'package:flutter/material.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';

import 'webgl_canvas_3d_stub.dart'
    if (dart.library.js_interop) 'webgl_canvas_3d_web.dart' as impl;

/// True when running on Flutter Web where the local Three.js WebGL PBR
/// renderer is available.
bool get isWebGlViewerSupported => impl.isWebGlViewerSupported;

/// Imperative command channel from Flutter UI controls (ViewCube, zoom,
/// first-person walk-through, HD PNG snapshot) to the active [WebGlCanvas3D].
class WebGlViewerController {
  void Function(String preset, bool instant)? _onSetCameraPreset;
  void Function(double factor)? _onZoomStep;
  void Function(bool enabled, double? floorElevation)? _onSetWalkMode;
  void Function(String filename)? _onCaptureSnapshot;

  void attach({
    required void Function(String preset, bool instant) onSetCameraPreset,
    required void Function(double factor) onZoomStep,
    required void Function(bool enabled, double? floorElevation) onSetWalkMode,
    required void Function(String filename) onCaptureSnapshot,
  }) {
    _onSetCameraPreset = onSetCameraPreset;
    _onZoomStep = onZoomStep;
    _onSetWalkMode = onSetWalkMode;
    _onCaptureSnapshot = onCaptureSnapshot;
  }

  void detach() {
    _onSetCameraPreset = null;
    _onZoomStep = null;
    _onSetWalkMode = null;
    _onCaptureSnapshot = null;
  }

  void setCameraPreset(String preset, {bool instant = false}) {
    _onSetCameraPreset?.call(preset, instant);
  }

  void zoomStep(double factor) {
    _onZoomStep?.call(factor);
  }

  void setWalkMode(bool enabled, {double? floorElevation}) {
    _onSetWalkMode?.call(enabled, floorElevation);
  }

  void captureSnapshot({String filename = 'trazzik_render_webgl.png'}) {
    _onCaptureSnapshot?.call(filename);
  }
}

/// Platform-safe WebGL PBR 3D canvas backed by locally bundled Three.js on Web.
class WebGlCanvas3D extends StatelessWidget {
  final List<Face3D> faces;
  final SunPreset3D sunPreset;
  final double explodedFactor;
  final SectionCutAxis3D sectionCutAxis;
  final double sectionCutRatio;
  final String? selectedModuleId;
  final bool highlightWallSelection;
  final bool isPerspective;
  final double orientationDegrees;
  final WebGlViewerController? controller;
  final void Function(String? moduleId, String? floorId, bool isWallFace)?
      onSurfaceTapped;
  final ValueChanged<bool>? onWalkModeChanged;
  final ValueChanged<String>? onSnapshotSaved;

  const WebGlCanvas3D({
    super.key,
    required this.faces,
    required this.sunPreset,
    this.explodedFactor = 0.0,
    this.sectionCutAxis = SectionCutAxis3D.none,
    this.sectionCutRatio = 0.65,
    this.selectedModuleId,
    this.highlightWallSelection = false,
    this.isPerspective = true,
    this.orientationDegrees = 0.0,
    this.controller,
    this.onSurfaceTapped,
    this.onWalkModeChanged,
    this.onSnapshotSaved,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildWebGlCanvas3D(
      faces: faces,
      sunPreset: sunPreset,
      explodedFactor: explodedFactor,
      sectionCutAxis: sectionCutAxis,
      sectionCutRatio: sectionCutRatio,
      selectedModuleId: selectedModuleId,
      highlightWallSelection: highlightWallSelection,
      isPerspective: isPerspective,
      orientationDegrees: orientationDegrees,
      controller: controller,
      onSurfaceTapped: onSurfaceTapped,
      onWalkModeChanged: onWalkModeChanged,
      onSnapshotSaved: onSnapshotSaved,
    );
  }
}
