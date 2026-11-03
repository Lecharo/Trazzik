import 'dart:math' as math;
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/features/ai_advisor/domain/architectural_audit_result.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Motor analítico local de auditoría y asesoramiento arquitectónico.
/// Evalúa con rigor técnico: iluminación, circulaciones, núcleos húmedos y viabilidad de remodelación.
class ArchitecturalAuditEngine {
  static ArchitecturalAuditResult auditFloor({
    required Floor floor,
    Lot? lot,
    List<Floor> allFloors = const [],
  }) {
    final findings = <AuditFinding>[];
    final strategicTips = <String>[];
    int scoreDeductions = 0;

    final boundary = floor.boundary.boundingBox;
    final modules = floor.modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return !t.contains('DOOR') && !t.contains('WINDOW') && !t.contains('GATE');
    }).toList();

    final openings = floor.modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return t.contains('DOOR') || t.contains('WINDOW') || t.contains('GATE');
    }).toList();

    final isRemodeling = floor.modules.any((m) =>
        m.status == ElementStatus.toDemolish ||
        m.status == ElementStatus.preserved);

    // 1. Áreas y Circulación
    double totalUsable = 0.0;
    double circulationArea = 0.0;

    for (final m in modules) {
      totalUsable += m.area;
      final t = m.moduleType.toUpperCase();
      final name = m.name.toUpperCase();
      if (t == 'CORRIDOR' ||
          t == 'HALLWAY' ||
          name.contains('PASILLO') ||
          name.contains('HALL') ||
          name.contains('DISTRIBUIDOR') ||
          name.contains('CIRCULACION')) {
        circulationArea += m.area;
      }
    }

    final circulationPct = totalUsable > 0 ? (circulationArea / totalUsable * 100) : 0.0;

    if (circulationPct > 18.0) {
      scoreDeductions += 15;
      findings.add(AuditFinding(
        title: 'Circulación excesiva (${circulationPct.toStringAsFixed(1)}%)',
        description:
            'Los pasillos y distribuidores ocupan ${circulationArea.toStringAsFixed(1)} m² de los ${totalUsable.toStringAsFixed(1)} m² útiles. En viviendas eficientes no debe superar el 12-15%.',
        severity: FindingSeverity.warning,
        category: FindingCategory.circulation,
        recommendation:
            'Integrar ambientes (ej. cocina-comedor abierta o accesos directos desde la sala) para transformar metros cuadrados de tránsito en espacio habitable útil.',
      ));
    } else if (circulationPct > 0 && circulationPct <= 12.0) {
      findings.add(AuditFinding(
        title: 'Circulación compacta y eficiente (${circulationPct.toStringAsFixed(1)}%)',
        description:
            'Excelente aprovechamiento de la planta. Menos del 12% se pierde en pasillos cerrados.',
        severity: FindingSeverity.strength,
        category: FindingCategory.circulation,
        recommendation:
            'Mantener este esquema de accesos directos en las siguientes plantas.',
      ));
    }

    // 2. Iluminación y Ventilación Natural de Ambientes Habitables
    int totalHabitable = 0;
    int naturallyLitCount = 0;
    int blindRooms = 0;

    final patiosAndGardens = modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return t == 'GARDEN' || t == 'TERRACE' || t == 'PATIO';
    }).toList();

    for (final m in modules) {
      final t = m.moduleType.toUpperCase();
      final isHabitable = t == 'BEDROOM' ||
          t == 'LIVING_ROOM' ||
          t == 'DINING_ROOM' ||
          t == 'LIVING_DINING' ||
          t == 'STUDY' ||
          t == 'OFFICE';

      if (!isHabitable) continue;
      totalHabitable++;

      final bb = m.geometry.boundingBox;
      // Toca el frente (Y min), el fondo (Y max) o los laterales si hay retiro
      final touchesFront = (bb.minY - boundary.minY).abs() <= 0.20;
      final touchesBack = (bb.maxY - boundary.maxY).abs() <= 0.20;
      final touchesPatio = patiosAndGardens.any((p) {
        final pb = p.geometry.boundingBox;
        return (bb.minX - pb.maxX).abs() <= 0.15 ||
            (bb.maxX - pb.minX).abs() <= 0.15 ||
            (bb.minY - pb.maxY).abs() <= 0.15 ||
            (bb.maxY - pb.minY).abs() <= 0.15;
      });

      // O tiene una ventana asignada
      final hasWindow = openings.any((op) {
        final opType = op.moduleType.toUpperCase();
        if (!opType.contains('WINDOW')) return false;
        final opBB = op.geometry.boundingBox;
        return opBB.intersects(bb);
      });

      // O es un Comedor/Sala integrado en concepto abierto contiguo a un ambiente social con luz exterior
      final isIntegratedSocialOpen = (t == 'DINING_ROOM' || t == 'LIVING_ROOM') && modules.any((other) {
        if (other.id == m.id) return false;
        final ot = other.moduleType.toUpperCase();
        if (ot != 'LIVING_ROOM' && ot != 'DINING_ROOM' && ot != 'LIVING_DINING') return false;
        final ob = other.geometry.boundingBox;
        final isAdjacent = (bb.minX - ob.maxX).abs() <= 0.25 ||
            (bb.maxX - ob.minX).abs() <= 0.25 ||
            (bb.minY - ob.maxY).abs() <= 0.25 ||
            (bb.maxY - ob.minY).abs() <= 0.25;
        if (!isAdjacent) return false;

        final otherFront = (ob.minY - boundary.minY).abs() <= 0.20;
        final otherBack = (ob.maxY - boundary.maxY).abs() <= 0.20;
        final otherPatio = patiosAndGardens.any((p) {
          final pb = p.geometry.boundingBox;
          return (ob.minX - pb.maxX).abs() <= 0.15 ||
              (ob.maxX - pb.minX).abs() <= 0.15 ||
              (ob.minY - pb.maxY).abs() <= 0.15 ||
              (ob.maxY - pb.minY).abs() <= 0.15;
        });
        final otherWindow = openings.any((op) {
          final opType = op.moduleType.toUpperCase();
          if (!opType.contains('WINDOW')) return false;
          return op.geometry.boundingBox.intersects(ob);
        });

        return otherFront || otherBack || otherPatio || otherWindow;
      });

      if (touchesFront || touchesBack || touchesPatio || hasWindow) {
        naturallyLitCount++;
      } else if (isIntegratedSocialOpen) {
        naturallyLitCount++;
        findings.add(AuditFinding(
          title: 'Iluminación y ventilación integrada ("${m.name}")',
          description:
              'El recinto "${m.name}" comparte un concepto abierto con la zona social contigua, recibiendo iluminación y ventilación natural prestada de fachada/patio.',
          severity: FindingSeverity.strength,
          category: FindingCategory.lightingVentilation,
          affectedModuleName: m.name,
          recommendation:
              'Garantizar que el ventanal principal del área social cubra al menos el 15% de la superficie acumulada de ambos ambientes integrados.',
        ));
      } else {
        blindRooms++;
        scoreDeductions += 20;
        findings.add(AuditFinding(
          title: 'Ambiente habitable sin ventilación directa exterior ("${m.name}")',
          description:
              'El recinto "${m.name}" se encuentra en posición mediterránea/ciega sin contacto con fachada, patio ni pozo de luz.',
          severity: FindingSeverity.critical,
          category: FindingCategory.lightingVentilation,
          affectedModuleName: m.name,
          recommendation: isRemodeling
              ? 'En vivienda existente: prever un tragaluz o claraboya cenital en cubierta, o abrir un vano hacia un patio interno.'
              : 'Reubicar el ambiente "${m.name}" hacia el frente, contrafrente o patio interno para garantizar luz natural obligatoria por norma de habitabilidad.',
        ));
      }
    }

    if (totalHabitable > 0 && blindRooms == 0) {
      findings.add(AuditFinding(
        title: '100% de ambientes principales con iluminación exterior',
        description:
            'Todos los dormitorios y zonas sociales cuentan con orientación hacia fachada o patio.',
        severity: FindingSeverity.strength,
        category: FindingCategory.lightingVentilation,
        recommendation:
            'Garantizar que las ventanas tengan un área vidriada mínima de 1/8 a 1/6 de la superficie del piso del ambiente.',
      ));
    }

    // 3. Núcleos Húmedos (Instalaciones Sanitarias y Costos)
    final wetModules = modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return t == 'BATHROOM' || t == 'KITCHEN' || t == 'LAUNDRY';
    }).toList();

    double maxWetDist = 0.0;
    if (wetModules.length >= 2) {
      for (int i = 0; i < wetModules.length; i++) {
        for (int j = i + 1; j < wetModules.length; j++) {
          final c1 = wetModules[i].geometry.boundingBox.center;
          final c2 = wetModules[j].geometry.boundingBox.center;
          final dist = c1.distanceTo(c2);
          if (dist > maxWetDist) maxWetDist = dist;
        }
      }

      if (maxWetDist > 8.0) {
        scoreDeductions += 10;
        findings.add(AuditFinding(
          title: 'Núcleos húmedos dispersos (Distancia máx: ${maxWetDist.toStringAsFixed(1)} m)',
          description:
              'Los baños, la cocina y el lavadero están alejados entre sí a más de 8 metros lineales en planta.',
          severity: FindingSeverity.warning,
          category: FindingCategory.wetCores,
          recommendation:
              'Agrupar o adosar recintos húmedos espalda con espalda permite compartir plenos de bajantes sanitarias, reduce el recorrido de cañerías y abarata el presupuesto de obra.',
        ));
      } else {
        findings.add(AuditFinding(
          title: 'Núcleos húmedos concentrados y eficientes (${maxWetDist.toStringAsFixed(1)} m)',
          description:
              'Las instalaciones de agua y desagüe están agrupadas, optimizando bajantes y costos de plomería.',
          severity: FindingSeverity.strength,
          category: FindingCategory.wetCores,
          recommendation:
              'Excelente para coordinar bajantes hacia planta baja y pozo de inspección.',
        ));
      }
    }

    // 4. Privacidad y Zonificación Social vs Íntima
    final bathrooms = modules.where((m) => m.moduleType.toUpperCase() == 'BATHROOM').toList();
    final diningOrKitchen = modules.where((m) {
      final t = m.moduleType.toUpperCase();
      return t == 'DINING_ROOM' || t == 'KITCHEN';
    }).toList();

    for (final bath in bathrooms) {
      final bathBB = bath.geometry.boundingBox;
      for (final foodArea in diningOrKitchen) {
        final foodBB = foodArea.geometry.boundingBox;
        final dist = bathBB.center.distanceTo(foodBB.center);
        if (dist < 2.5) {
          findings.add(AuditFinding(
            title: 'Interferencia de privacidad: Baño adyacente a ${foodArea.name}',
            description:
                'El acceso al "${bath.name}" se encuentra a menos de 2.50m del área de ${foodArea.name}.',
            severity: FindingSeverity.suggestion,
            category: FindingCategory.privacyZoning,
            affectedModuleName: bath.name,
            recommendation:
                'Generar una antecámara (lavamanos exterior o pequeño vestíbulo) o reorientar la puerta para evitar vista directa hacia la mesa o mesón de cocina.',
          ));
        }
      }
    }

    // 5. Coherencia en Remodelación
    if (isRemodeling) {
      final toDemolishCount = floor.modules.where((m) => m.status == ElementStatus.toDemolish).length;
      final preservedCount = floor.modules.where((m) => m.status == ElementStatus.preserved).length;
      final newCount = floor.modules.where((m) => m.status == ElementStatus.isNew).length;

      findings.add(AuditFinding(
        title: 'Plan de Remodelación: $preservedCount conservados, $toDemolishCount a demoler, $newCount nuevos',
        description:
            'Estrategia de transformación sobre la edificación existente identificada.',
        severity: FindingSeverity.suggestion,
        category: FindingCategory.remodeling,
        recommendation:
            'Verificar antes de demoler si los tabiques contienen instalaciones de gas o electricidad que requieran desvío previo.',
      ));

      strategicTips.add('En reformas, priorizá siempre abrir muros no portantes antes de tocar paredes medianeras o columnas.');
      strategicTips.add('Si conservás baños existentes, podés ahorrar hasta un 30% del costo total de la remodelación.');
    } else {
      strategicTips.add('Asegurá que la circulación principal tenga un ancho libre mínimo de 0.90 m para paso cómodo de personas y muebles.');
      strategicTips.add('En lotes angostos (ej. 3 a 5 m de frente), la ventilación cruzada y los patios internos son vitales.');
    }

    // Calcular Puntaje Global (0 a 100)
    final calculatedScore = (100 - scoreDeductions).clamp(25, 100);

    String summaryTitle;
    String summaryDesc;

    if (calculatedScore >= 90) {
      summaryTitle = 'Distribución Sobresaliente';
      summaryDesc = 'El planteamiento presenta óptima habitabilidad, excelente iluminación y una economía de circulaciones muy cuidada.';
    } else if (calculatedScore >= 75) {
      summaryTitle = 'Planteamiento Sólido con Oportunidades de Mejora';
      summaryDesc = 'La base funcional es buena, pero existen puntos puntuales de circulación o ventilación que pueden optimizarse.';
    } else if (calculatedScore >= 55) {
      summaryTitle = 'Requiere Ajustes de Habitabilidad';
      summaryDesc = 'Se detectaron recintos ciegos o recorridos excesivos que comprometen el confort diario o elevan costos de obra.';
    } else {
      summaryTitle = 'Revisión Estructural y Funcional Recomendada';
      summaryDesc = 'El esquema presenta conflictos serios de iluminación, ventilación o privacidad que deben resolverse antes de construir.';
    }

    return ArchitecturalAuditResult(
      overallScore: calculatedScore,
      summaryTitle: summaryTitle,
      summaryDescription: summaryDesc,
      metrics: AuditMetrics(
        totalUsableArea: totalUsable,
        circulationArea: circulationArea,
        circulationPercentage: circulationPct,
        totalHabitableRooms: totalHabitable,
        naturallyLitRooms: naturallyLitCount,
        blindRoomsCount: blindRooms,
        wetCoresMaxDistanceMeters: maxWetDist,
        isRemodeling: isRemodeling,
      ),
      findings: findings,
      strategicTips: strategicTips,
      auditedAt: DateTime.now(),
    );
  }
}
