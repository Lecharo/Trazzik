import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
import 'package:trazzik/features/ai_advisor/presentation/services/renovation_plan_pdf_service.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
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
  bool _showGranularSettings = false;

  Set<String> _roomsForFloors = {};
  Set<String> _roomsForPaint = {};
  Set<String> _roomsForLighting = {};
  Set<String> _selectedBathroomIds = {};
  Set<String> _forcedHalfBathroomIds = {};

  late RenovationPlanResult _plan;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _recalculate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  List<Module> _getSourceModules() {
    final state = ref.read(floorEditorProvider);
    if (_allHouseScope && state.allFloors.isNotEmpty) {
      return state.allFloors.expand((f) => f.modules).toList();
    } else {
      return state.floor.modules;
    }
  }

  void _recalculate() {
    final sourceModules = _getSourceModules();

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF00E5FF),
        content: Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF0A192F), size: 18),
            SizedBox(width: 8),
            Text(
              '¡Instrucciones procesadas y plan recalculado según el plano!',
              style: TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final state = ref.read(floorEditorProvider);
      final projectName = state.project?.name ?? 'Vivienda';
      final scopeName = _allHouseScope
          ? 'Toda la Casa (${state.allFloors.length} pisos)'
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
            content: Text('Error al generar PDF: $e'),
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
    final buffer = StringBuffer();
    buffer.writeln('PLAN DE COMPRAS Y MATERIALES - TRAZZIK');
    buffer.writeln('Área total a intervenir: ${_plan.totalRenovatedArea.toStringAsFixed(2)} m²');
    final bathSummary = _plan.halfBathroomCount > 0
        ? '${_plan.fullBathroomCount} baños completos + ${_plan.halfBathroomCount} medio baño'
        : '${_plan.bathroomCount} baños';
    buffer.writeln('Baños a remodelar: $bathSummary');
    buffer.writeln('------------------------------------------');
    for (final mat in _plan.materials) {
      final packaging = mat.packagingDetail != null ? ' (${mat.packagingDetail})' : '';
      final destination = mat.targetRoomNames.isNotEmpty ? ' [Destino: ${mat.targetRoomNames.join(', ')}]' : '';
      buffer.writeln('• ${mat.name}: ${mat.quantity.toStringAsFixed(mat.quantity % 1 == 0 ? 0 : 2)} ${mat.unit}$packaging$destination');
      buffer.writeln('  Rendimiento: ${mat.yieldFormula}');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('Tiempo estimado de ejecución:');
    buffer.writeln('• Cuadrillas en paralelo: ${_plan.totalParallelDays} días hábiles.');
    buffer.writeln('• Cuadrilla secuencial: ${_plan.totalSequentialDays} días hábiles.');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    setState(() => _showCopiedBadge = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showCopiedBadge = false);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF2E7D32),
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('¡Lista de compras con trazabilidad por recinto copiada!'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
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
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PLANIFICADOR DE OBRA, MATERIALES Y CUADRILLA IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cómputo métrico por recinto con desperdicio técnico, especialistas y ruta crítica',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Campo de Instrucciones en Lenguaje Natural a la IA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: const InputDecoration(
                          hintText: 'Indicaciones a la IA: ej. pisos solo en sala, medio baño sin ducha, luces led...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 10.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
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
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Interpretar',
                              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, color: Color(0xFF00E5FF), size: 9),
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
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Alcance
                    ChoiceChip(
                      avatar: const Icon(Icons.home, size: 13),
                      label: const Text('Toda la Casa', style: TextStyle(fontSize: 10)),
                      selected: _allHouseScope,
                      selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                      onSelected: (val) {
                        setState(() {
                          _allHouseScope = true;
                          _recalculate();
                        });
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.layers, size: 13),
                      label: const Text('Solo Este Piso', style: TextStyle(fontSize: 10)),
                      selected: !_allHouseScope,
                      selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
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
                      label: const Text('Pisos', style: TextStyle(fontSize: 10)),
                      selected: _renovateFloors,
                      selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateFloors = v;
                          _recalculate();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Baños', style: TextStyle(fontSize: 10)),
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
                      label: const Text('Cocina', style: TextStyle(fontSize: 10)),
                      selected: _renovateKitchen,
                      selectedColor: const Color(0xFFFFB74D).withValues(alpha: 0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateKitchen = v;
                          _recalculate();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Pintura', style: TextStyle(fontSize: 10)),
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
                      label: const Text('Luces LED', style: TextStyle(fontSize: 10)),
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
                          color: _showGranularSettings ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _showGranularSettings ? const Color(0xFF00E5FF) : Colors.white24,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showGranularSettings ? Icons.expand_less : Icons.room_preferences,
                              color: _showGranularSettings ? const Color(0xFF00E5FF) : Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Personalizar Recintos',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: _showGranularSettings ? const Color(0xFF00E5FF) : Colors.white70,
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
                _buildGranularSettingsPanel(),
              ],

              const SizedBox(height: 6),

              // Tarjeta Resumen KPI Adaptativa
              _buildResponsiveKpiCard(),
              const SizedBox(height: 6),

              // Pestañas
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF00E5FF),
                labelColor: const Color(0xFF00E5FF),
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.shopping_cart_outlined, size: 15),
                    text: 'Materiales (${_plan.materials.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.engineering_outlined, size: 15),
                    text: 'Cuadrilla (${_isParallelMode ? _plan.parallelCrews.length : _plan.sequentialCrews.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.timeline_outlined, size: 15),
                    text: 'Ruta Crítica (${_plan.phases.length})',
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Contenido de Pestañas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMaterialsTab(),
                    _buildCrewsTab(),
                    _buildScheduleTab(),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Footer con Exportar PDF, Copiar y Cerrar
              _buildResponsiveFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGranularSettingsPanel() {
    final modules = _getSourceModules().where((m) => !m.isOpening).toList();

    final bathrooms = modules.where((m) =>
        m.moduleType.toUpperCase() == 'BATHROOM' ||
        m.name.toUpperCase().contains('BAÑO') ||
        m.name.toUpperCase().contains('BANO') ||
        m.name.toUpperCase().contains('TOILETTE')).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bathrooms.isNotEmpty) ...[
              const Text(
                'TIPO DE BAÑOS (DIFERENCIAR BAÑO COMPLETO VS MEDIO BAÑO SOCIAL):',
                style: TextStyle(color: Color(0xFF29B6F6), fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: bathrooms.map((b) {
                  final isHalf = RenovationPlannerEngine.isHalfBathroom(b, forcedHalfBathroomIds: _forcedHalfBathroomIds);
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
                        color: isHalf ? const Color(0xFFFFB74D).withValues(alpha: 0.2) : const Color(0xFF29B6F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isHalf ? const Color(0xFFFFB74D) : const Color(0xFF29B6F6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHalf ? Icons.wc : Icons.shower,
                            size: 13,
                            color: isHalf ? const Color(0xFFFFB74D) : const Color(0xFF29B6F6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${b.name}: ${isHalf ? "Medio Baño (Sin ducha)" : "Completo (Con ducha)"}',
                            style: TextStyle(
                              fontSize: 9.2,
                              color: isHalf ? const Color(0xFFFFB74D) : const Color(0xFF29B6F6),
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
            const Text(
              'RECINTOS SELECCIONADOS PARA PISOS / PINTURA / LUCES:',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.bold),
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
                  selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.25),
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

  Widget _buildResponsiveKpiCard() {
    final bathSummary = _plan.halfBathroomCount > 0
        ? '${_plan.fullBathroomCount} completo(s) + ${_plan.halfBathroomCount} medio baño'
        : '${_plan.bathroomCount} baños';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E5FF).withValues(alpha: 0.12),
            const Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
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
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '(${_plan.selectedRoomNames.length} recintos | $bathSummary)',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _isParallelMode
                    ? '⚡ Modo Acelerado: ${_plan.totalParallelDays} días (${_plan.daysSaved} d de ahorro / ${_plan.timeReductionPercent.toStringAsFixed(0)}% más rápido)'
                    : '⏳ Modo Secuencial: ${_plan.totalSequentialDays} días con 1 sola cuadrilla',
                style: TextStyle(
                  color: _isParallelMode ? const Color(0xFF4CAF50) : const Color(0xFFFFB74D),
                  fontSize: 10.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );

          final toggleButton = Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
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
                      color: !_isParallelMode ? const Color(0xFFFFB74D).withValues(alpha: 0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '1 Cuadrilla',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: !_isParallelMode ? FontWeight.bold : FontWeight.normal,
                        color: !_isParallelMode ? const Color(0xFFFFB74D) : Colors.white60,
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
                      color: _isParallelMode ? const Color(0xFF00E5FF).withValues(alpha: 0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Paralelo ⚡',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: _isParallelMode ? FontWeight.bold : FontWeight.normal,
                        color: _isParallelMode ? const Color(0xFF00E5FF) : Colors.white60,
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

  Widget _buildResponsiveFooter() {
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
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A192F),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A192F)),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text(
                _isExportingPdf ? 'Generando...' : 'Descargar Plan PDF',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: _isExportingPdf ? null : _exportPdf,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _showCopiedBadge ? const Color(0xFF4CAF50) : const Color(0xFF00E5FF),
                  width: 1.1,
                ),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              icon: Icon(
                _showCopiedBadge ? Icons.check : Icons.copy_rounded,
                size: 15,
                color: _showCopiedBadge ? const Color(0xFF4CAF50) : const Color(0xFF00E5FF),
              ),
              label: Text(
                _showCopiedBadge ? '¡Copiado!' : 'Copiar Lista',
                style: TextStyle(
                  color: _showCopiedBadge ? const Color(0xFF4CAF50) : Colors.white,
                  fontSize: 11,
                ),
              ),
              onPressed: _copyShoppingListToClipboard,
            ),
          ],
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.white10,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildMaterialsTab() {
    if (_plan.materials.isEmpty) {
      return const Center(
        child: Text(
          'No hay partidas de materiales para los filtros seleccionados.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      itemCount: _plan.materials.length,
      itemBuilder: (context, idx) {
        final mat = _plan.materials[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(mat.icon, color: const Color(0xFF00E5FF), size: 16),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${mat.quantity.toStringAsFixed(mat.quantity % 1 == 0 ? 0 : 2)} ${mat.unit}',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (mat.targetRoomNames.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined, color: Color(0xFF00E5FF), size: 12),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'Destino: ${mat.targetRoomNames.join(', ')}',
                              style: const TextStyle(
                                color: Color(0xFF80D8FF),
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
                        'Presentación: ${mat.packagingDetail}',
                        style: const TextStyle(color: Color(0xFF81D4FA), fontSize: 9.6),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '• ${mat.yieldFormula}',
                      style: const TextStyle(color: Colors.white70, fontSize: 9.6),
                    ),
                    if (mat.purchaseTip != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '💡 Tip técnico: ${mat.purchaseTip}',
                        style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 9.4, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCrewsTab() {
    final crews = _isParallelMode ? _plan.parallelCrews : _plan.sequentialCrews;

    return ListView.builder(
      itemCount: crews.length,
      itemBuilder: (context, idx) {
        final crew = crews[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(crew.icon, color: const Color(0xFF4CAF50), size: 18),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${crew.headcount} op. • ${crew.estimatedDays} d',
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      crew.scopeDescription,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    if (crew.equipmentNeeded.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '🛠️ Herramientas: ${crew.equipmentNeeded.join(', ')}',
                        style: const TextStyle(color: Colors.white54, fontSize: 9.2),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleTab() {
    return ListView.builder(
      itemCount: _plan.phases.length,
      itemBuilder: (context, idx) {
        final phase = _plan.phases[idx];
        final days = _isParallelMode ? phase.estimatedDaysParallel : phase.estimatedDaysSequential;

        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: phase.canParallelize && _isParallelMode
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: const Color(0xFF00E5FF),
                    child: Text(
                      '${phase.phaseNumber}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0A192F)),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      phase.title,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$days días',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                phase.description,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 11, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ejecuta: ${phase.specialists.join(' + ')}',
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  ),
                ],
              ),
              if (phase.canParallelize) ...[
                const SizedBox(height: 2),
                Text(
                  '⚡ Paralelo: ${phase.parallelTip}',
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 9, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
