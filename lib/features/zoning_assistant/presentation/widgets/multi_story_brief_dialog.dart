import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
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
    final colors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lang = ref.watch(appLocaleProvider);
    final isEn = lang == 'en';
    final selectedChipTextColor =
        isLight ? Colors.white : const Color(0xFF0A192F);
    final notifier = ref.read(floorEditorProvider.notifier);

    return Dialog(
      backgroundColor: colors.panelBg,
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
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.cottage, color: colors.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn
                            ? 'Architectural Brief — 2-Story Residence'
                            : 'Programa de Necesidades — Vivienda 2 Pisos',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEn
                            ? 'Define each level program for coordinated vertical layout generation'
                            : 'Defina las zonas de cada nivel para distribuirlas de forma coordinada',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
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
                      colors,
                      icon: Icons.directions_car,
                      title: isEn
                          ? '1. GARAGE & STREET FRONT'
                          : '1. GARAJE & FRENTE DE CALLE',
                    ),
                    const SizedBox(height: 8),

                    _buildOptionCard(
                      colors: colors,
                      title: isEn
                          ? 'Semi-Covered in Front Setback (Recommended)'
                          : 'Semicubierto en Retiro Frontal (Recomendado)',
                      subtitle: isEn
                          ? 'Uses street setback space for vehicles without violating closed building footprint limits.'
                          : 'Aprovecha el espacio hacia la calle para vehículos sin violar la normativa de construcción cerrada cubierta.',
                      isSelected: _garagePlacement == GaragePlacement.frontSetbackSemiCovered,
                      onTap: () => setState(() =>
                          _garagePlacement = GaragePlacement.frontSetbackSemiCovered),
                    ),
                    const SizedBox(height: 6),
                    _buildOptionCard(
                      colors: colors,
                      title: isEn
                          ? 'Enclosed Garage with Walls'
                          : 'Garaje Cerrado con Muros',
                      subtitle: isEn
                          ? 'Placed behind the front setback as a roofed enclosed room.'
                          : 'Ubicado detrás del retiro frontal como recinto cerrado techado.',
                      isSelected: _garagePlacement == GaragePlacement.frontEnclosed,
                      onTap: () => setState(() =>
                          _garagePlacement = GaragePlacement.frontEnclosed),
                    ),
                    const SizedBox(height: 6),
                    _buildOptionCard(
                      colors: colors,
                      title: isEn
                          ? 'No Garage (Garden / Pedestrian Access Only)'
                          : 'Sin Garaje (Solo Jardín / Acceso Peatonal)',
                      subtitle: isEn
                          ? 'Dedicates the entire front to the entry porch and social zone.'
                          : 'Todo el frente se destina al porche de ingreso y zona social.',
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
                          Text(
                            isEn ? 'Garage Capacity:' : 'Capacidad del Garaje:',
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                          ChoiceChip(
                            label: Text(isEn ? '1 Vehicle (3.00 m)' : '1 Vehículo (3.00 m)'),
                            selected: _garageCars == 1,
                            selectedColor: colors.accent,
                            backgroundColor: colors.cardBg,
                            labelStyle: TextStyle(
                              color: _garageCars == 1
                                  ? selectedChipTextColor
                                  : colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            onSelected: (_) => setState(() => _garageCars = 1),
                          ),
                          ChoiceChip(
                            label: Text(isEn ? '2 Vehicles (5.50 m)' : '2 Vehículos (5.50 m)'),
                            selected: _garageCars == 2,
                            selectedColor: colors.accent,
                            backgroundColor: colors.cardBg,
                            labelStyle: TextStyle(
                              color: _garageCars == 2
                                  ? selectedChipTextColor
                                  : colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            onSelected: (_) => setState(() => _garageCars = 2),
                          ),
                        ],
                      ),
                    ],

                    Divider(color: colors.borderSubtle, height: 26),

                    // SECCIÓN 2: PLANTA BAJA (PISO 1)
                    _buildSectionHeader(
                      colors,
                      icon: Icons.meeting_room,
                      title: isEn
                          ? '2. GROUND FLOOR (LEVEL +0.00)'
                          : '2. PLANTA BAJA (NIVEL +0.00)',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEn ? 'Ground Floor Bedrooms:' : 'Habitaciones en Planta Baja:',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(isEn
                              ? 'Master Suite on Ground Floor (with bath)'
                              : 'Suite Principal en PB (con baño)'),
                          selected: _groundBedroom == GroundFloorBedroomOption.masterSuite,
                          selectedColor: colors.accent,
                          backgroundColor: colors.cardBg,
                          labelStyle: TextStyle(
                            color: _groundBedroom == GroundFloorBedroomOption.masterSuite
                                ? selectedChipTextColor
                                : colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() =>
                              _groundBedroom = GroundFloorBedroomOption.masterSuite),
                        ),
                        ChoiceChip(
                          label: Text(isEn
                              ? 'Social & Gallery Only (No ground bedrooms)'
                              : 'Solo Área Social & Galería (Sin dormitorios en PB)'),
                          selected: _groundBedroom == GroundFloorBedroomOption.none,
                          selectedColor: colors.accent,
                          backgroundColor: colors.cardBg,
                          labelStyle: TextStyle(
                            color: _groundBedroom == GroundFloorBedroomOption.none
                                ? selectedChipTextColor
                                : colors.textPrimary,
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
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: colors.accent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Automatically includes: Living room, dining, kitchen with sink & cooktop, guest half-bath, and staircase to Upper Floor.'
                                  : 'Incluye automáticamente: Sala de Estar al frente, Comedor, Cocina con lavaplatos y estufa, Baño Social de visitas y Escalera hacia Planta Alta.',
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(color: colors.borderSubtle, height: 26),

                    // SECCIÓN 3: PLANTA ALTA (PISO 2)
                    _buildSectionHeader(
                      colors,
                      icon: Icons.layers,
                      title: isEn
                          ? '3. UPPER FLOOR (LEVEL +2.80)'
                          : '3. PLANTA ALTA (NIVEL +2.80)',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isEn ? 'Upper Floor Bedrooms:' : 'Dormitorios en Planta Alta:',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        ChoiceChip(
                          label: Text(isEn ? '2 Bedrooms' : '2 Dormitorios'),
                          selected: _upperBedrooms == 2,
                          selectedColor: colors.accent,
                          backgroundColor: colors.cardBg,
                          labelStyle: TextStyle(
                            color: _upperBedrooms == 2
                                ? selectedChipTextColor
                                : colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() => _upperBedrooms = 2),
                        ),
                        ChoiceChip(
                          label: Text(isEn ? '3 Bedrooms' : '3 Dormitorios'),
                          selected: _upperBedrooms == 3,
                          selectedColor: colors.accent,
                          backgroundColor: colors.cardBg,
                          labelStyle: TextStyle(
                            color: _upperBedrooms == 3
                                ? selectedChipTextColor
                                : colors.textPrimary,
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
                      title: Text(
                        isEn
                            ? 'Upper Family Lounge / Study / Home Office'
                            : 'Estar Íntimo / Estudio / Home Office al frente con vista',
                        style: TextStyle(color: colors.textPrimary, fontSize: 12),
                      ),
                      subtitle: Text(
                        isEn
                            ? 'Adds a separate TV lounge or desk alcove beside the stair landing'
                            : 'Agrega espacio de TV o escritorio independiente junto a la llegada de la escalera',
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                      value: _upperLivingOrStudy,
                      activeThumbColor: colors.accent,
                      onChanged: (val) => setState(() => _upperLivingOrStudy = val),
                    ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.swap_vert, color: colors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Vertical Coordination: The staircase keeps identical X/Y coordinates across both floors for architectural continuity.'
                                  : 'Coordinación Vertical: La escalera se posiciona en las mismas coordenadas en ambos pisos para garantizar continuidad arquitectónica.',
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
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
                  child: Text(
                    isEn ? 'Cancel' : 'Cancelar',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: selectedChipTextColor,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.architecture, size: 18),
                  label: Text(
                    isEn
                        ? 'Generate 2-Story Residence'
                        : 'Generar Vivienda de 2 Pisos',
                  ),
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
                      SnackBar(
                        backgroundColor: colors.success,
                        content: Text(
                          isEn
                              ? '2-Story Residence generated! Switch between Ground and Upper floor using the top selector.'
                              : '¡Vivienda de 2 Pisos generada! Puede alternar entre Planta Baja y Planta Alta desde el selector superior.',
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

  Widget _buildSectionHeader(
    AppColors colors, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: colors.accent, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: colors.accent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required AppColors colors,
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
              ? colors.accent.withValues(alpha: 0.12)
              : colors.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? colors.accent : colors.borderSubtle,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? colors.accent : colors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 11),
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
