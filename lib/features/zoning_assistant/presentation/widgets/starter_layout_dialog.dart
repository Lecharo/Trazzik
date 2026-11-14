import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/zoning_assistant/domain/starter_layout_template.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/multi_story_brief_dialog.dart';

/// Diálogo interactivo del Asistente de Distribución Inicial para lote vacío.
class StarterLayoutDialog extends ConsumerStatefulWidget {
  const StarterLayoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const StarterLayoutDialog(),
    );
  }

  @override
  ConsumerState<StarterLayoutDialog> createState() => _StarterLayoutDialogState();
}

class _StarterLayoutDialogState extends ConsumerState<StarterLayoutDialog> {
  StarterLayoutType _selectedType = StarterLayoutType.compact2Bedrooms;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lang = ref.watch(appLocaleProvider);
    final isEn = lang == 'en';
    final state = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final hasExistingModules = state.floor.modules.isNotEmpty;

    return Dialog(
      backgroundColor: colors.panelBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome, color: colors.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn
                            ? 'Starter Layout Assistant'
                            : 'Asistente de Distribución Inicial',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEn
                            ? 'Select a functional architectural layout tailored to your lot'
                            : 'Seleccione un esquema arquitectónico funcional adaptado al lote',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
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

            const SizedBox(height: 14),

            // Banner directo a Vivienda de 2 Pisos
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                MultiStoryBriefDialog.show(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.layers, color: colors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn
                                ? 'Planning a 2-Story Residence?'
                                : '¿Proyecta una Vivienda de 2 Pisos?',
                            style: TextStyle(
                              color: colors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            isEn
                                ? 'Configure front garage, ground suite, upper bedrooms and coordinated stairs.'
                                : 'Configure garaje al frente, suite abajo, dormitorios arriba y escaleras coordinadas.',
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.accent, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tarjetas de Plantillas (Desplazables)
            Flexible(
              child: SingleChildScrollView(
                child: RadioGroup<StarterLayoutType>(
                  groupValue: _selectedType,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...StarterLayoutTemplate.templates.map((tpl) {
                        final isSelected = tpl.type == _selectedType;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => setState(() => _selectedType = tpl.type),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.accent.withValues(alpha: 0.12)
                                    : colors.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? colors.accent
                                      : colors.borderSubtle,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Radio<StarterLayoutType>(
                                    value: tpl.type,
                                    activeColor: colors.accent,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            tpl.title,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colors.accent.withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tpl.tag,
                                              style: TextStyle(
                                                color: colors.accent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tpl.description,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 6,
                                        children: [
                                          _buildStatChip(
                                            colors,
                                            Icons.bed,
                                            isEn
                                                ? '${tpl.bedroomsCount} Bedrooms'
                                                : '${tpl.bedroomsCount} Dormitorios',
                                          ),
                                          _buildStatChip(
                                            colors,
                                            Icons.bathtub,
                                            isEn
                                                ? '${tpl.bathroomsCount} Bathrooms'
                                                : '${tpl.bathroomsCount} Baños',
                                          ),
                                          _buildStatChip(
                                            colors,
                                            Icons.chair,
                                            isEn
                                                ? 'Starter furniture included'
                                                : 'Amoblado inicial incluido',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (hasExistingModules) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: colors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isEn
                                    ? 'Notice: Applying this layout replaces existing rooms. You can revert with Undo.'
                                    : 'Atención: Aplicar esta distribución reemplazará los recintos existentes. Se puede deshacer con el botón Deshacer (Undo).',
                                style: TextStyle(color: colors.warning, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    isEn ? 'Cancel' : 'Cancelar',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Theme.of(context).brightness == Brightness.light
                        ? Colors.white
                        : const Color(0xFF0A192F),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    isEn ? 'Generate Lot Layout' : 'Generar Esquema en el Lote',
                  ),
                  onPressed: () {
                    final selectedTpl = StarterLayoutTemplate.templates
                        .firstWhere((t) => t.type == _selectedType);
                    notifier.applyStarterLayout(selectedTpl);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        backgroundColor: colors.success,
                        content: Text(
                          isEn
                              ? 'Layout "${selectedTpl.title}" generated with starter furniture.'
                              : 'Se generó el esquema "${selectedTpl.title}" con amoblamiento base.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(AppColors colors, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.accent),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: colors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
