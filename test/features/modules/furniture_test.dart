import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/furniture_catalog_dialog.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/auto_furnish_engine.dart';
import 'package:trazzik/features/modules/domain/furniture_template.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/viewer_3d/domain/building_3d_builder.dart';

void main() {
  group('Catálogo de Mobiliario y Equipamiento Interior', () {
    late Lot lot;
    late Floor floor;
    late Module livingRoom;

    setUp(() {
      lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 10, 20),
      );

      livingRoom = Module(
        id: 'mod-living',
        floorId: 'fl-1',
        name: 'Sala de Estar',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(2, 2, 4.0, 4.0),
        status: ElementStatus.isNew,
      );

      floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 0, 8, 12),
        maxAllowedArea: 100,
        levelMeters: 0,
        heightMeters: 2.80,
        modules: [livingRoom],
      );
    });

    test('FurnitureTemplate contiene categorías y dimensiones arquitectónicas estándar', () {
      expect(FurnitureTemplate.catalog, isNotEmpty);
      expect(FurnitureTemplate.categories.contains('Estar / Social'), isTrue);
      expect(FurnitureTemplate.categories.contains('Cocina'), isTrue);
      expect(FurnitureTemplate.categories.contains('Dormitorio'), isTrue);
      expect(FurnitureTemplate.categories.contains('Baño'), isTrue);

      final sofa = FurnitureTemplate.catalog.firstWhere((f) => f.type == 'SOFA');
      expect(sofa.defaultWidth, greaterThan(1.0));
      expect(sofa.defaultDepth, greaterThan(0.5));
      expect(sofa.defaultHeight, greaterThan(0.5));
    });

    test('FloorEditorNotifier añade, rota y elimina mobiliario en un recinto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      // Agregar sala
      notifier.addModule(livingRoom);

      // 1. Añadir Sofá 3 Puestos
      final sofaTemplate = FurnitureTemplate.catalog.firstWhere((f) => f.id == 'furn_sofa_3');
      notifier.addFurnitureToModule('mod-living', sofaTemplate);

      var mod = container.read(floorEditorProvider).floor.modules.firstWhere((m) => m.id == 'mod-living');
      expect(mod.subModules.length, 1);
      final addedSub = mod.subModules.first;
      expect(addedSub.name, 'Sofá 3 Puestos');
      expect(addedSub.geometry.boundingBox.width, closeTo(sofaTemplate.defaultWidth, 0.05));
      expect(addedSub.geometry.boundingBox.height, closeTo(sofaTemplate.defaultDepth, 0.05));

      // 2. Rotar 90°
      notifier.rotateSubModule('mod-living', addedSub.id);
      mod = container.read(floorEditorProvider).floor.modules.firstWhere((m) => m.id == 'mod-living');
      final rotatedSub = mod.subModules.first;
      expect(rotatedSub.geometry.boundingBox.width, closeTo(sofaTemplate.defaultDepth, 0.05));
      expect(rotatedSub.geometry.boundingBox.height, closeTo(sofaTemplate.defaultWidth, 0.05));

      // 3. Eliminar
      notifier.removeSubModule('mod-living', addedSub.id);
      mod = container.read(floorEditorProvider).floor.modules.firstWhere((m) => m.id == 'mod-living');
      expect(mod.subModules.isEmpty, isTrue);
    });

    test('FloorEditorNotifier invertFloorVertical e invertFloorHorizontal trasladan el mobiliario dentro del recinto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.addModule(livingRoom);

      final sofaTemplate = FurnitureTemplate.catalog.firstWhere((f) => f.id == 'furn_sofa_3');
      notifier.addFurnitureToModule('mod-living', sofaTemplate);

      // Invertir verticalmente
      notifier.invertFloorVertical();
      var state = container.read(floorEditorProvider);
      var mod = state.floor.modules.firstWhere((m) => m.id == 'mod-living');
      expect(mod.subModules.isNotEmpty, isTrue);
      var sub = mod.subModules.first;
      // El mueble debe permanecer dentro de los límites del recinto invertido
      expect(mod.geometry.boundingBox.containsBoundingBox(sub.geometry.boundingBox), isTrue);

      // Invertir horizontalmente
      notifier.invertFloorHorizontal();
      state = container.read(floorEditorProvider);
      mod = state.floor.modules.firstWhere((m) => m.id == 'mod-living');
      sub = mod.subModules.first;
      expect(mod.geometry.boundingBox.containsBoundingBox(sub.geometry.boundingBox), isTrue);
    });

    test('Building3DBuilder extruye volumetría 3D de mobiliario interior', () {
      final bedTemplate = FurnitureTemplate.catalog.firstWhere((f) => f.type == 'BED');
      final furnishedModule = livingRoom.copyWith(
        subModules: [
          SubModule(
            id: 'sub-bed-1',
            moduleId: 'mod-living',
            name: 'Cama Queen',
            type: 'BED',
            geometry: Polygon2D.fromRect(2.5, 2.5, bedTemplate.defaultWidth, bedTemplate.defaultDepth),
            status: ElementStatus.isNew,
          ),
        ],
      );

      final furnishedFloor = floor.copyWith(modules: [furnishedModule]);

      final faces = Building3DBuilder.buildScene(
        floors: [furnishedFloor],
        lot: lot,
      );

      // Debe haber caras con elevación Z correspondiente a la altura de la cama (0.50m)
      expect(faces.any((f) => f.vertices.any((v) => v.z > 0.45 && v.z < 0.60)), isTrue);
    });

    testWidgets('FurnitureCatalogDialog renderiza categorías y permite amoblar recinto', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      final container = ProviderScope.containerOf(context);
                      container.read(floorEditorProvider.notifier).addModule(livingRoom);
                      FurnitureCatalogDialog.show(context, 'mod-living');
                    },
                    child: const Text('Abrir Catálogo'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Catálogo'));
      await tester.pumpAndSettle();

      expect(find.text('Amoblar: Sala de Estar'), findsOneWidget);
      expect(find.text('Estar / Social'), findsOneWidget);
      expect(find.text('Dormitorio'), findsOneWidget);
      expect(find.text('Cocina'), findsOneWidget);
      expect(find.text('Baño'), findsOneWidget);

      // Insertar primer mueble
      final addButtons = find.byIcon(Icons.add_circle);
      expect(addButtons, findsWidgets);
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('instalado en este espacio'), findsOneWidget);
    });

    test('AutoFurnishEngine y FloorEditorNotifier.autoFurnishAllRooms amueblan dormitorios, baños, cocinas y salas en 1 clic', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      final masterBed = Module(
        id: 'mod-bed',
        floorId: 'fl-1',
        name: 'Alcoba Principal',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0, 0, 3.8, 3.6),
        status: ElementStatus.isNew,
      );
      final fullBath = Module(
        id: 'mod-bath',
        floorId: 'fl-1',
        name: 'Baño Principal',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(4.0, 0, 2.4, 2.0),
        status: ElementStatus.isNew,
      );
      final kitchen = Module(
        id: 'mod-kit',
        floorId: 'fl-1',
        name: 'Cocina Integral',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(0, 4.0, 3.6, 3.0),
        status: ElementStatus.isNew,
      );

      final multiRoomFloor = floor.copyWith(
        modules: [livingRoom, masterBed, fullBath, kitchen],
      );
      notifier.loadProjectData(lot: lot, floor: multiRoomFloor);

      final totalPlaced = notifier.autoFurnishAllRooms();
      expect(totalPlaced, greaterThanOrEqualTo(10));

      final updatedFloor = container.read(floorEditorProvider).floor;
      for (final m in updatedFloor.modules) {
        expect(m.subModules, isNotEmpty, reason: '${m.name} debe quedar equipado');
        for (final sub in m.subModules) {
          expect(
            m.geometry.boundingBox.inflate(0.05).containsBoundingBox(sub.geometry.boundingBox),
            isTrue,
            reason: '${sub.name} debe estar contenido dentro de ${m.name}',
          );
        }
      }
    });

    test('AutoFurnishEngine respeta polígonos en L, clearance de puertas, elementos bloqueados y tipos canónicos', () {
      // Polígono en L con recorte 1.2m x 1.2m en esquina inferior derecha (x: 2.8..4.0, y: 0..1.2)
      final lBedroom = Module(
        id: 'l-bed',
        floorId: floor.id,
        name: 'Recámara en L',
        moduleType: 'MASTER_BEDROOM',
        geometry: Polygon2D(const [
          Point2D(0, 0),
          Point2D(2.8, 0),
          Point2D(2.8, 1.2),
          Point2D(4.0, 1.2),
          Point2D(4.0, 3.6),
          Point2D(0, 3.6),
        ]),
        status: ElementStatus.isNew,
      );
      final doorNearTopLeft = Module(
        id: 'door-entry',
        floorId: floor.id,
        name: 'Puerta',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(0.2, 0.0, 0.90, 0.15),
        status: ElementStatus.isNew,
      );

      final generated = AutoFurnishEngine.generateFurnitureForModule(
        lBedroom,
        allFloorModules: [lBedroom, doorNearTopLeft],
      );
      expect(generated, isNotEmpty);

      for (int i = 0; i < generated.length; i++) {
        final s = generated[i];
        expect(
          GeometryEngine.polygonContainsPolygon(lBedroom.geometry, s.geometry),
          isTrue,
          reason: '${s.name} debe permanecer dentro del contorno en L sin invadir el recorte',
        );
        for (int j = i + 1; j < generated.length; j++) {
          final a = s.geometry.boundingBox;
          final b = generated[j].geometry.boundingBox;
          final overlaps = a.minX < b.maxX - 0.01 &&
              a.maxX > b.minX + 0.01 &&
              a.minY < b.maxY - 0.01 &&
              a.maxY > b.minY + 0.01;
          expect(overlaps, isFalse, reason: '${s.name} y ${generated[j].name} no deben superponerse');
        }
      }

      // Tipos canónicos en Baño y Lavandería
      final bathMod = Module(
        id: 'canon-bath',
        floorId: floor.id,
        name: 'Baño Principal',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(0, 0, 2.4, 2.2),
        status: ElementStatus.isNew,
      );
      final bathItems = AutoFurnishEngine.generateFurnitureForModule(bathMod);
      expect(bathItems.any((s) => s.type == 'VANITY'), isTrue);

      final laundryMod = Module(
        id: 'canon-laundry',
        floorId: floor.id,
        name: 'Lavandería',
        moduleType: 'LAUNDRY',
        geometry: Polygon2D.fromRect(0, 0, 2.5, 2.0),
        status: ElementStatus.isNew,
      );
      final laundryItems = AutoFurnishEngine.generateFurnitureForModule(laundryMod);
      expect(laundryItems.any((s) => s.type == 'WASHING_MACHINE'), isTrue);
      expect(laundryItems.any((s) => s.type == 'LAUNDRY_SINK'), isTrue);

      // Preservar submódulos bloqueados y evitar colisión en autoFurnishModule
      final lockedFixture = SubModule(
        id: 'locked-sub',
        moduleId: livingRoom.id,
        name: 'Fijo',
        type: 'SOFA_2',
        geometry: Polygon2D.fromRect(1.5, 1.5, 1.0, 0.8),
        status: ElementStatus.existing,
        isLocked: true,
      );
      final roomWithLocked = livingRoom.copyWith(subModules: [lockedFixture]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(
        lot: lot,
        floor: floor.copyWith(modules: [roomWithLocked]),
      );
      notifier.autoFurnishModule(roomWithLocked.id);
      final afterSubs = container.read(floorEditorProvider).floor.modules.first.subModules;
      expect(afterSubs.any((s) => s.id == 'locked-sub'), isTrue);
      expect(afterSubs.length, greaterThan(1));
    });
  });
}
