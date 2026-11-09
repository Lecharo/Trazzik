import 'package:flutter/material.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/furniture_catalog_dialog.dart';
import 'package:trazzik/features/editor_2d/presentation/widgets/properties/property_controls.dart';
import 'package:trazzik/features/modules/domain/module.dart';

class FurnitureInspectorSection extends StatelessWidget {
  final Module module;
  final String? selectedSubModuleId;
  final FloorEditorNotifier notifier;
  final String lang;

  const FurnitureInspectorSection({
    super.key,
    required this.module,
    required this.selectedSubModuleId,
    required this.notifier,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chair, size: 16, color: colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lang == 'es'
                      ? 'Equipamiento y Muebles'
                      : 'Furniture & Equipment',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${module.subModules.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 8),
                elevation: 0,
              ),
              onPressed: () => FurnitureCatalogDialog.show(context, module.id),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                lang == 'es' ? 'Amoblar / Agregar Mueble' : 'Add Furniture',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (module.subModules.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...module.subModules.map((sub) {
              final bb = sub.geometry.boundingBox;
              final isSelectedSub = sub.id == selectedSubModuleId;
              return InkWell(
                onTap: () => notifier.selectSubModule(module.id, sub.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelectedSub
                        ? colors.accent.withValues(alpha: 0.12)
                        : colors.subtleSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelectedSub ? colors.accent : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${sub.name} (${bb.width.toStringAsFixed(2)}x${bb.height.toStringAsFixed(2)}m)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelectedSub
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelectedSub
                                    ? colors.accent
                                    : colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              sub.isLocked ? Icons.lock : Icons.lock_open,
                              size: 16,
                              color: sub.isLocked
                                  ? colors.warning
                                  : colors.textMuted,
                            ),
                            tooltip: sub.isLocked
                                ? (lang == 'es'
                                    ? 'Desbloquear Mueble'
                                    : 'Unlock Furniture')
                                : (lang == 'es'
                                    ? 'Fijar / Bloquear Mueble'
                                    : 'Lock Furniture'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                notifier.toggleSubModuleLock(module.id, sub.id),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.rotate_right,
                              size: 16,
                              color: sub.isLocked
                                  ? colors.borderSubtle
                                  : colors.accent,
                            ),
                            tooltip: 'Rotar 90°',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: sub.isLocked
                                ? null
                                : () =>
                                    notifier.rotateSubModule(module.id, sub.id),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: sub.isLocked
                                  ? colors.borderSubtle
                                  : colors.danger,
                            ),
                            tooltip: 'Eliminar',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: sub.isLocked
                                ? null
                                : () =>
                                    notifier.removeSubModule(module.id, sub.id),
                          ),
                        ],
                      ),
                      if (isSelectedSub) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Pos: (${bb.minX.toStringAsFixed(2)}, ${bb.minY.toStringAsFixed(2)}m)${sub.isLocked ? ' 🔒' : ''}',
                              style: TextStyle(
                                fontSize: 10,
                                color: sub.isLocked
                                    ? colors.warning
                                    : colors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                size: 14,
                                color: sub.isLocked
                                    ? colors.borderSubtle
                                    : colors.textSecondary,
                              ),
                              tooltip: 'Mover izquierda (-0.10m)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: sub.isLocked
                                  ? null
                                  : () => notifier.setSubModulePosition(
                                        module.id,
                                        sub.id,
                                        bb.minX - 0.10,
                                        bb.minY,
                                      ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: sub.isLocked
                                    ? colors.borderSubtle
                                    : colors.textSecondary,
                              ),
                              tooltip: 'Mover derecha (+0.10m)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: sub.isLocked
                                  ? null
                                  : () => notifier.setSubModulePosition(
                                        module.id,
                                        sub.id,
                                        bb.minX + 0.10,
                                        bb.minY,
                                      ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                size: 14,
                                color: sub.isLocked
                                    ? colors.borderSubtle
                                    : colors.textSecondary,
                              ),
                              tooltip: 'Mover arriba (-0.10m)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: sub.isLocked
                                  ? null
                                  : () => notifier.setSubModulePosition(
                                        module.id,
                                        sub.id,
                                        bb.minX,
                                        bb.minY - 0.10,
                                      ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                size: 14,
                                color: sub.isLocked
                                    ? colors.borderSubtle
                                    : colors.textSecondary,
                              ),
                              tooltip: 'Mover abajo (+0.10m)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: sub.isLocked
                                  ? null
                                  : () => notifier.setSubModulePosition(
                                        module.id,
                                        sub.id,
                                        bb.minX,
                                        bb.minY + 0.10,
                                      ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang == 'es'
                              ? 'Dimensiones y Elevación (m)'
                              : 'Dimensions & Elevation (m)',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: SubDimensionStepper(
                                label:
                                    lang == 'es' ? 'Ancho (X)' : 'Width (X)',
                                value: bb.width,
                                minVal: 0.15,
                                onChanged: (val) =>
                                    notifier.setSubModuleDimensions(
                                  module.id,
                                  sub.id,
                                  width: val,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SubDimensionStepper(
                                label:
                                    lang == 'es' ? 'Fondo (Y)' : 'Depth (Y)',
                                value: bb.height,
                                minVal: 0.15,
                                onChanged: (val) =>
                                    notifier.setSubModuleDimensions(
                                  module.id,
                                  sub.id,
                                  depth: val,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: SubDimensionStepper(
                                label: lang == 'es' ? 'Alto (Z)' : 'Height (Z)',
                                value: sub.resolvedHeight,
                                minVal: 0.05,
                                onChanged: (val) =>
                                    notifier.setSubModuleDimensions(
                                  module.id,
                                  sub.id,
                                  height: val,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SubDimensionStepper(
                                label:
                                    lang == 'es' ? 'Elevación' : 'Elevation',
                                value: sub.elevation,
                                minVal: 0.0,
                                onChanged: (val) =>
                                    notifier.setSubModuleDimensions(
                                  module.id,
                                  sub.id,
                                  elevation: val,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
