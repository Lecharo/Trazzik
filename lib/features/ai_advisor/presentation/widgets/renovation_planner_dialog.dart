import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/core/utils/file_export_helper.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_budget_config.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
import 'package:trazzik/features/ai_advisor/presentation/services/renovation_plan_pdf_service.dart';
import 'package:trazzik/features/ai_advisor/presentation/widgets/renovation_budget_forms.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/fee_proposal/presentation/services/architect_fee_proposal_pdf_service.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';

class RenovationPlannerDialog extends ConsumerStatefulWidget {
  const RenovationPlannerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const RenovationPlannerDialog(),
    );
  }

  @override
  ConsumerState<RenovationPlannerDialog> createState() =>
      _RenovationPlannerDialogState();
}

class _RenovationPlannerDialogState
    extends ConsumerState<RenovationPlannerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();

  bool _allHouseScope = true; // Toda la casa vs solo piso actual
  bool _renovateFloors = true;
  bool _renovateBathrooms = true;
  bool _renovateKitchen = true;
  bool _renovateWallsPaint = false;
  bool _renovateLighting = false;
  bool _isParallelMode = true;
  bool _isExportingPdf = false;
  bool _showCopiedBadge = false;
  bool _showCsvCopiedBadge = false;
  bool _showGranularSettings = false;

  Set<String> _roomsForFloors = {};
  Set<String> _roomsForPaint = {};
  Set<String> _roomsForLighting = {};
  Set<String> _selectedBathroomIds = {};
  Set<String> _forcedHalfBathroomIds = {};

  late RenovationPlanResult _plan;
  late RenovationBudgetConfig _budgetConfig;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _budgetConfig =
        ref.read(floorEditorProvider).project?.renovationBudgetConfig ??
            const RenovationBudgetConfig();
    _recalculate();
  }

  void _updateBudgetConfig(RenovationBudgetConfig next) {
    ref.read(floorEditorProvider.notifier).updateRenovationBudgetConfig(next);
    setState(() {
      _budgetConfig = next;
      _recalculate();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  List<Floor> _getSourceFloors() {
    final state = ref.read(floorEditorProvider);
    if (_allHouseScope && state.allFloors.isNotEmpty) {
      return state.allFloors;
    }
    return [state.floor];
  }

  List<Module> _getSourceModules() {
    return _getSourceFloors().expand((f) => f.modules).toList();
  }

  Set<String> _resolveScopedModuleIds(List<Module> sourceModules) {
    final ids = <String>{};
    if (_renovateFloors) {
      if (_roomsForFloors.isNotEmpty) {
        ids.addAll(_roomsForFloors);
      } else {
        ids.addAll(sourceModules.map((m) => m.id));
      }
    }
    if (_renovateBathrooms) {
      if (_selectedBathroomIds.isNotEmpty) {
        ids.addAll(_selectedBathroomIds);
      } else {
        ids.addAll(sourceModules.where((m) => m.isBathroom).map((m) => m.id));
      }
    }
    if (_renovateKitchen) {
      ids.addAll(sourceModules.where((m) => m.isKitchen).map((m) => m.id));
    }
    if (_renovateWallsPaint) {
      if (_roomsForPaint.isNotEmpty) {
        ids.addAll(_roomsForPaint);
      } else {
        ids.addAll(sourceModules.map((m) => m.id));
      }
    }
    if (_renovateLighting) {
      if (_roomsForLighting.isNotEmpty) {
        ids.addAll(_roomsForLighting);
      } else {
        ids.addAll(sourceModules.map((m) => m.id));
      }
    }
    return ids;
  }

  void _recalculate() {
    final sourceFloors = _getSourceFloors();
    final sourceModules = sourceFloors.expand((f) => f.modules).toList();
    final scopedIds = _resolveScopedModuleIds(sourceModules);
    final activeFloorHeight = ref.read(floorEditorProvider).floor.heightMeters;

    final config = RenovationPlanConfig(
      renovateFloors: _renovateFloors,
      renovateBathrooms: _renovateBathrooms,
      renovateKitchen: _renovateKitchen,
      renovateWallsPaint: _renovateWallsPaint,
      renovateLighting: _renovateLighting,
      roomsForFloors: _roomsForFloors,
      roomsForPaint: _roomsForPaint,
      roomsForLighting: _roomsForLighting,
      selectedBathroomIds: _selectedBathroomIds,
      forcedHalfBathroomIds: _forcedHalfBathroomIds,
      userPrompt: _promptController.text.trim().isNotEmpty ? _promptController.text.trim() : null,
    );

    _plan = RenovationPlannerEngine.generatePlan(
      allRooms: sourceModules,
      floors: sourceFloors,
      floorHeightMeters: activeFloorHeight,
      budgetConfig: _budgetConfig,
      selectedModuleIds: scopedIds.isEmpty ? null : scopedIds,
      config: config,
    );
  }

  void _applyPromptInstructions() {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    final sourceModules = _getSourceModules();
    final parsed = RenovationPlannerEngine.parsePromptInstructions(
      prompt: text,
      allRooms: sourceModules,
    );

    setState(() {
      _renovateFloors = parsed.renovateFloors;
      _renovateBathrooms = parsed.renovateBathrooms;
      _renovateKitchen = parsed.renovateKitchen;
      _renovateWallsPaint = parsed.renovateWallsPaint;
      _renovateLighting = parsed.renovateLighting;
      _roomsForFloors = parsed.roomsForFloors;
      _roomsForPaint = parsed.roomsForPaint;
      _roomsForLighting = parsed.roomsForLighting;
      _selectedBathroomIds = parsed.selectedBathroomIds;
      _forcedHalfBathroomIds = parsed.forcedHalfBathroomIds;
      _recalculate();
    });

    final isEn = ref.read(appLocaleProvider) == 'en';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00E5FF),
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF0A192F), size: 18),
            const SizedBox(width: 8),
            Text(
              isEn
                  ? 'Instructions parsed and plan recalculated from the floor plan!'
                  : '¡Instrucciones procesadas y plan recalculado según el plano!',
              style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final isEn = ref.read(appLocaleProvider) == 'en';
    setState(() => _isExportingPdf = true);
    try {
      final state = ref.read(floorEditorProvider);
      final projectName = state.project?.name ?? 'Vivienda';
      final scopeName = _allHouseScope
          ? (isEn
              ? 'Whole House (${state.allFloors.length} floors)'
              : 'Toda la Casa (${state.allFloors.length} pisos)')
          : state.floor.name;

      await RenovationPlanPdfService.exportAndSharePdf(
        context: context,
        plan: _plan,
        projectName: projectName,
        scopeName: scopeName,
        isParallelMode: _isParallelMode,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              isEn ? 'Error generating PDF: $e' : 'Error al generar PDF: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  void _copyShoppingListToClipboard() {
    final isEn = ref.read(appLocaleProvider) == 'en';
    final buffer = StringBuffer();
    buffer.writeln(isEn
        ? 'SHOPPING & MATERIALS PLAN - TRAZZIK'
        : 'PLAN DE COMPRAS Y MATERIALES - TRAZZIK');
    buffer.writeln(
      '${isEn ? 'Total intervened area' : 'Área total a intervenir'}: ${_plan.totalRenovatedArea.toStringAsFixed(2)} m²',
    );
    final bathSummary = _plan.halfBathroomCount > 0
        ? (isEn
            ? '${_plan.fullBathroomCount} full baths + ${_plan.halfBathroomCount} half bath'
            : '${_plan.fullBathroomCount} baños completos + ${_plan.halfBathroomCount} medio baño')
        : '${_plan.bathroomCount} ${isEn ? 'bathrooms' : 'baños'}';
    buffer.writeln('${isEn ? 'Bathrooms' : 'Baños a remodelar'}: $bathSummary');
    buffer.writeln('------------------------------------------');
    for (final mat in _plan.materials) {
      final packaging = mat.packagingDetail != null ? ' (${mat.packagingDetail})' : '';
      final destination = mat.targetRoomNames.isNotEmpty
          ? ' [${isEn ? 'Target' : 'Destino'}: ${mat.targetRoomNames.join(', ')}]'
          : '';
      buffer.writeln('• ${mat.name}: ${mat.quantity.toStringAsFixed(mat.quantity % 1 == 0 ? 0 : 2)} ${mat.unit}$packaging$destination');
      buffer.writeln('  ${isEn ? 'Yield' : 'Rendimiento'}: ${mat.yieldFormula}');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln(isEn ? 'Estimated execution timeline:' : 'Tiempo estimado de ejecución:');
    buffer.writeln(
      '• ${isEn ? 'Parallel crews' : 'Cuadrillas en paralelo'}: ${_plan.totalParallelDays} ${isEn ? 'business days' : 'días hábiles'}.',
    );
    buffer.writeln(
      '• ${isEn ? 'Sequential crew' : 'Cuadrilla secuencial'}: ${_plan.totalSequentialDays} ${isEn ? 'business days' : 'días hábiles'}.',
    );

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    setState(() => _showCopiedBadge = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showCopiedBadge = false);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2E7D32),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              isEn
                  ? 'Room-traceable shopping list copied!'
                  : '¡Lista de compras con trazabilidad por recinto copiada!',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsvToClipboard() async {
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(floorEditorProvider);
    final lang = ref.read(appLocaleProvider);
    final isEn = lang == 'en';
    final projectName = state.project?.name ?? 'Vivienda Trazzik';
    final sourceModules = _getSourceModules();
    final scopedIds = _resolveScopedModuleIds(sourceModules);
    final csv = RenovationPlannerEngine.exportPlanToCsv(
      plan: _plan,
      rooms: sourceModules,
      includedRoomIds: scopedIds.isEmpty ? null : scopedIds,
      projectName: projectName,
      lang: lang,
      parallelMode: _isParallelMode,
    );
    final safeName = projectName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();
    final result = await exportTextFile(
      fileName: 'trazzik_boq_$safeName.csv',
      content: csv,
      mimeType: 'text/csv;charset=utf-8',
    );

    if (mounted) {
      setState(() => _showCsvCopiedBadge = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showCsvCopiedBadge = false);
        }
      });
    }

    final desc = result.savedPath != null
        ? (isEn
            ? 'BOQ (.CSV) saved to ${result.savedPath} and copied!'
            : '¡Cómputo BOQ (.CSV) guardado en ${result.savedPath} y copiado!')
        : (result.downloaded
            ? (isEn
                ? 'BOQ & Finish Schedule (.CSV) downloaded!'
                : '¡Cómputo BOQ y Cuadro de Acabados (.CSV) descargado!')
            : (isEn
                ? 'BOQ & Finish Schedule (.CSV) copied!'
                : '¡Cómputo BOQ y Cuadro de Acabados (.CSV) copiado!'));
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF0F766E),
        content: Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(desc)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lang = ref.watch(appLocaleProvider);
    final isEn = lang == 'en';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Dialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.accent, width: 1.2),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.tune_rounded, color: colors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? 'AI WORK PLANNER, MATERIALS (BOQ) & CREWS'
                              : 'PLANIFICADOR DE OBRA, MATERIALES Y CUADRILLA IA',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEn
                              ? 'Room-by-room material takeoff with technical waste, crews, and critical path'
                              : 'Cómputo métrico por recinto con desperdicio técnico, especialistas y ruta crítica',
                          style: TextStyle(color: colors.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Campo de Instrucciones en Lenguaje Natural a la IA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colors.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        style: TextStyle(color: colors.textPrimary, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: isEn
                              ? 'AI scope prompt: e.g., floors only in living, half bath without shower, LED lights...'
                              : 'Indicaciones a la IA: ej. pisos solo en sala, medio baño sin ducha, luces led...',
                          hintStyle: TextStyle(color: colors.textMuted, fontSize: 10.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        onSubmitted: (_) => _applyPromptInstructions(),
                      ),
                    ),
                    InkWell(
                      onTap: _applyPromptInstructions,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isEn ? 'Parse' : 'Interpretar',
                              style: TextStyle(color: colors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, color: colors.accent, size: 9),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Barra de Configuración de Alcance y Filtros Rápidos
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Alcance
                    ChoiceChip(
                      avatar: const Icon(Icons.home, size: 13),
                      label: Text(isEn ? 'Whole House' : 'Toda la Casa', style: const TextStyle(fontSize: 10)),
                      selected: _allHouseScope,
                      selectedColor: colors.accent.withValues(alpha: 0.25),
                      onSelected: (val) {
                        setState(() {
                          _allHouseScope = true;
                          _recalculate();
                        });
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.layers, size: 13),
                      label: Text(isEn ? 'This Floor Only' : 'Solo Este Piso', style: const TextStyle(fontSize: 10)),
                      selected: !_allHouseScope,
                      selectedColor: colors.accent.withValues(alpha: 0.25),
                      onSelected: (val) {
                        setState(() {
                          _allHouseScope = false;
                          _recalculate();
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    // Filtros de partida
                    FilterChip(
                      label: Text(isEn ? 'Floors' : 'Pisos', style: const TextStyle(fontSize: 10)),
                      selected: _renovateFloors,
                      selectedColor: colors.success.withValues(alpha: 0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateFloors = v;
                          _recalculate();
                        });
                      },
                    ),
                    FilterChip(
                      label: Text(isEn ? 'Bathrooms' : 'Baños', style: const TextStyle(fontSize: 10)),
                      selected: _renovateBathrooms,
                      selectedColor: const Color(0xFF29B6F6).withValues(alpha: 0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateBathrooms = v;
                          _recalculate();
                        });
                      },
                    ),
                    FilterChip(
                      label: Text(isEn ? 'Kitchen' : 'Cocina', style: const TextStyle(fontSize: 10)),
                      selected: _renovateKitchen,
                      selectedColor: colors.warning.withValues(alpha: 0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateKitchen = v;
                          _recalculate();
                        });
                      },
                    ),
                    FilterChip(
                      label: Text(isEn ? 'Paint' : 'Pintura', style: const TextStyle(fontSize: 10)),
                      selected: _renovateWallsPaint,
                      selectedColor: const Color(0xFFAB47BC).withValues(alpha: 0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateWallsPaint = v;
                          _recalculate();
                        });
                      },
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 12),
                      label: Text(isEn ? 'LED Lights' : 'Luces LED', style: const TextStyle(fontSize: 10)),
                      selected: _renovateLighting,
                      selectedColor: const Color(0xFFFFD54F).withValues(alpha: 0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateLighting = v;
                          _recalculate();
                        });
                      },
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _showGranularSettings = !_showGranularSettings);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showGranularSettings
                              ? colors.accent.withValues(alpha: 0.2)
                              : colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _showGranularSettings ? colors.accent : colors.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showGranularSettings ? Icons.expand_less : Icons.room_preferences,
                              color: _showGranularSettings ? colors.accent : colors.textSecondary,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isEn ? 'Customize Rooms' : 'Personalizar Recintos',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: _showGranularSettings ? colors.accent : colors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Panel Desplegable de Configuración Granular por Recinto
              if (_showGranularSettings) ...[
                const SizedBox(height: 6),
                _buildGranularSettingsPanel(colors, isEn),
              ],

              const SizedBox(height: 6),

              // Tarjeta Resumen KPI Adaptativa
              _buildResponsiveKpiCard(colors, isEn),
              const SizedBox(height: 6),

              // Pestañas
              TabBar(
                controller: _tabController,
                indicatorColor: colors.accent,
                labelColor: colors.accent,
                unselectedLabelColor: colors.textMuted,
                isScrollable: isMobile,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.shopping_cart_outlined, size: 15),
                    text: '${isEn ? 'Materials' : 'Materiales'} (${_plan.materials.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.engineering_outlined, size: 15),
                    text: '${isEn ? 'Crews' : 'Cuadrilla'} (${_isParallelMode ? _plan.parallelCrews.length : _plan.sequentialCrews.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.timeline_outlined, size: 15),
                    text: '${isEn ? 'Schedule' : 'Cronograma'} (${_plan.phases.length})',
                  ),
                  Tab(
                    key: const Key('tab_expenses'),
                    icon: const Icon(Icons.receipt_long_outlined, size: 15),
                    text: '${isEn ? 'Expenses' : 'Gastos'} (${_plan.expenses.length})',
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Contenido de Pestañas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMaterialsTab(colors, isEn),
                    _buildCrewsTab(colors, isEn),
                    _buildScheduleTab(colors, isLight, isEn),
                    _buildExpensesTab(colors, isEn),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Footer con Exportar PDF, Copiar y Cerrar
              _buildResponsiveFooter(colors, isLight, isEn),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGranularSettingsPanel(AppColors colors, bool isEn) {
    final modules = _getSourceModules().where((m) => !m.isOpening).toList();

    final bathrooms = modules.where((m) => m.isBathroom).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bathrooms.isNotEmpty) ...[
              Text(
                isEn
                    ? 'BATHROOM TYPE (FULL BATH VS GUEST HALF-BATH):'
                    : 'TIPO DE BAÑOS (DIFERENCIAR BAÑO COMPLETO VS MEDIO BAÑO SOCIAL):',
                style: TextStyle(color: colors.accent, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: bathrooms.map((b) {
                  final isHalf = RenovationPlannerEngine.isHalfBathroom(b, forcedHalfBathroomIds: _forcedHalfBathroomIds);
                  final badgeColor = isHalf ? colors.warning : colors.accent;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isHalf) {
                          _forcedHalfBathroomIds.remove(b.id);
                        } else {
                          _forcedHalfBathroomIds.add(b.id);
                        }
                        _recalculate();
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHalf ? Icons.wc : Icons.shower,
                            size: 13,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${b.name}: ${isHalf ? (isEn ? "Half Bath (No shower)" : "Medio Baño (Sin ducha)") : (isEn ? "Full (With shower)" : "Completo (Con ducha)")}',
                            style: TextStyle(
                              fontSize: 9.2,
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              isEn
                  ? 'ROOMS SELECTED FOR FLOORING / PAINT / LIGHTING:'
                  : 'RECINTOS SELECCIONADOS PARA PISOS / PINTURA / LUCES:',
              style: TextStyle(color: colors.accent, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: modules.map((m) {
                final hasFloors = _roomsForFloors.isEmpty || _roomsForFloors.contains(m.id);
                return FilterChip(
                  label: Text('${m.name} (${m.area.toStringAsFixed(1)}m²)', style: const TextStyle(fontSize: 9)),
                  selected: hasFloors,
                  selectedColor: colors.success.withValues(alpha: 0.25),
                  onSelected: (selected) {
                    setState(() {
                      final allIds = modules.map((r) => r.id).toSet();
                      if (_roomsForFloors.isEmpty) {
                        _roomsForFloors = Set<String>.from(allIds);
                      }
                      if (_roomsForPaint.isEmpty) {
                        _roomsForPaint = Set<String>.from(allIds);
                      }
                      if (_roomsForLighting.isEmpty) {
                        _roomsForLighting = Set<String>.from(allIds);
                      }
                      if (selected) {
                        _roomsForFloors.add(m.id);
                        _roomsForPaint.add(m.id);
                        _roomsForLighting.add(m.id);
                      } else {
                        _roomsForFloors.remove(m.id);
                        _roomsForPaint.remove(m.id);
                        _roomsForLighting.remove(m.id);
                      }
                      _recalculate();
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveKpiCard(AppColors colors, bool isEn) {
    final bathSummary = _plan.halfBathroomCount > 0
        ? (isEn
            ? '${_plan.fullBathroomCount} full + ${_plan.halfBathroomCount} half bath'
            : '${_plan.fullBathroomCount} completo(s) + ${_plan.halfBathroomCount} medio baño')
        : '${_plan.bathroomCount} ${isEn ? 'bathrooms' : 'baños'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.12),
            colors.cardBg,
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;

          final kpiInfo = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    '${_plan.totalRenovatedArea.toStringAsFixed(2)} m²',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '(${_plan.selectedRoomNames.length} ${isEn ? 'rooms' : 'recintos'} | $bathSummary)',
                    style: TextStyle(color: colors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _isParallelMode
                    ? (isEn
                        ? '⚡ Accelerated Mode: ${_plan.totalParallelDays} days (${_plan.daysSaved}d saved / ${_plan.timeReductionPercent.toStringAsFixed(0)}% faster)'
                        : '⚡ Modo Acelerado: ${_plan.totalParallelDays} días (${_plan.daysSaved} d de ahorro / ${_plan.timeReductionPercent.toStringAsFixed(0)}% más rápido)')
                    : (isEn
                        ? '⏳ Sequential Mode: ${_plan.totalSequentialDays} days with 1 crew'
                        : '⏳ Modo Secuencial: ${_plan.totalSequentialDays} días con 1 sola cuadrilla'),
                style: TextStyle(
                  color: _isParallelMode ? colors.success : colors.warning,
                  fontSize: 10.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );

          final toggleButton = Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(
              color: colors.panelBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isParallelMode = false),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_isParallelMode ? colors.warning.withValues(alpha: 0.22) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isEn ? '1 Crew' : '1 Cuadrilla',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: !_isParallelMode ? FontWeight.bold : FontWeight.normal,
                        color: !_isParallelMode ? colors.warning : colors.textMuted,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isParallelMode = true),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isParallelMode ? colors.accent.withValues(alpha: 0.22) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isEn ? 'Parallel ⚡' : 'Paralelo ⚡',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: _isParallelMode ? FontWeight.bold : FontWeight.normal,
                        color: _isParallelMode ? colors.accent : colors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kpiInfo,
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: toggleButton),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(child: kpiInfo),
                const SizedBox(width: 8),
                toggleButton,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildResponsiveFooter(AppColors colors, bool isLight, bool isEn) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: isLight ? Colors.white : const Color(0xFF0A192F),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              icon: _isExportingPdf
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isLight ? Colors.white : const Color(0xFF0A192F),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text(
                _isExportingPdf
                    ? (isEn ? 'Generating...' : 'Generando...')
                    : (isEn ? 'Download Plan PDF' : 'Descargar Plan PDF'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: _isExportingPdf ? null : _exportPdf,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _showCopiedBadge ? colors.success : colors.accent,
                  width: 1.1,
                ),
                foregroundColor: colors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              icon: Icon(
                _showCopiedBadge ? Icons.check : Icons.copy_rounded,
                size: 15,
                color: _showCopiedBadge ? colors.success : colors.accent,
              ),
              label: Text(
                _showCopiedBadge
                    ? (isEn ? 'Copied!' : '¡Copiado!')
                    : (isEn ? 'Copy List' : 'Copiar Lista'),
                style: TextStyle(
                  color: _showCopiedBadge ? colors.success : colors.textPrimary,
                  fontSize: 11,
                ),
              ),
              onPressed: _copyShoppingListToClipboard,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _showCsvCopiedBadge ? colors.success : colors.accent,
                  width: 1.1,
                ),
                foregroundColor: colors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              icon: Icon(
                _showCsvCopiedBadge ? Icons.check : Icons.table_chart_outlined,
                size: 15,
                color: _showCsvCopiedBadge ? colors.success : colors.accent,
              ),
              label: Text(
                _showCsvCopiedBadge
                    ? (isEn ? 'CSV Copied!' : '¡CSV Copiado!')
                    : (isEn ? 'Export .CSV' : 'Exportar .CSV'),
                style: TextStyle(
                  color: _showCsvCopiedBadge ? colors.success : colors.textPrimary,
                  fontSize: 11,
                ),
              ),
              onPressed: _exportCsvToClipboard,
            ),
          ],
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: colors.surfaceSubtle,
            foregroundColor: colors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isEn ? 'Close' : 'Cerrar', style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  String _fmtCop(double amount) =>
      '${ArchitectFeeProposalPdfService.formatCop(amount)} COP';

  Future<void> _onEditUnitPrice(MaterialItem mat, bool isEn) async {
    final defaultPrice = RenovationPlannerEngine.defaultUnitPricesCop[mat.id];
    final res = await showEditUnitPriceDialog(
      context: context,
      item: mat,
      defaultPriceCop: defaultPrice,
      isEn: isEn,
    );
    if (res == null) return;
    if (mat.isCustom) {
      if (res.priceCop == null) return;
      final updatedCustom = _budgetConfig.customItems
          .map(
            (c) => c.id == mat.id ? c.copyWith(unitCostCop: res.priceCop) : c,
          )
          .toList();
      _updateBudgetConfig(_budgetConfig.copyWith(customItems: updatedCustom));
      return;
    }
    final nextOverrides = Map<String, double>.from(
      _budgetConfig.unitPriceOverridesCop,
    );
    if (res.resetToDefault) {
      nextOverrides.remove(mat.id);
    } else if (res.priceCop != null) {
      nextOverrides[mat.id] = res.priceCop!;
    }
    _updateBudgetConfig(
      _budgetConfig.copyWith(unitPriceOverridesCop: nextOverrides),
    );
  }

  Future<void> _onAddCustomItem(bool isEn) async {
    final created = await showAddCustomBudgetItemDialog(
      context: context,
      isEn: isEn,
    );
    if (created == null) return;
    _updateBudgetConfig(
      _budgetConfig.copyWith(
        customItems: [..._budgetConfig.customItems, created],
      ),
    );
  }

  void _onDeleteCustomItem(String id) {
    _updateBudgetConfig(
      _budgetConfig.copyWith(
        customItems:
            _budgetConfig.customItems.where((c) => c.id != id).toList(),
      ),
    );
  }

  Future<void> _onEditCrewRate(SpecialistCrew crew, bool isEn) async {
    if (crew.roleKey.isEmpty) return;
    final newRate = await showEditCrewRateDialog(
      context: context,
      crew: crew,
      isEn: isEn,
    );
    if (newRate == null) return;
    final nextRates = Map<String, double>.from(_budgetConfig.crewDailyRatesCop);
    nextRates[crew.roleKey] = newRate;
    _updateBudgetConfig(_budgetConfig.copyWith(crewDailyRatesCop: nextRates));
  }

  Future<void> _onAddExpense(bool isEn) async {
    final created = await showAddActualExpenseDialog(
      context: context,
      availableItems: _plan.materials,
      isEn: isEn,
    );
    if (created == null) return;
    _updateBudgetConfig(
      _budgetConfig.copyWith(
        expenses: [created, ..._budgetConfig.expenses],
      ),
    );
  }

  void _onCycleExpenseStatus(ActualExpenseRecord record) {
    final nextIdx = (record.status.index + 1) % ExpenseStatus.values.length;
    final nextStatus = ExpenseStatus.values[nextIdx];
    final updated = _budgetConfig.expenses
        .map((e) => e.id == record.id ? e.copyWith(status: nextStatus) : e)
        .toList();
    _updateBudgetConfig(_budgetConfig.copyWith(expenses: updated));
  }

  void _onDeleteExpense(String id) {
    _updateBudgetConfig(
      _budgetConfig.copyWith(
        expenses: _budgetConfig.expenses.where((e) => e.id != id).toList(),
      ),
    );
  }

  Widget _buildMaterialsTab(AppColors colors, bool isEn) {
    final laborCost = _isParallelMode
        ? _plan.totalParallelLaborCostCop
        : _plan.totalSequentialLaborCostCop;
    final grandTotal = _plan.totalBudgetCop(parallelMode: _isParallelMode);

    return Column(
      children: [
        Container(
          key: const Key('budget_cop_summary_banner'),
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.accent.withValues(alpha: 0.45)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEn ? 'Materials & Items' : 'Materiales y Partidas',
                    style: TextStyle(color: colors.textMuted, fontSize: 9.5),
                  ),
                  Text(
                    _fmtCop(_plan.totalMaterialsCostCop),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEn ? 'Labor (Crews)' : 'Mano de Obra',
                    style: TextStyle(color: colors.textMuted, fontSize: 9.5),
                  ),
                  Text(
                    _fmtCop(laborCost),
                    style: TextStyle(
                      color: colors.success,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEn ? 'Estimated Total' : 'Total General Obra',
                    style: TextStyle(color: colors.textMuted, fontSize: 9.5),
                  ),
                  Text(
                    _fmtCop(grandTotal),
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const Key('add_custom_item_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.accent.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _onAddCustomItem(isEn),
                icon: const Icon(Icons.add_circle_outline, size: 15),
                label: Text(
                  isEn ? 'Custom Item' : '+ Partida Manual',
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _plan.materials.isEmpty
              ? Center(
                  child: Text(
                    isEn
                        ? 'No material items for the selected filters.'
                        : 'No hay partidas de materiales para los filtros seleccionados.',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _plan.materials.length,
                  itemBuilder: (context, idx) {
                    final mat = _plan.materials[idx];
                    final isOverridden =
                        _budgetConfig.unitPriceOverridesCop.containsKey(mat.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOverridden || mat.isCustom
                              ? colors.accent.withValues(alpha: 0.45)
                              : colors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(mat.icon, color: colors.accent, size: 16),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        mat.name,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.accent.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${mat.quantity.toStringAsFixed(mat.quantity % 1 == 0 ? 0 : 2)} ${mat.unit}',
                                        style: TextStyle(
                                          color: colors.accent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 2,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            mat.estimatedUnitCostCop != null
                                                ? '${ArchitectFeeProposalPdfService.formatCop(mat.estimatedUnitCostCop!)} / ${mat.unit}'
                                                : (isEn
                                                    ? 'Unit price: N/A'
                                                    : 'V. Unit: N/A'),
                                            style: TextStyle(
                                              color: isOverridden
                                                  ? colors.warning
                                                  : colors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (mat.estimatedTotalCostCop != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colors.success
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _fmtCop(
                                                  mat.estimatedTotalCostCop!,
                                                ),
                                                style: TextStyle(
                                                  color: colors.success,
                                                  fontSize: 10.2,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      key: Key('edit_price_${mat.id}'),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 26,
                                        minHeight: 26,
                                      ),
                                      tooltip: isEn
                                          ? 'Edit unit price COP'
                                          : 'Editar tarifa COP',
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 15,
                                        color: colors.accent,
                                      ),
                                      onPressed: () =>
                                          _onEditUnitPrice(mat, isEn),
                                    ),
                                    if (mat.isCustom)
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 26,
                                          minHeight: 26,
                                        ),
                                        tooltip:
                                            isEn ? 'Delete item' : 'Eliminar partida',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 15,
                                          color: Color(0xFFEF5350),
                                        ),
                                        onPressed: () =>
                                            _onDeleteCustomItem(mat.id),
                                      ),
                                  ],
                                ),
                                if (mat.targetRoomNames.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.place_outlined,
                                        color: colors.accent,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          '${isEn ? 'Target' : 'Destino'}: ${mat.targetRoomNames.join(', ')}',
                                          style: TextStyle(
                                            color: colors.accent,
                                            fontSize: 9.8,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (mat.packagingDetail != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${isEn ? 'Detail' : 'Presentación'}: ${mat.packagingDetail}',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 9.6,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  '• ${mat.yieldFormula}',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 9.6,
                                  ),
                                ),
                                if (mat.purchaseTip != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '💡 ${isEn ? 'Tip' : 'Tip técnico'}: ${mat.purchaseTip}',
                                    style: TextStyle(
                                      color: colors.warning,
                                      fontSize: 9.4,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCrewsTab(AppColors colors, bool isEn) {
    final crews = _isParallelMode ? _plan.parallelCrews : _plan.sequentialCrews;
    final totalLabor = _isParallelMode
        ? _plan.totalParallelLaborCostCop
        : _plan.totalSequentialLaborCostCop;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.success.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn
                    ? 'Total Estimated Labor (days × workers × daily rate)'
                    : 'Total Mano de Obra (días × operarios × tarifa diaria)',
                style: TextStyle(color: colors.textSecondary, fontSize: 10.5),
              ),
              Text(
                _fmtCop(totalLabor),
                style: TextStyle(
                  color: colors.success,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: crews.length,
            itemBuilder: (context, idx) {
              final crew = crews[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(crew.icon, color: colors.success, size: 18),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  crew.roleName,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.success.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${crew.headcount} op. • ${crew.estimatedDays} d',
                                  style: TextStyle(
                                    color: colors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${ArchitectFeeProposalPdfService.formatCop(crew.dailyRateCop)} / ${isEn ? 'day' : 'día'}  →  ${_fmtCop(crew.totalLaborCostCop)}',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (crew.roleKey.isNotEmpty)
                                IconButton(
                                  key: Key('edit_crew_${crew.roleKey}'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  tooltip: isEn
                                      ? 'Edit daily wage COP'
                                      : 'Editar tarifa diaria COP',
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 15,
                                    color: colors.accent,
                                  ),
                                  onPressed: () => _onEditCrewRate(crew, isEn),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            crew.scopeDescription,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          if (crew.equipmentNeeded.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '🛠️ ${isEn ? 'Tools' : 'Herramientas'}: ${crew.equipmentNeeded.join(', ')}',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 9.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesTab(AppColors colors, bool isEn) {
    final budgeted = _plan.totalBudgetCop(parallelMode: _isParallelMode);
    final executed = _plan.totalExecutedCop;
    final inProgress = _plan.totalInProgressCop;
    final balance = _plan.remainingBalanceCop(parallelMode: _isParallelMode);
    final ratio = budgeted > 0 ? (executed / budgeted).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Container(
          key: const Key('expenses_summary_card'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.accent.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Budgeted' : 'Presupuestado',
                        style: TextStyle(color: colors.textMuted, fontSize: 9.5),
                      ),
                      Text(
                        _fmtCop(budgeted),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Executed (Paid)' : 'Ejecutado (Pagado)',
                        style: TextStyle(color: colors.textMuted, fontSize: 9.5),
                      ),
                      Text(
                        _fmtCop(executed),
                        style: TextStyle(
                          color: colors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Balance' : 'Saldo',
                        style: TextStyle(color: colors.textMuted, fontSize: 9.5),
                      ),
                      Text(
                        _fmtCop(balance),
                        style: TextStyle(
                          color: balance >= 0
                              ? colors.accent
                              : const Color(0xFFEF5350),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    key: const Key('add_expense_button'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _onAddExpense(isEn),
                    icon: const Icon(Icons.add, size: 15),
                    label: Text(
                      isEn ? 'Log Expense' : 'Registrar Gasto',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: colors.surfaceSubtle,
                  color: balance >= 0 ? colors.success : const Color(0xFFEF5350),
                ),
              ),
              if (inProgress > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${isEn ? 'In progress / committed' : 'En proceso / comprometido'}: ${_fmtCop(inProgress)}',
                  style: TextStyle(color: colors.warning, fontSize: 9.5),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _plan.expenses.isEmpty
              ? Center(
                  child: Text(
                    isEn
                        ? 'No expenses recorded yet. Log payments to compare Budget vs. Actual.'
                        : 'Aún no hay gastos registrados. Registra pagos o anticipos para controlar Presupuestado vs. Ejecutado.',
                    style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _plan.expenses.length,
                  itemBuilder: (context, idx) {
                    final exp = _plan.expenses[idx];
                    final statusColor = switch (exp.status) {
                      ExpenseStatus.paid => colors.success,
                      ExpenseStatus.inProgress => colors.warning,
                      ExpenseStatus.pending => colors.textMuted,
                    };
                    final dateStr = exp.date.toIso8601String().split('T').first;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exp.linkedLabel,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${exp.phaseName} • $dateStr${exp.vendorOrNote.isNotEmpty ? ' • ${exp.vendorOrNote}' : ''}',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 9.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _fmtCop(exp.amountCop),
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              InkWell(
                                onTap: () => _onCycleExpenseStatus(exp),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Text(
                                    exp.status.label(isEn ? 'en' : 'es'),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 15,
                              color: Color(0xFFEF5350),
                            ),
                            onPressed: () => _onDeleteExpense(exp.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab(AppColors colors, bool isLight, bool isEn) {
    return ListView.builder(
      itemCount: _plan.phases.length,
      itemBuilder: (context, idx) {
        final phase = _plan.phases[idx];
        final days = _isParallelMode ? phase.estimatedDaysParallel : phase.estimatedDaysSequential;

        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: phase.canParallelize && _isParallelMode
                  ? colors.accent.withValues(alpha: 0.35)
                  : colors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: colors.accent,
                    child: Text(
                      '${phase.phaseNumber}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isLight ? Colors.white : const Color(0xFF0A192F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      phase.title,
                      style: TextStyle(color: colors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$days ${isEn ? 'days' : 'días'}',
                      style: TextStyle(color: colors.accent, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                phase.description,
                style: TextStyle(color: colors.textSecondary, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.person_pin, size: 11, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${isEn ? 'Crew' : 'Ejecuta'}: ${phase.specialists.join(' + ')}',
                      style: TextStyle(color: colors.textMuted, fontSize: 9),
                    ),
                  ),
                ],
              ),
              if (phase.canParallelize) ...[
                const SizedBox(height: 2),
                Text(
                  '⚡ ${isEn ? 'Parallel' : 'Paralelo'}: ${phase.parallelTip}',
                  style: TextStyle(color: colors.success, fontSize: 9, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
