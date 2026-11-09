import 'package:flutter_test/flutter_test.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/validation/validation_engine.dart';
import 'package:trazzik/core/validation/validation_issue.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/lots/domain/zoning_zone.dart';
import 'package:trazzik/features/modules/domain/module.dart';

void main() {
  late Polygon2D standardFloorBoundary;
  late Floor baseFloor;

  setUp(() {
    // Piso de 15 x 20 m (Área geométrica: 300 m², Máximo permitido: 138 m²)
    standardFloorBoundary = Polygon2D.fromRect(0, 0, 15.0, 20.0);
    baseFloor = Floor(
      id: 'floor-1',
      buildingId: 'bldg-1',
      floorNumber: 1,
      name: 'Piso 1',
      boundary: standardFloorBoundary,
      maxAllowedArea: 138.0,
    );
  });

  group('ValidationEngine — 7 Tests Obligatorios de Remodelación', () {
    test('TEST 1: Nuevo módulo sobre existente conservado -> ERROR', () {
      final preservedModule = Module(
        id: 'mod-preserved',
        floorId: baseFloor.id,
        name: 'Sala Existente',
        moduleType: 'LIVING_ROOM',
        geometry: Polygon2D.fromRect(2, 2, 4, 4),
        status: ElementStatus.preserved,
      );

      final newModule = Module(
        id: 'mod-new',
        floorId: baseFloor.id,
        name: 'Estudio Nuevo',
        moduleType: 'STUDY',
        geometry: Polygon2D.fromRect(3, 3, 4, 4), // Superpone con Sala Existente
        status: ElementStatus.isNew,
      );

      final floor = baseFloor.copyWith(modules: [preservedModule, newModule]);
      final issues = ValidationEngine.validateFloor(floor: floor);

      final blockingErrors = issues.where((i) => i.severity == ValidationSeverity.error).toList();
      expect(blockingErrors, isNotEmpty);
      expect(
        blockingErrors.any((i) => i.code == 'NEW_MODULE_OVERLAPS_PRESERVED'),
        isTrue,
        reason: 'Debe arrojar ERROR bloqueante al construir sobre lo conservado.',
      );
    });

    test('TEST 2: Nuevo módulo sobre existente a demoler -> VÁLIDO (INFO)', () {
      final toDemolishModule = Module(
        id: 'mod-old-kitchen',
        floorId: baseFloor.id,
        name: 'Cocina Vieja',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.10, 3.20),
        status: ElementStatus.toDemolish,
      );

      final newKitchen = Module(
        id: 'mod-new-kitchen',
        floorId: baseFloor.id,
        name: 'Cocina Nueva',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.10, 3.20), // Ocupa el mismo espacio
        status: ElementStatus.isNew,
      );

      final floor = baseFloor.copyWith(modules: [toDemolishModule, newKitchen]);
      final issues = ValidationEngine.validateFloor(floor: floor);

      final errors = issues.where((i) => i.severity == ValidationSeverity.error);
      expect(errors, isEmpty, reason: 'No debe haber errores bloqueantes.');

      final info = issues.firstWhere((i) => i.code == 'NEW_MODULE_OVERLAPS_DEMOLITION');
      expect(info.severity, equals(ValidationSeverity.info));
    });

    test('TEST 3: Nuevo módulo parcialmente mayor que módulo demolido -> VÁLIDO en zona construible', () {
      final oldKitchen = Module(
        id: 'mod-old',
        floorId: baseFloor.id,
        name: 'Cocina Existente',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.10, 3.20), // 6.72 m²
        status: ElementStatus.toDemolish,
      );

      final expandedKitchen = Module(
        id: 'mod-new',
        floorId: baseFloor.id,
        name: 'Cocina Nueva Ampliada',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.80, 3.80), // 10.64 m² (Ampliación de 3.92 m²)
        status: ElementStatus.isNew,
      );

      final lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 15.30, 20.0),
        zones: [
          ZoningZone(
            id: 'zone-buildable',
            lotId: 'lot-1',
            name: 'Zona Construible Disponible',
            type: ZoningType.buildableUnoccupied,
            boundary: Polygon2D.fromRect(0, 0, 15.30, 15.0),
          ),
        ],
      );

      final floor = baseFloor.copyWith(modules: [oldKitchen, expandedKitchen]);
      final issues = ValidationEngine.validateFloor(floor: floor, lot: lot);

      final errors = issues.where((i) => i.severity == ValidationSeverity.error);
      expect(errors, isEmpty, reason: 'La ampliación en zona construible es válida.');
      expect(issues.any((i) => i.code == 'EXPANSION_ON_BUILDABLE_ZONE'), isTrue);
    });

    test('TEST 4: Nuevo módulo mayor que módulo demolido y ampliación invade zona no construible -> ERROR', () {
      final oldKitchen = Module(
        id: 'mod-old',
        floorId: baseFloor.id,
        name: 'Cocina Existente',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.10, 3.20),
        status: ElementStatus.toDemolish,
      );

      final expandedKitchen = Module(
        id: 'mod-new',
        floorId: baseFloor.id,
        name: 'Cocina Nueva Ampliada',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 5.0, 5.0), // Se expande hacia zona de retiros
        status: ElementStatus.isNew,
      );

      final lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 15.30, 20.0),
        zones: [
          ZoningZone(
            id: 'zone-setback',
            lotId: 'lot-1',
            name: 'Retiro Posterior No Construible',
            type: ZoningType.nonBuildable,
            boundary: Polygon2D.fromRect(4.0, 0, 10.0, 10.0), // Intersecta con la cocina ampliada en x >= 4
          ),
        ],
      );

      final floor = baseFloor.copyWith(modules: [oldKitchen, expandedKitchen]);
      final issues = ValidationEngine.validateFloor(floor: floor, lot: lot);

      expect(
        issues.any((i) => i.code == 'EXPANSION_ON_NON_BUILDABLE_ZONE' && i.severity == ValidationSeverity.error),
        isTrue,
        reason: 'Invadir zona no construible con ampliación debe ser ERROR bloqueante.',
      );
    });

    test('TEST 5: Nuevo módulo invade elemento existente conservado al ampliarse -> ERROR', () {
      final oldKitchen = Module(
        id: 'mod-old-kitchen',
        floorId: baseFloor.id,
        name: 'Cocina Existente',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.10, 3.20),
        status: ElementStatus.toDemolish,
      );

      final preservedBathroom = Module(
        id: 'mod-bath',
        floorId: baseFloor.id,
        name: 'Baño Conservado',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(4.20, 2, 2.0, 2.0), // Inmediatamente al lado
        status: ElementStatus.preserved,
      );

      // Cocina nueva que al crecer de 2.10 a 2.80 invade el baño conservado (2 + 2.80 = 4.80 > 4.20)
      final newKitchen = Module(
        id: 'mod-new-kitchen',
        floorId: baseFloor.id,
        name: 'Cocina Nueva Superpuesta',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.80, 3.20),
        status: ElementStatus.isNew,
      );

      final floor = baseFloor.copyWith(modules: [oldKitchen, preservedBathroom, newKitchen]);
      final issues = ValidationEngine.validateFloor(floor: floor);

      expect(
        issues.any((i) => i.code == 'EXPANSION_OVERLAPS_PRESERVED' && i.severity == ValidationSeverity.error),
        isTrue,
      );
    });

    test('TEST 6: Dos módulos nuevos se superponen mutuamente -> ERROR', () {
      final roomA = Module(
        id: 'mod-room-a',
        floorId: baseFloor.id,
        name: 'Habitación 1 Nueva',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(2, 2, 4, 4),
        status: ElementStatus.isNew,
      );

      final roomB = Module(
        id: 'mod-room-b',
        floorId: baseFloor.id,
        name: 'Habitación 2 Nueva',
        moduleType: 'BEDROOM',
        geometry: Polygon2D.fromRect(4, 3, 4, 4), // Superpone con Habitación 1
        status: ElementStatus.isNew,
      );

      final floor = baseFloor.copyWith(modules: [roomA, roomB]);
      final issues = ValidationEngine.validateFloor(floor: floor);

      expect(
        issues.any((i) => i.code == 'NEW_MODULES_MUTUAL_COLLISION' && i.severity == ValidationSeverity.error),
        isTrue,
      );
    });

    test('TEST 7: Submódulo sale del módulo -> ERROR', () {
      final bathroom = Module(
        id: 'mod-bath',
        floorId: baseFloor.id,
        name: 'Baño Principal',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(2, 2, 3, 3),
        status: ElementStatus.isNew,
        subModules: [
          SubModule(
            id: 'sub-shower',
            moduleId: 'mod-bath',
            name: 'Ducha',
            type: 'SHOWER',
            geometry: Polygon2D.fromRect(4.5, 2.5, 1.2, 1.2), // Sobresale en X (4.5 + 1.2 = 5.7 > 5.0)
            status: ElementStatus.isNew,
          ),
        ],
      );

      final floor = baseFloor.copyWith(modules: [bathroom]);
      final issues = ValidationEngine.validateFloor(floor: floor);

      expect(
        issues.any((i) => i.code == 'SUBMODULE_OUTSIDE_MODULE' && i.severity == ValidationSeverity.error),
        isTrue,
      );
    });

    test('TEST EXTRA: Ampliación sobre zona futura reservada -> WARNING', () {
      final oldKitchen = Module(
        id: 'mod-old',
        floorId: baseFloor.id,
        name: 'Cocina',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 2.0, 2.0),
        status: ElementStatus.toDemolish,
      );

      final newKitchen = Module(
        id: 'mod-new',
        floorId: baseFloor.id,
        name: 'Cocina Ampliada',
        moduleType: 'KITCHEN',
        geometry: Polygon2D.fromRect(2, 2, 4.0, 2.0), // Se expande hasta x=6
        status: ElementStatus.isNew,
      );

      final lot = Lot(
        id: 'lot-1',
        projectId: 'proj-1',
        boundary: Polygon2D.fromRect(0, 0, 15, 20),
        zones: [
          ZoningZone(
            id: 'zone-future',
            lotId: 'lot-1',
            name: 'Reserva Futura Terraza',
            type: ZoningType.futureReserved,
            boundary: Polygon2D.fromRect(4.5, 0, 5, 10), // Intersecta la ampliación
          ),
        ],
      );

      final floor = baseFloor.copyWith(modules: [oldKitchen, newKitchen]);
      final issues = ValidationEngine.validateFloor(floor: floor, lot: lot);

      expect(
        issues.any((i) => i.code == 'EXPANSION_ON_FUTURE_RESERVED' && i.severity == ValidationSeverity.warning),
        isTrue,
      );
    });

    test('Integración arquitectónica: Puerta en medio baño bajo escalera NO produce colisión de recintos', () {
      final stairs = Module(
        id: 'mod-stairs',
        floorId: baseFloor.id,
        name: 'Escalera Principal',
        moduleType: 'STAIRS',
        geometry: Polygon2D.fromRect(2.0, 2.0, 2.0, 3.5),
        status: ElementStatus.isNew,
      );

      final halfBath = Module(
        id: 'mod-half-bath',
        floorId: baseFloor.id,
        name: 'Medio Baño Social',
        moduleType: 'BATHROOM',
        geometry: Polygon2D.fromRect(2.0, 2.0, 1.4, 2.0), // Bajo la escalera
        status: ElementStatus.isNew,
      );

      final bathDoor = Module(
        id: 'mod-bath-door',
        floorId: baseFloor.id,
        name: 'Puerta Medio Baño',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(1.90, 2.20, 0.70, 0.20), // Umbral de acceso al baño
        status: ElementStatus.isNew,
      );

      final floor = baseFloor.copyWith(modules: [stairs, halfBath, bathDoor]);
      final issues = ValidationEngine.validateFloor(floor: floor);

      final errors = issues.where((i) => i.severity == ValidationSeverity.error).toList();
      expect(errors, isEmpty, reason: 'La puerta y el baño bajo escalera no deben generar error de colisión.');

      expect(
        issues.any((i) => i.code == 'BATHROOM_UNDER_STAIRS' && i.severity == ValidationSeverity.info),
        isTrue,
        reason: 'Debe reconocer la integración espacial de baño bajo escalera con mensaje informativo.',
      );
    });

    test('Colisión entre dos puertas en el mismo vano -> ERROR OPENINGS_MUTUAL_COLLISION', () {
      final door1 = Module(
        id: 'door-1',
        floorId: baseFloor.id,
        name: 'Puerta Principal',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(2.0, 2.0, 0.90, 0.20),
        status: ElementStatus.isNew,
      );

      final door2 = Module(
        id: 'door-2',
        floorId: baseFloor.id,
        name: 'Puerta Secundaria',
        moduleType: 'DOOR',
        geometry: Polygon2D.fromRect(2.0, 2.0, 0.90, 0.20),
        status: ElementStatus.isNew,
      );

      final floor = baseFloor.copyWith(modules: [door1, door2]);
      final issues = ValidationEngine.validateFloor(floor: floor);

      expect(
        issues.any((i) => i.code == 'OPENINGS_MUTUAL_COLLISION' && i.severity == ValidationSeverity.error),
        isTrue,
      );
    });
  });
}
