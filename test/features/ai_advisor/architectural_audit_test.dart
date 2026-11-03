import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/ai_advisor/data/architectural_audit_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/architectural_audit_result.dart';
import 'package:trazzik/features/ai_advisor/presentation/widgets/architectural_audit_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';

void main() {
  group('ArchitecturalAuditEngine - Habitabilidad y Circulación', () {
    late Polygon2D boundary;

    setUp(() {
      // Planta de 10m x 20m (Área = 200 m², minY=0, maxY=20)
      boundary = Polygon2D.fromRect(0, 0, 10, 20);
    });

    test('Deduce 15 puntos y genera alerta cuando la circulación supera el 18%', () {
      // 100 m² útiles en total: Habitación 80 m², Pasillo 20 m² (20% > 18%)
      final bedroom = Module(
        id: 'mod-bed',
        floorId: 'fl-1',
        name: 'Dormitorio Principal',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0, 0, 8, 10), // Toca fachada frontal minY=0
        status: ElementStatus.isNew,
      );

      final corridor = Module(
        id: 'mod-corr',
        floorId: 'fl-1',
        name: 'Pasillo Distribuidor',
        moduleType: 'CORRIDOR',
        geometry: Polygon2D.fromRect(8, 0, 2, 10), // 20 m²
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta Baja',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [bedroom, corridor],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.totalUsableArea, closeTo(100.0, 0.01));
      expect(result.metrics.circulationArea, closeTo(20.0, 0.01));
      expect(result.metrics.circulationPercentage, closeTo(20.0, 0.1));

      // 100 - 15 = 85 (sin recintos ciegos ni núcleos húmedos dispersos)
      expect(result.overallScore, equals(85));

      final circulationFinding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.circulation,
      );
      expect(circulationFinding.severity, equals(FindingSeverity.warning));
      expect(circulationFinding.title, contains('Circulación excesiva'));
      expect(circulationFinding.title, contains('20.0%'));
      expect(circulationFinding.recommendation, contains('Integrar ambientes'));
    });

    test('Reconoce circulación compacta y eficiente cuando es menor o igual al 12%', () {
      // 100 m² útiles en total: Habitación 90 m², Pasillo 10 m² (10% <= 12%)
      final living = Module(
        id: 'mod-liv',
        floorId: 'fl-1',
        name: 'Sala de Estar',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(0, 0, 9, 10), // Toca fachada frontal
        status: ElementStatus.isNew,
      );

      final hallway = Module(
        id: 'mod-hall',
        floorId: 'fl-1',
        name: 'Hall de Acceso',
        moduleType: 'HALLWAY',
        geometry: Polygon2D.fromRect(9, 0, 1, 10), // 10 m²
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [living, hallway],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.circulationPercentage, closeTo(10.0, 0.1));
      expect(result.overallScore, equals(100));

      final circulationFinding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.circulation,
      );
      expect(circulationFinding.severity, equals(FindingSeverity.strength));
      expect(circulationFinding.title, contains('Circulación compacta'));
    });

    test('Detecta circulación por nombre cuando moduleType es genérico', () {
      final room = Module(
        id: 'mod-r',
        floorId: 'fl-1',
        name: 'Habitación',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0, 0, 7, 10), // 70 m²
        status: ElementStatus.isNew,
      );

      final distributor = Module(
        id: 'mod-dist',
        floorId: 'fl-1',
        name: 'Distribuidor Central',
        moduleType: 'SPACE',
        geometry: Polygon2D.fromRect(7, 0, 3, 10), // 30 m² (30% > 18%)
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [room, distributor],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);
      expect(result.metrics.circulationPercentage, closeTo(30.0, 0.1));
      expect(
        result.findings.any((f) => f.title.contains('Circulación excesiva')),
        isTrue,
      );
    });
  });

  group('ArchitecturalAuditEngine - Iluminación y Ventilación Natural', () {
    late Polygon2D boundary;

    setUp(() {
      // Planta de 10m x 20m: Fachada frontal en Y=0, contrafrente en Y=20
      boundary = Polygon2D.fromRect(0, 0, 10, 20);
    });

    test('Detecta dormitorio ciego (mediterráneo) sin fachada, sin patio y sin ventana', () {
      // Dormitorio ubicado en Y=5..9, X=3..7 (no toca Y=0 ni Y=20)
      final blindBedroom = Module(
        id: 'mod-blind-bed',
        floorId: 'fl-1',
        name: 'Dormitorio 2',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(3, 5, 4, 4),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [blindBedroom],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.totalHabitableRooms, equals(1));
      expect(result.metrics.blindRoomsCount, equals(1));
      expect(result.metrics.naturallyLitRooms, equals(0));
      // Deducción de 20 puntos por dormitorio ciego: 100 - 20 = 80
      expect(result.overallScore, equals(80));

      final blindFinding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.lightingVentilation && f.severity == FindingSeverity.critical,
      );
      expect(blindFinding.title, contains('Ambiente habitable sin ventilación directa exterior'));
      expect(blindFinding.affectedModuleName, equals('Dormitorio 2'));
      expect(blindFinding.recommendation, contains('hacia el frente, contrafrente o patio interno'));
    });

    test('Reconoce ambiente habitable ventilado por contacto con contrafrente', () {
      // Dormitorio tocando contrafrente en Y=16..20 (maxY = 20)
      final rearBedroom = Module(
        id: 'mod-rear-bed',
        floorId: 'fl-1',
        name: 'Dormitorio Principal',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(2, 16, 4, 4),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [rearBedroom],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.blindRoomsCount, equals(0));
      expect(result.metrics.naturallyLitRooms, equals(1));
      expect(result.overallScore, equals(100));
      expect(
        result.findings.any((f) => f.title.contains('100% de ambientes principales')),
        isTrue,
      );
    });

    test('Reconoce ambiente habitable ventilado por adyacencia a patio interno', () {
      // Dormitorio interior en Y=5..9, X=2..6
      final bedroom = Module(
        id: 'mod-bed-patio',
        floorId: 'fl-1',
        name: 'Dormitorio Niños',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(2, 5, 4, 4),
        status: ElementStatus.isNew,
      );

      // Patio adyacente en Y=9..13, X=2..6 (toca el lado norte del dormitorio)
      final patio = Module(
        id: 'mod-patio',
        floorId: 'fl-1',
        name: 'Patio de Luz',
        moduleType: 'PATIO',
        geometry: Polygon2D.fromRect(2, 9, 4, 4),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [bedroom, patio],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.blindRoomsCount, equals(0));
      expect(result.metrics.naturallyLitRooms, equals(1));
      expect(
        result.findings.any((f) => f.severity == FindingSeverity.critical),
        isFalse,
      );
    });

    test('Reconoce ambiente habitable ventilado cuando intersecta con un vano de ventana', () {
      final interiorStudy = Module(
        id: 'mod-study',
        floorId: 'fl-1',
        name: 'Estudio de Trabajo',
        moduleType: 'STUDY',
        geometry: Polygon2D.fromRect(3, 5, 4, 4),
        status: ElementStatus.isNew,
      );

      final window = Module(
        id: 'mod-win',
        floorId: 'fl-1',
        name: 'Ventana V-01',
        moduleType: 'WINDOW',
        geometry: Polygon2D.fromRect(3, 5, 1.2, 0.2), // Intersecta el recinto
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [interiorStudy, window],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.blindRoomsCount, equals(0));
      expect(result.metrics.naturallyLitRooms, equals(1));
    });

    test('Ambientes no habitables como baños no se marcan como dormitorios ciegos', () {
      final interiorBath = Module(
        id: 'mod-bath',
        floorId: 'fl-1',
        name: 'Baño Social',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(3, 5, 2, 2),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 200,
        modules: [interiorBath],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.totalHabitableRooms, equals(0));
      expect(result.metrics.blindRoomsCount, equals(0));
      expect(
        result.findings.any((f) => f.category == FindingCategory.lightingVentilation && f.severity == FindingSeverity.critical),
        isFalse,
      );
    });
  });

  group('ArchitecturalAuditEngine - Núcleos Húmedos e Instalaciones Sanitarias', () {
    late Polygon2D boundary;

    setUp(() {
      boundary = Polygon2D.fromRect(0, 0, 15, 25);
    });

    test('Reconoce núcleos húmedos concentrados cuando la distancia máxima es <= 8.0 m', () {
      // Baño centro en (1, 1), Cocina centro en (1.5, 4.5) -> dist ≈ 3.53 m <= 8m
      final bath = Module(
        id: 'mod-b',
        floorId: 'fl-1',
        name: 'Baño Principal',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(0, 0, 2, 2),
        status: ElementStatus.isNew,
      );

      final kitchen = Module(
        id: 'mod-k',
        floorId: 'fl-1',
        name: 'Cocina',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(0, 3, 3, 3),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 300,
        modules: [bath, kitchen],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.wetCoresMaxDistanceMeters, lessThanOrEqualTo(8.0));
      final wetFinding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.wetCores,
      );
      expect(wetFinding.severity, equals(FindingSeverity.strength));
      expect(wetFinding.title, contains('Núcleos húmedos concentrados y eficientes'));
    });

    test('Deduce 10 puntos y emite advertencia cuando los núcleos húmedos están a más de 8m', () {
      // Baño centro en (1, 1), Lavadero centro en (1.5, 14.5) -> dist > 13 m > 8m
      final bath = Module(
        id: 'mod-b',
        floorId: 'fl-1',
        name: 'Baño Principal',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(0, 0, 2, 2),
        status: ElementStatus.isNew,
      );

      final laundry = Module(
        id: 'mod-l',
        floorId: 'fl-1',
        name: 'Lavadero',
        moduleType: 'LAUNDRY',
        geometry: Polygon2D.fromRect(0, 13, 3, 3),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 300,
        modules: [bath, laundry],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.wetCoresMaxDistanceMeters, greaterThan(8.0));
      expect(result.overallScore, equals(90)); // 100 - 10 = 90

      final wetFinding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.wetCores,
      );
      expect(wetFinding.severity, equals(FindingSeverity.warning));
      expect(wetFinding.title, contains('Núcleos húmedos dispersos'));
      expect(wetFinding.recommendation, contains('Agrupar o adosar recintos húmedos'));
    });

    test('Detecta interferencia de privacidad si el baño está pegado al comedor o cocina (< 2.5m)', () {
      // Baño centro en (2, 2), Comedor centro en (2, 3.5) -> dist = 1.5m < 2.5m
      final bath = Module(
        id: 'mod-b',
        floorId: 'fl-1',
        name: 'Baño Social',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(1, 1, 2, 2),
        status: ElementStatus.isNew,
      );

      final dining = Module(
        id: 'mod-d',
        floorId: 'fl-1',
        name: 'Comedor',
        moduleType: 'DINING_ROOM',
        geometry: Polygon2D.fromRect(1, 2.5, 2, 2),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta 1',
        boundary: boundary,
        maxAllowedArea: 300,
        modules: [bath, dining],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      final privacyFinding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.privacyZoning,
      );
      expect(privacyFinding.severity, equals(FindingSeverity.suggestion));
      expect(privacyFinding.title, contains('Interferencia de privacidad: Baño adyacente a Comedor'));
      expect(privacyFinding.recommendation, contains('Generar una antecámara'));
    });
  });

  group('ArchitecturalAuditEngine - Detección y Criterios de Remodelación', () {
    late Polygon2D boundary;

    setUp(() {
      boundary = Polygon2D.fromRect(0, 0, 10, 15);
    });

    test('Detecta remodelación cuando hay elementos preservados o a demoler', () {
      final preservedLiving = Module(
        id: 'mod-p',
        floorId: 'fl-1',
        name: 'Sala Existente',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(0, 0, 5, 5),
        status: ElementStatus.preserved,
      );

      final demolishWallSpace = Module(
        id: 'mod-d',
        floorId: 'fl-1',
        name: 'Tabique Obsoleto',
        moduleType: 'STORAGE',
        geometry: Polygon2D.fromRect(5, 0, 2, 2),
        status: ElementStatus.toDemolish,
      );

      final newKitchen = Module(
        id: 'mod-n',
        floorId: 'fl-1',
        name: 'Cocina Ampliada',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(0, 5, 5, 4),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta Remodelación',
        boundary: boundary,
        maxAllowedArea: 150,
        modules: [preservedLiving, demolishWallSpace, newKitchen],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.isRemodeling, isTrue);

      final remodelingFinding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.remodeling,
      );
      expect(remodelingFinding.severity, equals(FindingSeverity.suggestion));
      expect(remodelingFinding.title, contains('Plan de Remodelación'));
      expect(remodelingFinding.title, contains('1 conservados, 1 a demoler, 1 nuevos'));

      // Verifica que incluye tips específicos de reformas
      expect(
        result.strategicTips.any((tip) => tip.contains('En reformas')),
        isTrue,
      );
    });

    test('Recomendación de ventilación para ambiente ciego se adapta a remodelación', () {
      final blindRoomPreserved = Module(
        id: 'mod-blind',
        floorId: 'fl-1',
        name: 'Dormitorio Existente',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(2, 4, 4, 4), // Interior, no toca fachada
        status: ElementStatus.preserved,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta Remodelación',
        boundary: boundary,
        maxAllowedArea: 150,
        modules: [blindRoomPreserved],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.isRemodeling, isTrue);
      final finding = result.findings.firstWhere(
        (f) => f.category == FindingCategory.lightingVentilation && f.severity == FindingSeverity.critical,
      );
      // En remodelación sugiere tragaluz/claraboya en cubierta
      expect(finding.recommendation, contains('En vivienda existente: prever un tragaluz o claraboya cenital'));
    });

    test('En obra nueva isRemodeling es false y emite tips para construcción desde cero', () {
      final newRoom = Module(
        id: 'mod-1',
        floorId: 'fl-1',
        name: 'Habitación',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0, 0, 4, 4),
        status: ElementStatus.isNew,
      );

      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta Obra Nueva',
        boundary: boundary,
        maxAllowedArea: 150,
        modules: [newRoom],
      );

      final result = ArchitecturalAuditEngine.auditFloor(floor: floor);

      expect(result.metrics.isRemodeling, isFalse);
      expect(
        result.findings.any((f) => f.category == FindingCategory.remodeling),
        isFalse,
      );
      expect(
        result.strategicTips.any((tip) => tip.contains('ancho libre mínimo de 0.90 m')),
        isTrue,
      );
    });
  });

  group('ArchitecturalAuditDialog Widget Tests', () {
    testWidgets('Renderiza el diálogo con título, score, métricas y hallazgos', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late BuildContext testContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  testContext = context;
                  return ElevatedButton(
                    onPressed: () => ArchitecturalAuditDialog.show(context),
                    child: const Text('Abrir Auditoría'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Cargar datos en el floorEditorProvider para asegurar métricas completas
      final container = ProviderScope.containerOf(testContext);
      final lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 10, 20),
      );
      final bedroom = Module(
        id: 'mod-1',
        floorId: 'fl-1',
        name: 'Dormitorio 1',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(0, 0, 4, 5), // Toca fachada frontal
        status: ElementStatus.isNew,
      );
      final floor = Floor(
        id: 'fl-1',
        buildingId: 'b-1',
        floorNumber: 1,
        name: 'Planta Baja',
        boundary: Polygon2D.fromRect(0, 0, 10, 20),
        maxAllowedArea: 200,
        modules: [bedroom],
      );

      container.read(floorEditorProvider.notifier).loadProjectData(
        lot: lot,
        floor: floor,
      );

      // Abrir diálogo
      await tester.tap(find.text('Abrir Auditoría'));
      await tester.pumpAndSettle();

      // Verificar elementos principales del encabezado
      expect(find.text('AUDITORÍA Y ASESORÍA ARQUITECTÓNICA IA'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.byIcon(Icons.psychology), findsOneWidget);

      // Verificar chips de métricas KPI
      expect(find.textContaining('Iluminación Natural'), findsOneWidget);
      expect(find.textContaining('Circulación'), findsOneWidget);
      expect(find.textContaining('Núcleos Húmedos'), findsOneWidget);
      expect(find.textContaining('Intervención'), findsOneWidget);

      // Verificar que el botón de cerrar cierra el diálogo
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('AUDITORÍA Y ASESORÍA ARQUITECTÓNICA IA'), findsNothing);
    });

    testWidgets('Botón de refresco re-ejecuta la auditoría correctamente', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late BuildContext testContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  testContext = context;
                  return ElevatedButton(
                    onPressed: () => ArchitecturalAuditDialog.show(context),
                    child: const Text('Abrir'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      // El diálogo sigue presente tras refrescar
      expect(find.text('AUDITORÍA Y ASESORÍA ARQUITECTÓNICA IA'), findsOneWidget);
    });
  });
}
