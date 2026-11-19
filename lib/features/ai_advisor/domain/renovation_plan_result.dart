import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_budget_config.dart';

enum MaterialCategory {
  demolition,
  masonry,
  flooring,
  adhesives,
  sanitary,
  paint,
  fixtures,
  electrical,
  custom,
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
  final bool isCustom;

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
    this.isCustom = false,
  });

  String get categoryLabel {
    switch (category) {
      case MaterialCategory.demolition:
        return 'Demolición y Retiro de Escombros';
      case MaterialCategory.masonry:
        return 'Mampostería y Pañetes';
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
      case MaterialCategory.custom:
        return 'Partidas Personalizadas / Especiales';
    }
  }

  IconData get icon {
    switch (category) {
      case MaterialCategory.demolition:
        return Icons.hardware_outlined;
      case MaterialCategory.masonry:
        return Icons.view_quilt_outlined;
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
      case MaterialCategory.custom:
        return Icons.handyman_outlined;
    }
  }
}

class SpecialistCrew {
  final String roleKey;
  final String roleName;
  final int headcount;
  final int estimatedDays;
  final double dailyRateCop;
  final String scopeDescription;
  final List<String> equipmentNeeded;
  final IconData icon;

  const SpecialistCrew({
    this.roleKey = '',
    required this.roleName,
    required this.headcount,
    required this.estimatedDays,
    this.dailyRateCop = 0.0,
    required this.scopeDescription,
    this.equipmentNeeded = const [],
    this.icon = Icons.engineering,
  });

  /// Total labor cost in COP: `estimatedDays * headcount * dailyRateCop`.
  double get totalLaborCostCop =>
      math.max(0, estimatedDays) *
      math.max(0, headcount) *
      math.max(0.0, dailyRateCop);
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
  final List<ActualExpenseRecord> expenses;

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
    this.expenses = const [],
  });

  int get daysSaved => totalSequentialDays - totalParallelDays;
  double get timeReductionPercent => totalSequentialDays > 0
      ? ((daysSaved / totalSequentialDays) * 100)
      : 0.0;

  double get totalMaterialsCostCop => materials.fold(
        0.0,
        (sum, item) => sum + math.max(0.0, item.estimatedTotalCostCop ?? 0.0),
      );

  double get totalSequentialLaborCostCop => sequentialCrews.fold(
        0.0,
        (sum, crew) => sum + crew.totalLaborCostCop,
      );

  double get totalParallelLaborCostCop => parallelCrews.fold(
        0.0,
        (sum, crew) => sum + crew.totalLaborCostCop,
      );

  double totalBudgetCop({bool parallelMode = true}) =>
      totalMaterialsCostCop +
      (parallelMode ? totalParallelLaborCostCop : totalSequentialLaborCostCop);

  /// Paid expenses executed to date in COP.
  double get totalExecutedCop => expenses
      .where((e) => e.status == ExpenseStatus.paid)
      .fold(0.0, (sum, e) => sum + math.max(0.0, e.amountCop));

  /// Committed / in-progress expenses in COP.
  double get totalInProgressCop => expenses
      .where((e) => e.status == ExpenseStatus.inProgress)
      .fold(0.0, (sum, e) => sum + math.max(0.0, e.amountCop));

  /// Pending / quoted expenses in COP.
  double get totalPendingExpensesCop => expenses
      .where((e) => e.status == ExpenseStatus.pending)
      .fold(0.0, (sum, e) => sum + math.max(0.0, e.amountCop));

  double remainingBalanceCop({bool parallelMode = true}) =>
      totalBudgetCop(parallelMode: parallelMode) - totalExecutedCop;
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
