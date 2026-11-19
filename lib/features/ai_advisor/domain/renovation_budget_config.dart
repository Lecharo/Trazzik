import 'dart:math' as math;
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';

enum ExpenseStatus {
  pending,
  inProgress,
  paid;

  String label(String lang) {
    switch (this) {
      case ExpenseStatus.pending:
        return lang == 'en' ? 'Pending' : 'Pendiente';
      case ExpenseStatus.inProgress:
        return lang == 'en' ? 'In progress' : 'En proceso';
      case ExpenseStatus.paid:
        return lang == 'en' ? 'Paid' : 'Pagado';
    }
  }

  static ExpenseStatus parse(String? raw) {
    return ExpenseStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ExpenseStatus.pending,
    );
  }
}

double _sanitizeNonNegative(dynamic raw, {double fallback = 0.0}) {
  if (raw is num) {
    final v = raw.toDouble();
    if (v.isFinite && v >= 0) return v;
  }
  return fallback;
}

class CustomBudgetItem {
  final String id;
  final String name;
  final MaterialCategory category;
  final String phaseName;
  final String unit;
  final double quantity;
  final double unitCostCop;
  final String? notes;

  const CustomBudgetItem({
    required this.id,
    required this.name,
    this.category = MaterialCategory.custom,
    this.phaseName = 'Obra General',
    this.unit = 'und',
    required this.quantity,
    required this.unitCostCop,
    this.notes,
  });

  double get totalCostCop =>
      math.max(0.0, quantity) * math.max(0.0, unitCostCop);

  CustomBudgetItem copyWith({
    String? id,
    String? name,
    MaterialCategory? category,
    String? phaseName,
    String? unit,
    double? quantity,
    double? unitCostCop,
    String? notes,
  }) {
    return CustomBudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      phaseName: phaseName ?? this.phaseName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitCostCop: unitCostCop ?? this.unitCostCop,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'phase_name': phaseName,
        'unit': unit,
        'quantity': quantity,
        'unit_cost_cop': unitCostCop,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  factory CustomBudgetItem.fromJson(Map<String, dynamic> json) {
    final catName = json['category']?.toString();
    final category = MaterialCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => MaterialCategory.custom,
    );
    return CustomBudgetItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Partida personalizada',
      category: category,
      phaseName: json['phase_name']?.toString() ?? 'Obra General',
      unit: json['unit']?.toString() ?? 'und',
      quantity: _sanitizeNonNegative(json['quantity'], fallback: 1.0),
      unitCostCop: _sanitizeNonNegative(json['unit_cost_cop']),
      notes: json['notes'] as String?,
    );
  }
}

class ActualExpenseRecord {
  final String id;
  final String? linkedItemId;
  final String linkedLabel;
  final String phaseName;
  final double amountCop;
  final DateTime date;
  final String vendorOrNote;
  final ExpenseStatus status;

  const ActualExpenseRecord({
    required this.id,
    this.linkedItemId,
    required this.linkedLabel,
    this.phaseName = 'Obra General',
    required this.amountCop,
    required this.date,
    this.vendorOrNote = '',
    this.status = ExpenseStatus.paid,
  });

  ActualExpenseRecord copyWith({
    String? id,
    String? linkedItemId,
    String? linkedLabel,
    String? phaseName,
    double? amountCop,
    DateTime? date,
    String? vendorOrNote,
    ExpenseStatus? status,
  }) {
    return ActualExpenseRecord(
      id: id ?? this.id,
      linkedItemId: linkedItemId ?? this.linkedItemId,
      linkedLabel: linkedLabel ?? this.linkedLabel,
      phaseName: phaseName ?? this.phaseName,
      amountCop: amountCop ?? this.amountCop,
      date: date ?? this.date,
      vendorOrNote: vendorOrNote ?? this.vendorOrNote,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (linkedItemId != null) 'linked_item_id': linkedItemId,
        'linked_label': linkedLabel,
        'phase_name': phaseName,
        'amount_cop': amountCop,
        'date': date.toIso8601String(),
        'vendor_or_note': vendorOrNote,
        'status': status.name,
      };

  factory ActualExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ActualExpenseRecord(
      id: json['id']?.toString() ?? '',
      linkedItemId: json['linked_item_id'] as String?,
      linkedLabel: json['linked_label']?.toString() ?? 'Gasto de obra',
      phaseName: json['phase_name']?.toString() ?? 'Obra General',
      amountCop: _sanitizeNonNegative(json['amount_cop']),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      vendorOrNote: json['vendor_or_note']?.toString() ?? '',
      status: ExpenseStatus.parse(json['status']?.toString()),
    );
  }
}

class RenovationBudgetConfig {
  final Map<String, double> unitPriceOverridesCop;
  final Map<String, double> crewDailyRatesCop;
  final List<CustomBudgetItem> customItems;
  final List<ActualExpenseRecord> expenses;

  const RenovationBudgetConfig({
    this.unitPriceOverridesCop = const {},
    this.crewDailyRatesCop = const {},
    this.customItems = const [],
    this.expenses = const [],
  });

  bool get isEmpty =>
      unitPriceOverridesCop.isEmpty &&
      crewDailyRatesCop.isEmpty &&
      customItems.isEmpty &&
      expenses.isEmpty;

  RenovationBudgetConfig copyWith({
    Map<String, double>? unitPriceOverridesCop,
    Map<String, double>? crewDailyRatesCop,
    List<CustomBudgetItem>? customItems,
    List<ActualExpenseRecord>? expenses,
  }) {
    return RenovationBudgetConfig(
      unitPriceOverridesCop:
          unitPriceOverridesCop ?? this.unitPriceOverridesCop,
      crewDailyRatesCop: crewDailyRatesCop ?? this.crewDailyRatesCop,
      customItems: customItems ?? this.customItems,
      expenses: expenses ?? this.expenses,
    );
  }

  Map<String, dynamic> toJson() => {
        'unit_price_overrides_cop': unitPriceOverridesCop,
        'crew_daily_rates_cop': crewDailyRatesCop,
        'custom_items': customItems.map((i) => i.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory RenovationBudgetConfig.fromJson(Map<String, dynamic> json) {
    final unitOverrides = <String, double>{};
    final rawUnits = json['unit_price_overrides_cop'];
    if (rawUnits is Map) {
      for (final e in rawUnits.entries) {
        final v = _sanitizeNonNegative(e.value, fallback: -1);
        if (v >= 0) unitOverrides[e.key.toString()] = v;
      }
    }

    final crewRates = <String, double>{};
    final rawCrews = json['crew_daily_rates_cop'];
    if (rawCrews is Map) {
      for (final e in rawCrews.entries) {
        final v = _sanitizeNonNegative(e.value, fallback: -1);
        if (v >= 0) crewRates[e.key.toString()] = v;
      }
    }

    final items = (json['custom_items'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => CustomBudgetItem.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        const [];

    final expenses = (json['expenses'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) =>
                ActualExpenseRecord.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        const [];

    return RenovationBudgetConfig(
      unitPriceOverridesCop: unitOverrides,
      crewDailyRatesCop: crewRates,
      customItems: items,
      expenses: expenses,
    );
  }
}
