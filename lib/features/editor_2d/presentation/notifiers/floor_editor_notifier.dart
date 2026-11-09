import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/validation/validation_engine.dart';
import 'package:trazzik/features/demolition/domain/replacement_relationship.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/modules/domain/furniture_template.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/walls/domain/wall.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_brief.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_layout_generator.dart';
import 'package:trazzik/features/zoning_assistant/domain/starter_layout_template.dart';

final floorEditorProvider =
    NotifierProvider<FloorEditorNotifier, FloorEditorState>(
  FloorEditorNotifier.new,
);

class FloorEditorNotifier extends Notifier<FloorEditorState> {
  @override
  FloorEditorState build() {
    return _buildInitialMVPState();
  }

  void loadProjectData({
    required Lot lot,
    required Floor floor,
    List<Floor> allFloors = const [],
    Project? project,
  }) {
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
    );
  }

  static FloorEditorState _buildInitialMVPState() {
    // 1. Lote 15.30 x 20.00 m
    final lotBoundary = Polygon2D.fromRect(0, 0, 15.30, 20.0);
    final lot = Lot(
      id: 'lot-mvp',
      projectId: 'proj-remodelacion-casa',
      boundary: lotBoundary,
      orientationDegrees: 0.0,
      zones: [
        ZoningZone(
          id: 'zone-buildable',
          lotId: 'lot-mvp',
          name: 'Zona Construible',
          type: ZoningType.buildableUnoccupied,
          boundary: Polygon2D.fromRect(0, 0, 15.30, 15.0),
        ),
        ZoningZone(
          id: 'zone-setback',
          lotId: 'lot-mvp',
          name: 'Retiro Posterior No Construible',
          type: ZoningType.nonBuildable,
          boundary: Polygon2D.fromRect(0, 15.0, 15.30, 5.0),
        ),
      ],
    );

    // 2. Piso 1: 138 m² máximo permitido
    final floorBoundary = Polygon2D.fromRect(1.0, 1.0, 12.0, 13.0);

    // 3. Distribución EXISTENTE
    final existingKitchen = Module(
      id: 'mod-kitchen-existing',
      floorId: 'floor-1',
      name: 'Cocina Existente',
      moduleType: 'KITCHEN',
      geometry: Polygon2D.fromRect(2.0, 2.0, 2.10, 3.20),
      status: ElementStatus.existing,
    );

    final existingLiving = Module(
      id: 'mod-living-existing',
      floorId: 'floor-1',
      name: 'Sala Existente',
      moduleType: 'LIVING_ROOM',
      geometry: Polygon2D.fromRect(4.50, 2.0, 4.50, 4.00),
      status: ElementStatus.preserved,
    );

    final existingDining = Module(
      id: 'mod-dining-existing',
      floorId: 'floor-1',
      name: 'Comedor Existente',
      moduleType: 'DINING_ROOM',
      geometry: Polygon2D.fromRect(4.50, 6.50, 3.80, 3.50),
      status: ElementStatus.preserved,
    );

    final existingBath = Module(
      id: 'mod-bath-existing',
      floorId: 'floor-1',
      name: 'Baño Existente',
      moduleType: 'BATHROOM',
      geometry: Polygon2D.fromRect(2.0, 5.50, 2.00, 2.50),
      status: ElementStatus.preserved,
    );

    final initialFloor = Floor(
      id: 'floor-1',
      buildingId: 'bldg-1',
      floorNumber: 1,
      name: 'Piso 1 - Nivel 0.00m',
      boundary: floorBoundary,
      maxAllowedArea: 138.0,
      modules: [existingKitchen, existingLiving, existingDining, existingBath],
    );

    final initialIssues = ValidationEngine.validateFloor(floor: initialFloor, lot: lot);

    return FloorEditorState(
      floor: initialFloor,
      lot: lot,
      issues: initialIssues,
      selectedModuleId: existingKitchen.id,
    );
  }

  void selectModule(String? id) {
    state = state.copyWith(
      selectedModuleId: id,
      clearWallSelection: id != null,
      clearSubModuleSelection: true,
    );
  }

  void selectSubModule(String? moduleId, String? subModuleId) {
    state = state.copyWith(
      selectedModuleId: moduleId,
      selectedSubModuleId: subModuleId,
      clearWallSelection: true,
      clearSubModuleSelection: subModuleId == null,
    );
  }

  void selectWall(String? id) {
    state = state.copyWith(
      selectedWallId: id,
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

  /// Aplica una nueva versión del piso registrando la anterior en el historial de Undo
  void _applyFloorChange(Floor newFloor) {
    final newUndo = List<Floor>.from(state.undoStack)..add(state.floor);
    final issues = ValidationEngine.validateFloor(floor: newFloor, lot: state.lot);

    final updatedAllFloors = state.allFloors.map((f) {
      return f.id == newFloor.id ? newFloor : f;
    }).toList();

    state = state.copyWith(
      floor: newFloor,
      allFloors: updatedAllFloors,
      issues: issues,
      undoStack: newUndo,
      redoStack: [], // Limpiar redo en nueva acción
      hasUnsavedChanges: true,
    );
  }

  void switchFloor(String targetFloorId) {
    if (state.floor.id == targetFloorId) return;

    // 1. Guardar el estado actual del piso activo dentro de allFloors
    final updatedAllFloors = state.allFloors.map((f) {
      return f.id == state.floor.id ? state.floor : f;
    }).toList();

    // 2. Obtener el piso destino
    final targetFloor = updatedAllFloors.firstWhere(
      (f) => f.id == targetFloorId,
      orElse: () => state.floor,
    );

    final issues = ValidationEngine.validateFloor(floor: targetFloor, lot: state.lot);

    state = state.copyWith(
      floor: targetFloor,
      allFloors: updatedAllFloors,
      clearSelection: true,
      issues: issues,
      undoStack: const [],
      redoStack: const [],
      hasUnsavedChanges: false,
    );
  }

  void markFloorSaved() {
    state = state.copyWith(hasUnsavedChanges: false);
  }

  void undo() {
    if (state.undoStack.isEmpty) return;
    final previousFloor = state.undoStack.last;
    final newUndo = List<Floor>.from(state.undoStack)..removeLast();
    final newRedo = List<Floor>.from(state.redoStack)..add(state.floor);
    final issues = ValidationEngine.validateFloor(floor: previousFloor, lot: state.lot);

    state = state.copyWith(
      floor: previousFloor,
      issues: issues,
      undoStack: newUndo,
      redoStack: newRedo,
      hasUnsavedChanges: true,
    );
  }

  void redo() {
    if (state.redoStack.isEmpty) return;
    final nextFloor = state.redoStack.last;
    final newRedo = List<Floor>.from(state.redoStack)..removeLast();
    final newUndo = List<Floor>.from(state.undoStack)..add(state.floor);
    final issues = ValidationEngine.validateFloor(floor: nextFloor, lot: state.lot);

    state = state.copyWith(
      floor: nextFloor,
      issues: issues,
      undoStack: newUndo,
      redoStack: newRedo,
      hasUnsavedChanges: true,
    );
  }

  /// Marca el módulo seleccionado como A_DEMOLER (punto 44 del MVP)
  void markSelectedAsDemolish() {
    final selected = state.selectedModule;
    if (selected == null) return;

    final updatedModules = state.floor.modules.map((m) {
      if (m.id == selected.id) {
        return m.copyWith(status: ElementStatus.toDemolish);
      }
      return m;
    }).toList();

    _applyFloorChange(state.floor.copyWith(modules: updatedModules));
  }

  /// Crea la Cocina Nueva (2.80 x 3.80) reemplazando la cocina demolida (punto 44 del MVP)
  void addProposedNewKitchen() {
    final oldKitchen = state.floor.modules.firstWhere(
      (m) => m.id == 'mod-kitchen-existing',
      orElse: () => state.floor.modules.first,
    );

    // Cocina nueva con ampliación: 2.80 x 3.80 comenzando en la misma esquina (2.0, 2.0)
    final newKitchenGeom = Polygon2D.fromRect(2.0, 2.0, 2.80, 3.80);

    final overlap = GeometryEngine.calculateOverlapArea(newKitchenGeom, oldKitchen.geometry);
    final expansion = GeometryEngine.calculateExpansionArea(newKitchenGeom, oldKitchen.geometry);

    final newKitchenModule = Module(
      id: 'mod-kitchen-new',
      floorId: state.floor.id,
      name: 'Cocina Nueva (Propuesta)',
      moduleType: 'KITCHEN',
      geometry: newKitchenGeom,
      status: ElementStatus.isNew,
    );

    final replacement = ReplacementRelationship(
      id: 'rel-kitchen-replacement',
      floorId: state.floor.id,
      existingElementId: oldKitchen.id,
      proposedElementId: newKitchenModule.id,
      relationshipType: RelationshipType.expand,
      overlapArea: overlap,
      expandedArea: expansion,
      notes: 'Cocina nueva reemplaza y amplía la cocina existente.',
    );

    // Evitar duplicar si ya existe
    final filteredModules =
        state.floor.modules.where((m) => m.id != 'mod-kitchen-new').toList();
    filteredModules.add(newKitchenModule);

    final updatedFloor = state.floor.copyWith(
      modules: filteredModules,
      replacementRelationships: [replacement],
    );

    _applyFloorChange(updatedFloor);
    state = state.copyWith(selectedModuleId: newKitchenModule.id);
  }

  /// Desplaza el módulo seleccionado en metros
  void moveSelectedModule(double dxMeters, double dyMeters) {
    final selected = state.selectedModule;
    if (selected == null) return;

    final translatedVertices = selected.geometry.vertices
        .map((p) => p.translate(dxMeters, dyMeters))
        .toList();

    final updatedModule = selected.copyWith(
      geometry: Polygon2D(translatedVertices),
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
    final updatedFloor = state.floor.copyWith(modules: updatedModules);
    _applyFloorChange(updatedFloor);
    if (state.selectedModuleId == moduleId) {
      state = state.copyWith(selectedModuleId: null);
    }
  }

  void duplicateModule(String moduleId) {
    final original = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final newId = const Uuid().v4();
    final duplicated = Module(
      id: newId,
      floorId: original.floorId,
      name: '${original.name} (Copia)',
      moduleType: original.moduleType,
      geometry: original.geometry.translate(0.50, 0.50),
      status: original.status,
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
    final updatedGeom = mod.geometry.translate(dx, dy);
    updateModule(mod.copyWith(geometry: updatedGeom));
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
    updateModule(mod.copyWith(geometry: updatedGeom));
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

      final isStairsOrOpening = m.moduleType.toUpperCase().contains('STAIRS') ||
          m.moduleType.toUpperCase().contains('DOOR') ||
          m.moduleType.toUpperCase().contains('WINDOW');

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

      final isStairsOrOpening = m.moduleType.toUpperCase().contains('STAIRS') ||
          m.moduleType.toUpperCase().contains('DOOR') ||
          m.moduleType.toUpperCase().contains('WINDOW');

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

  /// Rota 180 grados la distribución completa del piso
  void rotateFloor180() {
    invertFloorVertical();
    invertFloorHorizontal();
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
      elevation: 0.0,
    );

    final updatedSubs = List<SubModule>.from(mod.subModules)..add(subModule);
    updateModule(mod.copyWith(subModules: updatedSubs));
  }

  /// Elimina una pieza de mobiliario / submódulo
  void removeSubModule(String moduleId, String subModuleId) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final updatedSubs = mod.subModules.where((s) => s.id != subModuleId).toList();
    updateModule(mod.copyWith(subModules: updatedSubs));
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
    final updatedGeom = Polygon2D.fromRect(
      snapToGrid(newX),
      snapToGrid(newY),
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
    );

    _applyFloorChange(updatedFloor);

    state = state.copyWith(
      selectedModuleId: newModules.isNotEmpty ? newModules.first.id : null,
      clearWallSelection: true,
      clearSubModuleSelection: true,
      showZoningGuide: true,
    );
  }

  /// Aplica un programa arquitectónico personalizado coordinado para dos pisos
  void applyMultiStoryBrief(MultiStoryBrief brief) {
    final generatedFloors = MultiStoryLayoutGenerator.generateTwoStoryLayout(
      lot: state.lot,
      brief: brief,
      existingFloors: state.allFloors,
    );

    final pb = generatedFloors.first;
    final issues = ValidationEngine.validateFloor(floor: pb, lot: state.lot);

    state = state.copyWith(
      floor: pb,
      allFloors: generatedFloors,
      selectedModuleId: pb.modules.isNotEmpty ? pb.modules.first.id : null,
      clearWallSelection: true,
      clearSubModuleSelection: true,
      issues: issues,
      showZoningGuide: true,
      undoStack: List<Floor>.from(state.undoStack)..add(state.floor),
      redoStack: const [],
      hasUnsavedChanges: true,
    );
  }

  static bool _isOpenSocialModule(Module m) {
    final t = m.moduleType.toUpperCase();
    final n = m.name.toUpperCase();
    return t == 'LIVING_ROOM' ||
        t == 'DINING_ROOM' ||
        t == 'LIVING_DINING' ||
        t == 'STUDIO' ||
        t == 'STUDY' ||
        t == 'CORRIDOR' ||
        t == 'HALLWAY' ||
        t == 'FOYER' ||
        t == 'TERRACE' ||
        t == 'BALCONY' ||
        t == 'GALLERY' ||
        t == 'STAIRS' ||
        n.contains('ESCALERA') ||
        n.contains('SALA') ||
        n.contains('COMEDOR') ||
        n.contains('ESTUDIO') ||
        n.contains('PASILLO') ||
        n.contains('HALL') ||
        n.contains('ZAGUAN') ||
        n.contains('ZAGUÁN') ||
        n.contains('VESTIBULO') ||
        n.contains('VESTÍBULO');
  }

  static List<List<Point2D>> _cutSegmentAtOpenings(
    Point2D p1,
    Point2D p2,
    List<Module> openings,
  ) {
    final len = p1.distanceTo(p2);
    if (len < 0.20) return [];
    final ux = (p2.x - p1.x) / len;
    final uy = (p2.y - p1.y) / len;

    for (final opening in openings) {
      final obb = opening.geometry.boundingBox;
      final cx = obb.minX + obb.width / 2;
      final cy = obb.minY + obb.height / 2;

      final crossDist = ((cx - p1.x) * uy - (cy - p1.y) * ux).abs();
      if (crossDist <= 0.60) {
        final t = (cx - p1.x) * ux + (cy - p1.y) * uy;
        final openDim = math.max(obb.width, obb.height);
        final half = openDim / 2;

        if (t >= -0.20 && t <= len + 0.20) {
          final t1 = math.max(0.0, t - half);
          final t2 = math.min(len, t + half);

          final pieces = <List<Point2D>>[];
          if (t1 > 0.15) {
            pieces.add([p1, Point2D(p1.x + ux * t1, p1.y + uy * t1)]);
          }
          if (len - t2 > 0.15) {
            pieces.add([Point2D(p1.x + ux * t2, p1.y + uy * t2), p2]);
          }
          return pieces;
        }
      }
    }
    return [
      [p1, p2]
    ];
  }

  /// Genera y demarca automáticamente los muros perimetrales e interiores
  /// a partir del contorno de los recintos, descontando automáticamente vanos
  /// y dejando pasos libres entre recintos sociales abiertos contiguos (ej. Sala, Comedor, Estudio).
  int generateWallsFromModules({double defaultThickness = 0.15}) {
    final modules = state.floor.modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return !t.contains('DOOR') && !t.contains('WINDOW') && !t.contains('GATE');
    }).toList();

    if (modules.isEmpty) return 0;

    final openings = state.floor.modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return t.contains('DOOR') || t.contains('WINDOW') || t.contains('GATE');
    }).toList();

    final createdWalls = <Wall>[];

    // 1. Recolectar segmentos perimetrales de los recintos
    // Omitiendo automáticamente divisorios interiores entre ambientes sociales abiertos contiguos
    final rawSegments = <List<Point2D>>[];
    for (final mod in modules) {
      final isModOpen = _isOpenSocialModule(mod);
      final vertices = mod.geometry.vertices;
      final count = vertices.length;

      for (int i = 0; i < count; i++) {
        final p1 = vertices[i];
        final p2 = vertices[(i + 1) % count];
        final len = p1.distanceTo(p2);
        if (len < 0.20) continue;

        // Si el módulo no es abierto (ej. Dormitorio, Baño), siempre necesita sus muros
        if (!isModOpen) {
          rawSegments.add([p1, p2]);
          continue;
        }

        // Si es un ambiente social abierto (ej. Sala, Comedor, Estudio, Pasillo):
        // Analizamos si cada tramo linda con el exterior (muro perimetral obligatorio)
        // o con otro ambiente social abierto (vano/paso libre sin tabique sólido).
        final ux = (p2.x - p1.x) / len;
        final uy = (p2.y - p1.y) / len;
        final nx = -uy;
        final ny = ux;

        const sliceStep = 0.10;
        final steps = (len / sliceStep).floor();
        double currentStart = 0.0;
        bool inWallSlice = false;

        for (int s = 0; s < steps; s++) {
          final tMid = (s + 0.5) * sliceStep;
          final midX = p1.x + ux * tMid;
          final midY = p1.y + uy * tMid;

          // Probar hacia afuera y hacia adentro del recinto
          final pA = Point2D(midX + nx * 0.05, midY + ny * 0.05);
          final pB = Point2D(midX - nx * 0.05, midY - ny * 0.05);
          final isAInside = mod.geometry.containsPoint(pA);
          final testOutside = isAInside ? pB : pA;

          Module? neighbor;
          for (final other in modules) {
            if (other.id != mod.id && other.geometry.containsPoint(testOutside)) {
              neighbor = other;
              break;
            }
          }

          // Si linda con otro módulo abierto (ej. Sala con Comedor, o Sala con Estudio): NO poner muro
          // Si no linda con nadie (exterior/lote) o linda con un dormitorio/baño: SÍ poner muro
          final shouldHaveWall = neighbor == null || !_isOpenSocialModule(neighbor);

          if (shouldHaveWall) {
            if (!inWallSlice) {
              inWallSlice = true;
              currentStart = s * sliceStep;
            }
          } else {
            if (inWallSlice) {
              inWallSlice = false;
              final segP1 = Point2D(p1.x + ux * currentStart, p1.y + uy * currentStart);
              final segP2 = Point2D(p1.x + ux * (s * sliceStep), p1.y + uy * (s * sliceStep));
              if (segP1.distanceTo(segP2) >= 0.15) {
                rawSegments.add([segP1, segP2]);
              }
            }
          }
        }

        if (inWallSlice) {
          final segP1 = Point2D(p1.x + ux * currentStart, p1.y + uy * currentStart);
          final segP2 = Point2D(p1.x + ux * len, p1.y + uy * len);
          if (segP1.distanceTo(segP2) >= 0.15) {
            rawSegments.add([segP1, segP2]);
          }
        }
      }
    }

    // 2. Fusionar segmentos colineales que se tocan o superponen
    final unifiedSegments = <List<Point2D>>[];
    final horizGroups = <int, List<List<double>>>{}; // key: rounded Y*20 -> [minX, maxX, avgY]
    final vertGroups = <int, List<List<double>>>{};  // key: rounded X*20 -> [minY, maxY, avgX]

    for (final seg in rawSegments) {
      final p1 = seg[0];
      final p2 = seg[1];
      final isHoriz = (p1.y - p2.y).abs() <= 0.05;
      final isVert = (p1.x - p2.x).abs() <= 0.05;

      if (isHoriz) {
        final avgY = (p1.y + p2.y) / 2;
        final key = (avgY * 20).round();
        final minX = math.min(p1.x, p2.x);
        final maxX = math.max(p1.x, p2.x);
        horizGroups.putIfAbsent(key, () => []).add([minX, maxX, avgY]);
      } else if (isVert) {
        final avgX = (p1.x + p2.x) / 2;
        final key = (avgX * 20).round();
        final minY = math.min(p1.y, p2.y);
        final maxY = math.max(p1.y, p2.y);
        vertGroups.putIfAbsent(key, () => []).add([minY, maxY, avgX]);
      } else {
        unifiedSegments.add(seg);
      }
    }

    // Fusionar intervalos horizontales
    for (final entry in horizGroups.entries) {
      final intervals = entry.value;
      intervals.sort((a, b) => a[0].compareTo(b[0]));
      final merged = <List<double>>[];
      for (final interval in intervals) {
        if (merged.isEmpty) {
          merged.add(List<double>.from(interval));
        } else {
          final last = merged.last;
          if (interval[0] <= last[1] + 0.05) {
            last[1] = math.max(last[1], interval[1]);
          } else {
            merged.add(List<double>.from(interval));
          }
        }
      }
      for (final m in merged) {
        final y = m[2];
        unifiedSegments.add([Point2D(m[0], y), Point2D(m[1], y)]);
      }
    }

    // Fusionar intervalos verticales
    for (final entry in vertGroups.entries) {
      final intervals = entry.value;
      intervals.sort((a, b) => a[0].compareTo(b[0]));
      final merged = <List<double>>[];
      for (final interval in intervals) {
        if (merged.isEmpty) {
          merged.add(List<double>.from(interval));
        } else {
          final last = merged.last;
          if (interval[0] <= last[1] + 0.05) {
            last[1] = math.max(last[1], interval[1]);
          } else {
            merged.add(List<double>.from(interval));
          }
        }
      }
      for (final m in merged) {
        final x = m[2];
        unifiedSegments.add([Point2D(x, m[0]), Point2D(x, m[1])]);
      }
    }

    // 3. Descontar vanos de aberturas (puertas, ventanas, portones) y crear muros
    for (final seg in unifiedSegments) {
      final p1 = seg[0];
      final p2 = seg[1];
      final wallPieces = _cutSegmentAtOpenings(p1, p2, openings);

      for (final piece in wallPieces) {
        createdWalls.add(
          Wall(
            id: const Uuid().v4(),
            floorId: state.floor.id,
            startPoint: piece[0],
            endPoint: piece[1],
            thickness: defaultThickness,
            height: state.floor.heightMeters,
            status: ElementStatus.isNew,
          ),
        );
      }
    }

    final updatedFloor = state.floor.copyWith(walls: createdWalls);
    _applyFloorChange(updatedFloor);
    return createdWalls.length;
  }

  /// Demarca muros en todo el contorno del recinto especificado (p. ej. para cerrar un estudio o ambiente)
  int addWallsForModule(String moduleId, {double defaultThickness = 0.15}) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final openings = state.floor.modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return t.contains('DOOR') || t.contains('WINDOW') || t.contains('GATE');
    }).toList();

    final vertices = mod.geometry.vertices;
    final count = vertices.length;
    final newWalls = <Wall>[];

    for (int i = 0; i < count; i++) {
      final p1 = vertices[i];
      final p2 = vertices[(i + 1) % count];
      if (p1.distanceTo(p2) < 0.20) continue;

      final pieces = _cutSegmentAtOpenings(p1, p2, openings);
      for (final piece in pieces) {
        final exists = state.floor.walls.any((w) =>
            (w.startPoint.distanceTo(piece[0]) < 0.15 && w.endPoint.distanceTo(piece[1]) < 0.15) ||
            (w.startPoint.distanceTo(piece[1]) < 0.15 && w.endPoint.distanceTo(piece[0]) < 0.15));

        if (!exists) {
          newWalls.add(
            Wall(
              id: const Uuid().v4(),
              floorId: state.floor.id,
              startPoint: piece[0],
              endPoint: piece[1],
              thickness: defaultThickness,
              height: state.floor.heightMeters,
              status: ElementStatus.isNew,
            ),
          );
        }
      }
    }

    if (newWalls.isNotEmpty) {
      final updatedWalls = List<Wall>.from(state.floor.walls)..addAll(newWalls);
      _applyFloorChange(state.floor.copyWith(walls: updatedWalls));
    }
    return newWalls.length;
  }

  void clearAllWalls() {
    final updatedFloor = state.floor.copyWith(walls: const []);
    _applyFloorChange(updatedFloor);
  }

  void addWall(Wall wall) {
    final updatedWalls = List<Wall>.from(state.floor.walls)..add(wall);
    final updatedFloor = state.floor.copyWith(walls: updatedWalls);
    _applyFloorChange(updatedFloor);
  }

  void deleteWall(String wallId) {
    final updatedWalls =
        state.floor.walls.where((w) => w.id != wallId).toList();
    final updatedFloor = state.floor.copyWith(walls: updatedWalls);
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

  void clearAllModules() {
    final updatedFloor = state.floor.copyWith(
      modules: const [],
      replacementRelationships: const [],
    );
    _applyFloorChange(updatedFloor);
    state = state.copyWith(selectedModuleId: null);
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
    final updatedAll = state.allFloors.map((f) {
      if (f.id == updatedFloor.id) return updatedFloor;
      return f;
    }).toList();
    _applyFloorChange(updatedFloor);
    state = state.copyWith(allFloors: updatedAll);
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

  /// Bloquea o desbloquea todos los muebles de un recinto
  void setAllSubModulesLocked(String moduleId, bool locked) {
    final mod = state.floor.modules.firstWhere((m) => m.id == moduleId);
    final updatedSubs = mod.subModules.map((s) => s.copyWith(isLocked: locked)).toList();
    updateModule(mod.copyWith(subModules: updatedSubs));
  }

  /// Crea una variante o escenario de diseño duplicando la planta actual con nuevos IDs
  void createDesignVariant(String variantName) {
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

    final newFloor = state.floor.copyWith(
      id: newFloorId,
      name: variantName,
      modules: clonedModules,
      walls: clonedWalls,
      replacementRelationships: const [],
    );

    final updatedAll = List<Floor>.from(state.allFloors)..add(newFloor);
    _applyFloorChange(newFloor);
    state = state.copyWith(allFloors: updatedAll);
  }

  /// Elimina una variante o piso de diseño secundario
  void deleteDesignVariant(String floorId) {
    if (state.allFloors.length <= 1) return;
    final updatedAll = state.allFloors.where((f) => f.id != floorId).toList();
    final nextFloor = updatedAll.firstWhere(
      (f) => f.id != floorId,
      orElse: () => updatedAll.first,
    );
    _applyFloorChange(nextFloor);
    state = state.copyWith(allFloors: updatedAll);
  }

  void resetToMVP() {
    state = _buildInitialMVPState();
  }
}
