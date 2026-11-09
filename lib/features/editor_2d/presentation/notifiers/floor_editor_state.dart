import 'dart:ui';
import 'package:trazzik/core/validation/validation_issue.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

class FloorEditorState {
  final Floor floor;
  final List<Floor> allFloors;
  final Lot lot;
  final Project? project;
  final String? selectedModuleId;
  final String? selectedWallId;
  final String? selectedSubModuleId;
  final List<ValidationIssue> issues;
  final double zoom; // Píxeles por metro
  final Offset panOffset;
  final List<Floor> undoStack;
  final List<Floor> redoStack;
  final Map<String, List<Floor>> undoStacksByFloor;
  final Map<String, List<Floor>> redoStacksByFloor;
  final Set<String> dirtyFloorIds;
  final Set<String> deletedFloorIds;
  final bool showZoningGuide;
  final bool hasUnsavedChanges;
  final bool isRenderedMode;

  const FloorEditorState({
    required this.floor,
    this.allFloors = const [],
    required this.lot,
    this.project,
    this.selectedModuleId,
    this.selectedWallId,
    this.selectedSubModuleId,
    this.issues = const [],
    this.zoom = 35.0,
    this.panOffset = const Offset(80.0, 80.0),
    this.undoStack = const [],
    this.redoStack = const [],
    this.undoStacksByFloor = const {},
    this.redoStacksByFloor = const {},
    this.dirtyFloorIds = const {},
    this.deletedFloorIds = const {},
    this.showZoningGuide = false,
    this.hasUnsavedChanges = false,
    this.isRenderedMode = true,
  });

  /// Returns all modified floors pending persistence across the project.
  List<Floor> get dirtyFloors {
    final sourceFloors = allFloors.isNotEmpty ? allFloors : [floor];
    return sourceFloors
        .where((f) => dirtyFloorIds.contains(f.id))
        .map((f) => f.id == floor.id ? floor : f)
        .toList();
  }

  /// Returns dirty floors to persist, falling back to the active floor on manual save.
  List<Floor> get floorsToSave {
    final dirty = dirtyFloors;
    if (dirty.isNotEmpty) return dirty;
    if (deletedFloorIds.isNotEmpty) return const [];
    return [floor];
  }

  Module? get selectedModule {
    if (selectedModuleId == null) return null;
    return floor.modules.where((m) => m.id == selectedModuleId).firstOrNull;
  }

  Wall? get selectedWall {
    if (selectedWallId == null) return null;
    return floor.walls.where((w) => w.id == selectedWallId).firstOrNull;
  }

  SubModule? get selectedSubModule {
    if (selectedModuleId == null || selectedSubModuleId == null) return null;
    final mod = selectedModule;
    if (mod == null) return null;
    return mod.subModules.where((s) => s.id == selectedSubModuleId).firstOrNull;
  }

  FloorEditorState copyWith({
    Floor? floor,
    List<Floor>? allFloors,
    Lot? lot,
    Project? project,
    String? selectedModuleId,
    String? selectedWallId,
    String? selectedSubModuleId,
    bool clearSelection = false,
    bool clearWallSelection = false,
    bool clearSubModuleSelection = false,
    List<ValidationIssue>? issues,
    double? zoom,
    Offset? panOffset,
    List<Floor>? undoStack,
    List<Floor>? redoStack,
    Map<String, List<Floor>>? undoStacksByFloor,
    Map<String, List<Floor>>? redoStacksByFloor,
    Set<String>? dirtyFloorIds,
    Set<String>? deletedFloorIds,
    bool? showZoningGuide,
    bool? hasUnsavedChanges,
    bool? isRenderedMode,
  }) {
    return FloorEditorState(
      floor: floor ?? this.floor,
      allFloors: allFloors ?? this.allFloors,
      lot: lot ?? this.lot,
      project: project ?? this.project,
      selectedModuleId: clearSelection ? null : (selectedModuleId ?? this.selectedModuleId),
      selectedWallId: clearWallSelection ? null : (selectedWallId ?? this.selectedWallId),
      selectedSubModuleId: clearSubModuleSelection ? null : (selectedSubModuleId ?? this.selectedSubModuleId),
      issues: issues ?? this.issues,
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      undoStacksByFloor: undoStacksByFloor ?? this.undoStacksByFloor,
      redoStacksByFloor: redoStacksByFloor ?? this.redoStacksByFloor,
      dirtyFloorIds: dirtyFloorIds ?? this.dirtyFloorIds,
      deletedFloorIds: deletedFloorIds ?? this.deletedFloorIds,
      showZoningGuide: showZoningGuide ?? this.showZoningGuide,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isRenderedMode: isRenderedMode ?? this.isRenderedMode,
    );
  }
}
