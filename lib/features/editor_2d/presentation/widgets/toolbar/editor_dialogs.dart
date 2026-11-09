import 'package:flutter/material.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/floors/domain/floor.dart';

class EditorDialogs {
  const EditorDialogs._();

  static void showFloorSettingsDialog({
    required BuildContext context,
    required Floor floor,
    required FloorEditorNotifier notifier,
    required String lang,
    bool canDelete = false,
  }) {
    final nameCtrl = TextEditingController(text: floor.name);
    final heightCtrl = TextEditingController(
      text: floor.heightMeters.toStringAsFixed(2),
    );
    final levelCtrl = TextEditingController(
      text: floor.levelMeters.toStringAsFixed(2),
    );

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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF5350),
                ),
                onPressed: () {
                  notifier.deleteDesignVariant(floor.id);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang == 'es'
                            ? 'Variante / piso eliminado.'
                            : 'Variant / floor removed.',
                      ),
                    ),
                  );
                },
                child: Text(
                  lang == 'es' ? 'Eliminar Piso/Variante' : 'Delete Variant',
                ),
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
                final newHeight = double.tryParse(heightCtrl.text.trim()) ??
                    floor.heightMeters;
                final newLevel = double.tryParse(levelCtrl.text.trim()) ??
                    floor.levelMeters;
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
    ).whenComplete(() {
      nameCtrl.dispose();
      heightCtrl.dispose();
      levelCtrl.dispose();
    });
  }

  static void showCreateVariantDialog({
    required BuildContext context,
    required FloorEditorNotifier notifier,
    required String currentFloorName,
    required String lang,
  }) {
    final variantCtrl = TextEditingController(
      text: lang == 'es'
          ? '$currentFloorName - Opción B'
          : '$currentFloorName - Option B',
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                labelText: lang == 'es'
                    ? 'Nombre del Escenario / Variante'
                    : 'Variant / Scenario Name',
                border: const OutlineInputBorder(),
                prefixIcon:
                    const Icon(Icons.edit_note, color: Color(0xFF00E5FF)),
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
                          ? 'Se creó el escenario "$name". Puedes experimentar libremente.'
                          : 'Scenario "$name" created. Experiment freely!',
                      style: const TextStyle(
                        color: Color(0xFF0A192F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ).whenComplete(variantCtrl.dispose);
  }

  static void showDemarcateWallsDialog({
    required BuildContext context,
    required FloorEditorNotifier notifier,
    required int existingWallsCount,
    required String lang,
  }) {
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang == 'es'
                          ? 'Muros actuales en este piso: $existingWallsCount'
                          : 'Current walls on this floor: $existingWallsCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF5350),
              ),
              onPressed: () {
                notifier.clearAllWalls();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lang == 'es' ? 'Muros eliminados.' : 'Walls cleared.',
                    ),
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

  static Future<String?> showUnsavedChangesDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Guardar y Continuar',
    String discardLabel = 'Descartar Cambios',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF9800),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: Text(discardLabel, style: const TextStyle(fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A192F),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => Navigator.of(ctx).pop('save'),
              child: Text(
                confirmLabel,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
