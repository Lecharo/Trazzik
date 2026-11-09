import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';

/// Leaf widget watching only [FloorEditorState.zoom] so zooming never rebuilds
/// the full [EditorAppBar].
class EditorZoomControls extends ConsumerWidget {
  final VoidCallback onFitToLot;

  const EditorZoomControls({
    super.key,
    required this.onFitToLot,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(floorEditorProvider.select((s) => s.zoom));
    final lang = ref.watch(appLocaleProvider);
    final notifier = ref.read(floorEditorProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: const Icon(Icons.zoom_out, size: 18),
          tooltip: AppStrings.tr('zoom_out', lang),
          onPressed: () => notifier.updateZoom(zoom - 5.0),
        ),
        Text(
          '${(zoom / 35.0 * 100).round()}%',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: const Icon(Icons.zoom_in, size: 18),
          tooltip: AppStrings.tr('zoom_in', lang),
          onPressed: () => notifier.updateZoom(zoom + 5.0),
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: const Icon(
            Icons.fit_screen,
            size: 18,
            color: Color(0xFF00E5FF),
          ),
          tooltip: lang == 'es' ? 'Ajustar al Lote' : 'Fit to Lot',
          onPressed: onFitToLot,
        ),
      ],
    );
  }
}
