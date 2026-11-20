import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:trazzik/features/viewer_3d/domain/geometry_3d.dart';
import 'package:trazzik/features/viewer_3d/domain/webgl_scene_payload.dart';
import 'package:trazzik/features/viewer_3d/presentation/widgets/webgl_canvas_3d.dart';

bool get isWebGlViewerSupported => true;

@JS('window')
external JSObject get _jsWindow;

@JS('document')
external JSObject get _jsDocument;

int _nextViewerInstanceId = 0;

Widget buildWebGlCanvas3D({
  required List<Face3D> faces,
  required SunPreset3D sunPreset,
  required double explodedFactor,
  required SectionCutAxis3D sectionCutAxis,
  required double sectionCutRatio,
  required String? selectedModuleId,
  required bool highlightWallSelection,
  required bool isPerspective,
  required double orientationDegrees,
  required WebGlViewerController? controller,
  required void Function(String? moduleId, String? floorId, bool isWallFace)?
      onSurfaceTapped,
  required ValueChanged<bool>? onWalkModeChanged,
  required ValueChanged<String>? onSnapshotSaved,
}) {
  return _WebGlCanvas3DWeb(
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

class _WebGlCanvas3DWeb extends StatefulWidget {
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

  const _WebGlCanvas3DWeb({
    required this.faces,
    required this.sunPreset,
    required this.explodedFactor,
    required this.sectionCutAxis,
    required this.sectionCutRatio,
    required this.selectedModuleId,
    required this.highlightWallSelection,
    required this.isPerspective,
    required this.orientationDegrees,
    required this.controller,
    required this.onSurfaceTapped,
    required this.onWalkModeChanged,
    required this.onSnapshotSaved,
  });

  @override
  State<_WebGlCanvas3DWeb> createState() => _WebGlCanvas3DWebState();
}

class _WebGlCanvas3DWebState extends State<_WebGlCanvas3DWeb> {
  late final String _viewerId;
  late final String _viewType;
  JSObject? _iframeElement;
  JSFunction? _messageListener;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _viewerId = 'trazzik-webgl-${++_nextViewerInstanceId}';
    _viewType = 'trazzik-webgl-view-$_viewerId';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe =
          _jsDocument.callMethod<JSObject>('createElement'.toJS, 'iframe'.toJS);
      iframe.setProperty('src'.toJS, 'trazzik_webgl_viewer.html?viewerId=$_viewerId'.toJS);
      iframe.setProperty('allow'.toJS, 'fullscreen'.toJS);
      final style = iframe.getProperty<JSObject>('style'.toJS);
      style.setProperty('border'.toJS, 'none'.toJS);
      style.setProperty('width'.toJS, '100%'.toJS);
      style.setProperty('height'.toJS, '100%'.toJS);
      style.setProperty('display'.toJS, 'block'.toJS);
      style.setProperty('background'.toJS, '#0f172a'.toJS);
      _iframeElement = iframe;
      return iframe;
    });

    _messageListener = ((JSObject event) {
      _handleWindowMessage(event);
    }).toJS;
    _jsWindow.callMethod<JSAny?>(
      'addEventListener'.toJS,
      'message'.toJS,
      _messageListener,
    );

    _attachController(widget.controller);
  }

  void _attachController(WebGlViewerController? ctrl) {
    ctrl?.attach(
      onSetCameraPreset: (preset, instant) {
        _postMessage(<String, dynamic>{
          'type': 'setCameraPreset',
          'preset': preset,
          'instant': instant,
        });
      },
      onZoomStep: (factor) {
        _postMessage(<String, dynamic>{
          'type': 'zoomStep',
          'factor': factor,
        });
      },
      onSetWalkMode: (enabled, floorElevation) {
        _postMessage(<String, dynamic>{
          'type': 'setWalkMode',
          'enabled': enabled,
          'floorElevation': floorElevation,
        });
      },
      onCaptureSnapshot: (filename) {
        _postMessage(<String, dynamic>{
          'type': 'captureSnapshot',
          'filename': filename,
        });
      },
    );
  }

  void _handleWindowMessage(JSObject event) {
    final rawData = event.getProperty<JSAny?>('data'.toJS);
    if (rawData == null || !rawData.isA<JSObject>()) return;
    final data = rawData as JSObject;
    final source = data.getProperty<JSAny?>('source'.toJS);
    if (source == null || !source.isA<JSString>() || (source as JSString).toDart != 'trazzik-webgl') {
      return;
    }
    final msgViewerId = data.getProperty<JSAny?>('viewerId'.toJS);
    if (msgViewerId != null &&
        msgViewerId.isA<JSString>() &&
        (msgViewerId as JSString).toDart != _viewerId) {
      return;
    }
    final typeAny = data.getProperty<JSAny?>('type'.toJS);
    if (typeAny == null || !typeAny.isA<JSString>()) return;
    final type = (typeAny as JSString).toDart;

    switch (type) {
      case 'ready':
        _isReady = true;
        _pushFullScene();
        break;
      case 'surfaceTapped':
        final modAny = data.getProperty<JSAny?>('moduleId'.toJS);
        final floorAny = data.getProperty<JSAny?>('floorId'.toJS);
        final wallAny = data.getProperty<JSAny?>('isWallFace'.toJS);
        final modId = (modAny != null && modAny.isA<JSString>())
            ? (modAny as JSString).toDart
            : null;
        final floorId = (floorAny != null && floorAny.isA<JSString>())
            ? (floorAny as JSString).toDart
            : null;
        final isWall = (wallAny != null && wallAny.isA<JSBoolean>())
            ? (wallAny as JSBoolean).toDart
            : false;
        widget.onSurfaceTapped?.call(modId, floorId, isWall);
        break;
      case 'walkModeChanged':
        final enabledAny = data.getProperty<JSAny?>('enabled'.toJS);
        final enabled = (enabledAny != null && enabledAny.isA<JSBoolean>())
            ? (enabledAny as JSBoolean).toDart
            : false;
        widget.onWalkModeChanged?.call(enabled);
        break;
      case 'snapshotSaved':
        final fileAny = data.getProperty<JSAny?>('filename'.toJS);
        final file = (fileAny != null && fileAny.isA<JSString>())
            ? (fileAny as JSString).toDart
            : 'trazzik_render_webgl.png';
        widget.onSnapshotSaved?.call(file);
        break;
    }
  }

  void _postMessage(Map<String, dynamic> msg) {
    if (!_isReady) return;
    final iframe = _iframeElement;
    if (iframe == null) return;
    final contentWindow = iframe.getProperty<JSAny?>('contentWindow'.toJS);
    if (contentWindow == null || !contentWindow.isA<JSObject>()) return;
    final envelope = <String, dynamic>{
      'target': 'trazzik-webgl',
      'viewerId': _viewerId,
      ...msg,
    };
    (contentWindow as JSObject).callMethod<JSAny?>(
      'postMessage'.toJS,
      envelope.jsify(),
      '*'.toJS,
    );
  }

  void _pushFullScene() {
    final payload = WebGlScenePayloadBuilder.buildPayload(
      faces: widget.faces,
      sunPreset: widget.sunPreset,
      explodedFactor: widget.explodedFactor,
      sectionCutAxis: widget.sectionCutAxis,
      sectionCutRatio: widget.sectionCutRatio,
      selectedModuleId: widget.selectedModuleId,
      highlightWallSelection: widget.highlightWallSelection,
      isPerspective: widget.isPerspective,
      orientationDegrees: widget.orientationDegrees,
    );
    _postMessage(<String, dynamic>{
      'type': 'loadScene',
      'payload': payload,
    });
  }

  void _pushSettingsOnly() {
    _postMessage(<String, dynamic>{
      'type': 'updateSettings',
      'settings': <String, dynamic>{
        'sunPreset': widget.sunPreset.name,
        'explodedFactor': widget.explodedFactor,
        'sectionCutAxis': widget.sectionCutAxis.name,
        'sectionCutRatio': widget.sectionCutRatio,
        'selectedModuleId': widget.selectedModuleId,
        'highlightWallSelection': widget.highlightWallSelection,
        'isPerspective': widget.isPerspective,
      },
    });
  }

  @override
  void didUpdateWidget(covariant _WebGlCanvas3DWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach();
      _attachController(widget.controller);
    }
    if (!_isReady) return;

    if (!identical(oldWidget.faces, widget.faces)) {
      _pushFullScene();
    } else if (oldWidget.sunPreset != widget.sunPreset ||
        oldWidget.explodedFactor != widget.explodedFactor ||
        oldWidget.sectionCutAxis != widget.sectionCutAxis ||
        oldWidget.sectionCutRatio != widget.sectionCutRatio ||
        oldWidget.selectedModuleId != widget.selectedModuleId ||
        oldWidget.highlightWallSelection != widget.highlightWallSelection ||
        oldWidget.isPerspective != widget.isPerspective) {
      _pushSettingsOnly();
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    if (_messageListener != null) {
      _jsWindow.callMethod<JSAny?>(
        'removeEventListener'.toJS,
        'message'.toJS,
        _messageListener,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
