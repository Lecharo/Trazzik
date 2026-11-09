import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/floor_overview_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/module_inspector_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/validation_issues_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/wall_inspector_section.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/space_catalog_dialog.dart';
import 'package:trazzik/features/modules/domain/module.dart';

class PropertiesPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(floorEditorProvider.notifier);
    final lang = ref.watch(appLocaleProvider);
    final colors = AppColors.of(context);

    final floor = ref.watch(floorEditorProvider.select((s) => s.floor));
    final selectedModule = ref.watch(
      floorEditorProvider.select((s) => s.selectedModule),
    );
    final selectedWall = ref.watch(
      floorEditorProvider.select((s) => s.selectedWall),
    );
    final selectedSubModuleId = ref.watch(
      floorEditorProvider.select((s) => s.selectedSubModuleId),
    );

    final replacement = selectedModule != null
        ? floor.replacementRelationships
            .where((r) => r.proposedElementId == selectedModule.id)
            .firstOrNull
        : null;

    return Container(
      width: isSheet ? double.infinity : 320,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: isSheet
            ? null
            : Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                Icon(
                  Icons.architecture,
                  color: colors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        floor.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${floor.calculatedBuiltArea.toStringAsFixed(1)} m²',
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isSheet)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cerrar',
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(14, 14, 14, isSheet ? 80 : 24),
              children: [
                const FloorOverviewSection(),
                const SizedBox(height: 16),
                if (selectedWall != null)
                  WallInspectorSection(
                    wall: selectedWall,
                    notifier: notifier,
                    lang: lang,
                  )
                else if (selectedModule == null)
                  _EmptySelectionSection(
                    modules: floor.modules,
                    notifier: notifier,
                    lang: lang,
                  )
                else
                  ModuleInspectorSection(
                    selectedModule: selectedModule,
                    selectedSubModuleId: selectedSubModuleId,
                    replacement: replacement,
                    notifier: notifier,
                    lang: lang,
                  ),
                const SizedBox(height: 16),
                const ValidationIssuesSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelectionSection extends StatelessWidget {
  final List<Module> modules;
  final FloorEditorNotifier notifier;
  final String lang;

  const _EmptySelectionSection({
    required this.modules,
    required this.notifier,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final openings = modules.where((m) => m.isOpening).toList();
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertySectionHeader(title: AppStrings.tr('selected_element', lang)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            AppStrings.tr('no_selection_hint', lang),
            style: TextStyle(color: colors.textMuted, fontSize: 11),
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
        if (openings.isNotEmpty) ...[
          const SizedBox(height: 14),
          PropertySectionHeader(
            title: lang == 'es'
                ? 'Aberturas y Accesos en Planta (${openings.length})'
                : 'Openings & Doors on Floor (${openings.length})',
          ),
          Text(
            lang == 'es'
                ? 'Toca cualquier puerta para seleccionarla y ajustarla:'
                : 'Tap any door or opening to select and adjust:',
            style: TextStyle(color: colors.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 8),
          ...openings.map((op) {
            final isDoor = op.isDoor;
            final isWindow = op.isWindow;
            final bb = op.geometry.boundingBox;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(
                    color: colors.accent.withValues(alpha: 0.4),
                  ),
                  backgroundColor: colors.cardSurface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => notifier.selectModule(op.id),
                child: Row(
                  children: [
                    Icon(
                      isDoor
                          ? Icons.sensor_door
                          : (isWindow ? Icons.window : Icons.garage),
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${bb.width.toStringAsFixed(2)} × ${bb.height.toStringAsFixed(2)} m (X: ${bb.minX.toStringAsFixed(2)}, Y: ${bb.minY.toStringAsFixed(2)})',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 11,
                      color: colors.accent,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
