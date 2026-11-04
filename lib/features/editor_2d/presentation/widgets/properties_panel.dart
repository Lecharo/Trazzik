import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/validation/validation_issue.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/furniture_catalog_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/project_area_schedule_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/space_catalog_dialog.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

class PropertiesPanel extends ConsumerStatefulWidget {
  final bool isSheet;
  final ScrollController? scrollController;
  final VoidCallback? onClose;

  const PropertiesPanel({
    super.key,
    this.isSheet = false,
    this.scrollController,
    this.onClose,
  });

  @override
  ConsumerState<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends ConsumerState<PropertiesPanel> {
  final _nameController = TextEditingController();
  final _xController = TextEditingController();
  final _yController = TextEditingController();
  final _wController = TextEditingController();
  final _dController = TextEditingController();

  String? _lastModuleId;
  double? _lastX;
  double? _lastY;
  double? _lastW;
  double? _lastD;

  @override
  void dispose() {
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _wController.dispose();
    _dController.dispose();
    super.dispose();
  }

  void _syncControllers(Module? module) {
    if (module == null) {
      _lastModuleId = null;
      return;
    }
    final bb = module.geometry.boundingBox;
    if (_lastModuleId != module.id ||
        _lastX != bb.minX ||
        _lastY != bb.minY ||
        _lastW != bb.width ||
        _lastD != bb.height) {
      _lastModuleId = module.id;
      _lastX = bb.minX;
      _lastY = bb.minY;
      _lastW = bb.width;
      _lastD = bb.height;
      _nameController.text = module.name;
      _xController.text = bb.minX.toStringAsFixed(2);
      _yController.text = bb.minY.toStringAsFixed(2);
      _wController.text = bb.width.toStringAsFixed(2);
      _dController.text = bb.height.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final lang = ref.watch(appLocaleProvider);
    final selectedModule = state.selectedModule;
    final selectedWall = state.selectedWall;

    _syncControllers(selectedModule);

    final replacement = selectedModule != null
        ? state.floor.replacementRelationships
            .where((r) => r.proposedElementId == selectedModule.id)
            .firstOrNull
        : null;

    return Container(
      width: widget.isSheet ? double.infinity : 320,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: widget.isSheet
            ? null
            : Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          // Header del Piso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                const Icon(Icons.architecture, color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.floor.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${state.floor.calculatedBuiltArea.toStringAsFixed(1)} m²',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (widget.isSheet)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cerrar',
                    onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(14, 14, 14, widget.isSheet ? 80 : 24),
              children: [
                // 1. Cuadro de Áreas
                _buildSectionHeader(AppStrings.tr('areas_table', lang)),
                _buildAreaRow(AppStrings.tr('total_lot', lang), '${state.lot.totalArea.toStringAsFixed(1)} m²'),
                _buildAreaRow(AppStrings.tr('max_floor_allowed', lang), '${state.floor.maxAllowedArea.toStringAsFixed(1)} m²'),
                _buildAreaRow(
                  AppStrings.tr('proposed_built_area', lang),
                  '${state.floor.calculatedBuiltArea.toStringAsFixed(2)} m²',
                  highlight: true,
                ),
                _buildAreaRow(
                  AppStrings.tr('available_expansion', lang),
                  '${(state.floor.maxAllowedArea - state.floor.calculatedBuiltArea).toStringAsFixed(2)} m²',
                ),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    ),
                    icon: const Icon(Icons.table_chart, size: 14),
                    label: Text(
                      lang == 'es'
                          ? 'Ver Cuadro Total (${state.allFloors.isNotEmpty ? state.allFloors.length : 1} pisos)'
                          : 'View Full Schedule (${state.allFloors.isNotEmpty ? state.allFloors.length : 1} floors)',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => ProjectAreaScheduleDialog.show(context),
                  ),
                ),

                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: state.floor.walls.isNotEmpty ? const Color(0xFF66BB6A) : const Color(0xFF00E5FF),
                      side: BorderSide(color: state.floor.walls.isNotEmpty ? const Color(0xFF66BB6A) : const Color(0xFF00E5FF)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    ),
                    icon: const Icon(Icons.fence, size: 14),
                    label: Text(
                      lang == 'es'
                          ? (state.floor.walls.isNotEmpty
                              ? 'Muros: ${state.floor.walls.length} trazados (Regenerar)'
                              : 'Demarcar Muros de Recintos')
                          : (state.floor.walls.isNotEmpty
                              ? 'Walls: ${state.floor.walls.length} drawn'
                              : 'Demarcate Room Walls'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final count = notifier.generateWallsFromModules();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF2E7D32),
                          content: Text(
                            lang == 'es'
                                ? 'Se demarcaron $count muros perimetrales e interiores.'
                                : 'Demarcated $count walls.',
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),
                if (state.floor.modules.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final allLocked = state.floor.modules.every((m) => m.isLocked);
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: allLocked ? const Color(0xFFFFB300) : Colors.white70,
                            side: BorderSide(color: allLocked ? const Color(0xFFFFB300) : Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          ),
                          icon: Icon(allLocked ? Icons.lock : Icons.lock_open, size: 14),
                          label: Text(
                            lang == 'es'
                                ? (allLocked ? 'Espacios Asegurados 🔒 (Desbloquear)' : 'Asegurar Todos los Espacios 🔒')
                                : (allLocked ? 'All Spaces Locked 🔒' : 'Lock All Spaces 🔒'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            notifier.setAllModulesLocked(!allLocked);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 2),
                                backgroundColor: !allLocked ? const Color(0xFF2E7D32) : const Color(0xFF37474F),
                                content: Text(
                                  !allLocked
                                      ? (lang == 'es'
                                          ? 'Todos los espacios asegurados 🔒. Solo se pueden amoblar o editar detalles.'
                                          : 'All spaces locked 🔒.')
                                      : (lang == 'es' ? 'Espacios desbloqueados para reubicar.' : 'Spaces unlocked.'),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // 2. Elemento Seleccionado (Muro o Ambiente)
                if (selectedWall != null) ...[
                  _buildSectionHeader(lang == 'es' ? 'Muro Seleccionado' : 'Selected Wall'),
                  _buildWallProperties(selectedWall, notifier, lang),
                ] else if (selectedModule == null) ...[
                  _buildSectionHeader(AppStrings.tr('selected_element', lang)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      AppStrings.tr('no_selection_hint', lang),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF0A192F),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => SpaceCatalogDialog.show(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        lang == 'es' ? 'Agregar Espacio al Plano' : 'Add Space to Plan',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final openings = state.floor.modules.where((m) {
                        final t = m.moduleType.toUpperCase();
                        return t.contains('DOOR') || t.contains('WINDOW') || t.contains('GATE');
                      }).toList();

                      if (openings.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          _buildSectionHeader(
                            lang == 'es'
                                ? 'Aberturas y Accesos en Planta (${openings.length})'
                                : 'Openings & Doors on Floor (${openings.length})',
                          ),
                          Text(
                            lang == 'es'
                                ? 'Toca cualquier puerta para seleccionarla y ajustarla:'
                                : 'Tap any door or opening to select and adjust:',
                            style: const TextStyle(color: Colors.white60, fontSize: 10),
                          ),
                          const SizedBox(height: 8),
                          ...openings.map((op) {
                            final isDoor = op.moduleType.toUpperCase().contains('DOOR');
                            final isWindow = op.moduleType.toUpperCase().contains('WINDOW');
                            final bb = op.geometry.boundingBox;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                                  backgroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => notifier.selectModule(op.id),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDoor
                                          ? Icons.sensor_door
                                          : (isWindow ? Icons.window : Icons.garage),
                                      size: 16,
                                      color: const Color(0xFF00E5FF),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            op.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${bb.width.toStringAsFixed(2)} × ${bb.height.toStringAsFixed(2)} m (X: ${bb.minX.toStringAsFixed(2)}, Y: ${bb.minY.toStringAsFixed(2)})',
                                            style: const TextStyle(color: Colors.white54, fontSize: 9),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF00E5FF)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(AppStrings.tr('selected_element', lang)),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(
                          selectedModule.isLocked ? Icons.lock : Icons.lock_open,
                          size: 18,
                          color: selectedModule.isLocked ? const Color(0xFFFFB300) : Colors.white60,
                        ),
                        tooltip: selectedModule.isLocked
                            ? (lang == 'es' ? 'Ubicación asegurada (Toca para desbloquear)' : 'Position locked (Tap to unlock)')
                            : (lang == 'es' ? 'Asegurar ubicación (Bloquear arrastre)' : 'Lock position (Prevent dragging)'),
                        onPressed: () {
                          notifier.toggleModuleLock(selectedModule.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              backgroundColor: selectedModule.isLocked ? const Color(0xFF37474F) : const Color(0xFF2E7D32),
                              content: Text(
                                selectedModule.isLocked
                                    ? (lang == 'es' ? 'Ambiente desbloqueado: ahora podés moverlo.' : 'Space unlocked.')
                                    : (lang == 'es' ? 'Ambiente asegurado 🔒: ya no se descuadrará al tocarlo.' : 'Space locked 🔒.'),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // Nombre Editable
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: lang == 'es' ? 'Nombre del Espacio' : 'Space Name',
                      labelStyle: const TextStyle(fontSize: 11),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, size: 16, color: Color(0xFF00E5FF)),
                        onPressed: () => notifier.setModuleName(
                          selectedModule.id,
                          _nameController.text.trim(),
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        notifier.setModuleName(selectedModule.id, val.trim());
                      }
                    },
                    onSubmitted: (val) => notifier.setModuleName(
                      selectedModule.id,
                      val.trim(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Selector de Estado Constructivo
                  Text(
                    lang == 'es' ? 'Estado Constructivo' : 'Constructive Status',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        avatar: const CircleAvatar(backgroundColor: Color(0xFF00E5FF), radius: 4),
                        label: Text(lang == 'es' ? 'Propuesto' : 'New', style: const TextStyle(fontSize: 10)),
                        selected: selectedModule.status == ElementStatus.isNew,
                        selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                        onSelected: (_) => notifier.setModuleStatus(selectedModule.id, ElementStatus.isNew),
                      ),
                      ChoiceChip(
                        avatar: const CircleAvatar(backgroundColor: Color(0xFF4CAF50), radius: 4),
                        label: Text(lang == 'es' ? 'Conservar' : 'Preserve', style: const TextStyle(fontSize: 10)),
                        selected: selectedModule.status == ElementStatus.preserved,
                        selectedColor: const Color(0xFF4CAF50).withOpacity(0.25),
                        onSelected: (_) => notifier.setModuleStatus(selectedModule.id, ElementStatus.preserved),
                      ),
                      ChoiceChip(
                        avatar: const CircleAvatar(backgroundColor: Color(0xFFE53935), radius: 4),
                        label: Text(lang == 'es' ? 'A Demoler' : 'Demolish', style: const TextStyle(fontSize: 10)),
                        selected: selectedModule.status == ElementStatus.toDemolish,
                        selectedColor: const Color(0xFFE53935).withOpacity(0.25),
                        onSelected: (_) => notifier.setModuleStatus(selectedModule.id, ElementStatus.toDemolish),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Área y Tipo
                  _buildPropertyRow('Tipo', selectedModule.moduleType),
                  _buildPropertyRow('Área', '${selectedModule.area.toStringAsFixed(2)} m²'),

                  if (selectedModule.geometry.vertices.length > 4) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.08),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.polyline, size: 16, color: Color(0xFF00E5FF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lang == 'es'
                                      ? 'Polígono Irregular (${selectedModule.geometry.vertices.length} lados)'
                                      : 'Irregular Polygon (${selectedModule.geometry.vertices.length} sides)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00E5FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lang == 'es'
                                ? '• Área útil construida: ${selectedModule.area.toStringAsFixed(2)} m²\n• Envolvente total: ${selectedModule.geometry.boundingBox.width.toStringAsFixed(2)} × ${selectedModule.geometry.boundingBox.height.toStringAsFixed(2)} m (${(selectedModule.geometry.boundingBox.width * selectedModule.geometry.boundingBox.height).toStringAsFixed(2)} m²)\n• Al modificar Ancho o Fondo, se escala preservando el remetido/quiebre en L.'
                                : '• Net usable area: ${selectedModule.area.toStringAsFixed(2)} m²\n• Enclosing envelope: ${selectedModule.geometry.boundingBox.width.toStringAsFixed(2)} × ${selectedModule.geometry.boundingBox.height.toStringAsFixed(2)} m\n• Scaling preserves the L-shaped recess.',
                            style: const TextStyle(fontSize: 10, color: Colors.white70, height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            icon: const Icon(Icons.crop_square, size: 14),
                            label: Text(
                              lang == 'es' ? 'Simplificar a Rectángulo' : 'Flatten to Rectangle',
                              style: const TextStyle(fontSize: 10),
                            ),
                            onPressed: () => notifier.toggleLShapedNook(selectedModule.id),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    if (!selectedModule.moduleType.toUpperCase().contains('DOOR') &&
                        !selectedModule.moduleType.toUpperCase().contains('WINDOW') &&
                        !selectedModule.moduleType.toUpperCase().contains('GATE') &&
                        !selectedModule.moduleType.toUpperCase().contains('STAIRS'))
                      Container(
                        margin: const EdgeInsets.only(top: 6, bottom: 6),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00E5FF),
                            side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 28),
                          ),
                          icon: const Icon(Icons.call_split, size: 14),
                          label: Text(
                            lang == 'es' ? 'Crear Remetido en L (0.50m puerta)' : 'Add L-shaped Nook (0.50m)',
                            style: const TextStyle(fontSize: 10),
                          ),
                          onPressed: () => notifier.toggleLShapedNook(selectedModule.id),
                        ),
                      ),
                  ],

                  const SizedBox(height: 10),

                  // Posición X e Y con steppers
                  Text(
                    lang == 'es' ? 'Posición Cartesiana (m)' : 'Position (m)',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumericStepper(
                          label: 'X',
                          controller: _xController,
                          value: selectedModule.geometry.boundingBox.minX,
                          enabled: !selectedModule.isLocked,
                          onChanged: (newX) {
                            final bb = selectedModule.geometry.boundingBox;
                            notifier.setModulePosition(selectedModule.id, newX, bb.minY);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildNumericStepper(
                          label: 'Y',
                          controller: _yController,
                          value: selectedModule.geometry.boundingBox.minY,
                          enabled: !selectedModule.isLocked,
                          onChanged: (newY) {
                            final bb = selectedModule.geometry.boundingBox;
                            notifier.setModulePosition(selectedModule.id, bb.minX, newY);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Dimensiones Ancho x Fondo con steppers
                  Text(
                    lang == 'es' ? 'Dimensiones (m)' : 'Dimensions (m)',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumericStepper(
                          label: lang == 'es' ? 'Ancho' : 'Width',
                          controller: _wController,
                          value: selectedModule.geometry.boundingBox.width,
                          minVal: 0.10,
                          enabled: !selectedModule.isLocked,
                          onChanged: (newW) {
                            final bb = selectedModule.geometry.boundingBox;
                            notifier.setModuleDimensions(selectedModule.id, newW, bb.height);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildNumericStepper(
                          label: lang == 'es' ? 'Fondo' : 'Depth',
                          controller: _dController,
                          value: selectedModule.geometry.boundingBox.height,
                          minVal: 0.10,
                          enabled: !selectedModule.isLocked,
                          onChanged: (newD) {
                            final bb = selectedModule.geometry.boundingBox;
                            notifier.setModuleDimensions(selectedModule.id, bb.width, newD);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Botón Rotar 90° (Orientación Arquitectónica)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00E5FF),
                        side: const BorderSide(color: Color(0xFF00E5FF)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => notifier.rotateModule90(selectedModule.id),
                      icon: const Icon(Icons.rotate_90_degrees_cw, size: 16),
                      label: Text(
                        lang == 'es' ? 'Rotar 90° (Giro en Planta)' : 'Rotate 90°',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Botones Invertir Mano y Apertura (Espejos para Aberturas / 4 cuadrantes)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: selectedModule.flipX ? Colors.amber : Colors.white70,
                            side: BorderSide(
                              color: selectedModule.flipX ? Colors.amber : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          ),
                          onPressed: () => notifier.flipModuleHorizontal(selectedModule.id),
                          icon: const Icon(Icons.swap_horiz, size: 15),
                          label: Text(
                            lang == 'es' ? 'Invertir Mano' : 'Flip Hinge',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: selectedModule.flipY ? Colors.amber : Colors.white70,
                            side: BorderSide(
                              color: selectedModule.flipY ? Colors.amber : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          ),
                          onPressed: () => notifier.flipModuleVertical(selectedModule.id),
                          icon: const Icon(Icons.swap_vert, size: 15),
                          label: Text(
                            lang == 'es' ? 'Invertir Giro' : 'Flip Swing',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Ajuste Fino de Posición en Muro (para Puertas, Ventanas y Portones)
                  if (selectedModule.moduleType.toUpperCase().contains('DOOR') ||
                      selectedModule.moduleType.toUpperCase().contains('WINDOW') ||
                      selectedModule.moduleType.toUpperCase().contains('GATE')) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune, size: 15, color: Color(0xFF00E5FF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lang == 'es' ? 'Ajuste Fino en Muro (±5 cm)' : 'Fine Position Nudge (±5 cm)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lang == 'es'
                                ? 'Desplaza la abertura suavemente sobre el muro sin tener que arrastrarla:'
                                : 'Nudge the opening smoothly along the wall without dragging:',
                            style: const TextStyle(fontSize: 10, color: Colors.white60),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF00E5FF)),
                                tooltip: lang == 'es' ? 'Izquierda (-0.05m)' : 'Left (-0.05m)',
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                                onPressed: selectedModule.isLocked
                                    ? null
                                    : () {
                                        final bb = selectedModule.geometry.boundingBox;
                                        notifier.setModulePosition(
                                          selectedModule.id,
                                          FloorEditorNotifier.snapToGrid(bb.minX - 0.05, 0.01),
                                          bb.minY,
                                        );
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_upward, size: 16, color: Color(0xFF00E5FF)),
                                tooltip: lang == 'es' ? 'Arriba (-0.05m)' : 'Up (-0.05m)',
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                                onPressed: selectedModule.isLocked
                                    ? null
                                    : () {
                                        final bb = selectedModule.geometry.boundingBox;
                                        notifier.setModulePosition(
                                          selectedModule.id,
                                          bb.minX,
                                          FloorEditorNotifier.snapToGrid(bb.minY - 0.05, 0.01),
                                        );
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward, size: 16, color: Color(0xFF00E5FF)),
                                tooltip: lang == 'es' ? 'Abajo (+0.05m)' : 'Down (+0.05m)',
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                                onPressed: selectedModule.isLocked
                                    ? null
                                    : () {
                                        final bb = selectedModule.geometry.boundingBox;
                                        notifier.setModulePosition(
                                          selectedModule.id,
                                          bb.minX,
                                          FloorEditorNotifier.snapToGrid(bb.minY + 0.05, 0.01),
                                        );
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF00E5FF)),
                                tooltip: lang == 'es' ? 'Derecha (+0.05m)' : 'Right (+0.05m)',
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                                onPressed: selectedModule.isLocked
                                    ? null
                                    : () {
                                        final bb = selectedModule.geometry.boundingBox;
                                        notifier.setModulePosition(
                                          selectedModule.id,
                                          FloorEditorNotifier.snapToGrid(bb.minX + 0.05, 0.01),
                                          bb.minY,
                                        );
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Sección Mobiliario y Equipamiento Interior (para recintos habitables)
                  if (!selectedModule.moduleType.toUpperCase().contains('DOOR') &&
                      !selectedModule.moduleType.toUpperCase().contains('WINDOW') &&
                      !selectedModule.moduleType.toUpperCase().contains('GATE')) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.chair, size: 16, color: Color(0xFF00E5FF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lang == 'es' ? 'Equipamiento y Muebles' : 'Furniture & Equipment',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              Text(
                                '${selectedModule.subModules.length}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 0,
                              ),
                              onPressed: () => FurnitureCatalogDialog.show(context, selectedModule.id),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                lang == 'es' ? 'Amoblar / Agregar Mueble' : 'Add Furniture',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (selectedModule.subModules.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...selectedModule.subModules.map((sub) {
                              final bb = sub.geometry.boundingBox;
                              final isSelectedSub = sub.id == state.selectedSubModuleId;
                              return InkWell(
                                onTap: () => notifier.selectSubModule(selectedModule.id, sub.id),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelectedSub ? const Color(0xFF263345) : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelectedSub ? const Color(0xFF00E5FF) : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${sub.name} (${bb.width.toStringAsFixed(2)}x${bb.height.toStringAsFixed(2)}m)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isSelectedSub ? FontWeight.bold : FontWeight.normal,
                                                color: isSelectedSub ? const Color(0xFF00E5FF) : Colors.white70,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              sub.isLocked ? Icons.lock : Icons.lock_open,
                                              size: 16,
                                              color: sub.isLocked ? const Color(0xFFFFB300) : Colors.white38,
                                            ),
                                            tooltip: sub.isLocked
                                                ? (lang == 'es' ? 'Desbloquear Mueble' : 'Unlock Furniture')
                                                : (lang == 'es' ? 'Fijar / Bloquear Mueble' : 'Lock Furniture'),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => notifier.toggleSubModuleLock(selectedModule.id, sub.id),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              Icons.rotate_right,
                                              size: 16,
                                              color: sub.isLocked ? Colors.white24 : const Color(0xFF00E5FF),
                                            ),
                                            tooltip: 'Rotar 90°',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: sub.isLocked ? null : () => notifier.rotateSubModule(selectedModule.id, sub.id),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: sub.isLocked ? Colors.white24 : Colors.redAccent,
                                            ),
                                            tooltip: 'Eliminar',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: sub.isLocked ? null : () => notifier.removeSubModule(selectedModule.id, sub.id),
                                          ),
                                        ],
                                      ),
                                      if (isSelectedSub) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'Pos: (${bb.minX.toStringAsFixed(2)}, ${bb.minY.toStringAsFixed(2)}m)${sub.isLocked ? ' 🔒' : ''}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: sub.isLocked ? const Color(0xFFFFB300) : Colors.grey,
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              icon: Icon(
                                                Icons.arrow_back,
                                                size: 14,
                                                color: sub.isLocked ? Colors.white24 : Colors.white70,
                                              ),
                                              tooltip: 'Mover izquierda (-0.10m)',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: sub.isLocked ? null : () => notifier.setSubModulePosition(selectedModule.id, sub.id, bb.minX - 0.10, bb.minY),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                Icons.arrow_forward,
                                                size: 14,
                                                color: sub.isLocked ? Colors.white24 : Colors.white70,
                                              ),
                                              tooltip: 'Mover derecha (+0.10m)',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: sub.isLocked ? null : () => notifier.setSubModulePosition(selectedModule.id, sub.id, bb.minX + 0.10, bb.minY),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                Icons.arrow_upward,
                                                size: 14,
                                                color: sub.isLocked ? Colors.white24 : Colors.white70,
                                              ),
                                              tooltip: 'Mover arriba (-0.10m)',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: sub.isLocked ? null : () => notifier.setSubModulePosition(selectedModule.id, sub.id, bb.minX, bb.minY - 0.10),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                Icons.arrow_downward,
                                                size: 14,
                                                color: sub.isLocked ? Colors.white24 : Colors.white70,
                                              ),
                                              tooltip: 'Mover abajo (+0.10m)',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: sub.isLocked ? null : () => notifier.setSubModulePosition(selectedModule.id, sub.id, bb.minX, bb.minY + 0.10),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          lang == 'es' ? 'Dimensiones y Elevación (m)' : 'Dimensions & Elevation (m)',
                                          style: const TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildSubDimensionStepper(
                                                label: lang == 'es' ? 'Ancho (X)' : 'Width (X)',
                                                value: bb.width,
                                                minVal: 0.15,
                                                onChanged: (val) => notifier.setSubModuleDimensions(
                                                  selectedModule.id,
                                                  sub.id,
                                                  width: val,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: _buildSubDimensionStepper(
                                                label: lang == 'es' ? 'Fondo (Y)' : 'Depth (Y)',
                                                value: bb.height,
                                                minVal: 0.15,
                                                onChanged: (val) => notifier.setSubModuleDimensions(
                                                  selectedModule.id,
                                                  sub.id,
                                                  depth: val,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildSubDimensionStepper(
                                                label: lang == 'es' ? 'Alto (Z)' : 'Height (Z)',
                                                value: sub.resolvedHeight,
                                                minVal: 0.05,
                                                onChanged: (val) => notifier.setSubModuleDimensions(
                                                  selectedModule.id,
                                                  sub.id,
                                                  height: val,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: _buildSubDimensionStepper(
                                                label: lang == 'es' ? 'Elevación' : 'Elevation',
                                                value: sub.elevation,
                                                minVal: 0.0,
                                                onChanged: (val) => notifier.setSubModuleDimensions(
                                                  selectedModule.id,
                                                  sub.id,
                                                  elevation: val,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Botones de acción rápida: Duplicar / Eliminar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => notifier.duplicateModule(selectedModule.id),
                          icon: const Icon(Icons.copy, size: 14),
                          label: Text(lang == 'es' ? 'Duplicar' : 'Duplicate', style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF5350),
                            side: const BorderSide(color: Color(0xFFEF5350)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => notifier.deleteModule(selectedModule.id),
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: Text(lang == 'es' ? 'Eliminar' : 'Delete', style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Cerrar este espacio con muros
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00E5FF),
                        side: const BorderSide(color: Color(0xFF00E5FF)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        final added = notifier.addWallsForModule(selectedModule.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF2E7D32),
                            content: Text(
                              lang == 'es'
                                  ? (added > 0
                                      ? 'Se añadieron $added muros al recinto ${selectedModule.name}.'
                                      : 'El recinto ya cuenta con muros en su contorno.')
                                  : 'Added $added walls to ${selectedModule.name}.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.fence, size: 14),
                      label: Text(
                        lang == 'es' ? 'Cerrar con Muros este Espacio' : 'Enclose Space with Walls',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Agregar otro espacio
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => SpaceCatalogDialog.show(context),
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF00E5FF)),
                      label: Text(
                        lang == 'es' ? '+ Agregar Otro Espacio' : '+ Add Another Space',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                    selectedModule.isLocked
                        ? (lang == 'es' ? 'Ubicación asegurada 🔒 (desbloqueá para mover):' : 'Position locked 🔒:')
                        : (lang == 'es' ? 'Ajuste fino (±5 cm):' : 'Fine adjust (±5 cm):'),
                    style: TextStyle(
                      color: selectedModule.isLocked ? const Color(0xFFFFB300) : Colors.grey,
                      fontSize: 10,
                      fontWeight: selectedModule.isLocked ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 18),
                        color: selectedModule.isLocked ? Colors.white24 : Colors.white70,
                        tooltip: '-5 cm X',
                        onPressed: selectedModule.isLocked ? null : () => notifier.moveSelectedModule(-0.05, 0),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            color: selectedModule.isLocked ? Colors.white24 : Colors.white70,
                            tooltip: '-5 cm Y',
                            onPressed: selectedModule.isLocked ? null : () => notifier.moveSelectedModule(0, -0.05),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            color: selectedModule.isLocked ? Colors.white24 : Colors.white70,
                            tooltip: '+5 cm Y',
                            onPressed: selectedModule.isLocked ? null : () => notifier.moveSelectedModule(0, 0.05),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        color: selectedModule.isLocked ? Colors.white24 : Colors.white70,
                        tooltip: '+5 cm X',
                        onPressed: selectedModule.isLocked ? null : () => notifier.moveSelectedModule(0.05, 0),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // 3. Relación de Reemplazo (si aplica)
                if (replacement != null) ...[
                  _buildSectionHeader(AppStrings.tr('remodeling_transition', lang)),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222733),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.transform, color: Color(0xFF00E5FF), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.tr('parametric_replacement', lang),
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildPropertyRow(AppStrings.tr('replacement_type', lang), replacement.relationshipType.name.toUpperCase()),
                        _buildPropertyRow(AppStrings.tr('overlap_area', lang), '${replacement.overlapArea.toStringAsFixed(2)} m²'),
                        _buildPropertyRow(AppStrings.tr('expanded_net_area', lang), '+${replacement.expandedArea.toStringAsFixed(2)} m²'),
                        if (replacement.notes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            replacement.notes!,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Validaciones en Tiempo Real
                _buildSectionHeader(AppStrings.tr('live_validation', lang)),
                if (state.issues.isEmpty)
                  Text(
                    AppStrings.tr('no_issues', lang),
                    style: const TextStyle(color: Color(0xFF81C784), fontSize: 11),
                  )
                else
                  ...state.issues.map((issue) => _buildIssueCard(issue)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericStepper({
    required String label,
    required TextEditingController controller,
    required double value,
    required ValueChanged<double> onChanged,
    double minVal = -100.0,
    double step = 0.05,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(Icons.remove, size: 14, color: enabled ? Colors.white70 : Colors.white24),
            onPressed: enabled
                ? () {
                    final next = (value - step).clamp(minVal, 100.0);
                    onChanged(FloorEditorNotifier.snapToGrid(next));
                  }
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
                Text(
                  '${value.toStringAsFixed(2)} m',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: enabled ? Colors.white : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(Icons.add, size: 14, color: enabled ? Colors.white70 : Colors.white24),
            onPressed: enabled
                ? () {
                    final next = value + step;
                    onChanged(FloorEditorNotifier.snapToGrid(next));
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSubDimensionStepper({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double minVal = 0.05,
    double step = 0.05,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            icon: const Icon(Icons.remove, size: 12, color: Colors.white70),
            onPressed: () {
              final next = (value - step).clamp(minVal, 10.0);
              onChanged((next * 100).round() / 100.0);
            },
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 8)),
                Text(
                  '${value.toStringAsFixed(2)}m',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF00E5FF)),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            icon: const Icon(Icons.add, size: 12, color: Colors.white70),
            onPressed: () {
              final next = value + step;
              onChanged((next * 100).round() / 100.0);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF90A4AE),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAreaRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF00E5FF) : Colors.white,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildIssueCard(ValidationIssue issue) {
    Color cardColor;
    IconData icon;

    switch (issue.severity) {
      case ValidationSeverity.error:
        cardColor = const Color(0xFFEF5350);
        icon = Icons.cancel;
        break;
      case ValidationSeverity.warning:
        cardColor = const Color(0xFFFFB74D);
        icon = Icons.warning;
        break;
      case ValidationSeverity.info:
        cardColor = const Color(0xFF29B6F6);
        icon = Icons.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardColor.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cardColor, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              issue.message,
              style: TextStyle(color: cardColor, fontSize: 10, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallProperties(Wall wall, FloorEditorNotifier notifier, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildPropertyRow(lang == 'es' ? 'Longitud' : 'Length', '${wall.length.toStringAsFixed(2)} m'),
              _buildPropertyRow(lang == 'es' ? 'Espesor computable' : 'Thickness', '${wall.thickness.toStringAsFixed(3)} m'),
              _buildPropertyRow(lang == 'es' ? 'Altura' : 'Height', '${wall.height.toStringAsFixed(2)} m'),
              _buildPropertyRow(lang == 'es' ? 'Huella en planta' : 'Footprint', '${(wall.length * wall.thickness).toStringAsFixed(2)} m²'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          lang == 'es' ? 'Tipo de Muro / Régimen de Propiedad:' : 'Wall Type & Property:',
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text(lang == 'es' ? 'Muro Propio (0.15m)' : 'Private Wall (0.15m)', style: const TextStyle(fontSize: 10)),
              selected: (wall.thickness - 0.15).abs() < 0.01,
              selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
              onSelected: (_) => notifier.setWallThickness(wall.id, 0.15),
            ),
            ChoiceChip(
              label: Text(lang == 'es' ? 'Medianero Compartido (0.075m)' : 'Shared Party Wall (0.075m)', style: const TextStyle(fontSize: 10)),
              selected: (wall.thickness - 0.075).abs() < 0.01,
              selectedColor: const Color(0xFFFFB300).withOpacity(0.25),
              onSelected: (_) => notifier.setWallThickness(wall.id, 0.075),
            ),
            ChoiceChip(
              label: Text(lang == 'es' ? 'Tabique (0.10m)' : 'Partition (0.10m)', style: const TextStyle(fontSize: 10)),
              selected: (wall.thickness - 0.10).abs() < 0.01,
              selectedColor: const Color(0xFF4CAF50).withOpacity(0.25),
              onSelected: (_) => notifier.setWallThickness(wall.id, 0.10),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF5350),
              side: const BorderSide(color: Color(0xFFEF5350)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () {
              notifier.deleteWall(wall.id);
            },
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(
              lang == 'es' ? 'Eliminar Muro (Hacer Abierto)' : 'Delete Wall (Make Open)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

