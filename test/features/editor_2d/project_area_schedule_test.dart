import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/canvas_2d_painter.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/project_area_schedule_dialog.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';

void main() {
  group('Cuadro General de Superficies — Cálculos y Planilla de Locales', () {
    testWidgets('ProjectAreaScheduleDialog muestra resumen global y desglose por piso con sus espacios', (tester) async {
      // 1. Configurar Lote (10m x 20m = 200 m²)
      final lot = Lot(
        id: 'lot-test',
        projectId: 'proj-test',
        boundary: Polygon2D.fromRect(0, 0, 10, 20),
        orientationDegrees: 0,
      );

      // 2. Piso 1: Cocina (6.72 m²) + Sala (18.00 m²) = 24.72 m²
      final m1 = Module(
        id: 'm1',
        floorId: 'f1',
        name: 'Cocina Integral',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(1, 1, 2.10, 3.20),
        status: ElementStatus.isNew,
      );
      final m2 = Module(
        id: 'm2',
        floorId: 'f1',
        name: 'Sala Comedor',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(4, 1, 4.50, 4.00),
        status: ElementStatus.preserved,
      );
      final floor1 = Floor(
        id: 'f1',
        buildingId: 'b1',
        floorNumber: 1,
        name: 'Piso 1 - Nivel 0.00m',
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
        maxAllowedArea: 150,
        levelMeters: 0.0,
        heightMeters: 2.80,
        modules: [m1, m2],
      );

      // 3. Piso 2: Dormitorio (12.00 m²) + Baño (4.00 m²) = 16.00 m²
      final m3 = Module(
        id: 'm3',
        floorId: 'f2',
        name: 'Dormitorio Principal',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(1, 1, 3.00, 4.00),
        status: ElementStatus.isNew,
      );
      final m4 = Module(
        id: 'm4',
        floorId: 'f2',
        name: 'Baño Principal',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(5, 1, 2.00, 2.00),
        status: ElementStatus.isNew,
      );
      final floor2 = Floor(
        id: 'f2',
        buildingId: 'b1',
        floorNumber: 2,
        name: 'Piso 2 - Nivel +2.80m',
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
        maxAllowedArea: 150,
        levelMeters: 2.80,
        heightMeters: 2.60,
        modules: [m3, m4],
      );

      // 4. Piso 3: Terraza / Lavadero (15.00 m²)
      final m5 = Module(
        id: 'm5',
        floorId: 'f3',
        name: 'Terraza y Lavado',
        moduleType: 'LAUNDRY',
        geometry: Polygon2D.fromRect(1, 1, 5.00, 3.00),
        status: ElementStatus.isNew,
      );
      final floor3 = Floor(
        id: 'f3',
        buildingId: 'b1',
        floorNumber: 3,
        name: 'Piso 3 - Nivel +5.40m',
        boundary: Polygon2D.fromRect(0, 0, 10, 15),
        maxAllowedArea: 150,
        levelMeters: 5.40,
        heightMeters: 2.40,
        modules: [m5],
      );

      final allFloors = [floor1, floor2, floor3];
      // Total construido = 24.72 + 16.00 + 15.00 = 55.72 m²
      // Total espacios = 5 ambientes

      final project = Project(
        id: 'proj-test',
        name: 'Proyecto Casa Moderna 3 Pisos',
        ownerId: 'owner-1',
        createdAt: DateTime.now(),
      );

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            floorEditorProvider.overrideWith(
              () => _TestFloorEditorNotifier(lot, floor1, allFloors, project),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProjectAreaScheduleDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar Título del Diálogo y Proyecto
      expect(find.text('Cuadro General de Superficies'), findsOneWidget);
      expect(find.textContaining('Proyecto Casa Moderna 3 Pisos'), findsOneWidget);

      // Verificar Tarjetas de Métricas Generales
      expect(find.text('55.72 m²'), findsOneWidget); // Área Total Construida
      expect(find.text('3 niveles'), findsOneWidget); // Pisos
      expect(find.text('5 ambientes'), findsOneWidget); // Total Ambientes

      // Verificar que aparecen los 3 Pisos
      expect(find.text('Piso 1 - Nivel 0.00m'), findsOneWidget);
      expect(find.text('Piso 2 - Nivel +2.80m'), findsOneWidget);
      expect(find.text('Piso 3 - Nivel +5.40m'), findsOneWidget);

      // Verificar Subtotales por Piso
      expect(find.text('24.72 m²'), findsOneWidget);
      expect(find.text('16.00 m²'), findsOneWidget);
      expect(find.text('15.00 m²'), findsNWidgets(2)); // Subtotal Piso 3 y fila del ambiente único

      // Verificar Ambientes listados
      expect(find.text('Cocina Integral'), findsOneWidget);
      expect(find.text('Sala Comedor'), findsOneWidget);
      expect(find.text('Dormitorio Principal'), findsOneWidget);
      expect(find.text('Baño Principal'), findsOneWidget);
      expect(find.text('Terraza y Lavado'), findsOneWidget);
    });

    test('Regla Láser 2D con snap a vértices y Calco de Plano Base (BlueprintUnderlayConfig) actualizan estado y pintan sin errores', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(floorEditorProvider.notifier);

      // Activar Regla Láser 2D y verificar snap a vértice cercano (0, 0 del lote)
      notifier.toggleLaserMeasure(true);
      expect(container.read(floorEditorProvider).isLaserMeasureActive, isTrue);

      final snappedOrigin = notifier.snapToNearestVertexOrGrid(const Point2D(0.08, 0.05));
      expect(snappedOrigin.x, closeTo(0.0, 0.001));
      expect(snappedOrigin.y, closeTo(0.0, 0.001));

      notifier.setLaserMeasurePoints(snappedOrigin, const Point2D(1.50, 0.0));
      expect(
        container.read(floorEditorProvider).laserStart!.distanceTo(
          container.read(floorEditorProvider).laserEnd!,
        ),
        closeTo(1.50, 0.001),
      );

      // Activar Calco de Plano Base (Blueprint Underlay)
      notifier.updateBlueprintUnderlay(
        const BlueprintUnderlayConfig(
          isEnabled: true,
          widthMeters: 12.0,
          heightMeters: 18.0,
          structuralBayMeters: 3.5,
          opacity: 0.50,
        ),
      );
      final state = container.read(floorEditorProvider);
      expect(state.blueprintUnderlay.isEnabled, isTrue);
      expect(state.blueprintUnderlay.structuralBayMeters, closeTo(3.5, 0.01));

      // Verificar que Canvas2DPainter pinta el Calco y la Regla Láser sin excepciones
      final painter = Canvas2DPainter(state);
      expect(() => painter.shouldRepaint(Canvas2DPainter(state)), returnsNormally);
    });
  });
}

class _TestFloorEditorNotifier extends FloorEditorNotifier {
  final Lot _testLot;
  final Floor _testFloor;
  final List<Floor> _testAllFloors;
  final Project? _testProject;

  _TestFloorEditorNotifier(
    this._testLot,
    this._testFloor,
    this._testAllFloors,
    this._testProject,
  );

  @override
  FloorEditorState build() {
    return FloorEditorState(
      lot: _testLot,
      floor: _testFloor,
      allFloors: _testAllFloors,
      project: _testProject,
    );
  }
}
