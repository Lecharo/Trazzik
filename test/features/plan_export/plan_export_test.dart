import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/ai_advisor/presentation/services/renovation_plan_pdf_service.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/fee_proposal/domain/architect_fee_proposal.dart';
import 'package:trazzik/features/fee_proposal/presentation/services/architect_fee_proposal_pdf_service.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/plan_export/domain/plan_export_options.dart';
import 'package:trazzik/features/plan_export/presentation/screens/technical_plan_export_screen.dart';
import 'package:trazzik/features/plan_export/presentation/services/technical_plan_pdf_service.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exportación de Láminas Técnicas Arquitectónicas en PDF', () {
    late Floor testFloor;
    late Lot testLot;

    setUp(() {
      testLot = Lot(
        id: 'lot_01',
        projectId: 'proj_01',
        boundary: Polygon2D.fromRect(0, 0, 10.0, 20.0),
      );

      final livingRoom = Module(
        id: 'mod_living',
        floorId: 'fl_01',
        name: 'Sala de Estar',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(1.0, 1.0, 4.0, 5.0),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: 'sub_sofa',
            moduleId: 'mod_living',
            name: 'Sofá 3 Puestos',
            type: 'SOFA',
            geometry: Polygon2D.fromRect(1.2, 1.2, 2.10, 0.90),
            status: ElementStatus.isNew,
          ),
        ],
      );

      final diningRoom = Module(
        id: 'mod_dining',
        floorId: 'fl_01',
        name: 'Comedor',
        moduleType: 'DINING_ROOM',
        geometry: Polygon2D.fromRect(5.0, 1.0, 3.5, 4.0),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: 'sub_table',
            moduleId: 'mod_dining',
            name: 'Mesa Comedor 6P',
            type: 'DINING_TABLE',
            geometry: Polygon2D.fromRect(5.5, 1.5, 1.60, 0.90),
            status: ElementStatus.isNew,
          ),
        ],
      );

      final wall1 = Wall(
        id: 'w1',
        floorId: 'fl_01',
        startPoint: const Point2D(1.0, 1.0),
        endPoint: const Point2D(8.5, 1.0),
        thickness: 0.15,
        height: 2.60,
        status: ElementStatus.isNew,
      );

      testFloor = Floor(
        id: 'fl_01',
        buildingId: 'bld_01',
        floorNumber: 1,
        name: 'Planta Baja',
        levelMeters: 0.0,
        heightMeters: 2.60,
        boundary: Polygon2D.fromRect(1.0, 1.0, 7.5, 5.0),
        maxAllowedArea: 100.0,
        modules: [livingRoom, diningRoom],
        walls: [wall1],
      );
    });

    test('TechnicalPlanPdfService genera bytes PDF válidos y no vacíos con lámina y cuadro de áreas', () async {
      final pdfBytes = await TechnicalPlanPdfService.generatePlanPdf(
        floor: testFloor,
        allFloors: [testFloor],
        lot: testLot,
        options: const PlanExportOptions(
          pageFormat: PdfPageFormat.a4,
          scaleLabel: '1:50',
          projectName: 'Residencia Moderna',
          professionalName: 'Arq. Andrés Mendoza',
          includeFurniture: true,
          includeWalls: true,
          includeAreaSchedulePage: true,
        ),
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      // Verificar encabezado de archivo PDF (%PDF-)
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('RenovationPlanPdfService genera PDF con fuente TTF Unicode embebida sin fallos de glifos', () async {
      final plan = RenovationPlannerEngine.generatePlan(
        allRooms: testFloor.modules,
        renovateFloors: true,
        renovateBathrooms: true,
        renovateKitchen: true,
      );

      final pdfBytes = await RenovationPlanPdfService.generatePlanPdf(
        plan: plan,
        projectName: 'Mansión Ñandú — Fase 2 (38.0 m² • ±5°)',
        scopeName: 'Planta Baja — Intervención Integral',
        isParallelMode: true,
      );

      expect(pdfBytes.length, greaterThan(1500));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('ArchitectFeeProposalPdfService genera propuesta de honorarios de 2 páginas estilo estudio', () async {
      final proposal = ArchitectFeeProposal.fromProjectFloors(
        projectName: 'Apartamento 85 m² - Valentina Buendía',
        floors: [testFloor],
        clientName: 'Valentina Buendía',
        architectName: 'Arq. Laura Sofía Medina',
      );

      expect(proposal.phases.length, equals(6));
      expect(proposal.milestones.length, equals(3));
      expect(proposal.totalFeeCop, greaterThan(1000000));

      final pdfBytes = await ArchitectFeeProposalPdfService.generateProposalPdf(
        proposal,
      );
      expect(pdfBytes.length, greaterThan(1500));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('TechnicalPlanPdfService soporta especialidades MEP/Demolición/Comparativa y Despiece PL-CARP', () async {
      for (final discipline in PlanDiscipline.values) {
        final pdfBytes = await TechnicalPlanPdfService.generatePlanPdf(
          floor: testFloor,
          allFloors: [testFloor],
          lot: testLot,
          options: PlanExportOptions(
            pageFormat: PdfPageFormat.a4,
            scaleLabel: '1:50',
            projectName: 'Apartamento Valentina Buendía',
            discipline: discipline,
            sheetCode: discipline.defaultSheetCode,
            sheetTitle: discipline.defaultSheetTitle,
            includeMillworkPage: discipline == PlanDiscipline.architectural,
          ),
        );
        expect(pdfBytes.length, greaterThan(1200));
        expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
      }
    });

    testWidgets('TechnicalPlanExportScreen monta sin errores y muestra AppBar y visor', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    final container = ProviderScope.containerOf(context);
                    container.read(floorEditorProvider.notifier).loadProjectData(lot: testLot, floor: testFloor);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TechnicalPlanExportScreen(),
                      ),
                    );
                  },
                  child: const Text('Exportar'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Exportar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Exportar Lámina Técnica'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byType(TechnicalPlanExportScreen), findsOneWidget);
    });
  });
}
