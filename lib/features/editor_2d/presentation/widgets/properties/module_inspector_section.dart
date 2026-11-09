import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/materials/finish_material.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/demolition/domain/replacement_relationship.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/furniture_inspector_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/space_catalog_dialog.dart';
import 'package:trazzik/features/modules/domain/module.dart';

class ModuleInspectorSection extends StatefulWidget {
  final Module selectedModule;
  final String? selectedSubModuleId;
  final ReplacementRelationship? replacement;
  final FloorEditorNotifier notifier;
  final String lang;

  const ModuleInspectorSection({
    super.key,
    required this.selectedModule,
    required this.selectedSubModuleId,
    required this.replacement,
    required this.notifier,
    required this.lang,
  });

  @override
  State<ModuleInspectorSection> createState() => _ModuleInspectorSectionState();
}

class _ModuleInspectorSectionState extends State<ModuleInspectorSection> {
  final _nameController = TextEditingController();
  String? _lastModuleId;
  String? _lastSyncedName;

  @override
  void initState() {
    super.initState();
    _syncName(widget.selectedModule);
  }

  @override
  void didUpdateWidget(covariant ModuleInspectorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncName(widget.selectedModule);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncName(Module module) {
    if (_lastModuleId != module.id ||
        (_lastSyncedName != module.name &&
            _nameController.text != module.name)) {
      _lastModuleId = module.id;
      _lastSyncedName = module.name;
      _nameController.text = module.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedModule = widget.selectedModule;
    final notifier = widget.notifier;
    final lang = widget.lang;
    final replacement = widget.replacement;
    final colors = AppColors.of(context);
    final bb = selectedModule.geometry.boundingBox;
    final isOpening = selectedModule.isOpening;
    final isStairs = selectedModule.isStairs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PropertySectionHeader(
              title: AppStrings.tr('selected_element', lang),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: Icon(
                selectedModule.isLocked ? Icons.lock : Icons.lock_open,
                size: 18,
                color: selectedModule.isLocked
                    ? colors.warning
                    : colors.textSecondary,
              ),
              tooltip: selectedModule.isLocked
                  ? (lang == 'es'
                      ? 'Ubicación asegurada (Toca para desbloquear)'
                      : 'Position locked (Tap to unlock)')
                  : (lang == 'es'
                      ? 'Asegurar ubicación (Bloquear arrastre)'
                      : 'Lock position (Prevent dragging)'),
              onPressed: () {
                notifier.toggleModuleLock(selectedModule.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    backgroundColor: selectedModule.isLocked
                        ? const Color(0xFF37474F)
                        : const Color(0xFF2E7D32),
                    content: Text(
                      selectedModule.isLocked
                          ? (lang == 'es'
                              ? 'Ambiente desbloqueado: ya puedes moverlo.'
                              : 'Space unlocked.')
                          : (lang == 'es'
                              ? 'Ambiente asegurado 🔒: ya no se moverá al tocarlo.'
                              : 'Space locked 🔒.'),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        TextField(
          controller: _nameController,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            labelText: lang == 'es' ? 'Nombre del Espacio' : 'Space Name',
            labelStyle: const TextStyle(fontSize: 11),
            suffixIcon: IconButton(
              icon: Icon(Icons.check, size: 16, color: colors.accent),
              onPressed: () => notifier.setModuleName(
                selectedModule.id,
                _nameController.text.trim(),
              ),
            ),
          ),
          onChanged: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              _lastSyncedName = trimmed;
              notifier.setModuleName(selectedModule.id, trimmed);
            }
          },
          onSubmitted: (val) => notifier.setModuleName(
            selectedModule.id,
            val.trim(),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          lang == 'es' ? 'Estado Constructivo' : 'Constructive Status',
          style: TextStyle(color: colors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ChoiceChip(
              avatar: const CircleAvatar(
                backgroundColor: Color(0xFF00E5FF),
                radius: 4,
              ),
              label: Text(
                lang == 'es' ? 'Propuesto' : 'New',
                style: const TextStyle(fontSize: 10),
              ),
              selected: selectedModule.status == ElementStatus.isNew,
              selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
              onSelected: (_) => notifier.setModuleStatus(
                selectedModule.id,
                ElementStatus.isNew,
              ),
            ),
            ChoiceChip(
              avatar: const CircleAvatar(
                backgroundColor: Color(0xFF4CAF50),
                radius: 4,
              ),
              label: Text(
                lang == 'es' ? 'Conservar' : 'Preserve',
                style: const TextStyle(fontSize: 10),
              ),
              selected: selectedModule.status == ElementStatus.preserved,
              selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.25),
              onSelected: (_) => notifier.setModuleStatus(
                selectedModule.id,
                ElementStatus.preserved,
              ),
            ),
            ChoiceChip(
              avatar: const CircleAvatar(
                backgroundColor: Color(0xFFE53935),
                radius: 4,
              ),
              label: Text(
                lang == 'es' ? 'A Demoler' : 'Demolish',
                style: const TextStyle(fontSize: 10),
              ),
              selected: selectedModule.status == ElementStatus.toDemolish,
              selectedColor: const Color(0xFFE53935).withValues(alpha: 0.25),
              onSelected: (_) => notifier.setModuleStatus(
                selectedModule.id,
                ElementStatus.toDemolish,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PropertyKeyValueRow(label: 'Tipo', value: selectedModule.moduleType),
        PropertyKeyValueRow(
          label: 'Área',
          value: '${selectedModule.area.toStringAsFixed(2)} m²',
        ),
        if (!isOpening && !isStairs) ...[
          const SizedBox(height: 8),
          _buildFinishSelectorCard(
            selectedModule: selectedModule,
            notifier: notifier,
            lang: lang,
            colors: colors,
          ),
        ],
        if (selectedModule.geometry.vertices.length > 4)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.08),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.polyline,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lang == 'es'
                            ? 'Polígono Irregular (${selectedModule.geometry.vertices.length} lados)'
                            : 'Irregular Polygon (${selectedModule.geometry.vertices.length} sides)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lang == 'es'
                      ? '• Área útil construida: ${selectedModule.area.toStringAsFixed(2)} m²\n• Envolvente total: ${bb.width.toStringAsFixed(2)} × ${bb.height.toStringAsFixed(2)} m (${(bb.width * bb.height).toStringAsFixed(2)} m²)\n• Al modificar Ancho o Fondo, se escala preservando el remetido/quiebre en L.'
                      : '• Net usable area: ${selectedModule.area.toStringAsFixed(2)} m²\n• Enclosing envelope: ${bb.width.toStringAsFixed(2)} × ${bb.height.toStringAsFixed(2)} m\n• Scaling preserves the L-shaped recess.',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.borderSubtle),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.crop_square, size: 14),
                  label: Text(
                    lang == 'es'
                        ? 'Simplificar a Rectángulo'
                        : 'Flatten to Rectangle',
                    style: const TextStyle(fontSize: 10),
                  ),
                  onPressed: () =>
                      notifier.toggleLShapedNook(selectedModule.id),
                ),
              ],
            ),
          )
        else if (!isOpening && !isStairs)
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 6),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accent,
                side: BorderSide(
                  color: colors.accent.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              icon: const Icon(Icons.call_split, size: 14),
              label: Text(
                lang == 'es'
                    ? 'Crear Remetido en L (0.50m puerta)'
                    : 'Add L-shaped Nook (0.50m)',
                style: const TextStyle(fontSize: 10),
              ),
              onPressed: () => notifier.toggleLShapedNook(selectedModule.id),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          lang == 'es' ? 'Posición Cartesiana (m)' : 'Position (m)',
          style: TextStyle(color: colors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: NumericMetricStepper(
                label: 'X',
                value: bb.minX,
                enabled: !selectedModule.isLocked,
                onChanged: (newX) =>
                    notifier.setModulePosition(selectedModule.id, newX, bb.minY),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumericMetricStepper(
                label: 'Y',
                value: bb.minY,
                enabled: !selectedModule.isLocked,
                onChanged: (newY) =>
                    notifier.setModulePosition(selectedModule.id, bb.minX, newY),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          lang == 'es' ? 'Dimensiones (m)' : 'Dimensions (m)',
          style: TextStyle(color: colors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: NumericMetricStepper(
                label: lang == 'es' ? 'Ancho' : 'Width',
                value: bb.width,
                minVal: 0.10,
                enabled: !selectedModule.isLocked,
                onChanged: (newW) => notifier.setModuleDimensions(
                  selectedModule.id,
                  newW,
                  bb.height,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumericMetricStepper(
                label: lang == 'es' ? 'Fondo' : 'Depth',
                value: bb.height,
                minVal: 0.10,
                enabled: !selectedModule.isLocked,
                onChanged: (newD) => notifier.setModuleDimensions(
                  selectedModule.id,
                  bb.width,
                  newD,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent),
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: selectedModule.flipX
                      ? colors.warning
                      : colors.textSecondary,
                  side: BorderSide(
                    color: selectedModule.flipX
                        ? colors.warning
                        : colors.borderSubtle,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                ),
                onPressed: () =>
                    notifier.flipModuleHorizontal(selectedModule.id),
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
                  foregroundColor: selectedModule.flipY
                      ? colors.warning
                      : colors.textSecondary,
                  side: BorderSide(
                    color: selectedModule.flipY
                        ? colors.warning
                        : colors.borderSubtle,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
        if (isOpening) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, size: 15, color: colors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lang == 'es'
                            ? 'Ajuste Fino en Muro (±5 cm)'
                            : 'Fine Position Nudge (±5 cm)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  lang == 'es'
                      ? 'Desplaza la abertura suavemente sobre el muro sin tener que arrastrarla:'
                      : 'Nudge the opening smoothly along the wall without dragging:',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: colors.accent,
                      ),
                      tooltip:
                          lang == 'es' ? 'Izquierda (-0.05m)' : 'Left (-0.05m)',
                      style: IconButton.styleFrom(
                        backgroundColor: colors.subtleSurface,
                      ),
                      onPressed: selectedModule.isLocked
                          ? null
                          : () => notifier.setModulePosition(
                                selectedModule.id,
                                FloorEditorNotifier.snapToGrid(
                                  bb.minX - 0.05,
                                  0.01,
                                ),
                                bb.minY,
                              ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_upward,
                        size: 16,
                        color: colors.accent,
                      ),
                      tooltip: lang == 'es' ? 'Arriba (-0.05m)' : 'Up (-0.05m)',
                      style: IconButton.styleFrom(
                        backgroundColor: colors.subtleSurface,
                      ),
                      onPressed: selectedModule.isLocked
                          ? null
                          : () => notifier.setModulePosition(
                                selectedModule.id,
                                bb.minX,
                                FloorEditorNotifier.snapToGrid(
                                  bb.minY - 0.05,
                                  0.01,
                                ),
                              ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: colors.accent,
                      ),
                      tooltip:
                          lang == 'es' ? 'Abajo (+0.05m)' : 'Down (+0.05m)',
                      style: IconButton.styleFrom(
                        backgroundColor: colors.subtleSurface,
                      ),
                      onPressed: selectedModule.isLocked
                          ? null
                          : () => notifier.setModulePosition(
                                selectedModule.id,
                                bb.minX,
                                FloorEditorNotifier.snapToGrid(
                                  bb.minY + 0.05,
                                  0.01,
                                ),
                              ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: colors.accent,
                      ),
                      tooltip:
                          lang == 'es' ? 'Derecha (+0.05m)' : 'Right (+0.05m)',
                      style: IconButton.styleFrom(
                        backgroundColor: colors.subtleSurface,
                      ),
                      onPressed: selectedModule.isLocked
                          ? null
                          : () => notifier.setModulePosition(
                                selectedModule.id,
                                FloorEditorNotifier.snapToGrid(
                                  bb.minX + 0.05,
                                  0.01,
                                ),
                                bb.minY,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          FurnitureInspectorSection(
            module: selectedModule,
            selectedSubModuleId: widget.selectedSubModuleId,
            notifier: notifier,
            lang: lang,
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.borderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => notifier.duplicateModule(selectedModule.id),
                icon: const Icon(Icons.copy, size: 14),
                label: Text(
                  lang == 'es' ? 'Duplicar' : 'Duplicate',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.danger,
                  side: BorderSide(color: colors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => notifier.deleteModule(selectedModule.id),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: Text(
                  lang == 'es' ? 'Eliminar' : 'Delete',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent),
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
              lang == 'es'
                  ? 'Cerrar con Muros este Espacio'
                  : 'Enclose Space with Walls',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => SpaceCatalogDialog.show(context),
            icon: Icon(
              Icons.add_circle_outline,
              size: 16,
              color: colors.accent,
            ),
            label: Text(
              lang == 'es' ? '+ Agregar Otro Espacio' : '+ Add Another Space',
              style: TextStyle(color: colors.accent, fontSize: 11),
            ),
          ),
        ),
        if (!isOpening) ...[
          const SizedBox(height: 6),
          Text(
            selectedModule.isLocked
                ? (lang == 'es'
                    ? 'Ubicación asegurada 🔒 (desbloquea para mover):'
                    : 'Position locked 🔒:')
                : (lang == 'es'
                    ? 'Ajuste fino (±5 cm):'
                    : 'Fine adjust (±5 cm):'),
            style: TextStyle(
              color: selectedModule.isLocked
                  ? colors.warning
                  : colors.textMuted,
              fontSize: 10,
              fontWeight:
                  selectedModule.isLocked ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                color: selectedModule.isLocked
                    ? colors.borderSubtle
                    : colors.textSecondary,
                tooltip: '-5 cm X',
                onPressed: selectedModule.isLocked
                    ? null
                    : () => notifier.moveSelectedModule(-0.05, 0),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    color: selectedModule.isLocked
                        ? colors.borderSubtle
                        : colors.textSecondary,
                    tooltip: '-5 cm Y',
                    onPressed: selectedModule.isLocked
                        ? null
                        : () => notifier.moveSelectedModule(0, -0.05),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    color: selectedModule.isLocked
                        ? colors.borderSubtle
                        : colors.textSecondary,
                    tooltip: '+5 cm Y',
                    onPressed: selectedModule.isLocked
                        ? null
                        : () => notifier.moveSelectedModule(0, 0.05),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                color: selectedModule.isLocked
                    ? colors.borderSubtle
                    : colors.textSecondary,
                tooltip: '+5 cm X',
                onPressed: selectedModule.isLocked
                    ? null
                    : () => notifier.moveSelectedModule(0.05, 0),
              ),
            ],
          ),
        ],
        if (replacement != null) ...[
          const SizedBox(height: 16),
          PropertySectionHeader(
            title: AppStrings.tr('remodeling_transition', lang),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.subtleSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.transform,
                      color: colors.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.tr('parametric_replacement', lang),
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                PropertyKeyValueRow(
                  label: AppStrings.tr('replacement_type', lang),
                  value: replacement.relationshipType.name.toUpperCase(),
                ),
                PropertyKeyValueRow(
                  label: AppStrings.tr('overlap_area', lang),
                  value: '${replacement.overlapArea.toStringAsFixed(2)} m²',
                ),
                PropertyKeyValueRow(
                  label: AppStrings.tr('expanded_net_area', lang),
                  value: '+${replacement.expandedArea.toStringAsFixed(2)} m²',
                ),
                if (replacement.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    replacement.notes!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFinishSelectorCard({
    required Module selectedModule,
    required FloorEditorNotifier notifier,
    required String lang,
    required AppColors colors,
  }) {
    final floorMat = FinishMaterialCatalog.resolveFloorForModule(selectedModule);
    final wallMat = FinishMaterialCatalog.resolveWallForModule(selectedModule);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.subtleSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 14, color: colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lang == 'es'
                      ? 'Acabados 2D / 3D y Presupuesto'
                      : '2D / 3D Finishes & Budget',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'es' ? 'Piso del recinto' : 'Floor finish',
            style: TextStyle(fontSize: 9.5, color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              value: floorMat.id,
              style: TextStyle(fontSize: 11, color: colors.textPrimary),
              dropdownColor: colors.panelBackground,
              items: FinishMaterialCatalog.floors.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: m.baseColor,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.label(lang),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.setModuleFloorMaterial(selectedModule.id, val);
                }
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'es' ? 'Acabado de muros' : 'Wall finish',
            style: TextStyle(fontSize: 9.5, color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              value: wallMat.id,
              style: TextStyle(fontSize: 11, color: colors.textPrimary),
              dropdownColor: colors.panelBackground,
              items: FinishMaterialCatalog.walls.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: m.baseColor,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.label(lang),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.setModuleWallFinish(selectedModule.id, val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
