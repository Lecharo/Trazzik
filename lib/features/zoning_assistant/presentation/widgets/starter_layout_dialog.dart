import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/zoning_assistant/domain/starter_layout_template.dart';
import 'package:trazzik/features/zoning_assistant/presentation/widgets/multi_story_brief_dialog.dart';

/// Diálogo interactivo del Asistente de Distribución Inicial para lote vacío.
class StarterLayoutDialog extends ConsumerStatefulWidget {
  const StarterLayoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const StarterLayoutDialog(),
    );
  }

  @override
  ConsumerState<StarterLayoutDialog> createState() => _StarterLayoutDialogState();
}

class _StarterLayoutDialogState extends ConsumerState<StarterLayoutDialog> {
  StarterLayoutType _selectedType = StarterLayoutType.compact2Bedrooms;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final hasExistingModules = state.floor.modules.isNotEmpty;

    return Dialog(
      backgroundColor: const Color(0xFF112240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistente de Distribución Inicial',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Elegí un esquema arquitectónico funcional adaptado a tu lote',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Banner directo a Vivienda de 2 Pisos
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                MultiStoryBriefDialog.show(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.layers, color: Color(0xFF00E5FF), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Proyectás una Vivienda de 2 Pisos?',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Configurá garaje al frente, suite abajo, dormitorios arriba y escaleras coordinadas.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Color(0xFF00E5FF), size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tarjetas de Plantillas (Desplazables)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...StarterLayoutTemplate.templates.map((tpl) {
                      final isSelected = tpl.type == _selectedType;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => setState(() => _selectedType = tpl.type),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00E5FF).withOpacity(0.12)
                                  : const Color(0xFF1E2D4A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF233554),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Radio<StarterLayoutType>(
                                  value: tpl.type,
                                  groupValue: _selectedType,
                                  activeColor: const Color(0xFF00E5FF),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedType = val);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            tpl.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E5FF).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tpl.tag,
                                              style: const TextStyle(
                                                color: Color(0xFF00E5FF),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tpl.description,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 6,
                                        children: [
                                          _buildStatChip(
                                            Icons.bed,
                                            '${tpl.bedroomsCount} Dormitorios',
                                          ),
                                          _buildStatChip(
                                            Icons.bathtub,
                                            '${tpl.bathroomsCount} Baños',
                                          ),
                                          _buildStatChip(
                                            Icons.chair,
                                            'Amoblado inicial incluido',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (hasExistingModules) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Atención: Aplicar esta distribución reemplazará los recintos existentes. Podrás deshacer la acción con el botón Deshacer (Undo).',
                                style: TextStyle(color: Colors.amber, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0A192F),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Generar Esquema en el Lote'),
                  onPressed: () {
                    final selectedTpl = StarterLayoutTemplate.templates
                        .firstWhere((t) => t.type == _selectedType);
                    notifier.applyStarterLayout(selectedTpl);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF2E7D32),
                        content: Text(
                          'Se generó el esquema "${selectedTpl.title}" con amoblamiento base.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF00E5FF)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}
