import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/cinematic_tour_overlay.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/editor_canvas_2d.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties_panel.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_app_bar.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_bottom_bar.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/toolbar/editor_dialogs.dart';
import 'package:trazzik/features/floors/data/supabase_floor_repository.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _isSaving = false;
  bool _isTourActive = false;
  String? _lastFittedLotId;

  String _describeUnsavedScope(FloorEditorState state) {
    final dirtyNames = state.dirtyFloors.map((f) => '"${f.name}"').toList();
    if (dirtyNames.isNotEmpty) {
      return dirtyNames.join(', ');
    }
    return '"${state.floor.name}"';
  }

  Future<bool> _saveFloorToSupabase() async {
    final notifier = ref.read(floorEditorProvider.notifier);
    notifier.endInteraction();
    final state = ref.read(floorEditorProvider);
    final lang = ref.read(appLocaleProvider);

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(floorRepositoryProvider);
      await repo.saveProjectFloors(
        dirtyFloors: state.floorsToSave,
        deletedFloorIds: state.deletedFloorIds,
      );
      notifier.markFloorSaved();
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
      return true;
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
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _navigateWithUnsavedCheck({
    required BuildContext context,
    required Widget screen,
    required String optionName,
  }) async {
    final state = ref.read(floorEditorProvider);
    if (!state.hasUnsavedChanges) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      return;
    }

    final scope = _describeUnsavedScope(state);
    final decision = await EditorDialogs.showUnsavedChangesDialog(
      context: context,
      title: 'Modificaciones sin Guardar',
      message:
          'Hay cambios en $scope sin guardar en la nube. ¿Deseas guardarlos antes de abrir $optionName?',
      confirmLabel: 'Guardar y Abrir',
      discardLabel: 'Abrir sin Guardar',
    );

    if (decision == 'save') {
      final success = await _saveFloorToSupabase();
      if (success && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      }
    } else if (decision == 'discard') {
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      }
    }
  }

  Future<void> _handleExitEditor(BuildContext context) async {
    final state = ref.read(floorEditorProvider);
    if (!state.hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final scope = _describeUnsavedScope(state);
    final decision = await EditorDialogs.showUnsavedChangesDialog(
      context: context,
      title: '¿Salir del Editor?',
      message:
          'Hay modificaciones en $scope que aún no se han guardado en la nube. ¿Deseas guardarlas antes de salir?',
      confirmLabel: 'Guardar y Salir',
      discardLabel: 'Salir sin Guardar',
    );

    if (decision == 'save') {
      final success = await _saveFloorToSupabase();
      if (success && context.mounted) {
        Navigator.of(context).pop();
      }
    } else if (decision == 'discard') {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _fitToLotResponsive(BuildContext context, FloorEditorNotifier notifier) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 720;
    final canvasSize = Size(
      math.max(
        300.0,
        isMobile ? mediaQuery.size.width : mediaQuery.size.width - 340.0,
      ),
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
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

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(floorEditorProvider.notifier);
    final lotId = ref.watch(floorEditorProvider.select((s) => s.lot.id));
    final isMobile = MediaQuery.sizeOf(context).width < 720;

    if (_lastFittedLotId != lotId) {
      _lastFittedLotId = lotId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitToLotResponsive(context, notifier);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExitEditor(context);
      },
      child: Scaffold(
        appBar: EditorAppBar(
          isMobile: isMobile,
          isSaving: _isSaving,
          onExit: () => _handleExitEditor(context),
          onSave: _saveFloorToSupabase,
          onStartTour: () => setState(() => _isTourActive = true),
          onFitToLot: () => _fitToLotResponsive(context, notifier),
          onNavigateWithUnsavedCheck: ({
            required Widget screen,
            required String optionName,
          }) =>
              _navigateWithUnsavedCheck(
            context: context,
            screen: screen,
            optionName: optionName,
          ),
        ),
        body: isMobile
            ? Stack(
                children: [
                  const EditorCanvas2D(),
                  if (_isTourActive)
                    RepaintBoundary(
                      child: CinematicTourOverlay(
                        onClose: () => setState(() => _isTourActive = false),
                      ),
                    ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        const EditorCanvas2D(),
                        if (_isTourActive)
                          RepaintBoundary(
                            child: CinematicTourOverlay(
                              onClose: () =>
                                  setState(() => _isTourActive = false),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const RepaintBoundary(child: PropertiesPanel()),
                ],
              ),
        bottomNavigationBar: EditorBottomBar(
          isMobile: isMobile,
          onOpenMobileProperties: () => _showMobilePropertiesSheet(context),
        ),
      ),
    );
  }
}
