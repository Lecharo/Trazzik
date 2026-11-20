import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/core/validation/validation_issue.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';

class EditorBottomBar extends ConsumerWidget {
  final bool isMobile;
  final VoidCallback onOpenMobileProperties;

  const EditorBottomBar({
    super.key,
    required this.isMobile,
    required this.onOpenMobileProperties,
  });

  Widget _buildMiniToggle({
    required Key key,
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: isDark ? 0.22 : 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.70)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active
                  ? activeColor
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLocaleProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final selectedModule = ref.watch(
      floorEditorProvider.select((s) => s.selectedModule),
    );
    final selectedWall = ref.watch(
      floorEditorProvider.select((s) => s.selectedWall),
    );
    final builtArea = ref.watch(
      floorEditorProvider.select((s) => s.floor.calculatedBuiltArea),
    );
    final modulesCount = ref.watch(
      floorEditorProvider.select((s) => s.floor.modules.length),
    );
    final issues = ref.watch(floorEditorProvider.select((s) => s.issues));
    final hasGhostFloor = ref.watch(
      floorEditorProvider.select((s) => s.ghostReferenceFloor != null),
    );
    final showFloorGhost = ref.watch(
      floorEditorProvider.select((s) => s.showFloorGhost),
    );
    final showPerimeterDimensions = ref.watch(
      floorEditorProvider.select((s) => s.showPerimeterDimensions),
    );
    final isSplitView3D = ref.watch(
      floorEditorProvider.select((s) => s.isSplitView3D),
    );
    final hasErrors = issues.any((i) => i.severity == ValidationSeverity.error);

    if (isMobile) {
      return SafeArea(
        top: false,
        child: InkWell(
          onTap: onOpenMobileProperties,
          child: Container(
            height: 44,
            color: colors.panelBg,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.tune, color: colors.accentCyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedModule != null
                        ? '${selectedModule.name} (${selectedModule.area.toStringAsFixed(1)} m²)'
                        : selectedWall != null
                            ? (lang == 'es'
                                ? 'Muro (${selectedWall.length.toStringAsFixed(2)} m)'
                                : 'Wall (${selectedWall.length.toStringAsFixed(2)} m)')
                            : (lang == 'es'
                                ? 'Piso: ${builtArea.toStringAsFixed(1)} m² | $modulesCount esp.'
                                : 'Floor: ${builtArea.toStringAsFixed(1)} m² | $modulesCount sp.'),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (issues.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasErrors
                          ? const Color(0xFFEF5350)
                          : const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${issues.length}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang == 'es' ? 'Propiedades' : 'Properties',
                      style: TextStyle(
                        color: colors.accentCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: colors.accentCyan,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: colors.panelBg,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (hasGhostFloor) ...[
            _buildMiniToggle(
              key: const Key('toggle_floor_ghost_btn'),
              icon: Icons.layers_outlined,
              label: lang == 'es' ? 'Calco Piso Inf.' : 'Lower Floor Ghost',
              active: showFloorGhost,
              activeColor: const Color(0xFF818CF8),
              onTap: notifier.toggleFloorGhost,
              isDark: isDark,
            ),
            const SizedBox(width: 6),
          ],
          _buildMiniToggle(
            key: const Key('toggle_perimeter_dims_btn'),
            icon: Icons.straighten,
            label: lang == 'es' ? 'Cotas Ext.' : 'Outer Dims',
            active: showPerimeterDimensions,
            activeColor: const Color(0xFF38BDF8),
            onTap: notifier.togglePerimeterDimensions,
            isDark: isDark,
          ),
          if (screenWidth >= 900) ...[
            const SizedBox(width: 6),
            _buildMiniToggle(
              key: const Key('toggle_split_view_3d_btn'),
              icon: Icons.view_sidebar_outlined,
              label: lang == 'es' ? '2D + 3D Vivo' : 'Live 2D + 3D',
              active: isSplitView3D,
              activeColor: const Color(0xFF10B981),
              onTap: notifier.toggleSplitView3D,
              isDark: isDark,
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lang == 'es'
                  ? 'Snap: 5 cm | Flechas: ±5 cm (Shift: ±1 cm) | Ctrl+D: Duplicar | Clic der.: Menú / Pan'
                  : 'Snap: 5 cm | Arrows: ±5 cm (Shift: ±1 cm) | Ctrl+D: Duplicate | Right-click: Menu / Pan',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 10.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            lang == 'es'
                ? 'Espacios: $modulesCount | Alertas: ${issues.length}'
                : 'Rooms: $modulesCount | Alerts: ${issues.length}',
            style: TextStyle(
              color:
                  hasErrors ? const Color(0xFFEF5350) : const Color(0xFF10B981),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
