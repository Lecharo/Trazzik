import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLocaleProvider);
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
    final hasErrors = issues.any((i) => i.severity == ValidationSeverity.error);

    if (isMobile) {
      return SafeArea(
        top: false,
        child: InkWell(
          onTap: onOpenMobileProperties,
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
                    selectedModule != null
                        ? '${selectedModule.name} (${selectedModule.area.toStringAsFixed(1)} m²)'
                        : selectedWall != null
                            ? (lang == 'es'
                                ? 'Muro (${selectedWall.length.toStringAsFixed(2)} m)'
                                : 'Wall')
                            : (lang == 'es'
                                ? 'Piso: ${builtArea.toStringAsFixed(1)} m² | $modulesCount esp.'
                                : 'Floor: ${builtArea.toStringAsFixed(1)} m² | $modulesCount sp.'),
                    style: const TextStyle(
                      color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_up,
                      color: Color(0xFF00E5FF),
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
            'Espacios: $modulesCount | Alertas: ${issues.length}',
            style: TextStyle(
              color:
                  hasErrors ? const Color(0xFFEF5350) : const Color(0xFF81C784),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
