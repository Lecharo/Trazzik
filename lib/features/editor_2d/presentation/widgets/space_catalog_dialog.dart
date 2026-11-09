import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/point_2d.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/core/i18n/app_strings.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/lots/domain/zoning_type.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/modules/domain/space_template.dart';

class SpaceCatalogDialog extends ConsumerStatefulWidget {
  const SpaceCatalogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SpaceCatalogDialog(),
    );
  }

  @override
  ConsumerState<SpaceCatalogDialog> createState() => _SpaceCatalogDialogState();
}

class _SpaceCatalogDialogState extends ConsumerState<SpaceCatalogDialog> {
  String _selectedCategory = 'Todos';
  ElementStatus _selectedStatus = ElementStatus.isNew;

  // Custom space controllers
  final _customNameController = TextEditingController(text: 'Espacio Personalizado');
  final _customWidthController = TextEditingController(text: '3.00');
  final _customDepthController = TextEditingController(text: '3.00');

  final List<String> _categories = [
    'Todos',
    'Aberturas',
    'Circulaciones',
    'Social',
    'Privado',
    'Servicios',
    'Exteriores',
    'Personalizado',
  ];

  @override
  void dispose() {
    _customNameController.dispose();
    _customWidthController.dispose();
    _customDepthController.dispose();
    super.dispose();
  }

  void _insertTemplate(SpaceTemplate template) {
    final state = ref.read(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);

    // Calcular posición inicial dentro de la zona construible del lote o piso
    final buildableZone = state.lot.zones
        .where((z) => z.type == ZoningType.buildableUnoccupied)
        .firstOrNull;
    final bb = buildableZone?.boundary.boundingBox ?? state.floor.boundary.boundingBox;

    // Calcular una posición razonable para que no se superponga exactamente en el origen
    final offsetCount = state.floor.modules.length;
    final offsetX = (offsetCount * 0.50) % (bb.width > template.defaultWidth ? bb.width - template.defaultWidth : 1.0);
    final offsetY = (offsetCount * 0.50) % (bb.height > template.defaultDepth ? bb.height - template.defaultDepth : 1.0);

    final originX = FloorEditorNotifier.snapToGrid(bb.minX + offsetX);
    final originY = FloorEditorNotifier.snapToGrid(bb.minY + offsetY);

    final geom = template.id == 'tpl_living_recessed'
        ? Polygon2D([
            Point2D(originX, originY),
            Point2D(originX + 4.50, originY),
            Point2D(originX + 4.50, originY + 0.50),
            Point2D(originX + 5.00, originY + 0.50),
            Point2D(originX + 5.00, originY + 4.00),
            Point2D(originX, originY + 4.00),
          ])
        : Polygon2D.fromRect(
            originX,
            originY,
            template.defaultWidth,
            template.defaultDepth,
          );

    final module = Module(
      id: const Uuid().v4(),
      floorId: state.floor.id,
      name: template.name,
      moduleType: template.moduleType,
      geometry: geom,
      status: _selectedStatus,
    );

    notifier.addModule(module);
    Navigator.of(context).pop();
  }

  void _insertCustomSpace() {
    final state = ref.read(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);

    final name = _customNameController.text.trim().isNotEmpty
        ? _customNameController.text.trim()
        : 'Espacio Personalizado';
    final width = double.tryParse(_customWidthController.text.trim()) ?? 3.0;
    final depth = double.tryParse(_customDepthController.text.trim()) ?? 3.0;

    final bb = state.floor.boundary.boundingBox;
    final originX = FloorEditorNotifier.snapToGrid(bb.minX + 0.50);
    final originY = FloorEditorNotifier.snapToGrid(bb.minY + 0.50);

    final geom = Polygon2D.fromRect(originX, originY, width, depth);

    final module = Module(
      id: const Uuid().v4(),
      floorId: state.floor.id,
      name: name,
      moduleType: 'CUSTOM',
      geometry: geom,
      status: _selectedStatus,
    );

    notifier.addModule(module);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final filteredTemplates = _selectedCategory == 'Todos'
        ? SpaceTemplate.catalog
        : SpaceTemplate.catalog.where((t) => t.category == _selectedCategory).toList();

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: 24),
      title: Row(
        children: [
          const Icon(Icons.dashboard_customize, color: Color(0xFF00E5FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lang == 'es' ? 'Catálogo de Espacios y Plantillas' : 'Spaces & Templates Catalog',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 760,
        height: isMobile ? MediaQuery.of(context).size.height * 0.72 : 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Selector de Estado Constructivo Inicial (con Wrap para evitar overflow)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(
                    lang == 'es' ? 'Estado constructivo inicial:' : 'Initial status:',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  ChoiceChip(
                    avatar: const CircleAvatar(backgroundColor: Color(0xFF00E5FF), radius: 5),
                    label: Text(lang == 'es' ? 'Nuevo (Propuesto)' : 'Proposed (New)'),
                    selected: _selectedStatus == ElementStatus.isNew,
                    selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _selectedStatus = ElementStatus.isNew),
                  ),
                  ChoiceChip(
                    avatar: const CircleAvatar(backgroundColor: Color(0xFF4CAF50), radius: 5),
                    label: Text(lang == 'es' ? 'Existente (Conservar)' : 'Preserved'),
                    selected: _selectedStatus == ElementStatus.preserved,
                    selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _selectedStatus = ElementStatus.preserved),
                  ),
                  ChoiceChip(
                    avatar: const CircleAvatar(backgroundColor: Color(0xFFE53935), radius: 5),
                    label: Text(lang == 'es' ? 'Existente (A Demoler)' : 'To Demolish'),
                    selected: _selectedStatus == ElementStatus.toDemolish,
                    selectedColor: const Color(0xFFE53935).withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _selectedStatus = ElementStatus.toDemolish),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Filtro de Categorías
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 16),

            // 3. Contenido (Plantillas o Formulario Personalizado)
            Expanded(
              child: _selectedCategory == 'Personalizado'
                  ? _buildCustomSpaceForm(lang)
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 1 : 2,
                        childAspectRatio: isMobile ? 3.8 : 3.0,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filteredTemplates.length,
                      itemBuilder: (ctx, index) {
                        final tpl = filteredTemplates[index];
                        return InkWell(
                          onTap: () => _insertTemplate(tpl),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor),
                              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(tpl.icon, color: const Color(0xFF00E5FF), size: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        tpl.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tpl.defaultWidth.toStringAsFixed(2)} × ${tpl.defaultDepth.toStringAsFixed(2)} m (${tpl.defaultArea.toStringAsFixed(2)} m²)',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF00E5FF)),
                              ],
                            ),
                          ),
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
          child: Text(AppStrings.tr('cancel', lang)),
        ),
      ],
    );
  }

  Widget _buildCustomSpaceForm(String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 'es' ? 'Crear Recinto con Dimensiones Libres' : 'Create Custom Space',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customNameController,
            decoration: InputDecoration(
              labelText: lang == 'es' ? 'Nombre del Espacio' : 'Space Name',
              hintText: 'Ej. Gimnasio / Sala de Juegos / Cava',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customWidthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: lang == 'es' ? 'Ancho (m)' : 'Width (m)',
                    suffixText: 'm',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _customDepthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: lang == 'es' ? 'Largo / Fondo (m)' : 'Depth (m)',
                    suffixText: 'm',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A192F),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _insertCustomSpace,
              icon: const Icon(Icons.add),
              label: Text(
                lang == 'es' ? 'Insertar Espacio en el Plano' : 'Insert Space in Floor Plan',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
