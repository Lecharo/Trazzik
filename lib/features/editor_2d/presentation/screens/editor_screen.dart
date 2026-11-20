import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:trazzik/features/viewer_3d/presentation/widgets/live_split_3d_pane.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _isSaving = false;
  bool _isTourActive = false;
  String? _lastFittedLotId;
  double _split2dRatio = 0.56;

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

  bool _isEditingText() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(floorEditorProvider.notifier);
    final lotId = ref.watch(floorEditorProvider.select((s) => s.lot.id));
    final isSplitView3D = ref.watch(
      floorEditorProvider.select((s) => s.isSplitView3D),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 720;
    final showSplit3d = !isMobile && isSplitView3D && screenWidth >= 900;

    if (_lastFittedLotId != lotId) {
      _lastFittedLotId = lotId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitToLotResponsive(context, notifier);
      });
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (!_isEditingText()) notifier.undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
          if (!_isEditingText()) notifier.undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          if (!_isEditingText()) notifier.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
          if (!_isEditingText()) notifier.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): () {
          if (!_isEditingText()) notifier.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!_isSaving) _saveFloorToSupabase();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (!_isSaving) _saveFloorToSupabase();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          notifier.cancelActiveToolsOrSelection();
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (!_isEditingText()) notifier.deleteSelectedElement();
        },
        const SingleActivator(LogicalKeyboardKey.backspace): () {
          if (!_isEditingText()) notifier.deleteSelectedElement();
        },
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (!_isEditingText()) {
            final selId = ref.read(floorEditorProvider).selectedModuleId;
            if (selId != null) notifier.duplicateModule(selId);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () {
          if (!_isEditingText()) {
            final selId = ref.read(floorEditorProvider).selectedModuleId;
            if (selId != null) notifier.duplicateModule(selId);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(-0.05, 0.0);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(0.05, 0.0);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(0.0, -0.05);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(0.0, 0.05);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(-0.01, 0.0);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(0.01, 0.0);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(0.0, -0.01);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () {
          if (!_isEditingText()) notifier.nudgeSelectedElement(0.0, 0.01);
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (!showSplit3d) {
                          return Stack(
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
                          );
                        }
                        final totalW = math.max(1.0, constraints.maxWidth - 6.0);
                        final leftW = (totalW * _split2dRatio)
                            .clamp(240.0, math.max(240.0, totalW - 240.0))
                            .toDouble();
                        return Row(
                          children: [
                            SizedBox(
                              width: leftW,
                              child: Stack(
                                children: [
                                  const EditorCanvas2D(),
                                  if (_isTourActive)
                                    RepaintBoundary(
                                      child: CinematicTourOverlay(
                                        onClose: () => setState(
                                          () => _isTourActive = false,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (details) {
                                  setState(() {
                                    _split2dRatio =
                                        (_split2dRatio + details.delta.dx / totalW)
                                            .clamp(0.30, 0.75);
                                  });
                                },
                                child: Container(
                                  width: 6,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF283244)
                                      : const Color(0xFFCBD5E1),
                                  child: Center(
                                    child: Container(
                                      width: 2,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: LiveSplit3dPane(
                                onClose: notifier.toggleSplitView3D,
                              ),
                            ),
                          ],
                        );
                      },
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
    ),
    ),
    );
  }
}
