import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

class WallInspectorSection extends StatelessWidget {
  final Wall wall;
  final FloorEditorNotifier notifier;
  final String lang;

  const WallInspectorSection({
    super.key,
    required this.wall,
    required this.notifier,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertySectionHeader(
          title: lang == 'es' ? 'Muro Seleccionado' : 'Selected Wall',
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              PropertyKeyValueRow(
                label: lang == 'es' ? 'Longitud' : 'Length',
                value: '${wall.length.toStringAsFixed(2)} m',
              ),
              PropertyKeyValueRow(
                label: lang == 'es' ? 'Espesor computable' : 'Thickness',
                value: '${wall.thickness.toStringAsFixed(3)} m',
              ),
              PropertyKeyValueRow(
                label: lang == 'es' ? 'Altura' : 'Height',
                value: '${wall.height.toStringAsFixed(2)} m',
              ),
              PropertyKeyValueRow(
                label: lang == 'es' ? 'Huella en planta' : 'Footprint',
                value: '${(wall.length * wall.thickness).toStringAsFixed(2)} m²',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          lang == 'es'
              ? 'Tipo de Muro / Régimen de Propiedad:'
              : 'Wall Type & Property:',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text(
                lang == 'es' ? 'Muro Propio (0.15m)' : 'Private Wall (0.15m)',
                style: const TextStyle(fontSize: 10),
              ),
              selected: (wall.thickness - 0.15).abs() < 0.01,
              selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
              onSelected: (_) => notifier.setWallThickness(wall.id, 0.15),
            ),
            ChoiceChip(
              label: Text(
                lang == 'es'
                    ? 'Medianero Compartido (0.075m)'
                    : 'Shared Party Wall (0.075m)',
                style: const TextStyle(fontSize: 10),
              ),
              selected: (wall.thickness - 0.075).abs() < 0.01,
              selectedColor: const Color(0xFFFFB300).withValues(alpha: 0.25),
              onSelected: (_) => notifier.setWallThickness(wall.id, 0.075),
            ),
            ChoiceChip(
              label: Text(
                lang == 'es' ? 'Tabique (0.10m)' : 'Partition (0.10m)',
                style: const TextStyle(fontSize: 10),
              ),
              selected: (wall.thickness - 0.10).abs() < 0.01,
              selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.25),
              onSelected: (_) => notifier.setWallThickness(wall.id, 0.10),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          lang == 'es'
              ? 'Estado de Remodelación (Antes / Después):'
              : 'Remodeling Status (Before / After):',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              key: const Key('wall_status_existing'),
              label: Text(
                lang == 'es' ? 'Existente' : 'Existing',
                style: const TextStyle(fontSize: 10),
              ),
              selected: wall.status == ElementStatus.existing,
              selectedColor: const Color(0xFF64748B).withValues(alpha: 0.30),
              onSelected: (_) =>
                  notifier.setWallStatus(wall.id, ElementStatus.existing),
            ),
            ChoiceChip(
              key: const Key('wall_status_preserved'),
              label: Text(
                lang == 'es' ? 'Conservar' : 'Preserved',
                style: const TextStyle(fontSize: 10),
              ),
              selected: wall.status == ElementStatus.preserved,
              selectedColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              onSelected: (_) =>
                  notifier.setWallStatus(wall.id, ElementStatus.preserved),
            ),
            ChoiceChip(
              key: const Key('wall_status_toDemolish'),
              label: Text(
                lang == 'es' ? 'Demoler' : 'Demolish',
                style: const TextStyle(fontSize: 10),
              ),
              selected: wall.status == ElementStatus.toDemolish,
              selectedColor: const Color(0xFFEF5350).withValues(alpha: 0.28),
              onSelected: (_) =>
                  notifier.setWallStatus(wall.id, ElementStatus.toDemolish),
            ),
            ChoiceChip(
              key: const Key('wall_status_isNew'),
              label: Text(
                lang == 'es' ? 'Muro Nuevo' : 'New Wall',
                style: const TextStyle(fontSize: 10),
              ),
              selected: wall.status == ElementStatus.isNew,
              selectedColor: const Color(0xFF10B981).withValues(alpha: 0.28),
              onSelected: (_) =>
                  notifier.setWallStatus(wall.id, ElementStatus.isNew),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('split_wall_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: wall.length >= 0.40
                ? () => notifier.splitWall(wall.id)
                : null,
            icon: const Icon(Icons.content_cut, size: 16),
            label: Text(
              lang == 'es'
                  ? 'Dividir Muro en 2 Tramos'
                  : 'Split Wall in 2 Segments',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('draw_manual_wall_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10B981),
              side: const BorderSide(color: Color(0xFF10B981)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () => notifier.toggleDrawWallMode(),
            icon: const Icon(Icons.edit_road_outlined, size: 16),
            label: Text(
              lang == 'es'
                  ? 'Dibujar Muro Manual (Arrastrar 2D)'
                  : 'Draw Manual Wall (Drag 2D)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF5350),
              side: const BorderSide(color: Color(0xFFEF5350)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () => notifier.deleteWall(wall.id),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(
              lang == 'es'
                  ? 'Eliminar Muro (Hacer Abierto)'
                  : 'Delete Wall (Make Open)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
