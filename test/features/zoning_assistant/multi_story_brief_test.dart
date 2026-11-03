import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_brief.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_layout_generator.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/multi_story_brief_dialog.dart';

void main() {
  group('MultiStoryBrief & Two-Story Generator', () {
    late Lot testLot;
    late Floor testFloor;

    setUp(() {
      testLot = Lot(
        id: 'lot_01',
        projectId: 'proj_01',
        boundary: Polygon2D.fromRect(0, 0, 12.0, 22.0),
        zones: [
          ZoningZone(
            id: 'z_front',
            lotId: 'lot_01',
            name: 'Retiro Frontal',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 0, 12.0, 4.0),
          ),
          ZoningZone(
            id: 'z_rear',
            lotId: 'lot_01',
            name: 'Retiro Posterior',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 18.0, 12.0, 4.0),
          ),
        ],
      );

      testFloor = Floor(
        id: 'fl_01',
        buildingId: 'bld_01',
        floorNumber: 1,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 4.0, 12.0, 14.0),
        maxAllowedArea: 160.0,
      );
    });

    test('MultiStoryLayoutGenerator genera 2 pisos con escaleras coordinadas y garaje al frente', () {
      const brief = MultiStoryBrief(
        garagePlacement: GaragePlacement.frontSetbackSemiCovered,
        garageCars: 2,
        groundFloorBedroom: GroundFloorBedroomOption.masterSuite,
        upperFloorBedrooms: 2,
        upperFloorLivingOrStudy: true,
      );

      final floors = MultiStoryLayoutGenerator.generateTwoStoryLayout(
        lot: testLot,
        brief: brief,
        existingFloors: [testFloor],
      );

      expect(floors.length, equals(2));

      final pb = floors[0];
      final pa = floors[1];

      expect(pb.floorNumber, equals(1));
      expect(pb.levelMeters, equals(0.0));
      expect(pa.floorNumber, equals(2));
      expect(pa.levelMeters, equals(2.80));

      // 1. Verificar garaje en PB
      final garage = pb.modules.firstWhere((m) => m.moduleType == 'GARAGE');
      expect(garage.subModules.length, equals(2)); // 2 autos
      expect(garage.geometry.boundingBox.minY, lessThanOrEqualTo(4.0)); // En el retiro frontal

      // 2. Verificar suite principal en PB
      final masterSuitePb = pb.modules.firstWhere((m) => m.name.contains('Principal'));
      expect(masterSuitePb.subModules.any((s) => s.type == 'BED'), isTrue);

      // 3. Verificar coordinación vertical de la escalera
      final stairPb = pb.modules.firstWhere((m) => m.moduleType == 'STAIRS');
      final stairPa = pa.modules.firstWhere((m) => m.moduleType == 'STAIRS');

      final stairPbBox = stairPb.geometry.boundingBox;
      final stairPaBox = stairPa.geometry.boundingBox;

      expect(stairPbBox.minX, closeTo(stairPaBox.minX, 0.01));
      expect(stairPbBox.minY, closeTo(stairPaBox.minY, 0.01));
      expect(stairPbBox.width, closeTo(stairPaBox.width, 0.01));
      expect(stairPbBox.height, closeTo(stairPaBox.height, 0.01));

      // 4. Verificar dormitorios en PA
      final bedroomsPa = pa.modules.where((m) => m.moduleType == 'BEDROOM').toList();
      expect(bedroomsPa.length, greaterThanOrEqualTo(2));
    });

    test('FloorEditorNotifier aplica brief de 2 pisos y sincroniza allFloors', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(lot: testLot, floor: testFloor);

      const brief = MultiStoryBrief(
        garagePlacement: GaragePlacement.frontSetbackSemiCovered,
        garageCars: 1,
        groundFloorBedroom: GroundFloorBedroomOption.none,
        upperFloorBedrooms: 3,
        upperFloorLivingOrStudy: true,
      );

      notifier.applyMultiStoryBrief(brief);

      final state = container.read(floorEditorProvider);
      expect(state.allFloors.length, equals(2));
      expect(state.floor.floorNumber, equals(1));

      // Cambiar a Planta Alta
      notifier.switchFloor(state.allFloors[1].id);
      final statePa = container.read(floorEditorProvider);
      expect(statePa.floor.floorNumber, equals(2));
      expect(statePa.floor.modules, isNotEmpty);
    });

    testWidgets('MultiStoryBriefDialog monta sin overflows y aplica configuración', (tester) async {
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
                      container.read(floorEditorProvider.notifier).loadProjectData(lot: testLot, floor: testFloor);
                      MultiStoryBriefDialog.show(context);
                    },
                    child: const Text('Abrir Programa 2 Pisos'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Programa 2 Pisos'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Programa de Necesidades — Vivienda 2 Pisos'), findsOneWidget);
      expect(find.textContaining('Semicubierto en Retiro Frontal'), findsOneWidget);
      expect(find.textContaining('Generar Vivienda de 2 Pisos'), findsOneWidget);

      await tester.tap(find.text('Generar Vivienda de 2 Pisos'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Programa de Necesidades — Vivienda 2 Pisos'), findsNothing);
    });
  });
}
