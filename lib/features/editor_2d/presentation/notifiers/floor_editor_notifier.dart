import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/validation/validation_engine.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/mvp_floor_seed.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/furniture_template.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/walls/domain/wall.dart';
import 'package:trazzik/features/walls/domain/wall_generation_engine.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_brief.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_layout_generator.dart';
import 'package:trazzik/features/zoning_assistant/domain/starter_layout_template.dart';

final floorEditorProvider =
    NotifierProvider<FloorEditorNotifier, FloorEditorState>(
  FloorEditorNotifier.new,
);

class FloorEditorNotifier extends Notifier<FloorEditorState> {
  static const int maxUndoHistory = 50;

  bool _isInteracting = false;
  Floor? _interactionInitialFloor;
  bool _interactionMutated = false;

  void _resetInteractionState() {
    _isInteracting = false;
    _interactionInitialFloor = null;
    _interactionMutated = false;
  }

  static List<Floor> _pushBoundedUndo(
    List<Floor> currentStack,
    Floor snapshot,
  ) {
    final updated = List<Floor>.from(currentStack)..add(snapshot);
    if (updated.length > maxUndoHistory) {
      return updated.sublist(updated.length - maxUndoHistory);
    }
    return updated;
  }

  @override
  FloorEditorState build() {
    _resetInteractionState();
    return MvpFloorSeed.buildInitialState();
  }

  void loadProjectData({
    required Lot lot,
    required Floor floor,
    List<Floor> allFloors = const [],
    Project? project,
  }) {
    _resetInteractionState();
    final cleanFloor = floor.copyWith(walls: Wall.deduplicate(floor.walls));
    final cleanAllFloors = allFloors.map((f) => f.copyWith(walls: Wall.deduplicate(f.walls))).toList();
    final floorsList = cleanAllFloors.isNotEmpty ? cleanAllFloors : [cleanFloor];

    state = FloorEditorState(
      lot: lot,
      floor: cleanFloor,
      allFloors: floorsList,
      project: project,
      selectedModuleId: cleanFloor.modules.isNotEmpty ? cleanFloor.modules.first.id : null,
      issues: ValidationEngine.validateFloor(floor: cleanFloor, lot: lot),
      zoom: 35.0,
      panOffset: const Offset(80.0, 80.0),
      undoStack: const [],
      redoStack: const [],
      undoStacksByFloor: const {},
      redoStacksByFloor: const {},
      dirtyFloorIds: const {},
      deletedFloorIds: const {},
    );
  }

  void selectModule(String? id) {
    state = state.copyWith(
      selectedModuleId: id,
      clearSelection: id == null,
      clearWallSelection: true,
      clearSubModuleSelection: true,
    );
  }

  void selectSubModule(String? moduleId, String? subModuleId) {
    state = state.copyWith(
      selectedModuleId: moduleId,
      selectedSubModuleId: subModuleId,
      clearSelection: moduleId == null,
      clearWallSelection: true,
      clearSubModuleSelection: subModuleId == null,
    );
  }

  void selectWall(String? id) {
    state = state.copyWith(
      selectedWallId: id,
      clearWallSelection: id == null,
      clearSelection: id != null,
      clearSubModuleSelection: true,
    );
  }

  void updatePan(Offset delta) {
    state = state.copyWith(panOffset: state.panOffset + delta);
  }

  void updateZoom(double newZoom) {
    final clampedZoom = newZoom.clamp(15.0, 100.0);
    state = state.copyWith(zoom: clampedZoom);
  }

  /// Starts an interactive gesture transaction (such as dragging on canvas)
  /// so intermediate frames coalesce into one Undo step and defer validation.
  void beginInteraction() {
    if (_isInteracting) {
      endInteraction();
    }
    _isInteracting = true;
    _interactionInitialFloor = state.floor;
    _interactionMutated = false;
  }

  /// Finalizes an interactive gesture transaction and runs floor validation once.
  void endInteraction() {
    if (!_isInteracting) return;
    final mutated = _interactionMutated;
    _resetInteractionState();

    if (mutated) {
      final issues = ValidationEngine.validateFloor(
        floor: state.floor,
        lot: state.lot,
      );
      final updatedUndoMap = Map<String, List<Floor>>.from(state.undoStacksByFloor)
        ..[state.floor.id] = state.undoStack;
      final updatedRedoMap = Map<String, List<Floor>>.from(state.redoStacksByFloor)
        ..[state.floor.id] = state.redoStack;

      state = state.copyWith(
        issues: issues,
        undoStacksByFloor: updatedUndoMap,
        redoStacksByFloor: updatedRedoMap,
      );
    }
  }

  /// Aplica una nueva versión del piso registrando la anterior en el historial de Undo
  void _applyFloorChange(Floor newFloor) {
    final baseAll = state.allFloors.isNotEmpty ? state.allFloors : [state.floor];
    final hasFloorInAll = baseAll.any((f) => f.id == newFloor.id);
    final updatedAllFloors = hasFloorInAll
        ? baseAll.map((f) => f.id == newFloor.id ? newFloor : f).toList()
        : [...baseAll, newFloor];
    final updatedDirtyIds = {...state.dirtyFloorIds, newFloor.id};

    if (_isInteracting) {
      final List<Floor> nextUndo;
      if (!_interactionMutated) {
        nextUndo = _pushBoundedUndo(
          state.undoStack,
          _interactionInitialFloor ?? state.floor,
        );
        _interactionMutated = true;
      } else {
        nextUndo = state.undoStack;
      }

      state = state.copyWith(
        floor: newFloor,
        allFloors: updatedAllFloors,
        undoStack: nextUndo,
        redoStack: const [],
        dirtyFloorIds: updatedDirtyIds,
        hasUnsavedChanges: true,
      );
      return;
    }

    final newUndo = _pushBoundedUndo(state.undoStack, state.floor);
    final issues = ValidationEngine.validateFloor(floor: newFloor, lot: state.lot);
    final updatedUndoMap = Map<String, List<Floor>>.from(state.undoStacksByFloor)
      ..[newFloor.id] = newUndo;
    final updatedRedoMap = Map<String, List<Floor>>.from(state.redoStacksByFloor)
      ..[newFloor.id] = const [];

    state = state.copyWith(
      floor: newFloor,
      allFloors: updatedAllFloors,
      issues: issues,
      undoStack: newUndo,
      redoStack: const [], // Limpiar redo en nueva acción
      undoStacksByFloor: updatedUndoMap,
      redoStacksByFloor: updatedRedoMap,
      dirtyFloorIds: updatedDirtyIds,
      hasUnsavedChanges: true,
    );
  }

  void switchFloor(String targetFloorId) {
    if (_isInteracting) {
      endInteraction();
    }
    if (state.floor.id == targetFloorId) return;

    // 1. Guardar el estado e historial del piso saliente
    final baseAll = state.allFloors.isNotEmpty ? state.allFloors : [state.floor];
    final updatedAllFloors = baseAll.map((f) {
      return f.id == state.floor.id ? state.floor : f;
    }).toList();

    final updatedUndoMap = Map<String, List<Floor>>.from(state.undoStacksByFloor)
      ..[state.floor.id] = state.undoStack;
    final updatedRedoMap = Map<String, List<Floor>>.from(state.redoStacksByFloor)
      ..[state.floor.id] = state.redoStack;

    // 2. Obtener el piso destino y restaurar su historial propio
    final targetFloor = updatedAllFloors.firstWhere(
      (f) => f.id == targetFloorId,
      orElse: () => state.floor,
    );

    final issues = ValidationEngine.validateFloor(floor: targetFloor, lot: state.lot);
    final keepUnsaved =
        state.dirtyFloorIds.isNotEmpty || state.deletedFloorIds.isNotEmpty;

    state = state.copyWith(
      floor: targetFloor,
      allFloors: updatedAllFloors,
      clearSelection: true,
      clearWallSelection: true,
      clearSubModuleSelection: true,
      issues: issues,
      undoStack: updatedUndoMap[targetFloor.id] ?? const [],
      redoStack: updatedRedoMap[targetFloor.id] ?? const [],
      undoStacksByFloor: updatedUndoMap,
      redoStacksByFloor: updatedRedoMap,
      hasUnsavedChanges: keepUnsaved,
    );
  }

  void markFloorSaved() {
    state = state.copyWith(
      dirtyFloorIds: const {},
      deletedFloorIds: const {},
      hasUnsavedChanges: false,
    );
  }

  void undo() {
    if (_isInteracting) {
      endInteraction();
    }
    if (state.undoStack.isEmpty) return;
    final previousFloor = state.undoStack.last;
    final newUndo = List<Floor>.from(state.undoStack)..removeLast();
    final newRedo = _pushBoundedUndo(state.redoStack, state.floor);
    final issues = ValidationEngine.validateFloor(floor: previousFloor, lot: state.lot);

    final updatedAllFloors = state.allFloors.map((f) {
      return f.id == previousFloor.id ? previousFloor : f;
    }).toList();
    final updatedUndoMap = Map<String, List<Floor>>.from(state.undoStacksByFloor)
      ..[previousFloor.id] = newUndo;
    final updatedRedoMap = Map<String, List<Floor>>.from(state.redoStacksByFloor)
      ..[previousFloor.id] = newRedo;
    final updatedDirtyIds = {...state.dirtyFloorIds, previousFloor.id};

    final hasSelectedModule = state.selectedModuleId != null &&
        previousFloor.modules.any((m) => m.id == state.selectedModuleId);
    final hasSelectedSub = hasSelectedModule &&
        state.selectedSubModuleId != null &&
        previousFloor.modules
            .firstWhere((m) => m.id == state.selectedModuleId)
            .subModules
            .any((s) => s.id == state.selectedSubModuleId);
    final hasSelectedWall = state.selectedWallId != null &&
        previousFloor.walls.any((w) => w.id == state.selectedWallId);

    state = state.copyWith(
      floor: previousFloor,
      allFloors: updatedAllFloors,
      issues: issues,
      undoStack: newUndo,
      redoStack: newRedo,
      undoStacksByFloor: updatedUndoMap,
      redoStacksByFloor: updatedRedoMap,
      dirtyFloorIds: updatedDirtyIds,
      hasUnsavedChanges: true,
      clearSelection: !hasSelectedModule,
      clearSubModuleSelection: !hasSelectedSub,
      clearWallSelection: !hasSelectedWall,
    );
  }

  void redo() {
    if (_isInteracting) {
      endInteraction();
    }
    if (state.redoStack.isEmpty) return;
    final nextFloor = state.redoStack.last;
    final newRedo = List<Floor>.from(state.redoStack)..removeLast();
    final newUndo = _pushBoundedUndo(state.undoStack, state.floor);
    final issues = ValidationEngine.validateFloor(floor: nextFloor, lot: state.lot);

    final updatedAllFloors = state.allFloors.map((f) {
      return f.id == nextFloor.id ? nextFloor : f;
    }).toList();
    final updatedUndoMap = Map<String, List<Floor>>.from(state.undoStacksByFloor)
      ..[nextFloor.id] = newUndo;
    final updatedRedoMap = Map<String, List<Floor>>.from(state.redoStacksByFloor)
      ..[nextFloor.id] = newRedo;
    final updatedDirtyIds = {...state.dirtyFloorIds, nextFloor.id};

    final hasSelectedModule = state.selectedModuleId != null &&
        nextFloor.modules.any((m) => m.id == state.selectedModuleId);
    final hasSelectedSub = hasSelectedModule &&
        state.selectedSubModuleId != null &&
        nextFloor.modules
            .firstWhere((m) => m.id == state.selectedModuleId)
            .subModules
            .any((s) => s.id == state.selectedSubModuleId);
    final hasSelectedWall = state.selectedWallId != null &&
        nextFloor.walls.any((w) => w.id == state.selectedWallId);

    state = state.copyWith(
      floor: nextFloor,
      allFloors: updatedAllFloors,
      issues: issues,
      undoStack: newUndo,
      redoStack: newRedo,
      undoStacksByFloor: updatedUndoMap,
      redoStacksByFloor: updatedRedoMap,
      dirtyFloorIds: updatedDirtyIds,
      hasUnsavedChanges: true,
      clearSelection: !hasSelectedModule,
      clearSubModuleSelection: !hasSelectedSub,
      clearWallSelection: !hasSelectedWall,
    );
  }

  /// Desplaza el módulo seleccionado en metros junto con su mobiliario interior
  void moveSelectedModule(double dxMeters, double dyMeters) {
    final selected = state.selectedModule;
    if (selected == null) return;
    if (dxMeters.abs() < 1e-6 && dyMeters.abs() < 1e-6) return;

    final updatedSubs = selected.subModules
        .map((s) => s.copyWith(geometry: s.geometry.translate(dxMeters, dyMeters)))
        .toList();

    final updatedModule = selected.copyWith(
      geometry: selected.geometry.translate(dxMeters, dyMeters),
      subModules: updatedSubs,
    );

    final updatedModules = state.floor.modules.map((m) {
      return m.id == selected.id ? updatedModule : m;
    }).toList();

    _applyFloorChange(state.floor.copyWith(modules: updatedModules));
  }

  static double snapToGrid(double value, [double step = 0.05]) {
    return (value / step).round() * step;
  }

  void addModule(Module module) {
    final updatedModules = List<Module>.from(state.floor.modules)..add(module);
    final updatedFloor = state.floor.copyWith(modules: updatedModules);
    _applyFloorChange(updatedFloor);
    state = state.copyWith(selectedModuleId: module.id);
  }

  void updateModule(Module module) {
    final updatedModules = state.floor.modules.map((m) {
      return m.id == module.id ? module : m;
    }).toList();
    _applyFloorChange(state.floor.copyWith(modules: updatedModules));
  }

  void deleteModule(String moduleId) {
    final updatedModules =
        state.floor.modules.where((m) => m.id != moduleId).toList();
    final updatedRels = state.floor.replacementRelationships
        .where(
          (r) =>
              r.existingElementId != moduleId &&
              r.proposedElementId != moduleId,
        )
        .toList();
    final updatedFloor = state.floor.copyWith(
      modules: updatedModules,
      replacementRelationships: updatedRels,
    );
    _applyFloorChange(updatedFloor);
    if (state.selectedModuleId == moduleId) {
      state = state.copyWith(
        clearSelection: true,
        clearSubModuleSelection: true,
      );
    }
  }

  void duplicateModule(String moduleId) {
    final original = state.floor.modules.firstWhere((m) => m.id == moduleId);
    const uuid = Uuid();
    final newId = uuid.v4();
    final clonedSubs = original.subModules
        .map(
          (s) => s.copyWith(
            id: uuid.v4(),
            moduleId: newId,
            geometry: s.geometry.translate(0.50, 0.50),
          ),
        )
        .toList();
    final duplicated = original.copyWith(
      id: newId,
      name: '${original.name} (Copia)',
      geometry: original.geometry.translate(0.50, 0.50),
      subModules: clonedSubs,
    );
    addModule(duplicated);
  }

  void setModulePosition(String moduleId, double newX, double newY) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final bb = mod.geometry.boundingBox;
    final snappedX = snapToGrid(newX);
    final snappedY = snapToGrid(newY);
    final dx = snappedX - bb.minX;
    final dy = snappedY - bb.minY;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return;
    final updatedGeom = mod.geometry.translate(dx, dy);
    final updatedSubs = mod.subModules.isEmpty
        ? mod.subModules
        : mod.subModules
            .map((s) => s.copyWith(geometry: s.geometry.translate(dx, dy)))
            .toList();
    updateModule(mod.copyWith(geometry: updatedGeom, subModules: updatedSubs));
  }

  void setModuleDimensions(String moduleId, double newWidth, double newHeight) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final bb = mod.geometry.boundingBox;
    final snappedW = math.max(0.10, snapToGrid(newWidth));
    final snappedH = math.max(0.10, snapToGrid(newHeight));

    final Polygon2D updatedGeom;
    if (mod.geometry.vertices.length == 4) {
      updatedGeom = Polygon2D.fromRect(bb.minX, bb.minY, snappedW, snappedH);
    } else {
      // Polígono irregular (ej. forma en L): escalar proporcionalmente preservando el remetido/quiebre
      final scaleX = bb.width > 0 ? (snappedW / bb.width) : 1.0;
      final scaleY = bb.height > 0 ? (snappedH / bb.height) : 1.0;
      updatedGeom = mod.geometry.scale(scaleX, scaleY);
    }
    updateModule(mod.copyWith(geometry: updatedGeom));
  }

  /// Alterna entre forma rectangular simple y forma en L con remetido de acceso (0.50m)
  void toggleLShapedNook(String moduleId, {double nookW = 0.50, double nookD = 0.50}) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final bb = mod.geometry.boundingBox;
    final Polygon2D newGeom;
    if (mod.geometry.vertices.length > 4) {
      // Simplificar a rectángulo puro
      newGeom = Polygon2D.fromRect(bb.minX, bb.minY, bb.width, bb.height);
    } else {
      // Crear quiebre en L con remetido de acceso (0.50m) en la esquina frontal
      final w = bb.width;
      final h = bb.height;
      final nw = math.min(nookW, w * 0.4);
      final nh = math.min(nookD, h * 0.4);
      newGeom = Polygon2D([
        Point2D(bb.minX, bb.minY),
        Point2D(bb.minX + w - nw, bb.minY),
        Point2D(bb.minX + w - nw, bb.minY + nh),
        Point2D(bb.minX + w, bb.minY + nh),
        Point2D(bb.minX + w, bb.minY + h),
        Point2D(bb.minX, bb.minY + h),
      ]);
    }
    updateModule(mod.copyWith(geometry: newGeom));
  }

  /// Rota el módulo 90 grados intercambiando ancho y largo respecto a su centro
  void rotateModule90(String moduleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final bb = mod.geometry.boundingBox;
    final center = Point2D(bb.minX + bb.width / 2, bb.minY + bb.height / 2);

    final Polygon2D updatedGeom;
    if (mod.geometry.vertices.length == 4) {
      final newWidth = bb.height;
      final newHeight = bb.width;
      final newMinX = snapToGrid(center.x - newWidth / 2);
      final newMinY = snapToGrid(center.y - newHeight / 2);
      updatedGeom = Polygon2D.fromRect(newMinX, newMinY, newWidth, newHeight);
    } else {
      updatedGeom = mod.geometry.rotate90(center: center);
    }

    final updatedSubs = mod.subModules.isEmpty
        ? mod.subModules
        : mod.subModules.map((s) {
            final rotatedSub = s.geometry.rotate90(center: center);
            final sbb = rotatedSub.boundingBox;
            return s.copyWith(
              geometry: Polygon2D.fromRect(
                snapToGrid(sbb.minX),
                snapToGrid(sbb.minY),
                sbb.width,
                sbb.height,
              ),
            );
          }).toList();

    updateModule(mod.copyWith(geometry: updatedGeom, subModules: updatedSubs));
  }

  /// Invierte la mano / bisagra de la abertura (espejo horizontal)
  void flipModuleHorizontal(String moduleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    updateModule(mod.copyWith(flipX: !mod.flipX));
  }

  /// Invierte el sentido de apertura / abatimiento (espejo vertical: adentro/afuera)
  void flipModuleVertical(String moduleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    updateModule(mod.copyWith(flipY: !mod.flipY));
  }

  /// Invierte verticalmente (espejo Frente/Fondo) la distribución completa del piso
  /// Traslada y espeja con precisión recintos, mobiliario interior y muros
  void invertFloorVertical() {
    final floorBbox = state.floor.boundary.boundingBox;
    final totalH = floorBbox.height;
    final minY = floorBbox.minY;
    final axisY = minY + totalH / 2;

    final updatedModules = state.floor.modules.map((m) {
      final updatedGeom = m.geometry.mirrorY(axisY);

      final isStairsOrOpening = m.isStairs || m.isOpening;

      // Espejar también los muebles dentro del recinto respetando su posición relativa
      final updatedSubs = m.subModules.map((s) {
        final subGeom = s.geometry.mirrorY(axisY);
        return s.copyWith(geometry: subGeom);
      }).toList();

      return m.copyWith(
        geometry: updatedGeom,
        subModules: updatedSubs,
        flipY: isStairsOrOpening ? !m.flipY : m.flipY,
      );
    }).toList();

    final updatedWalls = state.floor.walls.map((w) {
      final newP1 = Point2D(w.startPoint.x, snapToGrid(minY + (totalH - (w.startPoint.y - minY))));
      final newP2 = Point2D(w.endPoint.x, snapToGrid(minY + (totalH - (w.endPoint.y - minY))));
      return w.copyWith(startPoint: newP1, endPoint: newP2);
    }).toList();

    final updatedFloor = state.floor.copyWith(
      modules: updatedModules,
      walls: updatedWalls,
    );

    _applyFloorChange(updatedFloor);
  }

  /// Invierte horizontalmente (espejo Izquierda/Derecha) la distribución completa del piso
  /// Traslada y espeja recintos, mobiliario interior y muros
  void invertFloorHorizontal() {
    final floorBbox = state.floor.boundary.boundingBox;
    final totalW = floorBbox.width;
    final minX = floorBbox.minX;
    final axisX = minX + totalW / 2;

    final updatedModules = state.floor.modules.map((m) {
      final updatedGeom = m.geometry.mirrorX(axisX);

      final isStairsOrOpening = m.isStairs || m.isOpening;

      // Espejar también los muebles dentro del recinto
      final updatedSubs = m.subModules.map((s) {
        final subGeom = s.geometry.mirrorX(axisX);
        return s.copyWith(geometry: subGeom);
      }).toList();

      return m.copyWith(
        geometry: updatedGeom,
        subModules: updatedSubs,
        flipX: isStairsOrOpening ? !m.flipX : m.flipX,
      );
    }).toList();

    final updatedWalls = state.floor.walls.map((w) {
      final newP1 = Point2D(snapToGrid(minX + (totalW - (w.startPoint.x - minX))), w.startPoint.y);
      final newP2 = Point2D(snapToGrid(minX + (totalW - (w.endPoint.x - minX))), w.endPoint.y);
      return w.copyWith(startPoint: newP1, endPoint: newP2);
    }).toList();

    final updatedFloor = state.floor.copyWith(
      modules: updatedModules,
      walls: updatedWalls,
    );

    _applyFloorChange(updatedFloor);
  }

  /// Rota 180 grados la distribución completa del piso en una sola acción de Undo
  void rotateFloor180() {
    final alreadyInteracting = _isInteracting;
    if (!alreadyInteracting) {
      beginInteraction();
    }
    try {
      invertFloorVertical();
      invertFloorHorizontal();
    } finally {
      if (!alreadyInteracting) {
        endInteraction();
      }
    }
  }

  /// Añade una pieza de mobiliario o equipamiento al recinto seleccionado
  void addFurnitureToModule(String moduleId, FurnitureTemplate template, {double? customX, double? customY}) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final bb = mod.geometry.boundingBox;

    final posX = customX ?? snapToGrid(bb.minX + math.max(0.10, (bb.width - template.defaultWidth) / 2));
    final posY = customY ?? snapToGrid(bb.minY + math.max(0.10, (bb.height - template.defaultDepth) / 2));

    final subId = const Uuid().v4();
    final subModule = SubModule(
      id: subId,
      moduleId: moduleId,
      name: template.name,
      type: template.type,
      geometry: Polygon2D.fromRect(
        posX,
        posY,
        template.defaultWidth,
        template.defaultDepth,
      ),
      status: ElementStatus.isNew,
      height: template.defaultHeight,
      elevation: template.type.toUpperCase().contains('WALL_CABINET') ? 1.50 : 0.0,
    );

    final updatedSubs = List<SubModule>.from(mod.subModules)..add(subModule);
    updateModule(mod.copyWith(subModules: updatedSubs));
  }

  /// Elimina una pieza de mobiliario / submódulo
  void removeSubModule(String moduleId, String subModuleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final updatedSubs = mod.subModules.where((s) => s.id != subModuleId).toList();
    updateModule(mod.copyWith(subModules: updatedSubs));
    if (state.selectedSubModuleId == subModuleId) {
      state = state.copyWith(clearSubModuleSelection: true);
    }
  }

  /// Rota una pieza de mobiliario 90 grados intercambiando ancho y profundidad
  void rotateSubModule(String moduleId, String subModuleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final sub = mod.subModules.firstWhere((s) => s.id == subModuleId);
    final bb = sub.geometry.boundingBox;
    final cx = bb.minX + bb.width / 2;
    final cy = bb.minY + bb.height / 2;
    final newW = bb.height;
    final newH = bb.width;
    final newGeom = Polygon2D.fromRect(
      snapToGrid(cx - newW / 2),
      snapToGrid(cy - newH / 2),
      newW,
      newH,
    );
    final updatedSubs = mod.subModules.map((s) {
      if (s.id == subModuleId) {
        return s.copyWith(geometry: newGeom);
      }
      return s;
    }).toList();
    updateModule(mod.copyWith(subModules: updatedSubs));
  }

  /// Mueve una pieza de mobiliario dentro del recinto
  void setSubModulePosition(String moduleId, String subModuleId, double newX, double newY) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final sub = mod.subModules.firstWhere((s) => s.id == subModuleId);
    final bb = sub.geometry.boundingBox;
    final snappedX = snapToGrid(newX);
    final snappedY = snapToGrid(newY);
    if ((snappedX - bb.minX).abs() < 1e-6 && (snappedY - bb.minY).abs() < 1e-6) {
      return;
    }
    final updatedGeom = Polygon2D.fromRect(
      snappedX,
      snappedY,
      bb.width,
      bb.height,
    );
    final updatedSubs = mod.subModules.map((s) {
      if (s.id == subModuleId) {
        return s.copyWith(geometry: updatedGeom);
      }
      return s;
    }).toList();
    updateModule(mod.copyWith(subModules: updatedSubs));
  }

  /// Modifica las tres dimensiones y elevación de una pieza de mobiliario
  void setSubModuleDimensions(
    String moduleId,
    String subModuleId, {
    double? width,
    double? depth,
    double? height,
    double? elevation,
  }) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final sub = mod.subModules.firstWhere((s) => s.id == subModuleId);
    final bb = sub.geometry.boundingBox;

    final newW = width != null ? math.max(0.15, snapToGrid(width)) : bb.width;
    final newD = depth != null ? math.max(0.15, snapToGrid(depth)) : bb.height;
    final newH = height != null ? math.max(0.05, (height * 100).round() / 100.0) : sub.resolvedHeight;
    final newElev = elevation != null ? math.max(0.0, (elevation * 100).round() / 100.0) : sub.elevation;

    final updatedGeom = Polygon2D.fromRect(bb.minX, bb.minY, newW, newD);

    final updatedSubs = mod.subModules.map((s) {
      if (s.id == subModuleId) {
        return s.copyWith(
          geometry: updatedGeom,
          height: newH,
          elevation: newElev,
        );
      }
      return s;
    }).toList();

    updateModule(mod.copyWith(subModules: updatedSubs));
  }

  /// Ajusta el encuadre y zoom automáticamente al tamaño del lote y de la vista
  void fitToLot(Size viewportSize) {
    final lot = state.lot;
    final bb = lot.boundary.boundingBox;
    final lotW = math.max(4.0, bb.width);
    final lotH = math.max(4.0, bb.height);
    const padding = 50.0;
    final availW = math.max(100.0, viewportSize.width - padding * 2);
    final availH = math.max(100.0, viewportSize.height - padding * 2);
    final optimalZoom = math.min(availW / lotW, availH / lotH).clamp(20.0, 110.0);
    final offsetX = (viewportSize.width - lotW * optimalZoom) / 2 - bb.minX * optimalZoom;
    final offsetY = (viewportSize.height - lotH * optimalZoom) / 2 - bb.minY * optimalZoom;
    state = state.copyWith(zoom: optimalZoom, panOffset: Offset(offsetX, offsetY));
  }

  /// Alterna la visualización de la guía arquitectónica de zonificación y asoleamiento
  void toggleZoningGuide([bool? value]) {
    state = state.copyWith(showZoningGuide: value ?? !state.showZoningGuide);
  }

  /// Alterna entre el modo técnico plano y el modo renderizado arquitectónico (texturas y sombras)
  void toggleRenderedMode([bool? value]) {
    state = state.copyWith(isRenderedMode: value ?? !state.isRenderedMode);
  }

  /// Encuadra y hace zoom dinámico centrado en un módulo o recinto específico
  void focusOnModule(String moduleId, Size viewportSize) {
    final mod = state.floor.modules.where((m) => m.id == moduleId).firstOrNull;
    if (mod == null) return;

    final bb = mod.geometry.boundingBox;
    final modW = math.max(3.0, bb.width);
    final modH = math.max(3.0, bb.height);
    const padding = 70.0;
    final availW = math.max(100.0, viewportSize.width - padding * 2);
    final availH = math.max(100.0, viewportSize.height - padding * 2);
    final targetZoom = math.min(availW / modW, availH / modH).clamp(32.0, 90.0);
    final offsetX = (viewportSize.width - modW * targetZoom) / 2 - bb.minX * targetZoom;
    final offsetY = (viewportSize.height - modH * targetZoom) / 2 - bb.minY * targetZoom;

    state = state.copyWith(
      zoom: targetZoom,
      panOffset: Offset(offsetX, offsetY),
      selectedModuleId: moduleId,
      clearWallSelection: true,
      clearSubModuleSelection: true,
    );
  }

  /// Establece explícitamente el encuadre (pan y zoom) para transiciones animadas
  void setCamera({required double zoom, required Offset panOffset}) {
    state = state.copyWith(zoom: zoom, panOffset: panOffset);
  }

  /// Aplica una plantilla arquitectónica inicial distribuida en el lote vacío
  void applyStarterLayout(StarterLayoutTemplate template) {
    final newModules = StarterLayoutTemplate.generateModulesForLot(
      lot: state.lot,
      floorId: state.floor.id,
      type: template.type,
    );

    final updatedFloor = state.floor.copyWith(
      modules: newModules,
      walls: [], // Muros limpios listos para autodemarcar
      replacementRelationships: const [],
    );

    _applyFloorChange(updatedFloor);

    state = state.copyWith(
      selectedModuleId: newModules.isNotEmpty ? newModules.first.id : null,
      clearSelection: newModules.isEmpty,
      clearWallSelection: true,
      clearSubModuleSelection: true,
      showZoningGuide: true,
    );
  }

  /// Aplica un programa arquitectónico personalizado coordinado para dos pisos
  void applyMultiStoryBrief(MultiStoryBrief brief) {
    if (_isInteracting) {
      endInteraction();
    }
    final syncedUndoByFloor = Map<String, List<Floor>>.from(state.undoStacksByFloor)
      ..[state.floor.id] = state.undoStack;
    final syncedAll = state.allFloors.isNotEmpty
        ? state.allFloors
            .map((f) => f.id == state.floor.id ? state.floor : f)
            .toList()
        : [state.floor];

    final generatedFloors = MultiStoryLayoutGenerator.generateTwoStoryLayout(
      lot: state.lot,
      brief: brief,
      existingFloors: syncedAll,
    );

    final pb = generatedFloors.first;
    final issues = ValidationEngine.validateFloor(floor: pb, lot: state.lot);
    final generatedIds = generatedFloors.map((f) => f.id).toSet();

    final replacedIds = syncedAll
        .map((f) => f.id)
        .where((id) => !generatedIds.contains(id));

    final updatedDirtyIds = {
      ...state.dirtyFloorIds.where(generatedIds.contains),
      ...generatedIds,
    };
    final updatedDeletedIds = {
      ...state.deletedFloorIds,
      ...replacedIds,
    }..removeAll(generatedIds);

    final updatedUndoMap = <String, List<Floor>>{
      for (final entry in syncedUndoByFloor.entries)
        if (generatedIds.contains(entry.key)) entry.key: entry.value,
    };

    for (final genFloor in generatedFloors) {
      final priorFloor =
          syncedAll.where((f) => f.id == genFloor.id).firstOrNull;
      final baseStack = syncedUndoByFloor[genFloor.id] ?? const [];
      updatedUndoMap[genFloor.id] = priorFloor != null
          ? _pushBoundedUndo(baseStack, priorFloor)
          : baseStack;
    }

    final nextPbUndo = updatedUndoMap[pb.id] ?? const [];
    final updatedRedoMap = <String, List<Floor>>{
      for (final id in generatedIds) id: const [],
    };

    state = state.copyWith(
      floor: pb,
      allFloors: generatedFloors,
      selectedModuleId: pb.modules.isNotEmpty ? pb.modules.first.id : null,
      clearWallSelection: true,
      clearSubModuleSelection: true,
      issues: issues,
      showZoningGuide: true,
      undoStack: nextPbUndo,
      redoStack: const [],
      undoStacksByFloor: updatedUndoMap,
      redoStacksByFloor: updatedRedoMap,
      dirtyFloorIds: updatedDirtyIds,
      deletedFloorIds: updatedDeletedIds,
      hasUnsavedChanges: true,
    );
  }

  /// Genera y demarca automáticamente los muros perimetrales e interiores
  /// a partir del contorno de los recintos, descontando automáticamente vanos
  /// y dejando pasos libres entre recintos sociales abiertos contiguos (ej. Sala, Comedor, Estudio).
  int generateWallsFromModules({double defaultThickness = 0.15}) {
    final createdWalls = WallGenerationEngine.generateWallsForFloor(
      state.floor,
      defaultThickness: defaultThickness,
    );
    if (createdWalls.isEmpty && state.floor.modules.every((m) => m.isOpening)) {
      return 0;
    }

    final updatedFloor = state.floor.copyWith(walls: createdWalls);
    _applyFloorChange(updatedFloor);
    return createdWalls.length;
  }

  /// Demarca muros en todo el contorno del recinto especificado (p. ej. para cerrar un estudio o ambiente)
  int addWallsForModule(String moduleId, {double defaultThickness = 0.15}) {
    final newWalls = WallGenerationEngine.generateAdditionalWallsForModule(
      floor: state.floor,
      moduleId: moduleId,
      defaultThickness: defaultThickness,
    );

    if (newWalls.isNotEmpty) {
      final updatedWalls = List<Wall>.from(state.floor.walls)..addAll(newWalls);
      _applyFloorChange(state.floor.copyWith(walls: updatedWalls));
    }
    return newWalls.length;
  }

  void clearAllWalls() {
    final updatedFloor = state.floor.copyWith(walls: const []);
    _applyFloorChange(updatedFloor);
    state = state.copyWith(clearWallSelection: true);
  }

  void deleteWall(String wallId) {
    final updatedWalls =
        state.floor.walls.where((w) => w.id != wallId).toList();
    final updatedRels = state.floor.replacementRelationships
        .where(
          (r) =>
              r.existingElementId != wallId && r.proposedElementId != wallId,
        )
        .toList();
    final updatedFloor = state.floor.copyWith(
      walls: updatedWalls,
      replacementRelationships: updatedRels,
    );
    _applyFloorChange(updatedFloor);
    if (state.selectedWallId == wallId) {
      state = state.copyWith(clearWallSelection: true);
    }
  }

  void updateWall(Wall wall) {
    final updatedWalls = state.floor.walls.map((w) {
      return w.id == wall.id ? wall : w;
    }).toList();
    _applyFloorChange(state.floor.copyWith(walls: updatedWalls));
  }

  void setWallThickness(String wallId, double thickness) {
    final wall = state.floor.walls.firstWhere((w) => w.id == wallId);
    updateWall(wall.copyWith(thickness: thickness));
  }

  void setModuleStatus(String moduleId, ElementStatus status) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    updateModule(mod.copyWith(status: status));
  }

  void setModuleName(String moduleId, String name) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    updateModule(mod.copyWith(name: name));
  }

  /// Updates the floor finish material for a module (or all habitable rooms on its floor).
  void setModuleFloorMaterial(
    String moduleId,
    String? materialId, {
    String? floorId,
    bool applyToAllRoomsOnFloor = false,
  }) {
    if (floorId != null && floorId != state.floor.id) {
      switchFloor(floorId);
    }
    final updatedModules = state.floor.modules.map((m) {
      if (m.isOpening || m.isStairs) return m;
      if (applyToAllRoomsOnFloor || m.id == moduleId) {
        return m.copyWith(
          floorMaterialId: materialId,
          clearFloorMaterial: materialId == null,
        );
      }
      return m;
    }).toList();
    _applyFloorChange(state.floor.copyWith(modules: updatedModules));
  }

  /// Updates the wall finish material for a module (or all habitable rooms on its floor).
  void setModuleWallFinish(
    String moduleId,
    String? finishId, {
    String? floorId,
    bool applyToAllRoomsOnFloor = false,
  }) {
    if (floorId != null && floorId != state.floor.id) {
      switchFloor(floorId);
    }
    final updatedModules = state.floor.modules.map((m) {
      if (m.isOpening || m.isStairs) return m;
      if (applyToAllRoomsOnFloor || m.id == moduleId) {
        return m.copyWith(
          wallFinishId: finishId,
          clearWallFinish: finishId == null,
        );
      }
      return m;
    }).toList();
    _applyFloorChange(state.floor.copyWith(modules: updatedModules));
  }

  void clearAllModules() {
    final updatedFloor = state.floor.copyWith(
      modules: const [],
      replacementRelationships: const [],
    );
    _applyFloorChange(updatedFloor);
    state = state.copyWith(
      clearSelection: true,
      clearSubModuleSelection: true,
    );
  }

  void updateFloorProperties({
    String? name,
    double? heightMeters,
    double? levelMeters,
  }) {
    final updatedFloor = state.floor.copyWith(
      name: name ?? state.floor.name,
      heightMeters: heightMeters ?? state.floor.heightMeters,
      levelMeters: levelMeters ?? state.floor.levelMeters,
    );
    _applyFloorChange(updatedFloor);
  }

  void toggleModuleLock(String moduleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    updateModule(mod.copyWith(isLocked: !mod.isLocked));
  }

  void setAllModulesLocked(bool locked) {
    final updated = state.floor.modules.map((m) => m.copyWith(isLocked: locked)).toList();
    _applyFloorChange(state.floor.copyWith(modules: updated));
  }

  /// Bloquea o desbloquea una pieza de mobiliario específica
  void toggleSubModuleLock(String moduleId, String subModuleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final updatedSubs = mod.subModules.map((sub) {
      if (sub.id == subModuleId) {
        return sub.copyWith(isLocked: !sub.isLocked);
      }
      return sub;
    }).toList();
    updateModule(mod.copyWith(subModules: updatedSubs));
  }

  /// Crea una variante o escenario de diseño duplicando la planta actual con nuevos IDs
  void createDesignVariant(String variantName) {
    if (_isInteracting) {
      endInteraction();
    }
    final newFloorId = const Uuid().v4();
    final clonedModules = state.floor.modules.map((m) {
      final newModId = const Uuid().v4();
      return m.copyWith(
        id: newModId,
        floorId: newFloorId,
        subModules: m.subModules.map((s) => s.copyWith(
          id: const Uuid().v4(),
          moduleId: newModId,
        )).toList(),
      );
    }).toList();

    final clonedWalls = state.floor.walls.map((w) {
      return w.copyWith(
        id: const Uuid().v4(),
        floorId: newFloorId,
      );
    }).toList();

    final baseAll = state.allFloors.isNotEmpty ? state.allFloors : [state.floor];
    final nextFloorNum =
        baseAll.map((f) => f.floorNumber).fold<int>(0, math.max) + 1;

    final newFloor = state.floor.copyWith(
      id: newFloorId,
      floorNumber: nextFloorNum,
      name: variantName,
      modules: clonedModules,
      walls: clonedWalls,
      replacementRelationships: const [],
    );

    final syncedAll = baseAll
        .map((f) => f.id == state.floor.id ? state.floor : f)
        .toList()
      ..add(newFloor);

    final updatedUndoMap = Map<String, List<Floor>>.from(state.undoStacksByFloor)
      ..[state.floor.id] = state.undoStack
      ..[newFloorId] = const [];
    final updatedRedoMap = Map<String, List<Floor>>.from(state.redoStacksByFloor)
      ..[state.floor.id] = state.redoStack
      ..[newFloorId] = const [];
    final issues = ValidationEngine.validateFloor(floor: newFloor, lot: state.lot);

    state = state.copyWith(
      floor: newFloor,
      allFloors: syncedAll,
      clearSelection: true,
      clearWallSelection: true,
      clearSubModuleSelection: true,
      issues: issues,
      undoStack: const [],
      redoStack: const [],
      undoStacksByFloor: updatedUndoMap,
      redoStacksByFloor: updatedRedoMap,
      dirtyFloorIds: {...state.dirtyFloorIds, newFloorId},
      hasUnsavedChanges: true,
    );
  }

  /// Elimina una variante o piso de diseño secundario
  void deleteDesignVariant(String floorId) {
    if (_isInteracting) {
      endInteraction();
    }
    if (state.allFloors.length <= 1) return;

    final syncedAll = state.allFloors
        .map((f) => f.id == state.floor.id ? state.floor : f)
        .where((f) => f.id != floorId)
        .toList();
    if (syncedAll.isEmpty) return;

    final nextFloor = state.floor.id == floorId ? syncedAll.first : state.floor;

    final updatedUndoMap = Map<String, List<Floor>>.from(state.undoStacksByFloor)
      ..[state.floor.id] = state.undoStack
      ..remove(floorId);
    final updatedRedoMap = Map<String, List<Floor>>.from(state.redoStacksByFloor)
      ..[state.floor.id] = state.redoStack
      ..remove(floorId);
    final updatedDirtyIds = Set<String>.from(state.dirtyFloorIds)..remove(floorId);
    final updatedDeletedIds = {...state.deletedFloorIds, floorId};
    final issues = ValidationEngine.validateFloor(floor: nextFloor, lot: state.lot);

    state = state.copyWith(
      floor: nextFloor,
      allFloors: syncedAll,
      clearSelection: state.floor.id == floorId,
      clearWallSelection: state.floor.id == floorId,
      clearSubModuleSelection: state.floor.id == floorId,
      issues: issues,
      undoStack: updatedUndoMap[nextFloor.id] ?? const [],
      redoStack: updatedRedoMap[nextFloor.id] ?? const [],
      undoStacksByFloor: updatedUndoMap,
      redoStacksByFloor: updatedRedoMap,
      dirtyFloorIds: updatedDirtyIds,
      deletedFloorIds: updatedDeletedIds,
      hasUnsavedChanges: true,
    );
  }

  void resetToMVP() {
    _resetInteractionState();
    final seed = MvpFloorSeed.buildInitialState();
    final existingProj = state.project;
    if (existingProj == null) {
      state = seed;
      return;
    }
    final preservedFloor = seed.floor.copyWith(
      id: state.floor.id,
      buildingId: state.floor.buildingId,
      floorNumber: state.floor.floorNumber,
      modules: seed.floor.modules
          .map((m) => m.copyWith(floorId: state.floor.id))
          .toList(),
      walls: seed.floor.walls
          .map((w) => w.copyWith(floorId: state.floor.id))
          .toList(),
    );
    state = seed.copyWith(
      project: existingProj,
      lot: state.lot,
      floor: preservedFloor,
      allFloors: [preservedFloor],
      dirtyFloorIds: {preservedFloor.id},
      hasUnsavedChanges: true,
    );
  }
}
