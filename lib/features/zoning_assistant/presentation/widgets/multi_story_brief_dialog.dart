import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/zoning_assistant/domain/multi_story_brief.dart';

/// Diálogo interactivo del Configurador de Programa de Necesidades para Viviendas de 2 Pisos.
class MultiStoryBriefDialog extends ConsumerStatefulWidget {
  const MultiStoryBriefDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const MultiStoryBriefDialog(),
    );
  }

  @override
  ConsumerState<MultiStoryBriefDialog> createState() => _MultiStoryBriefDialogState();
}

class _MultiStoryBriefDialogState extends ConsumerState<MultiStoryBriefDialog> {
  GaragePlacement _garagePlacement = GaragePlacement.frontSetbackSemiCovered;
  int _garageCars = 1;
  GroundFloorBedroomOption _groundBedroom = GroundFloorBedroomOption.masterSuite;
  int _upperBedrooms = 2;
  bool _upperLivingOrStudy = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);

    return Dialog(
      backgroundColor: const Color(0xFF112240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 660,
        padding: const EdgeInsets.all(22),
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
                  child: const Icon(Icons.cottage, color: Color(0xFF00E5FF), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Programa de Necesidades — Vivienda 2 Pisos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Definí las zonas de cada nivel y la aplicación las distribuirá coordinadas',
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

            // Contenido desplazable
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECCIÓN 1: GARAJE Y RETIRO FRONTAL
                    _buildSectionHeader(
                      icon: Icons.directions_car,
                      title: '1. GARAJE & FRENTE DE CALLE',
                    ),
                    const SizedBox(height: 8),

                    _buildOptionCard(
                      title: 'Semicubierto en Retiro Frontal (Recomendado)',
                      subtitle:
                          'Aprovecha el espacio hacia la calle para vehículos sin violar la normativa de construcción cerrada cubierta.',
                      isSelected: _garagePlacement == GaragePlacement.frontSetbackSemiCovered,
                      onTap: () => setState(() =>
                          _garagePlacement = GaragePlacement.frontSetbackSemiCovered),
                    ),
                    const SizedBox(height: 6),
                    _buildOptionCard(
                      title: 'Garaje Cerrado con Muros',
                      subtitle:
                          'Ubicado detrás del retiro frontal como recinto cerrado techado.',
                      isSelected: _garagePlacement == GaragePlacement.frontEnclosed,
                      onTap: () => setState(() =>
                          _garagePlacement = GaragePlacement.frontEnclosed),
                    ),
                    const SizedBox(height: 6),
                    _buildOptionCard(
                      title: 'Sin Garaje (Solo Jardín / Acceso Peatonal)',
                      subtitle: 'Todo el frente se destina al porche de ingreso y zona social.',
                      isSelected: _garagePlacement == GaragePlacement.none,
                      onTap: () => setState(() =>
                          _garagePlacement = GaragePlacement.none),
                    ),

                    if (_garagePlacement != GaragePlacement.none) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Capacidad del Garaje:',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          ChoiceChip(
                            label: const Text('1 Vehículo (3.00 m)'),
                            selected: _garageCars == 1,
                            selectedColor: const Color(0xFF00E5FF),
                            labelStyle: TextStyle(
                              color: _garageCars == 1 ? const Color(0xFF0A192F) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            onSelected: (_) => setState(() => _garageCars = 1),
                          ),
                          ChoiceChip(
                            label: const Text('2 Vehículos (5.50 m)'),
                            selected: _garageCars == 2,
                            selectedColor: const Color(0xFF00E5FF),
                            labelStyle: TextStyle(
                              color: _garageCars == 2 ? const Color(0xFF0A192F) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            onSelected: (_) => setState(() => _garageCars = 2),
                          ),
                        ],
                      ),
                    ],

                    const Divider(color: Color(0xFF233554), height: 26),

                    // SECCIÓN 2: PLANTA BAJA (PISO 1)
                    _buildSectionHeader(
                      icon: Icons.meeting_room,
                      title: '2. PLANTA BAJA (NIVEL +0.00)',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Habitaciones en Planta Baja:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Suite Principal en PB (con baño)'),
                          selected: _groundBedroom == GroundFloorBedroomOption.masterSuite,
                          selectedColor: const Color(0xFF00E5FF),
                          labelStyle: TextStyle(
                            color: _groundBedroom == GroundFloorBedroomOption.masterSuite
                                ? const Color(0xFF0A192F)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() =>
                              _groundBedroom = GroundFloorBedroomOption.masterSuite),
                        ),
                        ChoiceChip(
                          label: const Text('Solo Área Social & Galería (Sin dormitorios en PB)'),
                          selected: _groundBedroom == GroundFloorBedroomOption.none,
                          selectedColor: const Color(0xFF00E5FF),
                          labelStyle: TextStyle(
                            color: _groundBedroom == GroundFloorBedroomOption.none
                                ? const Color(0xFF0A192F)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() =>
                              _groundBedroom = GroundFloorBedroomOption.none),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2D4A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Color(0xFF00E5FF), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Incluye automáticamente: Sala de Estar al frente, Comedor, Cocina con bacha y anafe, Baño Social de visitas y Escalera hacia Planta Alta.',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Color(0xFF233554), height: 26),

                    // SECCIÓN 3: PLANTA ALTA (PISO 2)
                    _buildSectionHeader(
                      icon: Icons.layers,
                      title: '3. PLANTA ALTA (NIVEL +2.80)',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Dormitorios en Planta Alta:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        ChoiceChip(
                          label: const Text('2 Dormitorios'),
                          selected: _upperBedrooms == 2,
                          selectedColor: const Color(0xFF00E5FF),
                          labelStyle: TextStyle(
                            color: _upperBedrooms == 2 ? const Color(0xFF0A192F) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() => _upperBedrooms = 2),
                        ),
                        ChoiceChip(
                          label: const Text('3 Dormitorios'),
                          selected: _upperBedrooms == 3,
                          selectedColor: const Color(0xFF00E5FF),
                          labelStyle: TextStyle(
                            color: _upperBedrooms == 3 ? const Color(0xFF0A192F) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() => _upperBedrooms = 3),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Estar Íntimo / Estudio / Home Office al frente con vista',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      subtitle: const Text(
                        'Agrega espacio de TV o escritorio independiente junto a la llegada de la escalera',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      value: _upperLivingOrStudy,
                      activeColor: const Color(0xFF00E5FF),
                      onChanged: (val) => setState(() => _upperLivingOrStudy = val),
                    ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.swap_vert, color: Color(0xFF00E5FF), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Coordinación Vertical: La escalera se posiciona en las mismas coordenadas en ambos pisos para garantizar continuidad arquitectónica.',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botones inferiores
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
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.architecture, size: 18),
                  label: const Text('Generar Vivienda de 2 Pisos'),
                  onPressed: () {
                    final brief = MultiStoryBrief(
                      garagePlacement: _garagePlacement,
                      garageCars: _garageCars,
                      groundFloorBedroom: _groundBedroom,
                      upperFloorBedrooms: _upperBedrooms,
                      upperFloorLivingOrStudy: _upperLivingOrStudy,
                    );

                    notifier.applyMultiStoryBrief(brief);
                    Navigator.of(context).pop();

                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF2E7D32),
                        content: Text(
                          '¡Vivienda de 2 Pisos generada! Podés alternar entre Planta Baja y Planta Alta desde el selector superior.',
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

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withOpacity(0.12)
              : const Color(0xFF1E2D4A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF233554),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
