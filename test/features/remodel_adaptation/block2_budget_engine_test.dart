import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_budget_config.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/domain/project_json_bundle.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

void main() {
  group('Block 2 — COP Budget Engine, Labor, Demolition & Expense Tracking', () {
    test(
      'Quantifies wall demolition, floor demolition, debris removal, new masonry, and plaster from Floor.walls and toDemolish rooms',
      () {
        final p1 = Floor(
          id: 'p1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: Polygon2D.fromRect(0, 0, 8, 12),
          maxAllowedArea: 96,
          modules: [
            Module(
              id: 'm_sala',
              floorId: 'p1',
              name: 'Sala',
              moduleType: 'LIVING_ROOM',
              geometry: Polygon2D.fromRect(0, 0, 5, 4), // 20 m²
              status: ElementStatus.existing,
            ),
            Module(
              id: 'm_old_closet',
              floorId: 'p1',
              name: 'Depósito Viejo',
              moduleType: 'STORAGE',
              geometry: Polygon2D.fromRect(5, 0, 2, 2), // 4 m² toDemolish
              status: ElementStatus.toDemolish,
            ),
          ],
          walls: [
            Wall(
              id: 'w_demo',
              floorId: 'p1',
              startPoint: const Point2D(0, 4),
              endPoint: const Point2D(5, 4), // length 5m * 2.34m = 11.70 m²
              thickness: 0.12,
              height: 2.34,
              status: ElementStatus.toDemolish,
            ),
            Wall(
              id: 'w_new',
              floorId: 'p1',
              startPoint: const Point2D(2, 0),
              endPoint: const Point2D(2, 3), // length 3m * 2.34m = 7.02 m²
              thickness: 0.12,
              height: 2.34,
              status: ElementStatus.isNew,
            ),
          ],
        );

        final plan = RenovationPlannerEngine.generatePlan(
          allRooms: p1.modules,
          floors: [p1],
          renovateFloors: true,
          renovateBathrooms: false,
          renovateKitchen: false,
        );

        final demoWall = plan.materials.firstWhere((m) => m.id == 'mat_demolition_walls');
        expect(demoWall.category, equals(MaterialCategory.demolition));
        expect(demoWall.quantity, closeTo(11.70, 0.02));
        expect(demoWall.estimatedTotalCostCop, greaterThan(0));

        final demoFloor = plan.materials.firstWhere((m) => m.id == 'mat_demolition_floors');
        expect(demoFloor.quantity, closeTo(4.0, 0.02));

        final debris = plan.materials.firstWhere((m) => m.id == 'mat_debris_removal');
        expect(debris.quantity, greaterThanOrEqualTo(2.0));

        final newMasonry = plan.materials.firstWhere((m) => m.id == 'mat_masonry_new_walls');
        expect(newMasonry.category, equals(MaterialCategory.masonry));
        expect(newMasonry.quantity, closeTo(7.02, 0.02));

        final plaster = plan.materials.firstWhere((m) => m.id == 'mat_plaster_new_walls');
        expect(plaster.quantity, closeTo(14.04, 0.02));
      },
    );

    test(
      'Applies unitPriceOverridesCop, crewDailyRatesCop, custom manual items, and computes Presupuestado vs Ejecutado vs Saldo + CSV',
      () {
        final room = Module(
          id: 'm1',
          floorId: 'p1',
          name: 'Sala',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(0, 0, 4, 5), // 20 m² -> 22 m² tile w/ 10%
          status: ElementStatus.existing,
        );
        final config = RenovationBudgetConfig(
          unitPriceOverridesCop: const {
            'mat_floor_tiles': 110000, // override default 78,000
          },
          crewDailyRatesCop: const {
            'crew_tiler': 220000,
          },
          customItems: const [
            CustomBudgetItem(
              id: 'custom_closets',
              name: 'Carpintería: 3 Clósets en Melamina RH',
              category: MaterialCategory.custom,
              phaseName: 'Carpintería',
              unit: 'und',
              quantity: 3,
              unitCostCop: 2800000,
            ),
            CustomBudgetItem(
              id: 'custom_windows',
              name: 'Ventanería Aluminio + Vidrio Acústico',
              category: MaterialCategory.custom,
              phaseName: 'Ventanería',
              unit: 'm²',
              quantity: 12.5,
              unitCostCop: 480000,
            ),
          ],
          expenses: [
            ActualExpenseRecord(
              id: 'exp_1',
              linkedItemId: 'custom_closets',
              linkedLabel: 'Anticipo Clósets',
              phaseName: 'Carpintería',
              amountCop: 4200000,
              date: DateTime.utc(2026, 11, 15),
              vendorOrNote: 'Carpintería San José',
              status: ExpenseStatus.paid,
            ),
            ActualExpenseRecord(
              id: 'exp_2',
              linkedItemId: 'mat_floor_tiles',
              linkedLabel: 'Cotización Porcelanato',
              phaseName: 'Pisos',
              amountCop: 2420000,
              date: DateTime.utc(2026, 11, 18),
              vendorOrNote: 'Alfa Bogotá',
              status: ExpenseStatus.inProgress,
            ),
          ],
        );

        final plan = RenovationPlannerEngine.generatePlan(
          allRooms: [room],
          budgetConfig: config,
          renovateFloors: true,
          renovateBathrooms: false,
          renovateKitchen: false,
        );

        final tile = plan.materials.firstWhere((m) => m.id == 'mat_floor_tiles');
        expect(tile.estimatedUnitCostCop, equals(110000));
        expect(tile.estimatedTotalCostCop, closeTo(tile.quantity * 110000, 1.0));

        final closets = plan.materials.firstWhere((m) => m.id == 'custom_closets');
        expect(closets.estimatedTotalCostCop, closeTo(8400000, 1.0));

        final tilerCrew = plan.parallelCrews.firstWhere((c) => c.roleKey == 'crew_tiler');
        expect(tilerCrew.dailyRateCop, equals(220000));
        expect(
          tilerCrew.totalLaborCostCop,
          equals(tilerCrew.headcount * tilerCrew.estimatedDays * 220000),
        );

        expect(plan.totalMaterialsCostCop, greaterThan(14400000));
        expect(plan.totalParallelLaborCostCop, greaterThan(0));
        expect(plan.totalExecutedCop, equals(4200000));
        expect(plan.totalInProgressCop, equals(2420000));
        expect(
          plan.remainingBalanceCop(parallelMode: true),
          closeTo(plan.totalBudgetCop(parallelMode: true) - 4200000, 1.0),
        );

        final csv = RenovationPlannerEngine.exportPlanToCsv(
          plan: plan,
          rooms: [room],
          projectName: 'Casa Bogotá',
          lang: 'es',
        );
        expect(csv, contains('PRESUPUESTO TOTAL COP'));
        expect(csv, contains('EJECUTADO (PAGADO) COP'));
        expect(csv, contains('SALDO RESTANTE COP'));
        expect(csv, contains('MANO DE OBRA'));
        expect(csv, contains('GASTOS REALES EJECUTADOS'));
        expect(csv, contains('Carpintería San José'));
      },
    );

    test(
      'RenovationBudgetConfig persists cleanly through Project and ProjectJsonBundle JSON round-trip',
      () {
        final lot = Lot(
          id: 'lot1',
          projectId: 'p1',
          boundary: Polygon2D.fromRect(0, 0, 7, 12),
        );
        final budget = RenovationBudgetConfig(
          unitPriceOverridesCop: const {'mat_paint_walls': 165000},
          crewDailyRatesCop: const {'crew_painter': 185000},
          customItems: const [
            CustomBudgetItem(
              id: 'c_elec',
              name: 'Tablero Eléctrico 12 Circuitos',
              category: MaterialCategory.electrical,
              phaseName: 'Eléctrico',
              unit: 'und',
              quantity: 1,
              unitCostCop: 1450000,
            ),
          ],
          expenses: [
            ActualExpenseRecord(
              id: 'e1',
              linkedItemId: 'c_elec',
              linkedLabel: 'Tablero Eléctrico',
              phaseName: 'Eléctrico',
              amountCop: 1450000,
              date: DateTime.utc(2026, 11, 19),
              vendorOrNote: 'ElectroBogotá',
              status: ExpenseStatus.paid,
            ),
          ],
        );
        final project = Project(
          id: 'p1',
          name: 'Casa Bogotá',
          ownerId: 'u1',
          lot: lot,
          renovationBudgetConfig: budget,
        );
        final floor = Floor(
          id: 'f1',
          buildingId: 'b1',
          floorNumber: 1,
          name: 'Piso 1',
          heightMeters: 2.34,
          boundary: lot.boundary,
          maxAllowedArea: 84,
        );
        final bundle = ProjectJsonBundle(
          project: project,
          lot: lot,
          floors: [floor],
        );

        final decoded = ProjectJsonBundle.tryFromJsonString(bundle.toPrettyJson());
        expect(decoded, isNotNull);
        final restoredBudget = decoded!.project.renovationBudgetConfig;
        expect(restoredBudget, isNotNull);
        expect(restoredBudget!.unitPriceOverridesCop['mat_paint_walls'], equals(165000));
        expect(restoredBudget.crewDailyRatesCop['crew_painter'], equals(185000));
        expect(restoredBudget.customItems, hasLength(1));
        expect(restoredBudget.customItems.first.name, equals('Tablero Eléctrico 12 Circuitos'));
        expect(restoredBudget.expenses, hasLength(1));
        expect(restoredBudget.expenses.first.status, equals(ExpenseStatus.paid));
        expect(restoredBudget.expenses.first.amountCop, equals(1450000));
      },
    );
  });
}
