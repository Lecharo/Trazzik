import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trazzik/features/editor_2d/presentation/notifiers/floor_editor_notifier.dart';
import 'package:trazzik/features/modules/domain/furniture_template.dart';

class FurnitureCatalogDialog extends ConsumerStatefulWidget {
  final String moduleId;

  const FurnitureCatalogDialog({
    super.key,
    required this.moduleId,
  });

  static Future<void> show(BuildContext context, String moduleId) {
    return showDialog(
      context: context,
      builder: (_) => FurnitureCatalogDialog(moduleId: moduleId),
    );
  }

  @override
  ConsumerState<FurnitureCatalogDialog> createState() => _FurnitureCatalogDialogState();
}

class _FurnitureCatalogDialogState extends ConsumerState<FurnitureCatalogDialog> {
  String _selectedCategory = 'Todos';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(floorEditorProvider);
    final notifier = ref.read(floorEditorProvider.notifier);
    final module = state.floor.modules.where((m) => m.id == widget.moduleId).firstOrNull;

    if (module == null) {
      return AlertDialog(
        title: const Text('Recinto no encontrado'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    final filteredTemplates = _selectedCategory == 'Todos'
        ? FurnitureTemplate.catalog
        : FurnitureTemplate.catalog.where((t) => t.category == _selectedCategory).toList();

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 720,
        height: isMobile ? size.height * 0.88 : 640,
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chair, color: Color(0xFF00E5FF), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amoblar: ${module.name}',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Área: ${module.geometry.area.toStringAsFixed(1)} m²  •  ${module.subModules.length} elementos equipados',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                    foregroundColor: const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(
                    isMobile ? 'Auto-Amoblar' : 'Auto-Amoblar Recinto (1-Clic)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final count = notifier.autoFurnishModule(module.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          count > 0
                              ? 'Se distribuyeron automáticamente $count piezas en ${module.name}'
                              : 'Este tipo de recinto no admite amoblado automático',
                        ),
                        duration: const Duration(milliseconds: 1800),
                        backgroundColor: const Color(0xFF1E293B),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chips de categorías
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: FurnitureTemplate.categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: const Color(0xFF00E5FF),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Catálogo de Muebles en Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 2,
                  childAspectRatio: isMobile ? 3.8 : 2.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredTemplates.length,
                itemBuilder: (context, index) {
                  final t = filteredTemplates[index];
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 12,
                      vertical: isMobile ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(t.icon, color: const Color(0xFF00E5FF), size: isMobile ? 20 : 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 12 : 13,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${t.defaultWidth.toStringAsFixed(2)} × ${t.defaultDepth.toStringAsFixed(2)} m (h: ${t.defaultHeight.toStringAsFixed(2)}m)',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 11,
                                  color: const Color(0xFF90A4AE),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.add_circle, color: Color(0xFF00E5FF), size: 22),
                          tooltip: 'Insertar en ${module.name}',
                          onPressed: () {
                            notifier.addFurnitureToModule(module.id, t);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${t.name} agregado a ${module.name}'),
                                duration: const Duration(milliseconds: 1500),
                                backgroundColor: const Color(0xFF1E293B),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Pie: Elementos ya equipados en el recinto
            if (module.subModules.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 24),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 6),
                  Text(
                    'Mobiliario instalado en este espacio (${module.subModules.length}):',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: module.subModules.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final sub = module.subModules[idx];
                    final bb = sub.geometry.boundingBox;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${sub.name} (${bb.width.toStringAsFixed(2)}x${bb.height.toStringAsFixed(2)}m)',
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.rotate_right, size: 16, color: Color(0xFF00E5FF)),
                            tooltip: 'Girar 90°',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => notifier.rotateSubModule(module.id, sub.id),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            tooltip: 'Eliminar',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => notifier.removeSubModule(module.id, sub.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
