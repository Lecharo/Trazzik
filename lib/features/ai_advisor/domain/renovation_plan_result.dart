import 'package:flutter/material.dart';

enum MaterialCategory {
  flooring,
  adhesives,
  sanitary,
  paint,
  fixtures,
}

class MaterialItem {
  final String id;
  final String name;
  final MaterialCategory category;
  final double quantity;
  final String unit;
  final double wastePercentage;
  final String yieldFormula;
  final List<String> targetRoomNames;
  final String? purchaseTip;
  final String? packagingDetail;

  const MaterialItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.wastePercentage = 0.0,
    required this.yieldFormula,
    this.targetRoomNames = const [],
    this.purchaseTip,
    this.packagingDetail,
  });

  String get categoryLabel {
    switch (category) {
      case MaterialCategory.flooring:
        return 'Pisos y Zócalos';
      case MaterialCategory.adhesives:
        return 'Pegantes y Boquillas';
      case MaterialCategory.sanitary:
        return 'Aparatos Sanitarios y Plomería';
      case MaterialCategory.paint:
        return 'Pinturas y Acabados';
      case MaterialCategory.fixtures:
        return 'Griferías y Accesorios';
    }
  }

  IconData get icon {
    switch (category) {
      case MaterialCategory.flooring:
        return Icons.grid_view;
      case MaterialCategory.adhesives:
        return Icons.format_color_fill;
      case MaterialCategory.sanitary:
        return Icons.bathtub_outlined;
      case MaterialCategory.paint:
        return Icons.brush_outlined;
      case MaterialCategory.fixtures:
        return Icons.water_drop_outlined;
    }
  }
}

class SpecialistCrew {
  final String roleName;
  final int headcount;
  final int estimatedDays;
  final String scopeDescription;
  final List<String> equipmentNeeded;
  final IconData icon;

  const SpecialistCrew({
    required this.roleName,
    required this.headcount,
    required this.estimatedDays,
    required this.scopeDescription,
    this.equipmentNeeded = const [],
    this.icon = Icons.engineering,
  });
}

class RenovationPhase {
  final int phaseNumber;
  final String title;
  final String description;
  final List<String> specialists;
  final bool canParallelize;
  final int estimatedDaysSequential;
  final int estimatedDaysParallel;
  final String parallelTip;

  const RenovationPhase({
    required this.phaseNumber,
    required this.title,
    required this.description,
    required this.specialists,
    required this.canParallelize,
    required this.estimatedDaysSequential,
    required this.estimatedDaysParallel,
    required this.parallelTip,
  });
}

class RenovationPlanResult {
  final double totalRenovatedArea;
  final int bathroomCount;
  final int kitchenCount;
  final List<MaterialItem> materials;
  final List<SpecialistCrew> sequentialCrews;
  final List<SpecialistCrew> parallelCrews;
  final List<RenovationPhase> phases;
  final int totalSequentialDays;
  final int totalParallelDays;
  final List<String> selectedRoomNames;

  const RenovationPlanResult({
    required this.totalRenovatedArea,
    required this.bathroomCount,
    required this.kitchenCount,
    required this.materials,
    required this.sequentialCrews,
    required this.parallelCrews,
    required this.phases,
    required this.totalSequentialDays,
    required this.totalParallelDays,
    required this.selectedRoomNames,
  });

  int get daysSaved => totalSequentialDays - totalParallelDays;
  double get timeReductionPercent => totalSequentialDays > 0
      ? ((daysSaved / totalSequentialDays) * 100)
      : 0.0;
}
