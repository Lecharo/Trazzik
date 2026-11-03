import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/features/ai_advisor/data/renovation_planner_engine.dart';
import 'package:trazzik/features/ai_advisor/domain/renovation_plan_result.dart';
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

  bool _allHouseScope = true; // Toda la casa vs solo piso actual
  bool _renovateFloors = true;
  bool _renovateBathrooms = true;
  bool _renovateKitchen = true;
  bool _renovateWallsPaint = false;
  bool _isParallelMode = true;

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
    super.dispose();
  }

  void _recalculate() {
    final state = ref.read(floorEditorProvider);
    final List<Module> sourceModules;

    if (_allHouseScope && state.allFloors.isNotEmpty) {
      sourceModules = state.allFloors.expand((f) => f.modules).toList();
    } else {
      sourceModules = state.floor.modules;
    }

    _plan = RenovationPlannerEngine.generatePlan(
      allRooms: sourceModules,
      renovateFloors: _renovateFloors,
      renovateBathrooms: _renovateBathrooms,
      renovateKitchen: _renovateKitchen,
      renovateWallsPaint: _renovateWallsPaint,
    );
  }

  void _copyShoppingListToClipboard() {
    final buffer = StringBuffer();
    buffer.writeln('📋 PLAN DE COMPRAS Y MATERIALES — TRAZZIK');
    buffer.writeln('Área total a intervenir: ${_plan.totalRenovatedArea.toStringAsFixed(2)} m²');
    buffer.writeln('Baños a remodelar: ${_plan.bathroomCount}');
    buffer.writeln('------------------------------------------');
    for (final mat in _plan.materials) {
      buffer.writeln('• ${mat.name}: ${mat.quantity.toStringAsFixed(mat.quantity % 1 == 0 ? 0 : 2)} ${mat.unit}');
      buffer.writeln('  (${mat.yieldFormula})');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('⏱️ Tiempo estimado de ejecución:');
    buffer.writeln('• Cuadrillas en paralelo: ${_plan.totalParallelDays} días hábiles.');
    buffer.writeln('• Cuadrilla secuencial: ${_plan.totalSequentialDays} días hábiles.');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2E7D32),
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('¡Lista de compras copiada al portapapeles!'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF)),
                    ),
                    child: const Icon(
                      Icons.checklist_rtl_rounded,
                      color: Color(0xFF00E5FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLANIFICADOR DE OBRA, MATERIALES Y CUADRILLA IA',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Cómputo métrico con desperdicio técnico, especialistas y ruta crítica de labores',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
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
              const SizedBox(height: 12),

              // Barra de Configuración de Alcance y Filtros
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Alcance
                    ChoiceChip(
                      avatar: const Icon(Icons.home, size: 14),
                      label: const Text('Toda la Casa', style: TextStyle(fontSize: 10)),
                      selected: _allHouseScope,
                      selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                      onSelected: (val) {
                        setState(() {
                          _allHouseScope = true;
                          _recalculate();
                        });
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.layers, size: 14),
                      label: const Text('Solo Este Piso', style: TextStyle(fontSize: 10)),
                      selected: !_allHouseScope,
                      selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                      onSelected: (val) {
                        setState(() {
                          _allHouseScope = false;
                          _recalculate();
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    // Filtros de partida
                    FilterChip(
                      label: const Text('Pisos', style: TextStyle(fontSize: 10)),
                      selected: _renovateFloors,
                      selectedColor: const Color(0xFF4CAF50).withOpacity(0.25),
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
                      selectedColor: const Color(0xFF29B6F6).withOpacity(0.25),
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
                      selectedColor: const Color(0xFFFFB74D).withOpacity(0.25),
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
                      selectedColor: const Color(0xFFAB47BC).withOpacity(0.25),
                      onSelected: (v) {
                        setState(() {
                          _renovateWallsPaint = v;
                          _recalculate();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tarjeta Resumen KPI (Tiempo y Paralelismo)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00E5FF).withOpacity(0.12),
                      const Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_plan.totalRenovatedArea.toStringAsFixed(2)} m²',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${_plan.selectedRoomNames.length} recintos • ${_plan.bathroomCount} baños)',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isParallelMode
                                ? '⚡ Modo Acelerado: ${_plan.totalParallelDays} días de obra (${_plan.daysSaved} días de ahorro / ${_plan.timeReductionPercent.toStringAsFixed(0)}% más rápido)'
                                : '⏳ Modo Secuencial: ${_plan.totalSequentialDays} días de obra con 1 sola cuadrilla',
                            style: TextStyle(
                              color: _isParallelMode ? const Color(0xFF4CAF50) : const Color(0xFFFFB74D),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Toggle Paralelo / Secuencial
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_isParallelMode ? const Color(0xFFFFB74D).withOpacity(0.3) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '1 Cuadrilla',
                                style: TextStyle(
                                  fontSize: 10,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isParallelMode ? const Color(0xFF00E5FF).withOpacity(0.3) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Paralelo ⚡',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: _isParallelMode ? FontWeight.bold : FontWeight.normal,
                                  color: _isParallelMode ? const Color(0xFF00E5FF) : Colors.white60,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Pestañas
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF00E5FF),
                labelColor: const Color(0xFF00E5FF),
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                    text: 'Materiales (${_plan.materials.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.engineering_outlined, size: 16),
                    text: 'Cuadrilla (${_isParallelMode ? _plan.parallelCrews.length : _plan.sequentialCrews.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.timeline_outlined, size: 16),
                    text: 'Ruta Crítica (${_plan.phases.length} Fases)',
                  ),
                ],
              ),
              const SizedBox(height: 8),

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

              const SizedBox(height: 10),

              // Footer con Botón de Copiar y Cerrar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar Lista de Compras', style: TextStyle(fontSize: 11)),
                    onPressed: _copyShoppingListToClipboard,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialsTab() {
    if (_plan.materials.isEmpty) {
      return const Center(
        child: Text(
          'Seleccioná al menos una partida (Pisos, Baños, Cocina o Pintura) para calcular.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      itemCount: _plan.materials.length,
      itemBuilder: (context, idx) {
        final mat = _plan.materials[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(mat.icon, color: const Color(0xFF00E5FF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            mat.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${mat.quantity.toStringAsFixed(mat.quantity % 1 == 0 ? 0 : 2)} ${mat.unit}',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '• ${mat.yieldFormula}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                    if (mat.purchaseTip != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '💡 Tip técnico: ${mat.purchaseTip}',
                        style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 10, fontStyle: FontStyle.italic),
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
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(crew.icon, color: const Color(0xFF4CAF50), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          crew.roleName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${crew.headcount} operario(s) • ${crew.estimatedDays} días',
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      crew.scopeDescription,
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                    if (crew.equipmentNeeded.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '🛠️ Herramientas clave: ${crew.equipmentNeeded.join(', ')}',
                        style: const TextStyle(color: Colors.white54, fontSize: 9.5),
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
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: phase.canParallelize && _isParallelMode
                  ? const Color(0xFF00E5FF).withOpacity(0.3)
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFF00E5FF),
                    child: Text(
                      '${phase.phaseNumber}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A192F)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phase.title,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$days días hábiles',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                phase.description,
                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ejecuta: ${phase.specialists.join(' + ')}',
                      style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                    ),
                  ),
                ],
              ),
              if (phase.canParallelize) ...[
                const SizedBox(height: 3),
                Text(
                  '⚡ Estrategia paralela: ${phase.parallelTip}',
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 9.5, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
