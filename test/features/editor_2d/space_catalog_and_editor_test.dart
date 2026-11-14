import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/modules/domain/space_template.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('SpaceTemplate — Catálogo Arquitectónico', () {
    test('El catálogo incluye plantillas esenciales: escaleras, circulaciones, servicios y social', () {
      final templates = SpaceTemplate.catalog;
      expect(templates.isNotEmpty, isTrue);

      final ids = templates.map((t) => t.id).toSet();
      expect(ids.contains('tpl_stairs_straight'), isTrue);
      expect(ids.contains('tpl_stairs_l'), isTrue);
      expect(ids.contains('tpl_stairs_u'), isTrue);
      expect(ids.contains('tpl_hall'), isTrue);
      expect(ids.contains('tpl_laundry'), isTrue);
      expect(ids.contains('tpl_living'), isTrue);
      expect(ids.contains('tpl_kitchen'), isTrue);
      expect(ids.contains('tpl_pool'), isTrue);
      expect(ids.contains('tpl_door_main'), isTrue);
      expect(ids.contains('tpl_gate_vehicle'), isTrue);
      expect(ids.contains('tpl_gate_pedestrian'), isTrue);
      expect(ids.contains('tpl_window_standard'), isTrue);
      expect(ids.contains('tpl_window_bath'), isTrue);
      expect(ids.contains('tpl_window_panoramic'), isTrue);

      final types = templates.map((t) => t.moduleType).toSet();
      expect(types.contains('STAIRS'), isTrue);
      expect(types.contains('CORRIDOR'), isTrue);
      expect(types.contains('LAUNDRY'), isTrue);
      expect(types.contains('LIVING_ROOM'), isTrue);
      expect(types.contains('KITCHEN'), isTrue);
      expect(types.contains('BATHROOM'), isTrue);
      expect(types.contains('POOL'), isTrue);
      expect(types.contains('DOOR'), isTrue);
      expect(types.contains('GATE'), isTrue);
      expect(types.contains('WINDOW'), isTrue);
    });

    test('Cada plantilla tiene dimensiones y áreas positivas coherentes', () {
      for (final tpl in SpaceTemplate.catalog) {
        expect(tpl.defaultWidth, greaterThan(0));
        expect(tpl.defaultDepth, greaterThan(0));
        expect(tpl.defaultArea, greaterThan(0));
      }
    });
  });

  group('FloorEditorNotifier — Manipulación y Snapping Centimétrico', () {
    test('snapToGrid redondea exactamente a múltiplos de 5 cm', () {
      expect(FloorEditorNotifier.snapToGrid(2.03), closeTo(2.05, 0.001));
      expect(FloorEditorNotifier.snapToGrid(2.02), closeTo(2.00, 0.001));
      expect(FloorEditorNotifier.snapToGrid(3.47), closeTo(3.45, 0.001));
      expect(FloorEditorNotifier.snapToGrid(3.48), closeTo(3.50, 0.001));
    });

    test('addModule, setModulePosition, setModuleDimensions y setModuleStatus funcionan correctamente', () {
      final container = ProviderContainer();
      final notifier = container.read(floorEditorProvider.notifier);

      // Limpiar piso inicial
      notifier.clearAllModules();
      expect(container.read(floorEditorProvider).floor.modules.isEmpty, isTrue);

      // Agregar escalera
      final stairsModule = Module(
        id: 'mod-stairs-1',
        floorId: 'floor-1',
        name: 'Escalera Principal',
        moduleType: 'STAIRS_STRAIGHT',
        geometry: Polygon2D.fromRect(1.0, 1.0, 1.0, 3.0),
        status: ElementStatus.preserved,
      );
      notifier.addModule(stairsModule);

      var state = container.read(floorEditorProvider);
      expect(state.floor.modules.length, equals(1));
      expect(state.selectedModuleId, equals('mod-stairs-1'));

      // Modificar posición con snapping
      notifier.setModulePosition('mod-stairs-1', 2.03, 4.07);
      state = container.read(floorEditorProvider);
      final bb = state.floor.modules.first.geometry.boundingBox;
      expect(bb.minX, closeTo(2.05, 0.001));
      expect(bb.minY, closeTo(4.05, 0.001));

      // Modificar dimensiones
      notifier.setModuleDimensions('mod-stairs-1', 1.20, 3.50);
      state = container.read(floorEditorProvider);
      final bbResized = state.floor.modules.first.geometry.boundingBox;
      expect(bbResized.width, closeTo(1.20, 0.001));
      expect(bbResized.height, closeTo(3.50, 0.001));

      // Cambiar estado constructivo
      notifier.setModuleStatus('mod-stairs-1', ElementStatus.toDemolish);
      state = container.read(floorEditorProvider);
      expect(state.floor.modules.first.status, equals(ElementStatus.toDemolish));

      // Duplicar
      notifier.duplicateModule('mod-stairs-1');
      state = container.read(floorEditorProvider);
      expect(state.floor.modules.length, equals(2));

      // Eliminar
      notifier.deleteModule('mod-stairs-1');
      state = container.read(floorEditorProvider);
      expect(state.floor.modules.length, equals(1));
    });

    test('rotateModule90 rota 90 grados intercambiando ancho y largo respecto al centro', () {
      final container = ProviderContainer();
      final notifier = container.read(floorEditorProvider.notifier);

      notifier.clearAllModules();
      final doorModule = Module(
        id: 'mod-door-test',
        floorId: 'floor-1',
        name: 'Puerta Principal',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(2.00, 3.00, 1.00, 0.20),
        status: ElementStatus.isNew,
      );
      notifier.addModule(doorModule);

      var mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.boundingBox.width, closeTo(1.00, 0.001));
      expect(mod.geometry.boundingBox.height, closeTo(0.20, 0.001));

      // Rotar 90 grados
      notifier.rotateModule90('mod-door-test');
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.boundingBox.width, closeTo(0.20, 0.001));
      expect(mod.geometry.boundingBox.height, closeTo(1.00, 0.001));

      // Soporta dimensiones delgadas de carpintería (0.15m)
      notifier.setModuleDimensions('mod-door-test', 0.15, 0.80);
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.boundingBox.width, closeTo(0.15, 0.001));
      expect(mod.geometry.boundingBox.height, closeTo(0.80, 0.001));

      // Invertir Mano (flipX) y Invertir Apertura (flipY)
      expect(mod.flipX, isFalse);
      expect(mod.flipY, isFalse);

      notifier.flipModuleHorizontal('mod-door-test');
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.flipX, isTrue);
      expect(mod.flipY, isFalse);

      notifier.flipModuleVertical('mod-door-test');
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.flipX, isTrue);
      expect(mod.flipY, isTrue);
    });

    test('generateWallsFromModules demarca automáticamente los muros desde el contorno de recintos', () {
      final container = ProviderContainer();
      final notifier = container.read(floorEditorProvider.notifier);

      notifier.clearAllModules();
      notifier.clearAllWalls();
      expect(container.read(floorEditorProvider).floor.walls.isEmpty, isTrue);

      // Agregar dos recintos ortogonales
      final kitchen = Module(
        id: 'mod-k',
        floorId: 'floor-1',
        name: 'Cocina',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(0, 0, 3.0, 3.0),
        status: ElementStatus.isNew,
      );
      final living = Module(
        id: 'mod-l',
        floorId: 'floor-1',
        name: 'Sala',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(3.0, 0, 4.0, 3.0),
        status: ElementStatus.isNew,
      );
      notifier.addModule(kitchen);
      notifier.addModule(living);

      final wallCount = notifier.generateWallsFromModules(defaultThickness: 0.15);
      expect(wallCount, greaterThan(0));

      final state = container.read(floorEditorProvider);
      expect(state.floor.walls.length, equals(wallCount));
      for (final wall in state.floor.walls) {
        expect(wall.thickness, equals(0.15));
        expect(wall.length, greaterThan(0));
      }

      // Limpiar muros
      notifier.clearAllWalls();
      expect(container.read(floorEditorProvider).floor.walls.isEmpty, isTrue);
    });

    test('switchFloor navega entre pisos manteniendo el estado de cada uno', () {
      final container = ProviderContainer();
      final notifier = container.read(floorEditorProvider.notifier);

      final floor1 = container.read(floorEditorProvider).floor.copyWith(
        id: 'floor-test-1',
        name: 'Piso 1 - Nivel 0.00m',
        modules: const [],
      );

      final floor2 = container.read(floorEditorProvider).floor.copyWith(
        id: 'floor-test-2',
        name: 'Piso 2 - Nivel +2.60m',
        floorNumber: 2,
        modules: const [],
      );

      notifier.loadProjectData(
        lot: container.read(floorEditorProvider).lot,
        floor: floor1,
        allFloors: [floor1, floor2],
      );

      expect(container.read(floorEditorProvider).floor.id, equals('floor-test-1'));

      // Agregar un módulo al Piso 1
      notifier.addModule(Module(
        id: 'mod-kitchen-p1',
        floorId: 'floor-test-1',
        name: 'Cocina Piso 1',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(0, 0, 2, 2),
        status: ElementStatus.isNew,
      ));

      // Cambiar al Piso 2
      notifier.switchFloor('floor-test-2');
      expect(container.read(floorEditorProvider).floor.id, equals('floor-test-2'));
      expect(container.read(floorEditorProvider).floor.modules.isEmpty, isTrue);

      // Agregar un dormitorio al Piso 2
      notifier.addModule(Module(
        id: 'mod-bed-p2',
        floorId: 'floor-test-2',
        name: 'Dormitorio Piso 2',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0, 0, 3, 3),
        status: ElementStatus.isNew,
      ));

      // Volver al Piso 1
      notifier.switchFloor('floor-test-1');
      expect(container.read(floorEditorProvider).floor.id, equals('floor-test-1'));
      expect(container.read(floorEditorProvider).floor.modules.length, equals(1));
      expect(container.read(floorEditorProvider).floor.modules.first.name, equals('Cocina Piso 1'));

      // Volver al Piso 2
      notifier.switchFloor('floor-test-2');
      expect(container.read(floorEditorProvider).floor.id, equals('floor-test-2'));
      expect(container.read(floorEditorProvider).floor.modules.length, equals(1));
      expect(container.read(floorEditorProvider).floor.modules.first.name, equals('Dormitorio Piso 2'));
    });

    test('Preservación de geometría en polígonos irregulares (Sala en L con remetido)', () {
      final container = ProviderContainer();
      final notifier = container.read(floorEditorProvider.notifier);
      notifier.clearAllModules();

      // Sala en L de 6 vértices (5.00m x 4.00m envolvente, remetido de 0.50m)
      final lShapedGeom = Polygon2D([
        const Point2D(1.0, 1.0),
        const Point2D(5.5, 1.0),
        const Point2D(5.5, 1.5),
        const Point2D(6.0, 1.5),
        const Point2D(6.0, 5.0),
        const Point2D(1.0, 5.0),
      ]);

      final lModule = Module(
        id: 'mod-living-l',
        floorId: 'floor-1',
        name: 'Sala en L',
        moduleType: 'LIVING_ROOM',
        geometry: lShapedGeom,
        status: ElementStatus.isNew,
      );
      notifier.addModule(lModule);

      var mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.vertices.length, equals(6));
      expect(mod.geometry.boundingBox.width, closeTo(5.00, 0.001));
      expect(mod.geometry.boundingBox.height, closeTo(4.00, 0.001));

      // 1. Mover con setModulePosition: DEBE conservar los 6 vértices
      notifier.setModulePosition('mod-living-l', 2.0, 2.0);
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.vertices.length, equals(6));
      expect(mod.geometry.boundingBox.minX, closeTo(2.00, 0.001));
      expect(mod.geometry.boundingBox.minY, closeTo(2.00, 0.001));

      // 2. Redimensionar con setModuleDimensions: DEBE escalar proporcionalmente conservando los 6 vértices
      notifier.setModuleDimensions('mod-living-l', 6.00, 4.80);
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.vertices.length, equals(6));
      expect(mod.geometry.boundingBox.width, closeTo(6.00, 0.001));
      expect(mod.geometry.boundingBox.height, closeTo(4.80, 0.001));

      // 3. Rotar 90°: DEBE conservar los 6 vértices
      notifier.rotateModule90('mod-living-l');
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.vertices.length, equals(6));
      expect(mod.geometry.boundingBox.width, closeTo(4.80, 0.001));
      expect(mod.geometry.boundingBox.height, closeTo(6.00, 0.001));

      // 4. toggleLShapedNook: simplificar a rectángulo (4 vértices)
      notifier.toggleLShapedNook('mod-living-l');
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.vertices.length, equals(4));

      // 5. toggleLShapedNook de nuevo: vuelve a generar forma en L (6 vértices)
      notifier.toggleLShapedNook('mod-living-l');
      mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.vertices.length, equals(6));
    });

    test('Wall.deduplicate elimina muros duplicados acumulados por reingreso o guardado', () {
      final wallA1 = Wall(
        id: 'w1',
        floorId: 'fl1',
        startPoint: const Point2D(0, 0),
        endPoint: const Point2D(5, 0),
        thickness: 0.15,
        status: ElementStatus.isNew,
      );
      // Muro duplicado exactamente igual con otro id
      final wallA2 = Wall(
        id: 'w2',
        floorId: 'fl1',
        startPoint: const Point2D(0, 0),
        endPoint: const Point2D(5, 0),
        thickness: 0.15,
        status: ElementStatus.isNew,
      );
      // Muro duplicado en sentido inverso
      final wallA3 = Wall(
        id: 'w3',
        floorId: 'fl1',
        startPoint: const Point2D(5, 0),
        endPoint: const Point2D(0, 0),
        thickness: 0.15,
        status: ElementStatus.isNew,
      );
      // Muro legítimo diferente
      final wallB = Wall(
        id: 'w4',
        floorId: 'fl1',
        startPoint: const Point2D(5, 0),
        endPoint: const Point2D(5, 4),
        thickness: 0.15,
        status: ElementStatus.isNew,
      );

      final deduplicated = Wall.deduplicate([wallA1, wallA2, wallA3, wallB]);
      expect(deduplicated.length, equals(2));
      expect(deduplicated.any((w) => w.id == 'w1'), isTrue);
      expect(deduplicated.any((w) => w.id == 'w4'), isTrue);
    });

    test('isLocked protege módulos y submódulos contra traslación, redimensionado, borrado y acabados', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(floorEditorProvider.notifier);

      final lockedSub = SubModule(
        id: 'sub-locked',
        moduleId: 'mod-locked',
        name: 'Cama Fija',
        type: 'BED_QUEEN',
        geometry: Polygon2D.fromRect(0.2, 0.2, 1.5, 2.0),
        status: ElementStatus.existing,
        isLocked: true,
      );
      final lockedMod = Module(
        id: 'mod-locked',
        floorId: 'f1',
        name: 'Habitación Bloqueada',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0, 0, 4.0, 4.0),
        status: ElementStatus.existing,
        isLocked: true,
        subModules: [lockedSub],
      );
      final lot = Lot(
        id: 'lot-lock',
        projectId: 'p1',
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
      );
      final floor = Floor(
        id: 'f1',
        buildingId: 'b1',
        name: 'PB',
        floorNumber: 1,
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
        maxAllowedArea: 150.0,
        modules: [lockedMod],
      );
      notifier.loadProjectData(lot: lot, floor: floor);

      notifier.setModulePosition('mod-locked', 2.0, 2.0);
      notifier.setModuleDimensions('mod-locked', 6.0, 6.0);
      notifier.deleteModule('mod-locked');
      notifier.setModuleFloorMaterial('mod-locked', 'floor_oak_wood');
      notifier.setModuleWallFinish('mod-locked', 'wall_pure_white');
      notifier.applyArchitecturalStylePack(FinishMaterialCatalog.stylePacks.first);
      notifier.removeSubModule('mod-locked', 'sub-locked');

      final mod = container.read(floorEditorProvider).floor.modules.first;
      expect(mod.geometry.boundingBox.minX, closeTo(0.0, 0.001));
      expect(mod.geometry.boundingBox.width, closeTo(4.0, 0.001));
      expect(mod.floorMaterialId, isNull);
      expect(mod.wallFinishId, isNull);
      expect(mod.subModules.length, equals(1));
    });

    test('setModuleDimensions y toggleLShapedNook re-confinan mobiliario dentro del recinto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(floorEditorProvider.notifier);

      final room = Module(
        id: 'mod-shrink',
        floorId: 'f1',
        name: 'Sala',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(0, 0, 5.0, 4.0),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: 'sub-edge',
            moduleId: 'mod-shrink',
            name: 'Sofá',
            type: 'SOFA_3',
            geometry: Polygon2D.fromRect(3.4, 0.1, 1.5, 0.9),
            status: ElementStatus.isNew,
          ),
        ],
      );
      final lot = Lot(
        id: 'lot-shrink',
        projectId: 'p1',
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
      );
      notifier.loadProjectData(
        lot: lot,
        floor: Floor(
          id: 'f1',
          buildingId: 'b1',
          name: 'PB',
          floorNumber: 1,
          boundary: Polygon2D.fromRect(0, 0, 10, 15),
          maxAllowedArea: 150.0,
          modules: [room],
        ),
      );

      notifier.setModuleDimensions('mod-shrink', 3.0, 3.0);
      var updatedRoom = container.read(floorEditorProvider).floor.modules.first;
      expect(
        GeometryEngine.polygonContainsPolygon(
          updatedRoom.geometry,
          updatedRoom.subModules.first.geometry,
        ),
        isTrue,
      );

      notifier.toggleLShapedNook('mod-shrink', nookW: 1.0, nookD: 1.0);
      updatedRoom = container.read(floorEditorProvider).floor.modules.first;
      expect(
        GeometryEngine.polygonContainsPolygon(
          updatedRoom.geometry,
          updatedRoom.subModules.first.geometry,
        ),
        isTrue,
      );
    });

    test('snapToNearestVertexOrGrid engancha a caras de muros y switchFloor aisla underlay y limpia laser', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(floorEditorProvider.notifier);

      final lot = Lot(
        id: 'lot-snap',
        projectId: 'p1',
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
      );
      final wall = Wall(
        id: 'w-snap',
        floorId: 'f1',
        startPoint: const Point2D(0, 2.0),
        endPoint: const Point2D(6.0, 2.0),
        thickness: 0.20,
        status: ElementStatus.existing,
      );
      final f1 = Floor(
        id: 'f1',
        buildingId: 'b1',
        name: 'PB',
        floorNumber: 1,
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
        maxAllowedArea: 150.0,
        walls: [wall],
      );
      final f2 = Floor(
        id: 'f2',
        buildingId: 'b1',
        name: 'PA',
        floorNumber: 2,
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
        maxAllowedArea: 150.0,
      );
      notifier.loadProjectData(lot: lot, floor: f1, allFloors: [f1, f2]);

      // Cara inferior del muro está en y = 1.90 (2.0 - 0.10)
      final snappedFace = notifier.snapToNearestVertexOrGrid(
        const Point2D(3.13, 1.84),
        snapRadiusMeters: 0.20,
      );
      expect(snappedFace.x, closeTo(3.13, 0.01));
      expect(snappedFace.y, closeTo(1.90, 0.01));

      // Underlay por piso + limpiar láser al cambiar de piso
      notifier.updateBlueprintUnderlay(
        const BlueprintUnderlayConfig(isEnabled: true, widthMeters: 14.0),
      );
      notifier.setLaserMeasurePoints(const Point2D(0, 0), const Point2D(2, 0));
      notifier.switchFloor('f2');
      var st = container.read(floorEditorProvider);
      expect(st.laserStart, isNull);
      expect(st.blueprintUnderlay.isEnabled, isFalse);

      notifier.switchFloor('f1');
      st = container.read(floorEditorProvider);
      expect(st.blueprintUnderlay.isEnabled, isTrue);
      expect(st.blueprintUnderlay.widthMeters, closeTo(14.0, 0.001));
    });
  });
}
