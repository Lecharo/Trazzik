import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/validation/validation_engine.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Builds the default in-memory MVP starter floor state when no project is loaded yet.
class MvpFloorSeed {
  static FloorEditorState buildInitialState() {
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

    final floorBoundary = Polygon2D.fromRect(1.0, 1.0, 12.0, 13.0);

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
}
