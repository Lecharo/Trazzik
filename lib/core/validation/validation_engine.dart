import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/validation/validation_issue.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Motor central de validación arquitectónica y reglas de colisión de remodelación.
class ValidationEngine {
  static const double epsilon = GeometryEngine.epsilon;

  /// Ejecuta el pipeline completo de validación sobre un piso y su contexto de lote.
  static List<ValidationIssue> validateFloor({
    required Floor floor,
    Lot? lot,
  }) {
    final issues = <ValidationIssue>[];

    // 1. Validar que los módulos estén dentro de la envolvente del piso
    for (final module in floor.modules) {
      final isOp = _isOpening(module);
      // Las aberturas perimetrales (puertas de acceso, portones, ventanas en fachada)
      // se colocan en los muros exteriores del piso y pueden asentarse sobre el límite.
      final isContained = isOp
          ? GeometryEngine.doPolygonsCollide(floor.boundary, module.geometry)
          : GeometryEngine.polygonContainsPolygon(floor.boundary, module.geometry);

      if (!isContained) {
        issues.add(
          ValidationIssue(
            code: 'MODULE_OUTSIDE_FLOOR',
            severity: ValidationSeverity.error,
            message: 'El módulo "${module.name}" excede los límites físicos del piso.',
            affectedElementId: module.id,
            conflictGeometry: module.geometry,
          ),
        );
      }

      // 1.1 Validar submódulos dentro del módulo
      for (final subModule in module.subModules) {
        if (!GeometryEngine.polygonContainsPolygon(module.geometry, subModule.geometry)) {
          issues.add(
            ValidationIssue(
              code: 'SUBMODULE_OUTSIDE_MODULE',
              severity: ValidationSeverity.error,
              message:
                  'El submódulo "${subModule.name}" se encuentra fuera de los límites de "${module.name}".',
              affectedElementId: subModule.id,
              relatedElementId: module.id,
              conflictGeometry: subModule.geometry,
            ),
          );
        }
      }
    }

    // 2. Validaciones entre pares de módulos (Colisiones y Reglas de Remodelación)
    final modules = floor.modules;
    final count = modules.length;

    for (int i = 0; i < count; i++) {
      for (int j = i + 1; j < count; j++) {
        final modA = modules[i];
        final modB = modules[j];

        if (!GeometryEngine.doPolygonsCollide(modA.geometry, modB.geometry)) {
          continue;
        }

        final overlap = GeometryEngine.calculateOverlapArea(modA.geometry, modB.geometry);
        if (overlap <= epsilon) continue;

        final isOpA = _isOpening(modA);
        final isOpB = _isOpening(modB);

        // Caso: Aberturas (puertas, ventanas, portones)
        // Se instalan en muros/umbrales y comunican recintos (ej. Puerta de Baño con Baño o Escalera).
        if (isOpA || isOpB) {
          if (isOpA && isOpB) {
            issues.add(
              ValidationIssue(
                code: 'OPENINGS_MUTUAL_COLLISION',
                severity: ValidationSeverity.error,
                message:
                    'Colisión de aberturas: "${modA.name}" y "${modB.name}" no pueden superponerse en el mismo vano.',
                affectedElementId: modA.id,
                relatedElementId: modB.id,
              ),
            );
          }
          // Una abertura con un recinto es un acceso legítimo
          continue;
        }

        // Caso especial: Baño o depósito bajo escalera (integración espacial multinivel en planta baja)
        final isUnderStairsSpace = (modA.moduleType.toUpperCase() == 'STAIRS' &&
                (modB.moduleType.toUpperCase() == 'BATHROOM' || modB.moduleType.toUpperCase() == 'STORAGE')) ||
            (modB.moduleType.toUpperCase() == 'STAIRS' &&
                (modA.moduleType.toUpperCase() == 'BATHROOM' || modA.moduleType.toUpperCase() == 'STORAGE'));

        if (isUnderStairsSpace) {
          issues.add(
            ValidationIssue(
              code: 'BATHROOM_UNDER_STAIRS',
              severity: ValidationSeverity.info,
              message:
                  'Integración espacial: Espacio bajo escalera detectado ("${modA.name}" y "${modB.name}"). Verificar gálibo/altura libre (≥2.10m en circulación y ≥1.90m sobre artefactos).',
              affectedElementId: modA.id,
              relatedElementId: modB.id,
            ),
          );
          continue;
        }

        // Caso: Dos módulos NUEVOS se superponen -> ERROR
        if (modA.status == ElementStatus.isNew && modB.status == ElementStatus.isNew) {
          issues.add(
            ValidationIssue(
              code: 'NEW_MODULES_MUTUAL_COLLISION',
              severity: ValidationSeverity.error,
              message:
                  'Colisión entre dos módulos nuevos: "${modA.name}" y "${modB.name}" no pueden superponerse.',
              affectedElementId: modA.id,
              relatedElementId: modB.id,
            ),
          );
          continue;
        }

        // Casos donde uno es NUEVO y el otro es EXISTENTE/CONSERVADO o A DEMOLER
        final (newMod, otherMod) = modA.status == ElementStatus.isNew
            ? (modA, modB)
            : (modB.status == ElementStatus.isNew ? (modB, modA) : (null, null));

        if (newMod != null && otherMod != null) {
          // Caso: Nuevo sobre Existente Conservado -> ERROR
          if (otherMod.status == ElementStatus.preserved ||
              otherMod.status == ElementStatus.existing) {
            issues.add(
              ValidationIssue(
                code: 'NEW_MODULE_OVERLAPS_PRESERVED',
                severity: ValidationSeverity.error,
                message:
                    'El nuevo módulo "${newMod.name}" invade "${otherMod.name}", que está marcado como conservar.',
                affectedElementId: newMod.id,
                relatedElementId: otherMod.id,
              ),
            );
          }
          // Caso: Nuevo sobre Existente A Demoler -> VÁLIDO / INFO
          else if (otherMod.status == ElementStatus.toDemolish) {
            issues.add(
              ValidationIssue(
                code: 'NEW_MODULE_OVERLAPS_DEMOLITION',
                severity: ValidationSeverity.info,
                message:
                    'El nuevo módulo "${newMod.name}" reemplaza legítimamente el espacio de "${otherMod.name}" a demoler.',
                affectedElementId: newMod.id,
                relatedElementId: otherMod.id,
              ),
            );

            // Validar ampliación del nuevo módulo respecto al demolido
            final expansionArea =
                GeometryEngine.calculateExpansionArea(newMod.geometry, otherMod.geometry);

            if (expansionArea > epsilon) {
              // Validar si la ampliación invade otro módulo conservado
              for (final other in modules) {
                if (other.id == newMod.id || other.id == otherMod.id) continue;
                if ((other.status == ElementStatus.preserved ||
                        other.status == ElementStatus.existing) &&
                    GeometryEngine.doPolygonsCollide(newMod.geometry, other.geometry)) {
                  issues.add(
                    ValidationIssue(
                      code: 'EXPANSION_OVERLAPS_PRESERVED',
                      severity: ValidationSeverity.error,
                      message:
                          'La ampliación de "${newMod.name}" invade el módulo conservado "${other.name}".',
                      affectedElementId: newMod.id,
                      relatedElementId: other.id,
                    ),
                  );
                }
              }

              // Validar ampliación contra zonas del lote
              if (lot != null) {
                for (final zone in lot.zones) {
                  if (GeometryEngine.doPolygonsCollide(newMod.geometry, zone.boundary)) {
                    if (zone.type == ZoningType.nonBuildable) {
                      issues.add(
                        ValidationIssue(
                          code: 'EXPANSION_ON_NON_BUILDABLE_ZONE',
                          severity: ValidationSeverity.error,
                          message:
                              'La ampliación de "${newMod.name}" invade la zona no construible "${zone.name}".',
                          affectedElementId: newMod.id,
                          relatedElementId: zone.id,
                        ),
                      );
                    } else if (zone.type == ZoningType.futureReserved) {
                      issues.add(
                        ValidationIssue(
                          code: 'EXPANSION_ON_FUTURE_RESERVED',
                          severity: ValidationSeverity.warning,
                          message:
                              'La ampliación de "${newMod.name}" invade el área reservada para futura construcción "${zone.name}". Requiere confirmación.',
                          affectedElementId: newMod.id,
                          relatedElementId: zone.id,
                        ),
                      );
                    } else if (zone.type == ZoningType.buildableUnoccupied) {
                      issues.add(
                        ValidationIssue(
                          code: 'EXPANSION_ON_BUILDABLE_ZONE',
                          severity: ValidationSeverity.info,
                          message:
                              'La ampliación de "${newMod.name}" se ubica en zona construible disponible ("${zone.name}").',
                          affectedElementId: newMod.id,
                          relatedElementId: zone.id,
                        ),
                      );
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // 3. Validar área construida total respecto al máximo permitido
    if (floor.calculatedBuiltArea > floor.maxAllowedArea + epsilon) {
      issues.add(
        ValidationIssue(
          code: 'BUILT_AREA_EXCEEDS_MAX_ALLOWED',
          severity: ValidationSeverity.error,
          message:
              'El área construida propuesta (${floor.calculatedBuiltArea.toStringAsFixed(2)} m²) supera el área máxima permitida (${floor.maxAllowedArea.toStringAsFixed(2)} m²).',
          affectedElementId: floor.id,
        ),
      );
    }

    return issues;
  }

  static bool _isOpening(Module m) {
    final t = m.moduleType.toUpperCase();
    return t.contains('DOOR') || t.contains('WINDOW') || t.contains('GATE');
  }
}
