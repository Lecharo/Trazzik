import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/ai_advisor/presentation/widgets/architectural_audit_dialog.dart';
import 'package:trazzik/features/ai_advisor/presentation/widgets/renovation_planner_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/furniture_catalog_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/project_area_schedule_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/space_catalog_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_dialogs.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_zoom_controls.dart';
import 'package:trazzik/features/fee_proposal/presentation/widgets/architect_fee_proposal_dialog.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/plan_export/presentation/screens/technical_plan_export_screen.dart';
import 'package:trazzik/features/projects/presentation/screens/lot_setup_screen.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/multi_story_brief_dialog.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/starter_layout_dialog.dart';

class EditorAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isMobile;
  final bool isSaving;
  final VoidCallback onExit;
  final VoidCallback onSave;
  final VoidCallback onStartTour;
  final VoidCallback onFitToLot;
  final void Function({
    required Widget screen,
    required String optionName,
  }) onNavigateWithUnsavedCheck;

  const EditorAppBar({
    super.key,
    required this.isMobile,
    required this.isSaving,
    required this.onExit,
    required this.onSave,
    required this.onStartTour,
    required this.onFitToLot,
    required this.onNavigateWithUnsavedCheck,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(floorEditorProvider.notifier);
    final lang = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    final themeNotifier = ref.read(appThemeProvider.notifier);
    final localeNotifier = ref.read(appLocaleProvider.notifier);
    final colors = AppColors.of(context);

    final floorHeader = ref.watch(
      floorEditorProvider.select((s) => (id: s.floor.id, name: s.floor.name)),
    );
    final allFloors = ref.watch(floorEditorProvider.select((s) => s.allFloors));
    final dirtyFloorIds = ref.watch(
      floorEditorProvider.select((s) => s.dirtyFloorIds),
    );
    final project = ref.watch(floorEditorProvider.select((s) => s.project));
    final selectedModuleHeader = ref.watch(
      floorEditorProvider.select(
        (s) => s.selectedModule == null
            ? null
            : (id: s.selectedModule!.id, name: s.selectedModule!.name),
      ),
    );
    final isRenderedMode = ref.watch(
      floorEditorProvider.select((s) => s.isRenderedMode),
    );
    final showZoningGuide = ref.watch(
      floorEditorProvider.select((s) => s.showZoningGuide),
    );
    final canUndo = ref.watch(
      floorEditorProvider.select((s) => s.undoStack.isNotEmpty),
    );
    final canRedo = ref.watch(
      floorEditorProvider.select((s) => s.redoStack.isNotEmpty),
    );
    final hasUnsavedChanges = ref.watch(
      floorEditorProvider.select((s) => s.hasUnsavedChanges),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useCompactToolbar = isMobile || screenWidth < 1400;

    final onOpenLotSetup = project != null
        ? () => onNavigateWithUnsavedCheck(
              screen: LotSetupScreen(project: project),
              optionName: 'Configurar Lote',
            )
        : null;

    void dispatchAction(String action) {
      _executeAction(
        context: context,
        ref: ref,
        action: action,
        allFloorsCount: allFloors.length,
        onOpenLotSetup: onOpenLotSetup,
        selectedModuleId: selectedModuleHeader?.id,
        notifier: notifier,
        lang: lang,
        themeNotifier: themeNotifier,
        localeNotifier: localeNotifier,
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 20),
        tooltip: lang == 'es' ? 'Volver a Proyectos' : 'Back to Projects',
        onPressed: onExit,
      ),
      titleSpacing: 4,
      title: useCompactToolbar
          ? _buildMobileTitle(
              context: context,
              floorId: floorHeader.id,
              floorName: floorHeader.name,
              allFloors: allFloors,
              dirtyFloorIds: dirtyFloorIds,
              notifier: notifier,
              lang: lang,
              colors: colors,
            )
          : _buildDesktopTitle(
              context: context,
              ref: ref,
              floorId: floorHeader.id,
              floorName: floorHeader.name,
              allFloors: allFloors,
              dirtyFloorIds: dirtyFloorIds,
              projectName: project?.name,
              notifier: notifier,
              lang: lang,
              colors: colors,
            ),
      actions: useCompactToolbar
          ? _buildMobileActions(
              context: context,
              hasProject: project != null,
              selectedModuleName: selectedModuleHeader?.name,
              isRenderedMode: isRenderedMode,
              showZoningGuide: showZoningGuide,
              canUndo: canUndo,
              canRedo: canRedo,
              hasUnsavedChanges: hasUnsavedChanges,
              lang: lang,
              onDispatch: dispatchAction,
            )
          : _buildDesktopActions(
              context: context,
              hasProject: project != null,
              selectedModuleHeader: selectedModuleHeader,
              isRenderedMode: isRenderedMode,
              showZoningGuide: showZoningGuide,
              canUndo: canUndo,
              canRedo: canRedo,
              hasUnsavedChanges: hasUnsavedChanges,
              lang: lang,
              themeMode: themeMode,
              onDispatch: dispatchAction,
            ),
    );
  }

  List<Widget> _buildDesktopActions({
    required BuildContext context,
    required bool hasProject,
    required ({String id, String name})? selectedModuleHeader,
    required bool isRenderedMode,
    required bool showZoningGuide,
    required bool canUndo,
    required bool canRedo,
    required bool hasUnsavedChanges,
    required String lang,
    required ThemeMode themeMode,
    required ValueChanged<String> onDispatch,
  }) {
    return [
      _toolbarIconButton(
        icon: isRenderedMode ? Icons.palette : Icons.palette_outlined,
        color: isRenderedMode
            ? const Color(0xFFFFB300)
            : const Color(0xFF00E5FF),
        tooltip: lang == 'es'
            ? (isRenderedMode
                ? 'Modo Renderizado Activo (Texturas y Sombras)'
                : 'Activar Modo Plano Renderizado')
            : 'Architectural Rendered Mode',
        onPressed: () => onDispatch('toggle_render_mode'),
      ),
      _toolbarIconButton(
        icon: Icons.movie_filter_rounded,
        tooltip: lang == 'es'
            ? 'Recorrido Virtual Cinematográfico (Tour Video)'
            : 'Cinematic Virtual Tour',
        onPressed: () => onDispatch('cinematic_tour'),
      ),
      _toolbarIconButton(
        icon: Icons.psychology,
        tooltip: lang == 'es'
            ? 'Auditoría y Asesoría Arquitectónica IA'
            : 'AI Architectural Audit & Advisory',
        onPressed: () => onDispatch('ai_audit'),
      ),
      _toolbarIconButton(
        icon: Icons.checklist_rtl_rounded,
        tooltip: lang == 'es'
            ? 'Plan de Obra, Materiales y Cuadrilla IA'
            : 'AI Renovation, Materials & Crew Planner',
        onPressed: () => onDispatch('renovation_planner'),
      ),
      _toolbarIconButton(
        icon: Icons.table_chart,
        size: 19,
        tooltip: AppStrings.tr('area_schedule', lang),
        onPressed: () => onDispatch('area_schedule'),
      ),
      _toolbarIconButton(
        icon: showZoningGuide ? Icons.wb_sunny : Icons.wb_sunny_outlined,
        size: 19,
        color: showZoningGuide
            ? const Color(0xFFFFB300)
            : const Color(0xFF00E5FF),
        tooltip: lang == 'es'
            ? (showZoningGuide
                ? 'Ocultar Guía de Zonificación'
                : 'Ver Guía de Zonificación y Asoleamiento')
            : 'Zoning & Orientation Guide',
        onPressed: () => onDispatch('zoning_guide'),
      ),
      _toolbarIconButton(
        icon: Icons.fence,
        size: 19,
        tooltip: AppStrings.tr('demarcate_walls_tooltip', lang),
        onPressed: () => onDispatch('demarcate_walls'),
      ),
      if (selectedModuleHeader != null)
        _toolbarIconButton(
          icon: Icons.chair,
          size: 19,
          tooltip: lang == 'es'
              ? 'Amoblar ${selectedModuleHeader.name}'
              : 'Furnish ${selectedModuleHeader.name}',
          onPressed: () => onDispatch('furnish'),
        ),
      _toolbarIconButton(
        icon: Icons.view_in_ar,
        tooltip: lang == 'es'
            ? 'Ver Maqueta 3D Axonométrica'
            : '3D Axonometric Model',
        onPressed: () => onDispatch('viewer_3d'),
      ),
      _toolbarIconButton(
        icon: Icons.picture_as_pdf,
        tooltip: lang == 'es'
            ? 'Exportar Lámina Técnica (PDF)'
            : 'Export Technical Plan (PDF)',
        onPressed: () => onDispatch('export_pdf'),
      ),
      IconButton(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        icon: const Icon(Icons.undo, size: 18),
        tooltip: AppStrings.tr('undo', lang),
        onPressed: canUndo ? () => onDispatch('undo') : null,
      ),
      IconButton(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        icon: const Icon(Icons.redo, size: 18),
        tooltip: AppStrings.tr('redo', lang),
        onPressed: canRedo ? () => onDispatch('redo') : null,
      ),
      EditorZoomControls(onFitToLot: onFitToLot),
      const SizedBox(width: 4),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: const Color(0xFF0A192F),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          icon: const Icon(Icons.add, size: 15),
          label: Text(AppStrings.tr('add_space', lang)),
          onPressed: () => SpaceCatalogDialog.show(context),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: hasUnsavedChanges
                ? const Color(0xFFFFB300)
                : const Color(0xFF00E5FF),
            side: BorderSide(
              color: hasUnsavedChanges
                  ? const Color(0xFFFFB300)
                  : const Color(0xFF00E5FF),
              width: hasUnsavedChanges ? 1.5 : 1.0,
            ),
            backgroundColor: hasUnsavedChanges
                ? const Color(0xFFFFB300).withValues(alpha: 0.08)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          icon: isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E5FF),
                  ),
                )
              : Icon(
                  hasUnsavedChanges
                      ? Icons.cloud_upload
                      : Icons.cloud_done_outlined,
                  size: 15,
                ),
          label: Text(
            hasUnsavedChanges
                ? (lang == 'es' ? 'Guardar Cambios *' : 'Save Changes *')
                : (lang == 'es' ? 'Piso Guardado ✓' : 'Floor Saved ✓'),
          ),
          onPressed: isSaving ? null : onSave,
        ),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        tooltip: 'Más Opciones',
        onSelected: onDispatch,
        itemBuilder: (_) => _buildDesktopOverflowItems(
          hasProject: hasProject,
          lang: lang,
        ),
      ),
      TextButton.icon(
        onPressed: () => onDispatch('toggle_lang'),
        icon: const Icon(Icons.language, size: 18),
        label: Text(
          AppStrings.tr('lang_switch', lang),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      IconButton(
        tooltip: themeMode == ThemeMode.dark
            ? AppStrings.tr('theme_light', lang)
            : AppStrings.tr('theme_dark', lang),
        icon: Icon(
          themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
        ),
        onPressed: () => onDispatch('toggle_theme'),
      ),
      const SizedBox(width: 4),
    ];
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = const Color(0xFF00E5FF),
    double size = 20,
  }) {
    return IconButton(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, size: size, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildDesktopTitle({
    required BuildContext context,
    required WidgetRef ref,
    required String floorId,
    required String floorName,
    required List<Floor> allFloors,
    required Set<String> dirtyFloorIds,
    required String? projectName,
    required FloorEditorNotifier notifier,
    required String lang,
    required AppColors colors,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00E5FF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    'assets/images/trazzik_logo.jpg',
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'TRAZZIK',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: colors.subtleSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apartment, size: 14, color: colors.accent),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      projectName ?? (lang == 'es' ? 'Proyecto' : 'Project'),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (allFloors.isNotEmpty) ...[
            _buildFloorSelectorDropdown(
              context: context,
              floorId: floorId,
              allFloors: allFloors,
              dirtyFloorIds: dirtyFloorIds,
              notifier: notifier,
              colors: colors,
              maxWidth: 135,
              showLayerIcon: true,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(
                Icons.alt_route,
                size: 17,
                color: Color(0xFF00E5FF),
              ),
              tooltip: lang == 'es'
                  ? 'Crear Variante de Diseño (Simulación)'
                  : 'Create Design Variant (Simulation)',
              onPressed: () => EditorDialogs.showCreateVariantDialog(
                context: context,
                notifier: notifier,
                currentFloorName: floorName,
                lang: lang,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.tune, size: 17, color: Color(0xFF00E5FF)),
              tooltip: AppStrings.tr('floor_settings', lang),
              onPressed: () => EditorDialogs.showFloorSettingsDialog(
                context: context,
                floor: ref.read(floorEditorProvider).floor,
                notifier: notifier,
                lang: lang,
                canDelete: allFloors.length > 1,
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers, size: 13, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 5),
                  Text(
                    floorName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileTitle({
    required BuildContext context,
    required String floorId,
    required String floorName,
    required List<Floor> allFloors,
    required Set<String> dirtyFloorIds,
    required FloorEditorNotifier notifier,
    required String lang,
    required AppColors colors,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/images/trazzik_logo.jpg',
            width: 20,
            height: 20,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        if (allFloors.isNotEmpty) ...[
          Flexible(
            child: _buildFloorSelectorDropdown(
              context: context,
              floorId: floorId,
              allFloors: allFloors,
              dirtyFloorIds: dirtyFloorIds,
              notifier: notifier,
              colors: colors,
              maxWidth: 130,
              showLayerIcon: false,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(
              Icons.alt_route,
              size: 17,
              color: Color(0xFF00E5FF),
            ),
            tooltip: lang == 'es' ? 'Nueva Variante' : 'New Variant',
            onPressed: () => EditorDialogs.showCreateVariantDialog(
              context: context,
              notifier: notifier,
              currentFloorName: floorName,
              lang: lang,
            ),
          ),
        ] else
          Flexible(
            child: Text(
              floorName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildFloorSelectorDropdown({
    required BuildContext context,
    required String floorId,
    required List<Floor> allFloors,
    required Set<String> dirtyFloorIds,
    required FloorEditorNotifier notifier,
    required AppColors colors,
    required double maxWidth,
    required bool showLayerIcon,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isDense: true,
            isExpanded: true,
            value: allFloors.any((f) => f.id == floorId)
                ? floorId
                : allFloors.first.id,
            dropdownColor: Theme.of(context).cardColor,
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF00E5FF),
              size: 18,
            ),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            items: allFloors.map((f) {
              final isDirty = dirtyFloorIds.contains(f.id);
              final labelText = isDirty ? '${f.name} *' : f.name;
              return DropdownMenuItem<String>(
                value: f.id,
                child: showLayerIcon
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers,
                            size: 13,
                            color: isDirty
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF00E5FF),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              labelText,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        labelText,
                        overflow: TextOverflow.ellipsis,
                      ),
              );
            }).toList(),
            onChanged: (newFloorId) {
              if (newFloorId != null && newFloorId != floorId) {
                notifier.switchFloor(newFloorId);
              }
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMobileActions({
    required BuildContext context,
    required bool hasProject,
    required String? selectedModuleName,
    required bool isRenderedMode,
    required bool showZoningGuide,
    required bool canUndo,
    required bool canRedo,
    required bool hasUnsavedChanges,
    required String lang,
    required ValueChanged<String> onDispatch,
  }) {
    return [
      IconButton(
        icon: const Icon(
          Icons.movie_filter_rounded,
          size: 21,
          color: Color(0xFF00E5FF),
        ),
        tooltip: lang == 'es'
            ? 'Recorrido Virtual / Tour Video'
            : 'Cinematic Virtual Tour',
        onPressed: () => onDispatch('cinematic_tour'),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle, size: 22, color: Color(0xFF00E5FF)),
        tooltip: AppStrings.tr('add_space', lang),
        onPressed: () => SpaceCatalogDialog.show(context),
      ),
      IconButton(
        icon: isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E5FF),
                ),
              )
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    hasUnsavedChanges
                        ? Icons.cloud_upload
                        : Icons.cloud_done_outlined,
                    size: 20,
                    color: hasUnsavedChanges
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF00E5FF),
                  ),
                  if (hasUnsavedChanges)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5252),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
        tooltip: hasUnsavedChanges
            ? (lang == 'es'
                ? 'Guardar Cambios Pendientes'
                : 'Save Unsaved Changes')
            : (lang == 'es' ? 'Piso Guardado' : 'Floor Saved'),
        onPressed: isSaving ? null : onSave,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        tooltip: 'Herramientas',
        onSelected: onDispatch,
        itemBuilder: (_) => _buildMobileMenuItems(
          hasProject: hasProject,
          selectedModuleName: selectedModuleName,
          isRenderedMode: isRenderedMode,
          showZoningGuide: showZoningGuide,
          canUndo: canUndo,
          canRedo: canRedo,
          lang: lang,
        ),
      ),
      const SizedBox(width: 4),
    ];
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? iconColor = const Color(0xFF00E5FF),
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: enabled ? iconColor : Colors.grey,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildSharedTransformAndResetItems(
    String lang, {
    bool verboseLabels = false,
  }) {
    return [
      _menuItem(
        'invert_vertical',
        Icons.swap_vert,
        lang == 'es'
            ? 'Espejo Frente / Fondo (Vertical)'
            : (verboseLabels
                ? 'Mirror Front / Back (Vertical)'
                : 'Mirror Front / Back'),
      ),
      _menuItem(
        'invert_horizontal',
        Icons.swap_horiz,
        lang == 'es'
            ? (verboseLabels
                ? 'Espejo Izquierda / Derecha (Horizontal)'
                : 'Espejo Izquierda / Derecha')
            : (verboseLabels
                ? 'Mirror Left / Right (Horizontal)'
                : 'Mirror Left / Right'),
      ),
      _menuItem(
        'rotate_180',
        Icons.rotate_90_degrees_ccw,
        lang == 'es'
            ? (verboseLabels
                ? 'Rotar Plano 180° (Giro Completo)'
                : 'Rotar Plano 180°')
            : (verboseLabels ? 'Rotate 180° (Full Turn)' : 'Rotate 180°'),
      ),
      const PopupMenuDivider(),
      _menuItem(
        'clear',
        Icons.delete_sweep,
        AppStrings.tr('clear_floor', lang),
        iconColor: Colors.orange,
      ),
      _menuItem(
        'reset',
        Icons.restart_alt,
        AppStrings.tr('reset_scenario', lang),
        iconColor: null,
      ),
    ];
  }

  List<PopupMenuEntry<String>> _buildDesktopOverflowItems({
    required bool hasProject,
    required String lang,
  }) {
    return [
      if (hasProject)
        _menuItem(
          'lot_setup',
          Icons.straighten,
          AppStrings.tr('lot_settings', lang),
        ),
      _menuItem(
        'starter_layout',
        Icons.auto_awesome,
        lang == 'es'
            ? 'Esquemas Base de Distribución'
            : 'Starter Layout Wizard',
      ),
      _menuItem(
        'multi_story',
        Icons.cottage_outlined,
        lang == 'es' ? 'Programa Vivienda 2 Pisos' : '2-Story Brief Wizard',
      ),
      _menuItem(
        'fee_proposal',
        Icons.request_quote_outlined,
        lang == 'es'
            ? 'Cotizar Honorarios Profesionales (PDF)'
            : 'Architect Fee Proposal (PDF)',
      ),
      const PopupMenuDivider(),
      ..._buildSharedTransformAndResetItems(lang, verboseLabels: true),
    ];
  }

  List<PopupMenuEntry<String>> _buildMobileMenuItems({
    required bool hasProject,
    required String? selectedModuleName,
    required bool isRenderedMode,
    required bool showZoningGuide,
    required bool canUndo,
    required bool canRedo,
    required String lang,
  }) {
    return [
      _menuItem('undo', Icons.undo, AppStrings.tr('undo', lang), enabled: canUndo),
      _menuItem('redo', Icons.redo, AppStrings.tr('redo', lang), enabled: canRedo),
      const PopupMenuDivider(),
      _menuItem(
        'ai_audit',
        Icons.psychology,
        lang == 'es' ? 'Auditoría y Asesoría IA' : 'AI Architectural Audit',
      ),
      _menuItem(
        'renovation_planner',
        Icons.checklist_rtl_rounded,
        lang == 'es'
            ? 'Plan de Obra y Materiales IA'
            : 'AI Renovation & Materials',
      ),
      _menuItem(
        'fee_proposal',
        Icons.request_quote_outlined,
        lang == 'es'
            ? 'Cotizar Honorarios Profesionales (PDF)'
            : 'Architect Fee Proposal (PDF)',
      ),
      _menuItem(
        'cinematic_tour',
        Icons.movie_filter_rounded,
        lang == 'es'
            ? 'Recorrido Virtual (Tour Video)'
            : 'Cinematic Virtual Tour',
      ),
      _menuItem(
        'toggle_render_mode',
        isRenderedMode ? Icons.palette : Icons.palette_outlined,
        isRenderedMode
            ? (lang == 'es' ? 'Plano Técnico (Sin Render)' : 'Technical Mode')
            : (lang == 'es'
                ? 'Plano Renderizado (Texturas/Sombras)'
                : 'Rendered Mode'),
        iconColor: isRenderedMode
            ? const Color(0xFFFFB300)
            : const Color(0xFF00E5FF),
      ),
      _menuItem(
        'area_schedule',
        Icons.table_chart,
        AppStrings.tr('area_schedule', lang),
      ),
      _menuItem(
        'viewer_3d',
        Icons.view_in_ar,
        lang == 'es' ? 'Ver Maqueta 3D' : '3D Axonometric Model',
      ),
      _menuItem(
        'export_pdf',
        Icons.picture_as_pdf,
        lang == 'es' ? 'Exportar Lámina PDF' : 'Export Technical Plan (PDF)',
      ),
      const PopupMenuDivider(),
      _menuItem(
        'demarcate_walls',
        Icons.fence,
        AppStrings.tr('demarcate_walls_tooltip', lang),
      ),
      if (selectedModuleName != null)
        _menuItem(
          'furnish',
          Icons.chair,
          lang == 'es' ? 'Amoblar $selectedModuleName' : 'Furnish Room',
        ),
      _menuItem(
        'zoning_guide',
        showZoningGuide ? Icons.wb_sunny : Icons.wb_sunny_outlined,
        lang == 'es' ? 'Guía de Zonificación y Sol' : 'Zoning & Sun Guide',
        iconColor: const Color(0xFFFFB300),
      ),
      _menuItem(
        'starter_layout',
        Icons.auto_awesome,
        lang == 'es'
            ? 'Esquemas Base de Distribución'
            : 'Starter Layout Wizard',
      ),
      _menuItem(
        'multi_story',
        Icons.cottage_outlined,
        lang == 'es' ? 'Programa Vivienda 2 Pisos' : '2-Story Brief Wizard',
      ),
      if (hasProject)
        _menuItem(
          'lot_setup',
          Icons.straighten,
          AppStrings.tr('lot_settings', lang),
        ),
      _menuItem(
        'create_variant',
        Icons.alt_route,
        lang == 'es' ? 'Nueva Variante de Diseño' : 'New Design Variant',
      ),
      _menuItem(
        'floor_settings',
        Icons.tune,
        AppStrings.tr('floor_settings', lang),
      ),
      _menuItem(
        'fit_to_lot',
        Icons.fit_screen,
        lang == 'es' ? 'Centrar y Ajustar al Lote' : 'Fit to Lot',
      ),
      const PopupMenuDivider(),
      ..._buildSharedTransformAndResetItems(lang),
      _menuItem(
        'toggle_lang',
        Icons.language,
        AppStrings.tr('lang_switch', lang),
        iconColor: null,
      ),
      _menuItem(
        'toggle_theme',
        Icons.brightness_medium,
        lang == 'es' ? 'Cambiar Tema (Claro / Oscuro)' : 'Toggle Theme',
        iconColor: null,
      ),
    ];
  }

  void _executeAction({
    required BuildContext context,
    required WidgetRef ref,
    required String action,
    required int allFloorsCount,
    required VoidCallback? onOpenLotSetup,
    required String? selectedModuleId,
    required FloorEditorNotifier notifier,
    required String lang,
    required AppThemeNotifier themeNotifier,
    required AppLocaleNotifier localeNotifier,
  }) {
    final floor = ref.read(floorEditorProvider).floor;
    switch (action) {
      case 'undo':
        notifier.undo();
        break;
      case 'redo':
        notifier.redo();
        break;
      case 'ai_audit':
        ArchitecturalAuditDialog.show(context);
        break;
      case 'renovation_planner':
        RenovationPlannerDialog.show(context);
        break;
      case 'fee_proposal':
        ArchitectFeeProposalDialog.show(context);
        break;
      case 'cinematic_tour':
        onStartTour();
        break;
      case 'toggle_render_mode':
        notifier.toggleRenderedMode();
        break;
      case 'area_schedule':
        ProjectAreaScheduleDialog.show(context);
        break;
      case 'viewer_3d':
        onNavigateWithUnsavedCheck(
          screen: const Viewer3dScreen(),
          optionName: 'la Maqueta 3D',
        );
        break;
      case 'export_pdf':
        onNavigateWithUnsavedCheck(
          screen: const TechnicalPlanExportScreen(),
          optionName: 'Lámina Técnica (PDF)',
        );
        break;
      case 'demarcate_walls':
        EditorDialogs.showDemarcateWallsDialog(
          context: context,
          notifier: notifier,
          existingWallsCount: floor.walls.length,
          lang: lang,
        );
        break;
      case 'furnish':
        if (selectedModuleId != null) {
          FurnitureCatalogDialog.show(context, selectedModuleId);
        }
        break;
      case 'zoning_guide':
        notifier.toggleZoningGuide();
        break;
      case 'starter_layout':
        StarterLayoutDialog.show(context);
        break;
      case 'multi_story':
        MultiStoryBriefDialog.show(context);
        break;
      case 'lot_setup':
        onOpenLotSetup?.call();
        break;
      case 'create_variant':
        EditorDialogs.showCreateVariantDialog(
          context: context,
          notifier: notifier,
          currentFloorName: floor.name,
          lang: lang,
        );
        break;
      case 'floor_settings':
        EditorDialogs.showFloorSettingsDialog(
          context: context,
          floor: floor,
          notifier: notifier,
          lang: lang,
          canDelete: allFloorsCount > 1,
        );
        break;
      case 'fit_to_lot':
        onFitToLot();
        break;
      case 'invert_vertical':
        notifier.invertFloorVertical();
        _showOrientationSnackBar(
          context,
          lang == 'es'
              ? 'Se invirtió la orientación Frente/Fondo (Espejo vertical).'
              : 'Front/Back orientation inverted.',
        );
        break;
      case 'invert_horizontal':
        notifier.invertFloorHorizontal();
        _showOrientationSnackBar(
          context,
          lang == 'es'
              ? 'Se invirtió Izquierda/Derecha (Espejo horizontal).'
              : 'Left/Right orientation inverted.',
        );
        break;
      case 'rotate_180':
        notifier.rotateFloor180();
        _showOrientationSnackBar(
          context,
          lang == 'es' ? 'Se rotó el plano 180°.' : 'Floor plan rotated 180°.',
        );
        break;
      case 'clear':
        notifier.clearAllModules();
        break;
      case 'reset':
        notifier.resetToMVP();
        break;
      case 'toggle_lang':
        localeNotifier.toggleLocale();
        break;
      case 'toggle_theme':
        themeNotifier.toggleTheme();
        break;
    }
  }

  void _showOrientationSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF00E5FF),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF0A192F),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
