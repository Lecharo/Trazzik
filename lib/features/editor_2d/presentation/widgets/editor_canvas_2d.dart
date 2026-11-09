import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
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
  Point2D? _subModuleInitialOrigin;

  void _finishDragGesture(FloorEditorNotifier notifier) {
    if (_draggingModuleId != null || _draggingSubModuleId != null) {
      notifier.endInteraction();
    }
    if (mounted) {
      setState(() {
        _draggingModuleId = null;
        _draggingSubModuleId = null;
        _draggingParentModuleId = null;
        _dragStartMeters = null;
        _moduleInitialOrigin = null;
        _subModuleInitialOrigin = null;
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

    return GestureDetector(
      onPanStart: (details) {
        final localPos = details.localPosition;
        final metersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
        final metersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
        final clickPoint = Point2D(metersX, metersY);
        final hit = _hitTestAt(clickPoint, editorState.floor, editorState.zoom);

        switch (hit.kind) {
          case _HitKind.opening:
          case _HitKind.module:
            final hitMod = hit.module!;
            setState(() {
              _draggingModuleId = hitMod.isLocked ? null : hitMod.id;
              _dragStartMeters = hitMod.isLocked ? null : clickPoint;
              _moduleInitialOrigin = hitMod.isLocked ? null : hit.initialOrigin;
              _draggingSubModuleId = null;
              _draggingParentModuleId = null;
              _subModuleInitialOrigin = null;
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
      onPanEnd: (_) => _finishDragGesture(notifier),
      onPanCancel: () => _finishDragGesture(notifier),
      onTapUp: (details) {
        final localPos = details.localPosition;
        final metersX = (localPos.dx - editorState.panOffset.dx) / editorState.zoom;
        final metersY = (localPos.dy - editorState.panOffset.dy) / editorState.zoom;
        final clickPoint = Point2D(metersX, metersY);
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
            painter: Canvas2DPainter(editorState),
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
