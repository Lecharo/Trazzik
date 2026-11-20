import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/canvas_2d_painter.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';

class EditorCanvas2D extends ConsumerStatefulWidget {
  const EditorCanvas2D({super.key});

  @override
  ConsumerState<EditorCanvas2D> createState() => _EditorCanvas2DState();
}

enum _HitKind { opening, subModule, wall, module, none }

class _CanvasHitResult {
  final _HitKind kind;
  final Module? module;
  final SubModule? subModule;
  final String? wallId;
  final Point2D? initialOrigin;

  const _CanvasHitResult.none()
      : kind = _HitKind.none,
        module = null,
        subModule = null,
        wallId = null,
        initialOrigin = null;

  const _CanvasHitResult({
    required this.kind,
    this.module,
    this.subModule,
    this.wallId,
    this.initialOrigin,
  });
}

class _EditorCanvas2DState extends ConsumerState<EditorCanvas2D> {
  String? _draggingModuleId;
  String? _draggingSubModuleId;
  String? _draggingParentModuleId;
  Point2D? _dragStartMeters;
  Point2D? _moduleInitialOrigin;
  double? _moduleInitialWidth;
  double? _moduleInitialHeight;
  Point2D? _subModuleInitialOrigin;

  // Direct handle resize state
  String? _resizingModuleId;
  ResizeHandle2D? _activeResizeHandle;
  double? _resizeInitialMinX;
  double? _resizeInitialMinY;
  double? _resizeInitialMaxX;
  double? _resizeInitialMaxY;

  // Hover, cursor & smart-snap guide feedback state
  String? _hoveredModuleId;
  String? _hoveredWallId;
  ResizeHandle2D? _hoveredHandle;
  Point2D? _cursorMeters;
  List<SnapGuide2D> _activeSnapGuides = const <SnapGuide2D>[];

  bool _isAuxPanning = false;
  bool _isSpacePanning = false;
  Offset? _lastAuxPanPos;
  Offset? _primaryPointerDownLocalPos;

  static MouseCursor _cursorForResizeHandle(ResizeHandle2D handle) {
    switch (handle) {
      case ResizeHandle2D.left:
      case ResizeHandle2D.right:
        return SystemMouseCursors.resizeLeftRight;
      case ResizeHandle2D.top:
      case ResizeHandle2D.bottom:
        return SystemMouseCursors.resizeUpDown;
      case ResizeHandle2D.topLeft:
      case ResizeHandle2D.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case ResizeHandle2D.topRight:
      case ResizeHandle2D.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
    }
  }

  MouseCursor _resolveCursor(FloorEditorState editorState) {
    final handle = _activeResizeHandle ?? _hoveredHandle;
    if (handle != null) {
      return _cursorForResizeHandle(handle);
    }
    if (_isAuxPanning ||
        _isSpacePanning ||
        _draggingModuleId != null ||
        _draggingSubModuleId != null) {
      return SystemMouseCursors.grabbing;
    }
    if (editorState.isDrawWallMode || editorState.isLaserMeasureActive) {
      return SystemMouseCursors.precise;
    }
    if (_hoveredModuleId != null || _hoveredWallId != null) {
      return SystemMouseCursors.click;
    }
    return SystemMouseCursors.grab;
  }

  static ResizeHandle2D? _hitTestResizeHandle(
    Point2D pointMeters,
    FloorEditorState editorState,
  ) {
    final selectedId = editorState.selectedModuleId;
    if (selectedId == null) return null;
    final selected = editorState.floor.modules
        .where((m) => m.id == selectedId)
        .firstOrNull;
    if (selected == null) return null;

    final handles = computeModuleResizeHandles(selected);
    if (handles.isEmpty) return null;

    final tol = math.max(0.16, 12.0 / editorState.zoom);
    ResizeHandle2D? closest;
    double bestDist = tol + 1e-6;
    for (final entry in handles.entries) {
      final d = pointMeters.distanceTo(entry.value);
      if (d <= tol && d < bestDist) {
        bestDist = d;
        closest = entry.key;
      }
    }
    return closest;
  }

  void _updateHover(Offset localPosition, FloorEditorState editorState) {
    if (_isAuxPanning ||
        _isSpacePanning ||
        _draggingModuleId != null ||
        _draggingSubModuleId != null ||
        _resizingModuleId != null) {
      return;
    }
    final metersX = (localPosition.dx - editorState.panOffset.dx) / editorState.zoom;
    final metersY = (localPosition.dy - editorState.panOffset.dy) / editorState.zoom;
    final rawPoint = Point2D(metersX, metersY);
    final quantized = Point2D(
      (metersX * 100).round() / 100.0,
      (metersY * 100).round() / 100.0,
    );

    final nextHandle = (editorState.isDrawWallMode || editorState.isLaserMeasureActive)
        ? null
        : _hitTestResizeHandle(rawPoint, editorState);

    String? nextHoveredModule;
    String? nextHoveredWall;
    if (nextHandle == null &&
        !editorState.isDrawWallMode &&
        !editorState.isLaserMeasureActive) {
      final hit = _hitTestAt(rawPoint, editorState.floor, editorState.zoom);
      if (hit.kind == _HitKind.module ||
          hit.kind == _HitKind.opening ||
          hit.kind == _HitKind.subModule) {
        nextHoveredModule = hit.module?.id;
      } else if (hit.kind == _HitKind.wall) {
        nextHoveredWall = hit.wallId;
      }
    }

    if (quantized != _cursorMeters ||
        nextHandle != _hoveredHandle ||
        nextHoveredModule != _hoveredModuleId ||
        nextHoveredWall != _hoveredWallId) {
      setState(() {
        _cursorMeters = quantized;
        _hoveredHandle = nextHandle;
        _hoveredModuleId = nextHoveredModule;
        _hoveredWallId = nextHoveredWall;
      });
    }
  }

  void _finishDragGesture(FloorEditorNotifier notifier) {
    if (_draggingModuleId != null ||
        _draggingSubModuleId != null ||
        _resizingModuleId != null) {
      notifier.endInteraction();
    }
    if (mounted) {
      setState(() {
        _draggingModuleId = null;
        _draggingSubModuleId = null;
        _draggingParentModuleId = null;
        _dragStartMeters = null;
        _moduleInitialOrigin = null;
        _moduleInitialWidth = null;
        _moduleInitialHeight = null;
        _subModuleInitialOrigin = null;
        _resizingModuleId = null;
        _activeResizeHandle = null;
        _resizeInitialMinX = null;
        _resizeInitialMinY = null;
        _resizeInitialMaxX = null;
        _resizeInitialMaxY = null;
        _activeSnapGuides = const <SnapGuide2D>[];
        _isSpacePanning = false;
      });
    }
  }

  static _CanvasHitResult _hitTestAt(
    Point2D clickPoint,
    Floor floor,
    double zoom,
  ) {
    // 0. Prioritize openings (doors, windows, gates) mounted on room borders.
    for (final module in floor.modules.reversed) {
      if (module.isOpening && _isPointNearOpening(clickPoint, module, zoom)) {
        return _CanvasHitResult(
          kind: _HitKind.opening,
          module: module,
          initialOrigin: Point2D(
            module.geometry.boundingBox.minX,
            module.geometry.boundingBox.minY,
          ),
        );
      }
    }

    // 1. Interior furniture / fixtures (subModules).
    for (final module in floor.modules.reversed) {
      for (final sub in module.subModules.reversed) {
        if (sub.geometry.containsPoint(clickPoint)) {
          return _CanvasHitResult(
            kind: _HitKind.subModule,
            module: module,
            subModule: sub,
            initialOrigin: Point2D(
              sub.geometry.boundingBox.minX,
              sub.geometry.boundingBox.minY,
            ),
          );
        }
      }
    }

    // 2. Walls with unified screen-space / meter tolerance.
    final wallToleranceMeters = math.max(0.28, 14.0 / zoom);
    for (final wall in floor.walls.reversed) {
      if (wall.footprint.containsPoint(clickPoint) ||
          GeometryEngine.distanceToSegment(
                clickPoint,
                wall.startPoint,
                wall.endPoint,
              ) <=
              wallToleranceMeters) {
        return _CanvasHitResult(
          kind: _HitKind.wall,
          wallId: wall.id,
        );
      }
    }

    // 3. Regular room modules.
    for (final module in floor.modules.reversed) {
      if (!module.isOpening && module.geometry.containsPoint(clickPoint)) {
        return _CanvasHitResult(
          kind: _HitKind.module,
          module: module,
          initialOrigin: Point2D(
            module.geometry.boundingBox.minX,
            module.geometry.boundingBox.minY,
          ),
        );
      }
    }

    return const _CanvasHitResult.none();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);

    return MouseRegion(
      cursor: _resolveCursor(editorState),
      onHover: (event) => _updateHover(event.localPosition, editorState),
      onExit: (_) {
        if (_cursorMeters != null ||
            _hoveredHandle != null ||
            _hoveredModuleId != null ||
            _hoveredWallId != null) {
          setState(() {
            _cursorMeters = null;
            _hoveredHandle = null;
            _hoveredModuleId = null;
            _hoveredWallId = null;
          });
        }
      },
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final zoomFactor = pointerSignal.scrollDelta.dy < 0 ? 1.12 : 0.89;
            notifier.zoomAtPoint(
              editorState.zoom * zoomFactor,
              pointerSignal.localPosition,
            );
          }
        },
        onPointerDown: (event) {
          final isAuxButton = (event.buttons & kMiddleMouseButton) != 0 ||
              (event.buttons & kSecondaryMouseButton) != 0;
          if (isAuxButton) {
            setState(() {
              _isAuxPanning = true;
              _lastAuxPanPos = event.localPosition;
            });
          } else {
            _primaryPointerDownLocalPos = event.localPosition;
          }
        },
        onPointerMove: (event) {
          if (_isAuxPanning && _lastAuxPanPos != null) {
            final delta = event.localPosition - _lastAuxPanPos!;
            _lastAuxPanPos = event.localPosition;
            notifier.updatePan(delta);
          }
        },
        onPointerUp: (_) {
          _primaryPointerDownLocalPos = null;
          if (_isAuxPanning) {
            setState(() {
              _isAuxPanning = false;
              _lastAuxPanPos = null;
            });
          }
        },
        onPointerCancel: (_) {
          _primaryPointerDownLocalPos = null;
          if (_isAuxPanning) {
            setState(() {
              _isAuxPanning = false;
              _lastAuxPanPos = null;
            });
          }
        },
        child: GestureDetector(
      onPanStart: (details) {
        if (_isAuxPanning) return;
        if (HardwareKeyboard.instance
            .isLogicalKeyPressed(LogicalKeyboardKey.space)) {
          setState(() => _isSpacePanning = true);
          return;
        }
        final localPos = _primaryPointerDownLocalPos ?? details.localPosition;
        final metersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
        final metersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
        final clickPoint = Point2D(metersX, metersY);

        if (editorState.isDrawWallMode) {
          final snapped = notifier.snapToNearestVertexOrGrid(clickPoint);
          notifier.setDraftWallPoints(snapped, snapped);
          return;
        }

        if (editorState.isLaserMeasureActive) {
          final snapped = notifier.snapToNearestVertexOrGrid(clickPoint);
          notifier.setLaserMeasurePoints(snapped, snapped);
          return;
        }

        // Check direct resize handle hit on the currently selected room first
        final hitHandle = _hitTestResizeHandle(clickPoint, editorState);
        if (hitHandle != null && editorState.selectedModuleId != null) {
          final selectedMod = editorState.floor.modules
              .where((m) => m.id == editorState.selectedModuleId)
              .firstOrNull;
          if (selectedMod != null && !selectedMod.isLocked) {
            final bb = selectedMod.geometry.boundingBox;
            setState(() {
              _resizingModuleId = selectedMod.id;
              _activeResizeHandle = hitHandle;
              _resizeInitialMinX = bb.minX;
              _resizeInitialMinY = bb.minY;
              _resizeInitialMaxX = bb.maxX;
              _resizeInitialMaxY = bb.maxY;
              _draggingModuleId = null;
              _draggingSubModuleId = null;
              _draggingParentModuleId = null;
              _dragStartMeters = clickPoint;
              _activeSnapGuides = const <SnapGuide2D>[];
            });
            notifier.beginInteraction();
            return;
          }
        }

        final hit = _hitTestAt(clickPoint, editorState.floor, editorState.zoom);

        switch (hit.kind) {
          case _HitKind.opening:
          case _HitKind.module:
            final hitMod = hit.module!;
            final hitBb = hitMod.geometry.boundingBox;
            setState(() {
              _draggingModuleId = hitMod.isLocked ? null : hitMod.id;
              _dragStartMeters = hitMod.isLocked ? null : clickPoint;
              _moduleInitialOrigin = hitMod.isLocked ? null : hit.initialOrigin;
              _moduleInitialWidth = hitMod.isLocked ? null : hitBb.width;
              _moduleInitialHeight = hitMod.isLocked ? null : hitBb.height;
              _draggingSubModuleId = null;
              _draggingParentModuleId = null;
              _subModuleInitialOrigin = null;
              _resizingModuleId = null;
              _activeResizeHandle = null;
              _activeSnapGuides = const <SnapGuide2D>[];
            });
            notifier.selectModule(hitMod.id);
            if (!hitMod.isLocked) {
              notifier.beginInteraction();
            }
            break;
          case _HitKind.subModule:
            final parentMod = hit.module!;
            final hitSub = hit.subModule!;
            setState(() {
              _draggingSubModuleId = hitSub.isLocked ? null : hitSub.id;
              _draggingParentModuleId = hitSub.isLocked ? null : parentMod.id;
              _subModuleInitialOrigin = hitSub.isLocked ? null : hit.initialOrigin;
              _dragStartMeters = hitSub.isLocked ? null : clickPoint;
              _draggingModuleId = null;
              _moduleInitialOrigin = null;
            });
            notifier.selectSubModule(parentMod.id, hitSub.id);
            if (!hitSub.isLocked) {
              notifier.beginInteraction();
            }
            break;
          case _HitKind.wall:
            notifier.selectWall(hit.wallId);
            setState(() {
              _draggingModuleId = null;
              _dragStartMeters = null;
              _moduleInitialOrigin = null;
              _draggingSubModuleId = null;
              _draggingParentModuleId = null;
              _subModuleInitialOrigin = null;
            });
            break;
          case _HitKind.none:
            setState(() {
              _draggingModuleId = null;
              _dragStartMeters = null;
              _moduleInitialOrigin = null;
              _draggingSubModuleId = null;
              _draggingParentModuleId = null;
              _subModuleInitialOrigin = null;
            });
            break;
        }
      },
      onPanUpdate: (details) {
        if (_isAuxPanning) return;
        if (_isSpacePanning) {
          notifier.updatePan(details.delta);
          return;
        }
        if (editorState.isDrawWallMode) {
          final localPos = details.localPosition;
          final curMetersX =
              (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
          final curMetersY =
              (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
          final snappedEnd = notifier.snapToNearestVertexOrGrid(
            Point2D(curMetersX, curMetersY),
            snapRadiusMeters: (12.0 / editorState.zoom).clamp(0.12, 0.45),
          );
          final startPt = editorState.draftWallStart ?? snappedEnd;
          notifier.setDraftWallPoints(startPt, snappedEnd);
          return;
        }

        if (editorState.isLaserMeasureActive) {
          final localPos = details.localPosition;
          final curMetersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
          final curMetersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
          final snappedEnd = notifier.snapToNearestVertexOrGrid(
            Point2D(curMetersX, curMetersY),
            snapRadiusMeters: (12.0 / editorState.zoom).clamp(0.12, 0.45),
          );
          final startPt = editorState.laserStart ?? snappedEnd;
          notifier.setLaserMeasurePoints(startPt, snappedEnd);
          return;
        }

        if (_resizingModuleId != null &&
            _activeResizeHandle != null &&
            _resizeInitialMinX != null &&
            _resizeInitialMinY != null &&
            _resizeInitialMaxX != null &&
            _resizeInitialMaxY != null) {
          final localPos = details.localPosition;
          final curMetersX =
              (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
          final curMetersY =
              (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
          final snappedX = FloorEditorNotifier.snapToGrid(curMetersX, 0.05);
          final snappedY = FloorEditorNotifier.snapToGrid(curMetersY, 0.05);

          const minDim = 0.40;
          double newMinX = _resizeInitialMinX!;
          double newMinY = _resizeInitialMinY!;
          double newMaxX = _resizeInitialMaxX!;
          double newMaxY = _resizeInitialMaxY!;

          final handle = _activeResizeHandle!;
          final movesLeft = handle == ResizeHandle2D.left ||
              handle == ResizeHandle2D.topLeft ||
              handle == ResizeHandle2D.bottomLeft;
          final movesRight = handle == ResizeHandle2D.right ||
              handle == ResizeHandle2D.topRight ||
              handle == ResizeHandle2D.bottomRight;
          final movesTop = handle == ResizeHandle2D.top ||
              handle == ResizeHandle2D.topLeft ||
              handle == ResizeHandle2D.topRight;
          final movesBottom = handle == ResizeHandle2D.bottom ||
              handle == ResizeHandle2D.bottomLeft ||
              handle == ResizeHandle2D.bottomRight;

          if (movesLeft) {
            newMinX = math.min(snappedX, newMaxX - minDim);
          } else if (movesRight) {
            newMaxX = math.max(snappedX, newMinX + minDim);
          }

          if (movesTop) {
            newMinY = math.min(snappedY, newMaxY - minDim);
          } else if (movesBottom) {
            newMaxY = math.max(snappedY, newMinY + minDim);
          }

          final newW = math.max(minDim, newMaxX - newMinX);
          final newH = math.max(minDim, newMaxY - newMinY);

          if (movesLeft || movesTop) {
            notifier.setModulePosition(
              _resizingModuleId!,
              newMinX,
              newMinY,
              snap: false,
            );
          }
          notifier.setModuleDimensions(
            _resizingModuleId!,
            newW,
            newH,
            snap: false,
          );
          final quantizedCursor = Point2D(
            (curMetersX * 100).round() / 100.0,
            (curMetersY * 100).round() / 100.0,
          );
          if (quantizedCursor != _cursorMeters) {
            setState(() => _cursorMeters = quantizedCursor);
          }
          return;
        }

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
          // Arrastrar recinto completo con guías magnéticas inteligentes (Smart Snap)
          final localPos = details.localPosition;
          final curMetersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
          final curMetersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
          final deltaX = curMetersX - _dragStartMeters!.x;
          final deltaY = curMetersY - _dragStartMeters!.y;

          final rawTargetX = FloorEditorNotifier.snapToGrid(_moduleInitialOrigin!.x + deltaX, 0.05);
          final rawTargetY = FloorEditorNotifier.snapToGrid(_moduleInitialOrigin!.y + deltaY, 0.05);

          final draggedMod = editorState.floor.modules
              .where((m) => m.id == _draggingModuleId)
              .firstOrNull;
          if (draggedMod != null && !draggedMod.isOpening) {
            final snapResult = computeSmartSnapGuides(
              candidateX: rawTargetX,
              candidateY: rawTargetY,
              width: _moduleInitialWidth ?? draggedMod.geometry.boundingBox.width,
              height: _moduleInitialHeight ?? draggedMod.geometry.boundingBox.height,
              floor: editorState.floor,
              excludeModuleId: _draggingModuleId!,
            );
            notifier.setModulePosition(
              _draggingModuleId!,
              snapResult.x,
              snapResult.y,
              snap: false,
            );
            setState(() {
              _activeSnapGuides = snapResult.guides;
              _cursorMeters = Point2D(
                (curMetersX * 100).round() / 100.0,
                (curMetersY * 100).round() / 100.0,
              );
            });
          } else {
            notifier.setModulePosition(_draggingModuleId!, rawTargetX, rawTargetY);
          }
        } else {
          notifier.updatePan(details.delta);
        }
      },
      onPanEnd: (_) {
        if (editorState.isDrawWallMode) {
          notifier.commitDraftWall();
          return;
        }
        _finishDragGesture(notifier);
      },
      onPanCancel: () {
        if (editorState.isDrawWallMode) {
          notifier.setDraftWallPoints(null, null);
          return;
        }
        _finishDragGesture(notifier);
      },
      onTapUp: (details) {
        final localPos = details.localPosition;
        final metersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
        final metersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
        final clickPoint = Point2D(metersX, metersY);

        if (editorState.isDrawWallMode) {
          final snapped = notifier.snapToNearestVertexOrGrid(
            clickPoint,
            snapRadiusMeters: (12.0 / editorState.zoom).clamp(0.12, 0.45),
          );
          if (editorState.draftWallStart == null) {
            notifier.setDraftWallPoints(snapped, snapped);
          } else {
            notifier.setDraftWallPoints(editorState.draftWallStart, snapped);
            notifier.commitDraftWall();
          }
          return;
        }

        if (editorState.isLaserMeasureActive) {
          final snapped = notifier.snapToNearestVertexOrGrid(
            clickPoint,
            snapRadiusMeters: (12.0 / editorState.zoom).clamp(0.12, 0.45),
          );
          if (editorState.laserStart == null ||
              (editorState.laserEnd != null &&
                  editorState.laserStart != editorState.laserEnd)) {
            notifier.setLaserMeasurePoints(snapped, snapped);
          } else {
            notifier.setLaserMeasurePoints(editorState.laserStart, snapped);
          }
          return;
        }

        final hit = _hitTestAt(clickPoint, editorState.floor, editorState.zoom);

        switch (hit.kind) {
          case _HitKind.opening:
          case _HitKind.module:
            notifier.selectModule(hit.module!.id);
            break;
          case _HitKind.subModule:
            notifier.selectSubModule(hit.module!.id, hit.subModule!.id);
            break;
          case _HitKind.wall:
            notifier.selectWall(hit.wallId);
            break;
          case _HitKind.none:
            notifier.selectModule(null);
            break;
        }
      },
      child: RepaintBoundary(
        child: ClipRect(
          child: CustomPaint(
            size: Size.infinite,
            painter: Canvas2DPainter(
              editorState,
              lang: ref.watch(appLocaleProvider),
              isDarkTheme: Theme.of(context).brightness == Brightness.dark,
              hoveredModuleId: _hoveredModuleId,
              hoveredWallId: _hoveredWallId,
              hoveredHandle: _hoveredHandle,
              activeHandle: _activeResizeHandle,
              cursorMeters: _cursorMeters,
              snapGuides: _activeSnapGuides,
            ),
          ),
        ),
      ),
    ),
    ),
    );
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
    if (module.isSwingDoor) {
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
}
