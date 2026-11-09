import 'dart:math' as math;
import 'package:trazzik/features/floors/domain/floor.dart';

/// Pricing formula used by the architect to calculate professional design fees.
enum FeePricingMode {
  perSquareMeter,
  percentageOfConstruction,
  fixedFee,
}

/// Individual deliverable stage in an architectural design proposal.
class DesignScopePhase {
  final String code;
  final String title;
  final String description;
  final int businessDays;
  final bool included;

  const DesignScopePhase({
    required this.code,
    required this.title,
    required this.description,
    required this.businessDays,
    this.included = true,
  });

  DesignScopePhase copyWith({
    String? code,
    String? title,
    String? description,
    int? businessDays,
    bool? included,
  }) {
    return DesignScopePhase(
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      businessDays: businessDays ?? this.businessDays,
      included: included ?? this.included,
    );
  }
}

/// Payment milestone split (e.g., 40% / 30% / 30%).
class PaymentMilestone {
  final String title;
  final String triggerCondition;
  final double percentage;

  const PaymentMilestone({
    required this.title,
    required this.triggerCondition,
    required this.percentage,
  });

  double amountFor(double totalFee) => totalFee * (percentage / 100.0);
}

/// Complete domain model for a Professional Design Fee Proposal & Schedule
/// (modeled after real studio proposals such as Valentina Buendia's 2-page quote).
class ArchitectFeeProposal {
  final String studioName;
  final String studioInitials;
  final String architectName;
  final String architectContact;
  final String clientName;
  final String projectName;
  final double totalBuiltAreaM2;
  final int floorCount;
  final int habitableRoomsCount;
  final FeePricingMode pricingMode;
  final double ratePerM2Cop;
  final double constructionCostPerM2Cop;
  final double feePercentageOfConstruction;
  final double customFixedFeeCop;
  final List<DesignScopePhase> phases;
  final List<PaymentMilestone> milestones;
  final int validityDays;
  final int includedRevisionRounds;
  final List<String> exclusions;

  const ArchitectFeeProposal({
    required this.studioName,
    required this.studioInitials,
    required this.architectName,
    required this.architectContact,
    required this.clientName,
    required this.projectName,
    required this.totalBuiltAreaM2,
    required this.floorCount,
    required this.habitableRoomsCount,
    this.pricingMode = FeePricingMode.perSquareMeter,
    this.ratePerM2Cop = 62000.0,
    this.constructionCostPerM2Cop = 1850000.0,
    this.feePercentageOfConstruction = 8.5,
    this.customFixedFeeCop = 6000000.0,
    required this.phases,
    required this.milestones,
    this.validityDays = 15,
    this.includedRevisionRounds = 2,
    required this.exclusions,
  });

  /// Creates a default proposal calibrated from the project's floors and rooms.
  factory ArchitectFeeProposal.fromProjectFloors({
    required String projectName,
    required List<Floor> floors,
    String studioName = 'ESTUDIO DE ARQUITECTURA & DISEÑO INTERIOR',
    String architectName = 'Dirección de Proyectos Arquitectónicos',
    String clientName = 'Cliente Titular',
  }) {
    final nonEmptyFloors = floors;
    double builtArea = 0.0;
    int roomsCount = 0;
    for (final f in nonEmptyFloors) {
      builtArea += f.calculatedBuiltArea > 0 ? f.calculatedBuiltArea : f.floorGeometricArea;
      roomsCount += f.modules.where((m) => !m.isOpening && !m.isStairs).length;
    }
    if (builtArea <= 0) builtArea = 97.0;
    final levels = math.max(1, nonEmptyFloors.length);

    // Scale business days realistically by area and levels (baseline ~36 business days = 7-8 weeks for ~97m²)
    final scaleFactor = (builtArea / 95.0).clamp(0.75, 2.2);
    int scaleDays(int base) => math.max(2, (base * scaleFactor).round());

    return ArchitectFeeProposal(
      studioName: studioName,
      studioInitials: 'VB',
      architectName: architectName,
      architectContact: 'proyectos@trazzik.studio',
      clientName: clientName,
      projectName: projectName,
      totalBuiltAreaM2: builtArea,
      floorCount: levels,
      habitableRoomsCount: roomsCount,
      ratePerM2Cop: 62000.0,
      customFixedFeeCop: ((builtArea * 62000.0) / 50000).round() * 50000.0,
      phases: [
        DesignScopePhase(
          code: '01',
          title: 'Levantamiento y Diagnóstico Espacial',
          description:
              'Verificación métrica de estado actual ($levels nivel(es)), registro de alturas, puntos húmedos, estructura aparente y elaboración de plano base de levantamiento.',
          businessDays: scaleDays(3),
        ),
        DesignScopePhase(
          code: '02',
          title: 'Conceptualización y Dirección Estética',
          description:
              'Definición del concepto rector e intención espacial, paleta cromática, selección de acabados de pisos/muros y moodboard de mobiliario e iluminación.',
          businessDays: scaleDays(5),
        ),
        DesignScopePhase(
          code: '03',
          title: 'Desarrollo de Diseño y Modelado 3D',
          description:
              'Propuesta de redistribución arquitectónica, zonificación funcional y levantamiento volumétrico 3D integral con mobiliario e iluminación.',
          businessDays: scaleDays(10),
        ),
        DesignScopePhase(
          code: '04',
          title: 'Ajustes de Diseño y Aprobación de Materiales',
          description:
              'Revisión conjunta con el cliente sobre la maqueta 3D interactiva, refinamiento de texturas, herrajes y cierre definitivo del diseño.',
          businessDays: scaleDays(5),
        ),
        DesignScopePhase(
          code: '05',
          title: 'Visualización Arquitectónica y Vistas Finales',
          description:
              'Generación de vistas interiores y axonométricas de alta resolución mostrando la atmósfera, iluminación y materialidad aprobada.',
          businessDays: scaleDays(6),
        ),
        DesignScopePhase(
          code: '06',
          title: 'Documentación Técnica y Despiece de Carpintería',
          description:
              'Planos ejecutivos de obra: Arquitectónico, Demolición, Mampostería, Cableado e Iluminación, Hidrosanitario, Acabados y Despiece de Mobiliario.',
          businessDays: scaleDays(8),
        ),
      ],
      milestones: const [
        PaymentMilestone(
          title: '1er Pago — Anticipo de Inicio',
          triggerCondition: 'A la firma y aprobación de la propuesta para iniciar Fase 01 y 02',
          percentage: 40.0,
        ),
        PaymentMilestone(
          title: '2do Pago — Entrega de Diseño 3D',
          triggerCondition: 'Contra entrega del modelo 3D y aprobación de distribución (Fase 03 y 04)',
          percentage: 30.0,
        ),
        PaymentMilestone(
          title: '3er Pago — Entrega Final de Dossier y Planos',
          triggerCondition: 'Contra entrega de vistas finales, planos técnicos y despieces (Fase 05 y 06)',
          percentage: 30.0,
        ),
      ],
      exclusions: const [
        'No incluye ejecución física de obra civil, compra de materiales ni dirección/administración de obra en sitio.',
        'No incluye estudios geotécnicos, memorias de cálculo estructural firmadas (NSR-10) ni trámites de curaduría o licencias urbanísticas.',
        'Incluye hasta 2 rondas de ajustes durante las etapas de diseño (Fases 02 a 04). Cambios posteriores a la aprobación de cada fase se cotizarán como adicional.',
        'Los tiempos del cronograma se contabilizan en días hábiles y no contemplan los tiempos de respuesta o revisión por parte del cliente.',
      ],
    );
  }

  List<DesignScopePhase> get includedPhases =>
      phases.where((p) => p.included).toList();

  double get scopeRatio {
    if (phases.isEmpty) return 1.0;
    final totalPossibleDays = phases.fold(0, (s, p) => s + p.businessDays);
    if (totalPossibleDays <= 0) return 1.0;
    return totalBusinessDays / totalPossibleDays;
  }

  /// Total professional fee in COP according to the active pricing mode.
  double get totalFeeCop {
    switch (pricingMode) {
      case FeePricingMode.perSquareMeter:
        final raw = totalBuiltAreaM2 * ratePerM2Cop * scopeRatio;
        return ((raw / 50000).round() * 50000).toDouble();
      case FeePricingMode.percentageOfConstruction:
        final estConstruction = totalBuiltAreaM2 * constructionCostPerM2Cop;
        final raw = estConstruction * (feePercentageOfConstruction / 100.0) * scopeRatio;
        return ((raw / 50000).round() * 50000).toDouble();
      case FeePricingMode.fixedFee:
        return customFixedFeeCop;
    }
  }

  int get totalBusinessDays =>
      includedPhases.fold(0, (sum, p) => sum + p.businessDays);

  String get estimatedWeeksLabel {
    final minWeeks = math.max(1, (totalBusinessDays / 5.0).floor());
    final maxWeeks = math.max(minWeeks + 1, (totalBusinessDays / 5.0).ceil() + 1);
    return '$minWeeks – $maxWeeks semanas ($totalBusinessDays días hábiles)';
  }

  ArchitectFeeProposal copyWith({
    String? studioName,
    String? studioInitials,
    String? architectName,
    String? architectContact,
    String? clientName,
    String? projectName,
    double? totalBuiltAreaM2,
    int? floorCount,
    int? habitableRoomsCount,
    FeePricingMode? pricingMode,
    double? ratePerM2Cop,
    double? constructionCostPerM2Cop,
    double? feePercentageOfConstruction,
    double? customFixedFeeCop,
    List<DesignScopePhase>? phases,
    List<PaymentMilestone>? milestones,
    int? validityDays,
    int? includedRevisionRounds,
    List<String>? exclusions,
  }) {
    return ArchitectFeeProposal(
      studioName: studioName ?? this.studioName,
      studioInitials: studioInitials ?? this.studioInitials,
      architectName: architectName ?? this.architectName,
      architectContact: architectContact ?? this.architectContact,
      clientName: clientName ?? this.clientName,
      projectName: projectName ?? this.projectName,
      totalBuiltAreaM2: totalBuiltAreaM2 ?? this.totalBuiltAreaM2,
      floorCount: floorCount ?? this.floorCount,
      habitableRoomsCount: habitableRoomsCount ?? this.habitableRoomsCount,
      pricingMode: pricingMode ?? this.pricingMode,
      ratePerM2Cop: ratePerM2Cop ?? this.ratePerM2Cop,
      constructionCostPerM2Cop:
          constructionCostPerM2Cop ?? this.constructionCostPerM2Cop,
      feePercentageOfConstruction:
          feePercentageOfConstruction ?? this.feePercentageOfConstruction,
      customFixedFeeCop: customFixedFeeCop ?? this.customFixedFeeCop,
      phases: phases ?? this.phases,
      milestones: milestones ?? this.milestones,
      validityDays: validityDays ?? this.validityDays,
      includedRevisionRounds:
          includedRevisionRounds ?? this.includedRevisionRounds,
      exclusions: exclusions ?? this.exclusions,
    );
  }
}
