import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/zoning_assistant/domain/starter_layout_template.dart';
import 'package:trazzik/features/zoning_assistant/domain/zoning_engine.dart';
import 'package:trazzik/features/zoning_assistant/domain/zoning_guide_band.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/starter_layout_dialog.dart';

void main() {
  group('ZoningAssistant & StarterLayout', () {
    late Lot testLot;
    late Floor testFloor;

    setUp(() {
      testLot = Lot(
        id: 'lot_01',
        projectId: 'proj_01',
        boundary: Polygon2D.fromRect(0, 0, 10.0, 20.0),
        zones: [
          ZoningZone(
            id: 'z_front',
            lotId: 'lot_01',
            name: 'Retiro Frontal',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 0, 10.0, 3.0),
          ),
          ZoningZone(
            id: 'z_rear',
            lotId: 'lot_01',
            name: 'Retiro Posterior',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(0, 17.0, 10.0, 3.0),
          ),
        ],
      );

      testFloor = Floor(
        id: 'fl_01',
        buildingId: 'bld_01',
        floorNumber: 1,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 3.0, 10.0, 14.0),
        maxAllowedArea: 140.0,
      );
    });

    test('ZoningEngine calcula 3 franjas funcionales respetando retiros del lote', () {
      final bands = ZoningEngine.calculateZoningBands(testLot);

      expect(bands.length, equals(3));

      final frontBand = bands.firstWhere((b) => b.category == ZoningCategory.socialFront);
      final centerBand = bands.firstWhere((b) => b.category == ZoningCategory.serviceCenter);
      final rearBand = bands.firstWhere((b) => b.category == ZoningCategory.privateRear);

      expect(frontBand.recommendedSpaces, contains('Sala de Estar'));
      expect(centerBand.recommendedSpaces, contains('Cocina'));
      expect(rearBand.recommendedSpaces, contains('Dormitorio Principal'));

      // Verificar que el inicio de la franja frontal respeta el retiro frontal (y >= 3.0)
      final frontBbox = frontBand.boundary.boundingBox;
      expect(frontBbox.minY, closeTo(3.0, 0.01));

      // Verificar que el final de la franja posterior respeta el retiro posterior (maxY <= 17.0)
      final rearBbox = rearBand.boundary.boundingBox;
      expect(rearBbox.maxY, closeTo(17.0, 0.01));
    });

    test('StarterLayoutTemplate genera módulos arquitectónicos funcionales con mobiliario', () {
      final modules = StarterLayoutTemplate.generateModulesForLot(
        lot: testLot,
        floorId: 'fl_01',
        type: StarterLayoutType.compact2Bedrooms,
      );

      expect(modules, isNotEmpty);
      expect(modules.length, greaterThanOrEqualTo(5)); // Estar, Comedor, Cocina, Baño, Dormitorios

      // Comprobar que los módulos contienen submódulos de mobiliario
      final living = modules.firstWhere((m) => m.moduleType == 'LIVING_ROOM');
      expect(living.subModules, isNotEmpty);
      expect(living.subModules.any((s) => s.type == 'SOFA'), isTrue);

      final kitchen = modules.firstWhere((m) => m.moduleType == 'KITCHEN');
      expect(kitchen.subModules, isNotEmpty);
      expect(kitchen.subModules.any((s) => s.type == 'STOVE'), isTrue);
    });

    test('FloorEditorNotifier alterna showZoningGuide y aplica distribución base', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);
      notifier.loadProjectData(lot: testLot, floor: testFloor);

      expect(container.read(floorEditorProvider).showZoningGuide, isFalse);
      notifier.toggleZoningGuide();
      expect(container.read(floorEditorProvider).showZoningGuide, isTrue);

      final template = StarterLayoutTemplate.templates.first;
      notifier.applyStarterLayout(template);

      final state = container.read(floorEditorProvider);
      expect(state.floor.modules, isNotEmpty);
      expect(state.showZoningGuide, isTrue);
    });

    testWidgets('StarterLayoutDialog renderiza plantillas y permite aplicar esquema base', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
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
                      StarterLayoutDialog.show(context);
                    },
                    child: const Text('Abrir Asistente'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Asistente'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Asistente de Distribución Inicial'), findsOneWidget);
      expect(find.textContaining('Vivienda Compacta (2 Dormitorios)'), findsOneWidget);
      expect(find.textContaining('Generar Esquema en el Lote'), findsOneWidget);

      await tester.tap(find.text('Generar Esquema en el Lote'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Asistente de Distribución Inicial'), findsNothing);
    });
  });
}
