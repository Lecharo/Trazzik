import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_budget_config.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';

double? _parseCopNumber(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
  if (cleaned.isEmpty) return null;
  final normalized = cleaned.contains('.') && cleaned.contains(',')
      ? cleaned.replaceAll('.', '').replaceAll(',', '.')
      : cleaned.replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null || !parsed.isFinite || parsed < 0) return null;
  return parsed;
}

/// Dialog to override a material's unit price in COP (or restore default).
Future<({double? priceCop, bool resetToDefault})?> showEditUnitPriceDialog({
  required BuildContext context,
  required MaterialItem item,
  required double? defaultPriceCop,
  required bool isEn,
}) {
  return showDialog<({double? priceCop, bool resetToDefault})>(
    context: context,
    builder: (_) => _EditUnitPriceDialog(
      item: item,
      defaultPriceCop: defaultPriceCop,
      isEn: isEn,
    ),
  );
}

class _EditUnitPriceDialog extends StatefulWidget {
  final MaterialItem item;
  final double? defaultPriceCop;
  final bool isEn;

  const _EditUnitPriceDialog({
    required this.item,
    required this.defaultPriceCop,
    required this.isEn,
  });

  @override
  State<_EditUnitPriceDialog> createState() => _EditUnitPriceDialogState();
}

class _EditUnitPriceDialogState extends State<_EditUnitPriceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.item.estimatedUnitCostCop ?? widget.defaultPriceCop ?? 0)
          .toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AlertDialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      title: Text(
        widget.isEn ? 'Edit Unit Price (COP)' : 'Editar Valor Unitario (COP)',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.item.name} (${widget.item.unit})',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('unit_price_cop_input'),
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: widget.isEn
                    ? 'Unit Price COP / ${widget.item.unit}'
                    : 'Valor Unitario COP / ${widget.item.unit}',
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.defaultPriceCop != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              (priceCop: null, resetToDefault: true),
            ),
            child: Text(widget.isEn ? 'Reset Default' : 'Restaurar Default'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isEn ? 'Cancel' : 'Cancelar'),
        ),
        ElevatedButton(
          key: const Key('save_unit_price_button'),
          onPressed: () {
            final parsed = _parseCopNumber(_controller.text);
            if (parsed != null) {
              Navigator.of(context).pop(
                (priceCop: parsed, resetToDefault: false),
              );
            }
          },
          child: Text(widget.isEn ? 'Save' : 'Guardar'),
        ),
      ],
    );
  }
}

/// Dialog to edit a specialist crew daily wage rate in COP.
Future<double?> showEditCrewRateDialog({
  required BuildContext context,
  required SpecialistCrew crew,
  required bool isEn,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _EditCrewRateDialog(crew: crew, isEn: isEn),
  );
}

class _EditCrewRateDialog extends StatefulWidget {
  final SpecialistCrew crew;
  final bool isEn;

  const _EditCrewRateDialog({required this.crew, required this.isEn});

  @override
  State<_EditCrewRateDialog> createState() => _EditCrewRateDialogState();
}

class _EditCrewRateDialogState extends State<_EditCrewRateDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.crew.dailyRateCop.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AlertDialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      title: Text(
        widget.isEn
            ? 'Daily Labor Rate (COP)'
            : 'Tarifa Diaria de Mano de Obra (COP)',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.crew.roleName} (${widget.crew.headcount} op. × ${widget.crew.estimatedDays} d)',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('crew_rate_cop_input'),
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: widget.isEn
                    ? 'Daily rate per worker (COP/day)'
                    : 'Tarifa diaria por operario (COP/día)',
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isEn ? 'Cancel' : 'Cancelar'),
        ),
        ElevatedButton(
          key: const Key('save_crew_rate_button'),
          onPressed: () {
            final parsed = _parseCopNumber(_controller.text);
            if (parsed != null) Navigator.of(context).pop(parsed);
          },
          child: Text(widget.isEn ? 'Save' : 'Guardar'),
        ),
      ],
    );
  }
}

/// Dialog to create a custom manual remodeling line item.
Future<CustomBudgetItem?> showAddCustomBudgetItemDialog({
  required BuildContext context,
  required bool isEn,
}) {
  return showDialog<CustomBudgetItem>(
    context: context,
    builder: (_) => _AddCustomBudgetItemDialog(isEn: isEn),
  );
}

class _AddCustomBudgetItemDialog extends StatefulWidget {
  final bool isEn;

  const _AddCustomBudgetItemDialog({required this.isEn});

  @override
  State<_AddCustomBudgetItemDialog> createState() =>
      _AddCustomBudgetItemDialogState();
}

class _AddCustomBudgetItemDialogState
    extends State<_AddCustomBudgetItemDialog> {
  final _nameCtrl = TextEditingController();
  late final TextEditingController _phaseCtrl;
  final _unitCtrl = TextEditingController(text: 'und');
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  var _selectedCategory = MaterialCategory.custom;

  @override
  void initState() {
    super.initState();
    _phaseCtrl = TextEditingController(
      text: widget.isEn
          ? 'Carpentry & Special Works'
          : 'Carpintería y Especiales',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phaseCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isEn = widget.isEn;
    final presets = <({String label, String phase, String unit, MaterialCategory cat})>[
      (
        label: isEn ? 'Closets / Carpentry' : 'Carpintería / Clósets',
        phase: isEn ? 'Carpentry' : 'Carpintería',
        unit: 'und',
        cat: MaterialCategory.custom,
      ),
      (
        label: isEn ? 'Kitchen Cabinets' : 'Muebles de Cocina',
        phase: isEn ? 'Kitchen' : 'Cocina',
        unit: 'ml',
        cat: MaterialCategory.custom,
      ),
      (
        label: isEn ? 'Windows & Glazing' : 'Ventanería Aluminio',
        phase: isEn ? 'Windows' : 'Ventanería',
        unit: 'm²',
        cat: MaterialCategory.custom,
      ),
      (
        label: isEn ? 'Roof Waterproofing' : 'Impermeabilización Cubierta',
        phase: isEn ? 'Roof' : 'Cubierta',
        unit: 'm²',
        cat: MaterialCategory.masonry,
      ),
      (
        label: isEn ? 'Electrical Panel' : 'Tablero Eléctrico',
        phase: isEn ? 'Electrical' : 'Eléctrico',
        unit: 'und',
        cat: MaterialCategory.electrical,
      ),
    ];

    return AlertDialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      title: Text(
        isEn ? 'Add Custom Budget Item' : 'Agregar Partida Manual (COP)',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets
                    .map(
                      (p) => ActionChip(
                        label: Text(
                          p.label,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        onPressed: () {
                          setState(() {
                            _nameCtrl.text = p.label;
                            _phaseCtrl.text = p.phase;
                            _unitCtrl.text = p.unit;
                            _selectedCategory = p.cat;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('custom_item_name_input'),
                controller: _nameCtrl,
                style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: isEn
                      ? 'Item Description'
                      : 'Descripción de la Partida',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<MaterialCategory>(
                      initialValue: _selectedCategory,
                      isExpanded: true,
                      dropdownColor: colors.panelBg,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 11.5,
                      ),
                      decoration: InputDecoration(
                        labelText: isEn ? 'Category' : 'Categoría',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: MaterialCategory.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phaseCtrl,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: isEn ? 'Phase' : 'Fase / Capítulo',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('custom_item_qty_input'),
                      controller: _qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: isEn ? 'Quantity' : 'Cantidad',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _unitCtrl,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: isEn ? 'Unit' : 'Unidad',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const Key('custom_item_unit_cost_input'),
                      controller: _costCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        labelText:
                            isEn ? 'Unit Cost (COP)' : 'Valor Unit. (COP)',
                        prefixText: '\$ ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                style: TextStyle(color: colors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  labelText: isEn
                      ? 'Notes (optional)'
                      : 'Notas / Especificación (opcional)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isEn ? 'Cancel' : 'Cancelar'),
        ),
        ElevatedButton(
          key: const Key('save_custom_item_button'),
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final qty = _parseCopNumber(_qtyCtrl.text) ?? 0;
            final unitCost = _parseCopNumber(_costCtrl.text) ?? 0;
            if (name.isEmpty || qty <= 0) return;
            Navigator.of(context).pop(
              CustomBudgetItem(
                id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
                name: name,
                category: _selectedCategory,
                phaseName: _phaseCtrl.text.trim().isEmpty
                    ? 'Obra General'
                    : _phaseCtrl.text.trim(),
                unit: _unitCtrl.text.trim().isEmpty
                    ? 'und'
                    : _unitCtrl.text.trim(),
                quantity: qty,
                unitCostCop: unitCost,
                notes: _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim(),
              ),
            );
          },
          child: Text(isEn ? 'Add Item' : 'Agregar'),
        ),
      ],
    );
  }
}

/// Dialog to log an actual executed expense linked to a BOQ item or phase.
Future<ActualExpenseRecord?> showAddActualExpenseDialog({
  required BuildContext context,
  required List<MaterialItem> availableItems,
  required bool isEn,
}) {
  return showDialog<ActualExpenseRecord>(
    context: context,
    builder: (_) => _AddActualExpenseDialog(
      availableItems: availableItems,
      isEn: isEn,
    ),
  );
}

class _AddActualExpenseDialog extends StatefulWidget {
  final List<MaterialItem> availableItems;
  final bool isEn;

  const _AddActualExpenseDialog({
    required this.availableItems,
    required this.isEn,
  });

  @override
  State<_AddActualExpenseDialog> createState() =>
      _AddActualExpenseDialogState();
}

class _AddActualExpenseDialogState extends State<_AddActualExpenseDialog> {
  final _labelCtrl = TextEditingController();
  late final TextEditingController _phaseCtrl;
  final _amountCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  String? _selectedItemId;
  var _selectedStatus = ExpenseStatus.paid;
  var _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _phaseCtrl = TextEditingController(
      text: widget.isEn ? 'General Work' : 'Obra General',
    );
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _phaseCtrl.dispose();
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isEn = widget.isEn;
    return AlertDialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      title: Text(
        isEn
            ? 'Log Actual Expense (COP)'
            : 'Registrar Gasto Real de Obra (COP)',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.availableItems.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedItemId,
                  isExpanded: true,
                  dropdownColor: colors.panelBg,
                  style: TextStyle(color: colors.textPrimary, fontSize: 11.5),
                  decoration: InputDecoration(
                    labelText: isEn
                        ? 'Link to BOQ Item (optional)'
                        : 'Vincular a Partida BOQ (opcional)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        isEn
                            ? 'Manual / Free item'
                            : 'Partida libre / general',
                      ),
                    ),
                    ...widget.availableItems.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedItemId = val;
                      if (val != null) {
                        final matched = widget.availableItems.firstWhere(
                          (i) => i.id == val,
                        );
                        if (_labelCtrl.text.trim().isEmpty) {
                          _labelCtrl.text = matched.name;
                        }
                        _phaseCtrl.text = matched.categoryLabel;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                key: const Key('expense_label_input'),
                controller: _labelCtrl,
                style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: isEn ? 'Expense Concept' : 'Concepto / Partida',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('expense_amount_input'),
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style:
                          TextStyle(color: colors.textPrimary, fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: isEn ? 'Amount (COP)' : 'Monto (COP)',
                        prefixText: '\$ ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<ExpenseStatus>(
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      dropdownColor: colors.panelBg,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: isEn ? 'Status' : 'Estado',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ExpenseStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label(isEn ? 'en' : 'es')),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedStatus = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phaseCtrl,
                style: TextStyle(color: colors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  labelText: isEn ? 'Phase / Trade' : 'Fase / Capítulo',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('expense_vendor_input'),
                controller: _vendorCtrl,
                style: TextStyle(color: colors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  labelText: isEn
                      ? 'Vendor / Receipt Note'
                      : 'Proveedor / Nota / Factura',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${isEn ? 'Date' : 'Fecha'}: ${_selectedDate.toIso8601String().split('T').first}',
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 11.5),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Text(isEn ? 'Change Date' : 'Cambiar fecha'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isEn ? 'Cancel' : 'Cancelar'),
        ),
        ElevatedButton(
          key: const Key('save_expense_button'),
          onPressed: () {
            final label = _labelCtrl.text.trim();
            final amount = _parseCopNumber(_amountCtrl.text) ?? 0;
            if (label.isEmpty || amount <= 0) return;
            Navigator.of(context).pop(
              ActualExpenseRecord(
                id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
                linkedItemId: _selectedItemId,
                linkedLabel: label,
                phaseName: _phaseCtrl.text.trim().isEmpty
                    ? 'Obra General'
                    : _phaseCtrl.text.trim(),
                amountCop: amount,
                date: _selectedDate,
                vendorOrNote: _vendorCtrl.text.trim(),
                status: _selectedStatus,
              ),
            );
          },
          child: Text(isEn ? 'Save Expense' : 'Guardar Gasto'),
        ),
      ],
    );
  }
}
