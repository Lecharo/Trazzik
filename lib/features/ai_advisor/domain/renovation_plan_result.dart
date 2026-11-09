import 'package:flutter/material.dart';

enum MaterialCategory {
  flooring,
  adhesives,
  sanitary,
  paint,
  fixtures,
  electrical,
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
  final double? estimatedUnitCostCop;
  final double? estimatedTotalCostCop;

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
    this.estimatedUnitCostCop,
    this.estimatedTotalCostCop,
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
      case MaterialCategory.electrical:
        return 'Iluminación y Redes Eléctricas';
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
      case MaterialCategory.electrical:
        return Icons.lightbulb_outlined;
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
  final int fullBathroomCount;
  final int halfBathroomCount;
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
    this.fullBathroomCount = 0,
    this.halfBathroomCount = 0,
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

class RenovationPlanConfig {
  final bool renovateFloors;
  final bool renovateBathrooms;
  final bool renovateKitchen;
  final bool renovateWallsPaint;
  final bool renovateLighting;
  final Set<String> roomsForFloors;
  final Set<String> roomsForPaint;
  final Set<String> roomsForLighting;
  final Set<String> selectedBathroomIds;
  final Set<String> forcedHalfBathroomIds;
  final String? userPrompt;

  const RenovationPlanConfig({
    this.renovateFloors = true,
    this.renovateBathrooms = true,
    this.renovateKitchen = true,
    this.renovateWallsPaint = false,
    this.renovateLighting = false,
    this.roomsForFloors = const {},
    this.roomsForPaint = const {},
    this.roomsForLighting = const {},
    this.selectedBathroomIds = const {},
    this.forcedHalfBathroomIds = const {},
    this.userPrompt,
  });

  RenovationPlanConfig copyWith({
    bool? renovateFloors,
    bool? renovateBathrooms,
    bool? renovateKitchen,
    bool? renovateWallsPaint,
    bool? renovateLighting,
    Set<String>? roomsForFloors,
    Set<String>? roomsForPaint,
    Set<String>? roomsForLighting,
    Set<String>? selectedBathroomIds,
    Set<String>? forcedHalfBathroomIds,
    String? userPrompt,
  }) {
    return RenovationPlanConfig(
      renovateFloors: renovateFloors ?? this.renovateFloors,
      renovateBathrooms: renovateBathrooms ?? this.renovateBathrooms,
      renovateKitchen: renovateKitchen ?? this.renovateKitchen,
      renovateWallsPaint: renovateWallsPaint ?? this.renovateWallsPaint,
      renovateLighting: renovateLighting ?? this.renovateLighting,
      roomsForFloors: roomsForFloors ?? this.roomsForFloors,
      roomsForPaint: roomsForPaint ?? this.roomsForPaint,
      roomsForLighting: roomsForLighting ?? this.roomsForLighting,
      selectedBathroomIds: selectedBathroomIds ?? this.selectedBathroomIds,
      forcedHalfBathroomIds: forcedHalfBathroomIds ?? this.forcedHalfBathroomIds,
      userPrompt: userPrompt ?? this.userPrompt,
    );
  }
}
