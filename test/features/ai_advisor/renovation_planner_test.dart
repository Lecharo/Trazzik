import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
import 'package:trazzik/features/modules/domain/module.dart';

void main() {
  group('RenovationPlannerEngine - Cómputo de Materiales y Planificación IA', () {
    late List<Module> sampleRooms;

    setUp(() {
      sampleRooms = [
        Module(
          id: 'mod_living',
          floorId: 'fl1',
          name: 'Sala - Comedor',
          moduleType: 'LIVING_ROOM',
          geometry: Polygon2D.fromRect(0, 0, 5.0, 4.0), // 20.0 m²
          status: ElementStatus.isNew,
        ),
        Module(
          id: 'mod_kitchen',
          floorId: 'fl1',
          name: 'Cocina',
          moduleType: 'KITCHEN',
          geometry: Polygon2D.fromRect(0, 4.0, 3.0, 2.5), // 7.5 m²
          status: ElementStatus.isNew,
        ),
        Module(
          id: 'mod_bath1',
          floorId: 'fl1',
          name: 'Baño Social',
          moduleType: 'BATHROOM',
          geometry: Polygon2D.fromRect(3.0, 4.0, 2.0, 1.5), // 3.0 m²
          status: ElementStatus.isNew,
        ),
        Module(
          id: 'mod_bath2',
          floorId: 'fl2',
          name: 'Baño Principal',
          moduleType: 'BATHROOM',
          geometry: Polygon2D.fromRect(0, 0, 2.2, 1.6), // 3.52 m²
          status: ElementStatus.isNew,
        ),
      ];
    });

    test('Calcula cómputo métrico de pisos con 10% de desperdicio y adhesivos', () {
      final plan = RenovationPlannerEngine.generatePlan(
        allRooms: sampleRooms,
        renovateFloors: true,
        renovateBathrooms: false,
        renovateKitchen: false,
      );

      final totalArea = 20.0 + 7.5 + 3.0 + 3.52; // 34.02 m²
      expect(plan.totalRenovatedArea, closeTo(totalArea, 0.01));

      // Piso cerámico con 10% desperdicio: 34.02 * 1.10 = 37.42 m²
      final floorTile = plan.materials.firstWhere((m) => m.id == 'mat_floor_tiles');
      expect(floorTile.quantity, closeTo(37.42, 0.05));
      expect(floorTile.category, equals(MaterialCategory.flooring));

      // Pegante: 34.02 / 5.0 = ceil(6.804) = 7 bultos de 25 kg
      final adhesive = plan.materials.firstWhere((m) => m.id == 'mat_adhesive_floor');
      expect(adhesive.quantity, equals(7.0));

      // Boquilla: 34.02 / 3.5 = ceil(9.72) = 10 kg
      final grout = plan.materials.firstWhere((m) => m.id == 'mat_grout_floor');
      expect(grout.quantity, equals(10.0));
    });

    test('Genera kit completo de aparatos y distingue medio baño social de baño completo', () {
      final plan = RenovationPlannerEngine.generatePlan(
        allRooms: sampleRooms,
        renovateFloors: false,
        renovateBathrooms: true,
        renovateKitchen: false,
      );

      expect(plan.bathroomCount, equals(2));
      expect(plan.fullBathroomCount, equals(1));
      expect(plan.halfBathroomCount, equals(1));

      // 2 combos inodoro (aplica a Baño Social y Baño Principal)
      final combo = plan.materials.firstWhere((m) => m.id == 'mat_sanitary_combo');
      expect(combo.quantity, equals(2.0));

      // 2 muebles lavamanos
      final vanity = plan.materials.firstWhere((m) => m.id == 'mat_vanity_sink');
      expect(vanity.quantity, equals(2.0));

      // 1 kit de ducha únicamente para el Baño Principal (excluye Baño Social)
      final shower = plan.materials.firstWhere((m) => m.id == 'mat_shower_set');
      expect(shower.quantity, equals(1.0));

      // Impermeabilizante de ducha (4 kg por baño completo = 4 kg)
      final waterproof = plan.materials.firstWhere((m) => m.id == 'mat_waterproofing_shower');
      expect(waterproof.quantity, equals(4.0));
    });

    test('Planifica cuadrillas y calcula reducción de tiempo en modo paralelo', () {
      final plan = RenovationPlannerEngine.generatePlan(
        allRooms: sampleRooms,
        renovateFloors: true,
        renovateBathrooms: true,
        renovateKitchen: true,
      );

      // Fases estructuradas
      expect(plan.phases.isNotEmpty, isTrue);
      expect(plan.phases.first.phaseNumber, equals(1)); // Demolición

      // Cuadrillas
      expect(plan.sequentialCrews.isNotEmpty, isTrue);
      expect(plan.parallelCrews.isNotEmpty, isTrue);

      // Modo paralelo debe ser estrictamente más rápido que el secuencial
      expect(plan.totalParallelDays, lessThan(plan.totalSequentialDays));
      expect(plan.daysSaved, greaterThan(0));
      expect(plan.timeReductionPercent, greaterThan(25.0));
    });
  });
}
