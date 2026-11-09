import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
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
  });
}
