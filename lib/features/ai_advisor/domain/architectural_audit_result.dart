import 'package:flutter/material.dart';

enum FindingSeverity {
  critical,   // Requiere atención urgente (ej. dormitorio sin ventilación o norma de habitabilidad vulnerada)
  warning,    // Advertencia de diseño o costo (ej. circulación excesiva, núcleos húmedos dispersos)
  suggestion, // Oportunidad de mejora / optimización
  strength,   // Acierto de diseño
}

enum FindingCategory {
  lightingVentilation, // Iluminación y ventilación natural
  circulation,         // Pasillos y recorridos
  privacyZoning,       // Privacidad y distribución de zonas
  wetCores,            // Baños, cocinas, bajantes
  remodeling,          // Coherencia de remodelación / demolición
}

class AuditFinding {
  final String title;
  final String description;
  final FindingSeverity severity;
  final FindingCategory category;
  final String? affectedModuleName;
  final String recommendation;

  const AuditFinding({
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    this.affectedModuleName,
    required this.recommendation,
  });

  Color get color {
    switch (severity) {
      case FindingSeverity.critical:
        return const Color(0xFFEF5350);
      case FindingSeverity.warning:
        return const Color(0xFFFFB74D);
      case FindingSeverity.suggestion:
        return const Color(0xFF00E5FF);
      case FindingSeverity.strength:
        return const Color(0xFF66BB6A);
    }
  }

  IconData get icon {
    switch (severity) {
      case FindingSeverity.critical:
        return Icons.report_problem;
      case FindingSeverity.warning:
        return Icons.warning_amber_rounded;
      case FindingSeverity.suggestion:
        return Icons.lightbulb_outline;
      case FindingSeverity.strength:
        return Icons.check_circle_outline;
    }
  }
}

class AuditMetrics {
  final double totalUsableArea;
  final double circulationArea;
  final double circulationPercentage;
  final int totalHabitableRooms;
  final int naturallyLitRooms;
  final int blindRoomsCount;
  final double wetCoresMaxDistanceMeters;
  final bool isRemodeling;

  const AuditMetrics({
    required this.totalUsableArea,
    required this.circulationArea,
    required this.circulationPercentage,
    required this.totalHabitableRooms,
    required this.naturallyLitRooms,
    required this.blindRoomsCount,
    required this.wetCoresMaxDistanceMeters,
    required this.isRemodeling,
  });
}

class ArchitecturalAuditResult {
  final int overallScore; // 0 a 100
  final String summaryTitle;
  final String summaryDescription;
  final AuditMetrics metrics;
  final List<AuditFinding> findings;
  final List<String> strategicTips;
  final DateTime auditedAt;

  const ArchitecturalAuditResult({
    required this.overallScore,
    required this.summaryTitle,
    required this.summaryDescription,
    required this.metrics,
    required this.findings,
    required this.strategicTips,
    required this.auditedAt,
  });
}
