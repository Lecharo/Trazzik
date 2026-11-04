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
  final bool showZoningGuide;
  final bool hasUnsavedChanges;

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
    this.showZoningGuide = false,
    this.hasUnsavedChanges = false,
  });

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
    bool? showZoningGuide,
    bool? hasUnsavedChanges,
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
      showZoningGuide: showZoningGuide ?? this.showZoningGuide,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}
