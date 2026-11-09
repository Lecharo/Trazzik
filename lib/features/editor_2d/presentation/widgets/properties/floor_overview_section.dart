import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/project_area_schedule_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';

class FloorOverviewSection extends ConsumerWidget {
  const FloorOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLocaleProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final colors = AppColors.of(context);

    final lotTotalArea = ref.watch(
      floorEditorProvider.select((s) => s.lot.totalArea),
    );
    final floor = ref.watch(floorEditorProvider.select((s) => s.floor));
    final floorsCount = ref.watch(
      floorEditorProvider.select(
        (s) => s.allFloors.isNotEmpty ? s.allFloors.length : 1,
      ),
    );

    final builtArea = floor.calculatedBuiltArea;
    final availableExpansion = floor.maxAllowedArea - builtArea;
    final hasWalls = floor.walls.isNotEmpty;
    final allLocked =
        floor.modules.isNotEmpty && floor.modules.every((m) => m.isLocked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertySectionHeader(title: AppStrings.tr('areas_table', lang)),
        PropertyAreaRow(
          label: AppStrings.tr('total_lot', lang),
          value: '${lotTotalArea.toStringAsFixed(1)} m²',
        ),
        PropertyAreaRow(
          label: AppStrings.tr('max_floor_allowed', lang),
          value: '${floor.maxAllowedArea.toStringAsFixed(1)} m²',
        ),
        PropertyAreaRow(
          label: AppStrings.tr('proposed_built_area', lang),
          value: '${builtArea.toStringAsFixed(2)} m²',
          highlight: true,
        ),
        PropertyAreaRow(
          label: AppStrings.tr('available_expansion', lang),
          value: '${availableExpansion.toStringAsFixed(2)} m²',
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            ),
            icon: const Icon(Icons.table_chart, size: 14),
            label: Text(
              lang == 'es'
                  ? 'Ver Cuadro Total ($floorsCount pisos)'
                  : 'View Full Schedule ($floorsCount floors)',
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
              foregroundColor: hasWalls ? colors.success : colors.accent,
              side: BorderSide(
                color: hasWalls ? colors.success : colors.accent,
              ),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            ),
            icon: const Icon(Icons.fence, size: 14),
            label: Text(
              lang == 'es'
                  ? (hasWalls
                      ? 'Muros: ${floor.walls.length} trazados (Regenerar)'
                      : 'Demarcar Muros de Recintos')
                  : (hasWalls
                      ? 'Walls: ${floor.walls.length} drawn'
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
        if (floor.modules.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    allLocked ? colors.warning : colors.textSecondary,
                side: BorderSide(
                  color: allLocked ? colors.warning : colors.borderSubtle,
                ),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              ),
              icon: Icon(allLocked ? Icons.lock : Icons.lock_open, size: 14),
              label: Text(
                lang == 'es'
                    ? (allLocked
                        ? 'Espacios Asegurados 🔒 (Desbloquear)'
                        : 'Asegurar Todos los Espacios 🔒')
                    : (allLocked
                        ? 'All Spaces Locked 🔒'
                        : 'Lock All Spaces 🔒'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                notifier.setAllModulesLocked(!allLocked);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    backgroundColor: !allLocked
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF37474F),
                    content: Text(
                      !allLocked
                          ? (lang == 'es'
                              ? 'Todos los espacios asegurados 🔒. Solo se pueden amoblar o editar detalles.'
                              : 'All spaces locked 🔒.')
                          : (lang == 'es'
                              ? 'Espacios desbloqueados para reubicar.'
                              : 'Spaces unlocked.'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
