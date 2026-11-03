import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/core/theme/app_theme.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_state.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Diálogo modal del Cuadro General de Superficies y Planilla de Locales del Proyecto.
class ProjectAreaScheduleDialog extends ConsumerWidget {
  const ProjectAreaScheduleDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ProjectAreaScheduleDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final lang = ref.watch(appLocaleProvider);

    final floors = state.allFloors.isNotEmpty ? state.allFloors : [state.floor];

    // Cálculos globales del proyecto
    final totalBuiltArea = floors.fold<double>(
      0.0,
      (sum, f) => sum + f.calculatedBuiltArea,
    );
    final totalUsableArea = floors.fold<double>(
      0.0,
      (sum, f) => sum + f.usableSpacesArea,
    );
    final totalWallsFootprint = floors.fold<double>(
      0.0,
      (sum, f) => sum + f.wallsFootprintArea,
    );
    final totalWallsLinear = floors.fold<double>(
      0.0,
      (sum, f) => sum + f.wallsTotalLinearMeters,
    );
    final totalModulesCount = floors.fold<int>(
      0,
      (sum, f) => sum + f.modules.length,
    );
    final groundFloorArea = floors.isNotEmpty ? floors.first.calculatedBuiltArea : 0.0;
    final fosPercentage = state.lot.totalArea > 0
        ? (groundFloorArea / state.lot.totalArea * 100).clamp(0.0, 100.0)
        : 0.0;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: 24),
      titlePadding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 18, 16, 12),
      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.table_chart, color: Color(0xFF00E5FF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('area_schedule', lang),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  state.project?.name != null
                      ? '${state.project!.name} — Lote: ${state.lot.totalArea.toStringAsFixed(1)} m²'
                      : 'Lote Total: ${state.lot.totalArea.toStringAsFixed(1)} m²',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 820,
        height: isMobile ? MediaQuery.of(context).size.height * 0.75 : 580,
        child: Column(
          children: [
            // 1. Tarjetas de Métricas Generales (KPIs)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        Row(
                          children: [
                            _buildMetricTile(
                              icon: Icons.domain,
                              label: AppStrings.tr('total_built_area', lang),
                              value: '${totalBuiltArea.toStringAsFixed(2)} m²',
                              accentColor: const Color(0xFF00E5FF),
                            ),
                            _buildDivider(context),
                            _buildMetricTile(
                              icon: Icons.layers,
                              label: AppStrings.tr('total_floors', lang),
                              value: '${floors.length} ${floors.length == 1 ? "nivel" : "niveles"}',
                              accentColor: Colors.amber,
                            ),
                          ],
                        ),
                        const Divider(height: 10),
                        Row(
                          children: [
                            _buildMetricTile(
                              icon: Icons.grid_view,
                              label: AppStrings.tr('total_spaces', lang),
                              value: '$totalModulesCount ambientes',
                              accentColor: const Color(0xFF81C784),
                            ),
                            _buildDivider(context),
                            _buildMetricTile(
                              icon: Icons.pie_chart_outline,
                              label: AppStrings.tr('ground_occupancy', lang),
                              value: '${fosPercentage.toStringAsFixed(1)}%',
                              accentColor: const Color(0xFF64B5F6),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _buildMetricTile(
                          icon: Icons.domain,
                          label: AppStrings.tr('total_built_area', lang),
                          value: '${totalBuiltArea.toStringAsFixed(2)} m²',
                          accentColor: const Color(0xFF00E5FF),
                        ),
                        _buildDivider(context),
                        _buildMetricTile(
                          icon: Icons.layers,
                          label: AppStrings.tr('total_floors', lang),
                          value: '${floors.length} ${floors.length == 1 ? "nivel" : "niveles"}',
                          accentColor: Colors.amber,
                        ),
                        _buildDivider(context),
                        _buildMetricTile(
                          icon: Icons.grid_view,
                          label: AppStrings.tr('total_spaces', lang),
                          value: '$totalModulesCount ambientes',
                          accentColor: const Color(0xFF81C784),
                        ),
                        _buildDivider(context),
                        _buildMetricTile(
                          icon: Icons.pie_chart_outline,
                          label: AppStrings.tr('ground_occupancy', lang),
                          value: '${fosPercentage.toStringAsFixed(1)}%',
                          accentColor: const Color(0xFF64B5F6),
                        ),
                      ],
                    ),
            ),

            if (totalWallsFootprint > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fence, color: Colors.amber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang == 'es'
                            ? 'Muros Totales del Proyecto: ${totalWallsFootprint.toStringAsFixed(2)} m² de huella (${totalWallsLinear.toStringAsFixed(1)} m lineales)  •  Área Útil Neta: ${totalUsableArea.toStringAsFixed(2)} m²'
                            : 'Total Project Walls: ${totalWallsFootprint.toStringAsFixed(2)} m² footprint (${totalWallsLinear.toStringAsFixed(1)} linear m)  •  Net Usable Area: ${totalUsableArea.toStringAsFixed(2)} m²',
                        style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // 2. Lista Desplegable / Desglose por Planta
            Expanded(
              child: ListView.separated(
                itemCount: floors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final floor = floors[index];
                  final isCurrentFloor = floor.id == state.floor.id;
                  return _buildFloorCard(
                    context: context,
                    floor: floor,
                    isCurrentFloor: isCurrentFloor,
                    notifier: notifier,
                    lang: lang,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.tr('close', lang)),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard({
    required BuildContext context,
    required Floor floor,
    required bool isCurrentFloor,
    required FloorEditorNotifier notifier,
    required String lang,
  }) {
    final modules = floor.modules;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isCurrentFloor
              ? const Color(0xFF00E5FF).withOpacity(0.6)
              : Theme.of(context).dividerColor,
          width: isCurrentFloor ? 1.5 : 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrentFloor
                  ? const Color(0xFF00E5FF).withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.layers,
              size: 20,
              color: isCurrentFloor ? const Color(0xFF00E5FF) : Colors.grey,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  floor.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrentFloor) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            'H: ${floor.heightMeters.toStringAsFixed(2)}m  •  Cota: +${floor.levelMeters.toStringAsFixed(2)}m  •  ${modules.length} ${modules.length == 1 ? "espacio" : "espacios"}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Text(
                  '${floor.calculatedBuiltArea.toStringAsFixed(2)} m²',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
              if (!isCurrentFloor) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF00E5FF)),
                  tooltip: AppStrings.tr('switch_to_floor', lang),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    notifier.switchFloor(floor.id);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
          children: [
            if (modules.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppStrings.tr('no_spaces_in_floor', lang),
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Table(
                  columnWidths: MediaQuery.of(context).size.width < 600
                      ? const {
                          0: FlexColumnWidth(2.6), // Nombre
                          1: FlexColumnWidth(1.6), // Estado
                          2: FlexColumnWidth(1.8), // Medidas
                          3: FlexColumnWidth(1.8), // Área
                        }
                      : const {
                          0: FlexColumnWidth(3.0), // Nombre
                          1: FlexColumnWidth(1.8), // Estado
                          2: FlexColumnWidth(1.8), // Medidas
                          3: FlexColumnWidth(1.4), // Área
                        },
                  children: [
                    // Header de la tabla
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      children: [
                        _buildTableHeader(AppStrings.tr('space_name_col', lang)),
                        _buildTableHeader(AppStrings.tr('status_col', lang)),
                        _buildTableHeader(AppStrings.tr('dimensions_col', lang)),
                        _buildTableHeader(AppStrings.tr('area_col', lang), alignRight: true),
                      ],
                    ),
                    // Filas de espacios
                    ...modules.map((mod) {
                      final bb = mod.geometry.boundingBox;
                      return TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                          ),
                        ),
                        children: [
                          _buildSpaceNameCell(mod),
                          _buildStatusCell(mod.status, lang),
                          _buildDimensionsCell(bb.width, bb.height),
                          _buildAreaCell(mod.area),
                        ],
                      );
                    }),
                    // Fila de Muros si existen en la planta
                    if (floor.wallsFootprintArea > 0)
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.06),
                          border: Border(
                            top: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.fence, size: 15, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lang == 'es' ? 'Muros y Tabiques' : 'Walls & Partitions',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  lang == 'es' ? 'Estructura' : 'Structure',
                                  style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              '${floor.wallsTotalLinearMeters.toStringAsFixed(2)} m lin.',
                              style: const TextStyle(fontSize: 11, color: Colors.amber),
                            ),
                          ),
                          _buildAreaCell(floor.wallsFootprintArea),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSpaceNameCell(Module mod) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(
            _getIconForModuleType(mod.moduleType),
            size: 15,
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mod.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(ElementStatus status, String lang) {
    Color color;
    String label;

    switch (status) {
      case ElementStatus.isNew:
        color = const Color(0xFF00E5FF);
        label = lang == 'es' ? 'Nuevo' : 'New';
        break;
      case ElementStatus.preserved:
      case ElementStatus.existing:
        color = const Color(0xFF4CAF50);
        label = lang == 'es' ? 'Conservar' : 'Preserved';
        break;
      case ElementStatus.toDemolish:
        color = const Color(0xFFEF5350);
        label = lang == 'es' ? 'A Demoler' : 'Demolish';
        break;
      case ElementStatus.toModify:
        color = const Color(0xFFFFB74D);
        label = lang == 'es' ? 'Modificar' : 'Modify';
        break;
      default:
        color = Colors.grey;
        label = status.name;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionsCell(double width, double height) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        '${width.toStringAsFixed(2)} × ${height.toStringAsFixed(2)} m',
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }

  Widget _buildAreaCell(double area) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        '${area.toStringAsFixed(2)} m²',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getIconForModuleType(String type) {
    switch (type.toUpperCase()) {
      case 'KITCHEN':
        return Icons.soup_kitchen;
      case 'LIVING_ROOM':
        return Icons.weekend;
      case 'DINING_ROOM':
        return Icons.dining;
      case 'BATHROOM':
        return Icons.bathtub;
      case 'BEDROOM':
        return Icons.bed;
      case 'OFFICE':
        return Icons.work;
      case 'STAIRS':
        return Icons.stairs;
      case 'HALLWAY':
        return Icons.door_sliding;
      case 'LAUNDRY':
        return Icons.local_laundry_service;
      case 'GARAGE':
        return Icons.directions_car;
      case 'POOL':
        return Icons.pool;
      case 'GARDEN':
        return Icons.park;
      default:
        return Icons.crop_square;
    }
  }
}


