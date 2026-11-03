import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/editor_canvas_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/furniture_catalog_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/project_area_schedule_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties_panel.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/space_catalog_dialog.dart';
import 'package:trazzik/features/floors/data/supabase_floor_repository.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/projects/presentation/screens/lot_setup_screen.dart';
import 'package:trazzik/features/plan_export/presentation/screens/technical_plan_export_screen.dart';
import 'package:trazzik/features/viewer_3d/presentation/screens/viewer_3d_screen.dart';
import 'package:trazzik/features/ai_advisor/presentation/widgets/architectural_audit_dialog.dart';
import 'package:trazzik/features/ai_advisor/presentation/widgets/renovation_planner_dialog.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/multi_story_brief_dialog.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/starter_layout_dialog.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _isSaving = false;
  String? _lastFittedLotId;

  void _showFloorSettingsDialog(
    BuildContext context,
    Floor floor,
    FloorEditorNotifier notifier,
    String lang, {
    bool canDelete = false,
  }) {
    final nameCtrl = TextEditingController(text: floor.name);
    final heightCtrl =
        TextEditingController(text: floor.heightMeters.toStringAsFixed(2));
    final levelCtrl =
        TextEditingController(text: floor.levelMeters.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Row(
            children: [
              const Icon(Icons.tune, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.tr('floor_settings', lang),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('floor_name', lang),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: heightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('floor_height', lang),
                    border: const OutlineInputBorder(),
                    suffixText: 'm',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: levelCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('level_elevation', lang),
                    border: const OutlineInputBorder(),
                    suffixText: 'm',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (canDelete)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
                onPressed: () {
                  notifier.deleteDesignVariant(floor.id);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang == 'es' ? 'Variante / piso eliminado.' : 'Variant / floor removed.',
                      ),
                    ),
                  );
                },
                child: Text(lang == 'es' ? 'Eliminar Piso/Variante' : 'Delete Variant'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppStrings.tr('cancel', lang)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A192F),
              ),
              onPressed: () {
                final newName = nameCtrl.text.trim().isNotEmpty
                    ? nameCtrl.text.trim()
                    : floor.name;
                final newHeight =
                    double.tryParse(heightCtrl.text.trim()) ?? floor.heightMeters;
                final newLevel =
                    double.tryParse(levelCtrl.text.trim()) ?? floor.levelMeters;
                notifier.updateFloorProperties(
                  name: newName,
                  heightMeters: newHeight,
                  levelMeters: newLevel,
                );
                Navigator.of(ctx).pop();
              },
              child: Text(
                AppStrings.tr('save_floor_settings', lang),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateVariantDialog(
    BuildContext context,
    FloorEditorNotifier notifier,
    FloorEditorState state,
    String lang,
  ) {
    final variantCtrl = TextEditingController(
      text: lang == 'es'
          ? '${state.floor.name} - Opción B'
          : '${state.floor.name} - Option B',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            const Icon(Icons.alt_route, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang == 'es' ? 'Nueva Variante de Diseño' : 'New Design Variant',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'es'
                  ? 'Duplica el piso actual para simular una distribución alternativa de recintos o muebles sin alterar el diseño base.'
                  : 'Duplicates the current floor to simulate an alternative layout or furniture arrangement without altering the base design.',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: variantCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: lang == 'es' ? 'Nombre del Escenario / Variante' : 'Variant / Scenario Name',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF00E5FF)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.tr('cancel', lang)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF0A192F),
            ),
            icon: const Icon(Icons.copy_all, size: 16),
            label: Text(
              lang == 'es' ? 'Crear y Simular' : 'Create & Simulate',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              final name = variantCtrl.text.trim();
              if (name.isNotEmpty) {
                notifier.createDesignVariant(name);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF00E5FF),
                    content: Text(
                      lang == 'es'
                          ? 'Se creó el escenario "$name". ¡Podés experimentar libremente!'
                          : 'Scenario "$name" created. Experiment freely!',
                      style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDemarcateWallsDialog(
    BuildContext context,
    FloorEditorNotifier notifier,
    FloorEditorState state,
    String lang,
  ) {
    final existingWallsCount = state.floor.walls.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            const Icon(Icons.fence, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.tr('demarcate_walls_title', lang),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr('demarcate_walls_desc', lang),
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang == 'es'
                          ? 'Muros actuales en este piso: $existingWallsCount'
                          : 'Current walls on this floor: $existingWallsCount',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (existingWallsCount > 0)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
              onPressed: () {
                notifier.clearAllWalls();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang == 'es' ? 'Muros eliminados.' : 'Walls cleared.'),
                  ),
                );
              },
              child: Text(AppStrings.tr('clear_walls', lang)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.tr('cancel', lang)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF0A192F),
            ),
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: Text(
              AppStrings.tr('generate_walls', lang),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              final count = notifier.generateWallsFromModules();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF2E7D32),
                  content: Text(
                    lang == 'es'
                        ? 'Se demarcaron $count muros perimetrales e interiores.'
                        : 'Demarcated $count perimeter and interior walls.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveFloorToSupabase() async {
    final state = ref.read(floorEditorProvider);
    final lang = ref.read(appLocaleProvider);

    setState(() => _isSaving = true);
    try {
      final repo = SupabaseFloorRepository();
      await repo.saveFloor(state.floor);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(AppStrings.tr('floor_saved', lang))),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${AppStrings.tr('error_saving_floor', lang)} $e'),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _fitToLotResponsive(BuildContext context, FloorEditorNotifier notifier) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 720;
    final canvasSize = Size(
      math.max(300.0, isMobile ? mediaQuery.size.width : mediaQuery.size.width - 340.0),
      math.max(300.0, mediaQuery.size.height - 80.0),
    );
    notifier.fitToLot(canvasSize);
  }

  void _showMobilePropertiesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: PropertiesPanel(
                    isSheet: true,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMobileMenuItems(
    BuildContext context,
    FloorEditorState state,
    String lang,
  ) {
    return [
      // Historial
      PopupMenuItem(
        value: 'undo',
        enabled: state.undoStack.isNotEmpty,
        child: Row(
          children: [
            Icon(Icons.undo, size: 18, color: state.undoStack.isNotEmpty ? const Color(0xFF00E5FF) : Colors.grey),
            const SizedBox(width: 8),
            Text(AppStrings.tr('undo', lang)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'redo',
        enabled: state.redoStack.isNotEmpty,
        child: Row(
          children: [
            Icon(Icons.redo, size: 18, color: state.redoStack.isNotEmpty ? const Color(0xFF00E5FF) : Colors.grey),
            const SizedBox(width: 8),
            Text(AppStrings.tr('redo', lang)),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Diagnóstico y Consultoría IA
      PopupMenuItem(
        value: 'ai_audit',
        child: Row(
          children: [
            const Icon(Icons.psychology, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Auditoría y Asesoría IA' : 'AI Architectural Audit'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'renovation_planner',
        child: Row(
          children: [
            const Icon(Icons.checklist_rtl_rounded, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Plan de Obra y Materiales IA' : 'AI Renovation & Materials'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'area_schedule',
        child: Row(
          children: [
            const Icon(Icons.table_chart, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(AppStrings.tr('area_schedule', lang)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'viewer_3d',
        child: Row(
          children: [
            const Icon(Icons.view_in_ar, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Ver Maqueta 3D' : '3D Axonometric Model'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'export_pdf',
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Exportar Lámina PDF' : 'Export Technical Plan (PDF)'),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Herramientas Arquitectónicas
      PopupMenuItem(
        value: 'demarcate_walls',
        child: Row(
          children: [
            const Icon(Icons.fence, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(AppStrings.tr('demarcate_walls_tooltip', lang)),
          ],
        ),
      ),
      if (state.selectedModule != null)
        PopupMenuItem(
          value: 'furnish',
          child: Row(
            children: [
              const Icon(Icons.chair, size: 18, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text(lang == 'es' ? 'Amoblar ${state.selectedModule!.name}' : 'Furnish Room'),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'zoning_guide',
        child: Row(
          children: [
            Icon(
              state.showZoningGuide ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              size: 18,
              color: const Color(0xFFFFB300),
            ),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Guía de Zonificación y Sol' : 'Zoning & Sun Guide'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'starter_layout',
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Esquemas Base de Distribución' : 'Starter Layout Wizard'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'multi_story',
        child: Row(
          children: [
            const Icon(Icons.cottage_outlined, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Programa Vivienda 2 Pisos' : '2-Story Brief Wizard'),
          ],
        ),
      ),
      if (state.project != null)
        PopupMenuItem(
          value: 'lot_setup',
          child: Row(
            children: [
              const Icon(Icons.straighten, size: 18, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text(AppStrings.tr('lot_settings', lang)),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'create_variant',
        child: Row(
          children: [
            const Icon(Icons.alt_route, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Nueva Variante de Diseño' : 'New Design Variant'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'floor_settings',
        child: Row(
          children: [
            const Icon(Icons.tune, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(AppStrings.tr('floor_settings', lang)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'fit_to_lot',
        child: Row(
          children: [
            const Icon(Icons.fit_screen, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Centrar y Ajustar al Lote' : 'Fit to Lot'),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Transformaciones de Orientación
      PopupMenuItem(
        value: 'invert_vertical',
        child: Row(
          children: [
            const Icon(Icons.swap_vert, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Espejo Frente / Fondo (Vertical)' : 'Mirror Front / Back'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'invert_horizontal',
        child: Row(
          children: [
            const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Espejo Izquierda / Derecha' : 'Mirror Left / Right'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'rotate_180',
        child: Row(
          children: [
            const Icon(Icons.rotate_90_degrees_ccw, size: 18, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Rotar Plano 180°' : 'Rotate 180°'),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Sistema y Ajustes
      PopupMenuItem(
        value: 'clear',
        child: Row(
          children: [
            const Icon(Icons.delete_sweep, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Text(AppStrings.tr('clear_floor', lang)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'reset',
        child: Row(
          children: [
            const Icon(Icons.restart_alt, size: 18),
            const SizedBox(width: 8),
            Text(AppStrings.tr('reset_scenario', lang)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'toggle_lang',
        child: Row(
          children: [
            const Icon(Icons.language, size: 18),
            const SizedBox(width: 8),
            Text(AppStrings.tr('lang_switch', lang)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'toggle_theme',
        child: Row(
          children: [
            const Icon(Icons.brightness_medium, size: 18),
            const SizedBox(width: 8),
            Text(lang == 'es' ? 'Cambiar Tema (Claro / Oscuro)' : 'Toggle Theme'),
          ],
        ),
      ),
    ];
  }

  void _handleMobileMenuAction(
    BuildContext context,
    String action,
    FloorEditorNotifier notifier,
    FloorEditorState state,
    String lang,
    AppThemeNotifier themeNotifier,
    AppLocaleNotifier localeNotifier,
  ) {
    switch (action) {
      case 'undo':
        if (state.undoStack.isNotEmpty) notifier.undo();
        break;
      case 'redo':
        if (state.redoStack.isNotEmpty) notifier.redo();
        break;
      case 'ai_audit':
        ArchitecturalAuditDialog.show(context);
        break;
      case 'renovation_planner':
        RenovationPlannerDialog.show(context);
        break;
      case 'area_schedule':
        ProjectAreaScheduleDialog.show(context);
        break;
      case 'viewer_3d':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const Viewer3dScreen()),
        );
        break;
      case 'export_pdf':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TechnicalPlanExportScreen()),
        );
        break;
      case 'demarcate_walls':
        _showDemarcateWallsDialog(context, notifier, state, lang);
        break;
      case 'furnish':
        if (state.selectedModule != null) {
          FurnitureCatalogDialog.show(context, state.selectedModule!.id);
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
        if (state.project != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LotSetupScreen(project: state.project!)),
          );
        }
        break;
      case 'create_variant':
        _showCreateVariantDialog(context, notifier, state, lang);
        break;
      case 'floor_settings':
        _showFloorSettingsDialog(
          context,
          state.floor,
          notifier,
          lang,
          canDelete: state.allFloors.length > 1,
        );
        break;
      case 'fit_to_lot':
        _fitToLotResponsive(context, notifier);
        break;
      case 'invert_vertical':
        notifier.invertFloorVertical();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00E5FF),
            content: Text(
              lang == 'es'
                  ? 'Se invirtió la orientación Frente/Fondo (Espejo vertical).'
                  : 'Front/Back orientation inverted.',
              style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
            ),
          ),
        );
        break;
      case 'invert_horizontal':
        notifier.invertFloorHorizontal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00E5FF),
            content: Text(
              lang == 'es'
                  ? 'Se invirtió Izquierda/Derecha (Espejo horizontal).'
                  : 'Left/Right orientation inverted.',
              style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
            ),
          ),
        );
        break;
      case 'rotate_180':
        notifier.rotateFloor180();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00E5FF),
            content: Text(
              lang == 'es' ? 'Se rotó el plano 180°.' : 'Floor plan rotated 180°.',
              style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
            ),
          ),
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

  Widget _buildMobileAppBarTitle(
    BuildContext context,
    FloorEditorState state,
    FloorEditorNotifier notifier,
    String lang,
  ) {
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
        if (state.allFloors.isNotEmpty) ...[
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    isExpanded: true,
                    value: state.allFloors.any((f) => f.id == state.floor.id)
                        ? state.floor.id
                        : state.allFloors.first.id,
                    dropdownColor: Theme.of(context).cardColor,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF), size: 18),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    items: state.allFloors.map((f) {
                      return DropdownMenuItem<String>(
                        value: f.id,
                        child: Text(f.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (newFloorId) {
                      if (newFloorId != null) {
                        notifier.switchFloor(newFloorId);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.alt_route, size: 17, color: Color(0xFF00E5FF)),
            tooltip: lang == 'es' ? 'Nueva Variante' : 'New Variant',
            onPressed: () => _showCreateVariantDialog(context, notifier, state, lang),
          ),
        ]
        else
          Flexible(
            child: Text(
              state.floor.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildMobileAppBarActions(
    BuildContext context,
    FloorEditorState state,
    FloorEditorNotifier notifier,
    String lang,
    AppThemeNotifier themeNotifier,
    AppLocaleNotifier localeNotifier,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.add_circle, size: 22, color: Color(0xFF00E5FF)),
        tooltip: AppStrings.tr('add_space', lang),
        onPressed: () => SpaceCatalogDialog.show(context),
      ),
      IconButton(
        icon: _isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
              )
            : const Icon(Icons.cloud_upload_outlined, size: 20, color: Color(0xFF00E5FF)),
        tooltip: AppStrings.tr('save_floor', lang),
        onPressed: _isSaving ? null : _saveFloorToSupabase,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        tooltip: 'Herramientas',
        onSelected: (val) => _handleMobileMenuAction(
          context,
          val,
          notifier,
          state,
          lang,
          themeNotifier,
          localeNotifier,
        ),
        itemBuilder: (ctx) => _buildMobileMenuItems(context, state, lang),
      ),
      const SizedBox(width: 4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final lang = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeProvider);
    final themeNotifier = ref.read(appThemeProvider.notifier);
    final localeNotifier = ref.read(appLocaleProvider.notifier);

    final isMobile = MediaQuery.of(context).size.width < 720;

    // Auto-ajustar encuadre al cargar o cambiar de lote/proyecto
    final lotId = state.lot.id;
    if (_lastFittedLotId != lotId) {
      _lastFittedLotId = lotId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitToLotResponsive(context, notifier);
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: isMobile
            ? _buildMobileAppBarTitle(context, state, notifier, lang)
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
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

            // Proyecto Activo (Siempre visible, con ancho acotado)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment, size: 14, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        state.project?.name ?? (lang == 'es' ? 'Proyecto' : 'Project'),
                        style: const TextStyle(
                          color: Colors.white,
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

            // Selector de Piso Activo (Planta de Arquitectura)
            if (state.allFloors.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 135),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      isExpanded: true,
                      value: state.allFloors.any((f) => f.id == state.floor.id)
                          ? state.floor.id
                          : state.allFloors.first.id,
                      dropdownColor: Theme.of(context).cardColor,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF), size: 18),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      items: state.allFloors.map((f) {
                        return DropdownMenuItem<String>(
                          value: f.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.layers, size: 13, color: Color(0xFF00E5FF)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  f.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newFloorId) {
                        if (newFloorId != null) {
                          notifier.switchFloor(newFloorId);
                        }
                      },
                    ),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.alt_route, size: 17, color: Color(0xFF00E5FF)),
                tooltip: lang == 'es'
                    ? 'Crear Variante de Diseño (Simulación)'
                    : 'Create Design Variant (Simulation)',
                onPressed: () => _showCreateVariantDialog(context, notifier, state, lang),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.tune, size: 17, color: Color(0xFF00E5FF)),
                tooltip: AppStrings.tr('floor_settings', lang),
                onPressed: () => _showFloorSettingsDialog(
                  context,
                  state.floor,
                  notifier,
                  lang,
                  canDelete: state.allFloors.length > 1,
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers, size: 13, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 5),
                    Text(
                      state.floor.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: isMobile
            ? _buildMobileAppBarActions(
                context,
                state,
                notifier,
                lang,
                themeNotifier,
                localeNotifier,
              )
            : [
          // Auditoría y Asesoría Arquitectónica IA
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.psychology, size: 20, color: Color(0xFF00E5FF)),
            tooltip: lang == 'es'
                ? 'Auditoría y Asesoría Arquitectónica IA'
                : 'AI Architectural Audit & Advisory',
            onPressed: () => ArchitecturalAuditDialog.show(context),
          ),

          // Planificador de Obra, Materiales y Cuadrilla IA
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.checklist_rtl_rounded, size: 20, color: Color(0xFF00E5FF)),
            tooltip: lang == 'es'
                ? 'Plan de Obra, Materiales y Cuadrilla IA'
                : 'AI Renovation, Materials & Crew Planner',
            onPressed: () => RenovationPlannerDialog.show(context),
          ),

          // Cuadro General de Superficies del Proyecto
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.table_chart, size: 19, color: Color(0xFF00E5FF)),
            tooltip: AppStrings.tr('area_schedule', lang),
            onPressed: () => ProjectAreaScheduleDialog.show(context),
          ),

          // Guía de Zonificación y Asoleamiento
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              state.showZoningGuide ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              size: 19,
              color: state.showZoningGuide ? const Color(0xFFFFB300) : const Color(0xFF00E5FF),
            ),
            tooltip: lang == 'es'
                ? (state.showZoningGuide
                    ? 'Ocultar Guía de Zonificación'
                    : 'Ver Guía de Zonificación y Asoleamiento')
                : 'Zoning & Orientation Guide',
            onPressed: () => notifier.toggleZoningGuide(),
          ),

          // Demarcar Muros de Recintos
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.fence, size: 19, color: Color(0xFF00E5FF)),
            tooltip: AppStrings.tr('demarcate_walls_tooltip', lang),
            onPressed: () => _showDemarcateWallsDialog(context, notifier, state, lang),
          ),

          // Amoblar Recinto Seleccionado
          if (state.selectedModule != null)
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.chair, size: 19, color: Color(0xFF00E5FF)),
              tooltip: lang == 'es'
                  ? 'Amoblar ${state.selectedModule!.name}'
                  : 'Furnish ${state.selectedModule!.name}',
              onPressed: () => FurnitureCatalogDialog.show(context, state.selectedModule!.id),
            ),

          // Maqueta Axonométrica 3D
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.view_in_ar, size: 20, color: Color(0xFF00E5FF)),
            tooltip: lang == 'es' ? 'Ver Maqueta 3D Axonométrica' : '3D Axonometric Model',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const Viewer3dScreen(),
                ),
              );
            },
          ),

          // Exportar Plano Técnico PDF / Lámina Imprimible
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.picture_as_pdf, size: 20, color: Color(0xFF00E5FF)),
            tooltip: lang == 'es'
                ? 'Exportar Lámina Técnica (PDF)'
                : 'Export Technical Plan (PDF)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TechnicalPlanExportScreen(),
                ),
              );
            },
          ),

          // Deshacer / Rehacer
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.undo, size: 18),
            tooltip: AppStrings.tr('undo', lang),
            onPressed: state.undoStack.isNotEmpty ? () => notifier.undo() : null,
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.redo, size: 18),
            tooltip: AppStrings.tr('redo', lang),
            onPressed: state.redoStack.isNotEmpty ? () => notifier.redo() : null,
          ),

          // Controles de Zoom
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.zoom_out, size: 18),
            tooltip: AppStrings.tr('zoom_out', lang),
            onPressed: () => notifier.updateZoom(state.zoom - 5.0),
          ),
          Text(
            '${(state.zoom / 35.0 * 100).round()}%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.zoom_in, size: 18),
            tooltip: AppStrings.tr('zoom_in', lang),
            onPressed: () => notifier.updateZoom(state.zoom + 5.0),
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.fit_screen, size: 18, color: Color(0xFF00E5FF)),
            tooltip: lang == 'es' ? 'Ajustar al Lote' : 'Fit to Lot',
            onPressed: () => _fitToLotResponsive(context, notifier),
          ),

          const SizedBox(width: 4),

          // Botón Principal: + Agregar Espacio
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A192F),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              icon: const Icon(Icons.add, size: 15),
              label: Text(AppStrings.tr('add_space', lang)),
              onPressed: () => SpaceCatalogDialog.show(context),
            ),
          ),

          // Botón: Guardar en Supabase
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 15),
              label: Text(AppStrings.tr('save_floor', lang)),
              onPressed: _isSaving ? null : _saveFloorToSupabase,
            ),
          ),

          // Menú Más Opciones (Asistentes, Transformaciones, Limpieza)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: 'Más Opciones',
            onSelected: (val) {
              if (val == 'lot_setup' && state.project != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LotSetupScreen(project: state.project!)),
                );
              } else if (val == 'starter_layout') {
                StarterLayoutDialog.show(context);
              } else if (val == 'multi_story') {
                MultiStoryBriefDialog.show(context);
              } else if (val == 'invert_vertical') {
                notifier.invertFloorVertical();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF00E5FF),
                    content: Text(
                      lang == 'es'
                          ? 'Se invirtió la orientación Frente/Fondo (Espejo vertical).'
                          : 'Front/Back orientation inverted.',
                      style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              } else if (val == 'invert_horizontal') {
                notifier.invertFloorHorizontal();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF00E5FF),
                    content: Text(
                      lang == 'es'
                          ? 'Se invirtió Izquierda/Derecha (Espejo horizontal).'
                          : 'Left/Right orientation inverted.',
                      style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              } else if (val == 'rotate_180') {
                notifier.rotateFloor180();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF00E5FF),
                    content: Text(
                      lang == 'es'
                          ? 'Se rotó el plano 180°.'
                          : 'Floor plan rotated 180°.',
                      style: const TextStyle(color: Color(0xFF0A192F), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              } else if (val == 'clear') {
                notifier.clearAllModules();
              } else if (val == 'reset') {
                notifier.resetToMVP();
              }
            },
            itemBuilder: (ctx) => [
              if (state.project != null)
                PopupMenuItem(
                  value: 'lot_setup',
                  child: Row(
                    children: [
                      const Icon(Icons.straighten, size: 18, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 8),
                      Text(AppStrings.tr('lot_settings', lang)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'starter_layout',
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 8),
                    Text(lang == 'es' ? 'Esquemas Base de Distribución' : 'Starter Layout Wizard'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'multi_story',
                child: Row(
                  children: [
                    const Icon(Icons.cottage_outlined, size: 18, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 8),
                    Text(lang == 'es' ? 'Programa Vivienda 2 Pisos' : '2-Story Brief Wizard'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'invert_vertical',
                child: Row(
                  children: [
                    const Icon(Icons.swap_vert, size: 18, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 8),
                    Text(lang == 'es' ? 'Espejo Frente / Fondo (Vertical)' : 'Mirror Front / Back (Vertical)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'invert_horizontal',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 8),
                    Text(lang == 'es' ? 'Espejo Izquierda / Derecha (Horizontal)' : 'Mirror Left / Right (Horizontal)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rotate_180',
                child: Row(
                  children: [
                    const Icon(Icons.rotate_90_degrees_ccw, size: 18, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 8),
                    Text(lang == 'es' ? 'Rotar Plano 180° (Giro Completo)' : 'Rotate 180° (Full Turn)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(AppStrings.tr('clear_floor', lang)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.restart_alt, size: 18),
                    const SizedBox(width: 8),
                    Text(AppStrings.tr('reset_scenario', lang)),
                  ],
                ),
              ),
            ],
          ),

          // Toggle Idioma
          TextButton.icon(
            onPressed: () => localeNotifier.toggleLocale(),
            icon: const Icon(Icons.language, size: 18),
            label: Text(
              AppStrings.tr('lang_switch', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          // Toggle Tema
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? AppStrings.tr('theme_light', lang)
                : AppStrings.tr('theme_dark', lang),
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isMobile
          ? const EditorCanvas2D()
          : const Row(
              children: [
                Expanded(child: EditorCanvas2D()),
                PropertiesPanel(),
              ],
            ),
      bottomNavigationBar: isMobile
          ? SafeArea(
              top: false,
              child: InkWell(
                onTap: () => _showMobilePropertiesSheet(context),
                child: Container(
                  height: 44,
                  color: const Color(0xFF181B22),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF00E5FF), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.selectedModule != null
                              ? '${state.selectedModule!.name} (${state.selectedModule!.area.toStringAsFixed(1)} m²)'
                              : state.selectedWall != null
                                  ? (lang == 'es' ? 'Muro (${state.selectedWall!.length.toStringAsFixed(2)} m)' : 'Wall')
                                  : (lang == 'es'
                                      ? 'Piso: ${state.floor.calculatedBuiltArea.toStringAsFixed(1)} m² | ${state.floor.modules.length} esp.'
                                      : 'Floor: ${state.floor.calculatedBuiltArea.toStringAsFixed(1)} m² | ${state.floor.modules.length} sp.'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (state.issues.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: state.issues.any((i) => i.severity.name == 'error')
                                ? const Color(0xFFEF5350)
                                : const Color(0xFFFFB300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${state.issues.length}',
                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lang == 'es' ? 'Propiedades' : 'Properties',
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.keyboard_arrow_up, color: Color(0xFF00E5FF), size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              height: 28,
              color: const Color(0xFF181B22),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cuadrícula: 5 cm (magnética) | 10 cm / 50 cm / 1.00 m | Coordenadas: Metros (m)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  Text(
                    'Espacios: ${state.floor.modules.length} | Alertas: ${state.issues.length}',
                    style: TextStyle(
                      color: state.issues.any((i) => i.severity.name == 'error')
                          ? const Color(0xFFEF5350)
                          : const Color(0xFF81C784),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
