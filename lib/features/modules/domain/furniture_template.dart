import 'package:flutter/material.dart';

/// Plantilla arquitectónica de mobiliario y artefactos interiores
class FurnitureTemplate {
  final String id;
  final String name;
  final String category; // 'Estar / Social', 'Comedor', 'Cocina', 'Dormitorio', 'Baño', 'Lavadero'
  final String type;     // SOFA, TABLE, BED, TOILET, SINK, STOVE, REFRIGERATOR, SHOWER, WARDROBE, DESK, etc.
  final double defaultWidth;
  final double defaultDepth;
  final double defaultHeight; // Altura tridimensional (metros)
  final IconData icon;

  const FurnitureTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.defaultWidth,
    required this.defaultDepth,
    required this.defaultHeight,
    required this.icon,
  });

  static const List<FurnitureTemplate> catalog = [
    // 0. General / Estándar (Aptos para cualquier espacio)
    FurnitureTemplate(
      id: 'furn_generic_table',
      name: 'Mesa Estándar / Multiuso',
      category: 'General / Estándar',
      type: 'TABLE',
      defaultWidth: 1.20,
      defaultDepth: 0.70,
      defaultHeight: 0.75,
      icon: Icons.table_restaurant,
    ),
    FurnitureTemplate(
      id: 'furn_generic_cabinet',
      name: 'Mueble / Armario Multiuso',
      category: 'General / Estándar',
      type: 'CABINET',
      defaultWidth: 1.00,
      defaultDepth: 0.45,
      defaultHeight: 0.90,
      icon: Icons.all_inbox,
    ),
    FurnitureTemplate(
      id: 'furn_generic_chair',
      name: 'Silla Estándar',
      category: 'General / Estándar',
      type: 'CHAIR',
      defaultWidth: 0.45,
      defaultDepth: 0.45,
      defaultHeight: 0.85,
      icon: Icons.chair_alt,
    ),
    FurnitureTemplate(
      id: 'furn_side_table',
      name: 'Mesa Auxiliar / Lateral',
      category: 'General / Estándar',
      type: 'SIDE_TABLE',
      defaultWidth: 0.50,
      defaultDepth: 0.50,
      defaultHeight: 0.50,
      icon: Icons.crop_square,
    ),
    FurnitureTemplate(
      id: 'furn_bookshelf',
      name: 'Estantería / Biblioteca',
      category: 'General / Estándar',
      type: 'BOOKSHELF',
      defaultWidth: 1.00,
      defaultDepth: 0.35,
      defaultHeight: 1.80,
      icon: Icons.menu_book,
    ),
    FurnitureTemplate(
      id: 'furn_wall_cabinet',
      name: 'Alacena / Mueble Colgante',
      category: 'General / Estándar',
      type: 'WALL_CABINET',
      defaultWidth: 1.00,
      defaultDepth: 0.35,
      defaultHeight: 0.60,
      icon: Icons.vertical_split,
    ),

    // 1. Estar / Zona Social
    FurnitureTemplate(
      id: 'furn_sofa_3',
      name: 'Sofá 3 Puestos',
      category: 'Estar / Social',
      type: 'SOFA',
      defaultWidth: 2.10,
      defaultDepth: 0.90,
      defaultHeight: 0.80,
      icon: Icons.weekend,
    ),
    FurnitureTemplate(
      id: 'furn_sofa_2',
      name: 'Sofá 2 Puestos',
      category: 'Estar / Social',
      type: 'SOFA',
      defaultWidth: 1.60,
      defaultDepth: 0.85,
      defaultHeight: 0.80,
      icon: Icons.weekend_outlined,
    ),
    FurnitureTemplate(
      id: 'furn_armchair',
      name: 'Sillón Individual',
      category: 'Estar / Social',
      type: 'ARMCHAIR',
      defaultWidth: 0.85,
      defaultDepth: 0.85,
      defaultHeight: 0.80,
      icon: Icons.chair,
    ),
    FurnitureTemplate(
      id: 'furn_coffee_table',
      name: 'Mesa de Centro / Ratona',
      category: 'Estar / Social',
      type: 'COFFEE_TABLE',
      defaultWidth: 1.10,
      defaultDepth: 0.60,
      defaultHeight: 0.45,
      icon: Icons.table_restaurant,
    ),
    FurnitureTemplate(
      id: 'furn_tv_unit',
      name: 'Mueble TV / Modular',
      category: 'Estar / Social',
      type: 'TV_UNIT',
      defaultWidth: 1.80,
      defaultDepth: 0.45,
      defaultHeight: 0.60,
      icon: Icons.tv,
    ),

    // 2. Comedor
    FurnitureTemplate(
      id: 'furn_dining_6',
      name: 'Comedor 6 Puestos',
      category: 'Comedor',
      type: 'DINING_TABLE',
      defaultWidth: 1.60,
      defaultDepth: 0.90,
      defaultHeight: 0.75,
      icon: Icons.table_bar,
    ),
    FurnitureTemplate(
      id: 'furn_dining_4',
      name: 'Comedor 4 Puestos',
      category: 'Comedor',
      type: 'DINING_TABLE',
      defaultWidth: 1.20,
      defaultDepth: 0.80,
      defaultHeight: 0.75,
      icon: Icons.table_restaurant_outlined,
    ),
    FurnitureTemplate(
      id: 'furn_round_dining',
      name: 'Mesa Redonda 4 Puestos',
      category: 'Comedor',
      type: 'ROUND_TABLE',
      defaultWidth: 1.10,
      defaultDepth: 1.10,
      defaultHeight: 0.75,
      icon: Icons.circle_outlined,
    ),

    // 3. Cocina
    FurnitureTemplate(
      id: 'furn_sink_counter',
      name: 'Mesada con Bacha / Lavaplatos',
      category: 'Cocina',
      type: 'SINK_COUNTER',
      defaultWidth: 1.80,
      defaultDepth: 0.60,
      defaultHeight: 0.90,
      icon: Icons.countertops,
    ),
    FurnitureTemplate(
      id: 'furn_stove',
      name: 'Cocina / Anafe 4 Hornallas',
      category: 'Cocina',
      type: 'STOVE',
      defaultWidth: 0.60,
      defaultDepth: 0.60,
      defaultHeight: 0.90,
      icon: Icons.soup_kitchen,
    ),
    FurnitureTemplate(
      id: 'furn_fridge',
      name: 'Refrigerador / Heladera',
      category: 'Cocina',
      type: 'REFRIGERATOR',
      defaultWidth: 0.75,
      defaultDepth: 0.75,
      defaultHeight: 1.85,
      icon: Icons.kitchen,
    ),
    FurnitureTemplate(
      id: 'furn_kitchen_island',
      name: 'Isla de Cocina / Desayunador',
      category: 'Cocina',
      type: 'KITCHEN_ISLAND',
      defaultWidth: 1.60,
      defaultDepth: 0.85,
      defaultHeight: 0.90,
      icon: Icons.shelves,
    ),

    // 4. Dormitorio
    FurnitureTemplate(
      id: 'furn_bed_king',
      name: 'Cama King Size',
      category: 'Dormitorio',
      type: 'BED',
      defaultWidth: 2.00,
      defaultDepth: 2.00,
      defaultHeight: 0.55,
      icon: Icons.king_bed,
    ),
    FurnitureTemplate(
      id: 'furn_bed_queen',
      name: 'Cama Queen Size (2 Plazas)',
      category: 'Dormitorio',
      type: 'BED',
      defaultWidth: 1.60,
      defaultDepth: 2.00,
      defaultHeight: 0.50,
      icon: Icons.bed,
    ),
    FurnitureTemplate(
      id: 'furn_bed_single',
      name: 'Cama Individual (1 Plaza)',
      category: 'Dormitorio',
      type: 'BED',
      defaultWidth: 1.00,
      defaultDepth: 1.90,
      defaultHeight: 0.45,
      icon: Icons.single_bed,
    ),
    FurnitureTemplate(
      id: 'furn_nightstand',
      name: 'Mesa de Noche / Velador',
      category: 'Dormitorio',
      type: 'NIGHTSTAND',
      defaultWidth: 0.50,
      defaultDepth: 0.40,
      defaultHeight: 0.55,
      icon: Icons.crop_square,
    ),
    FurnitureTemplate(
      id: 'furn_wardrobe',
      name: 'Placard / Guardarropa',
      category: 'Dormitorio',
      type: 'WARDROBE',
      defaultWidth: 1.80,
      defaultDepth: 0.60,
      defaultHeight: 2.20,
      icon: Icons.door_sliding,
    ),
    FurnitureTemplate(
      id: 'furn_desk',
      name: 'Escritorio de Estudio',
      category: 'Dormitorio',
      type: 'DESK',
      defaultWidth: 1.20,
      defaultDepth: 0.60,
      defaultHeight: 0.75,
      icon: Icons.desk,
    ),

    // 5. Baño
    FurnitureTemplate(
      id: 'furn_toilet',
      name: 'Inodoro / Sanitario con Mochila',
      category: 'Baño',
      type: 'TOILET',
      defaultWidth: 0.45,
      defaultDepth: 0.70,
      defaultHeight: 0.45,
      icon: Icons.wc,
    ),
    FurnitureTemplate(
      id: 'furn_vanity',
      name: 'Vanitory / Lavamanos con Mueble',
      category: 'Baño',
      type: 'VANITY',
      defaultWidth: 0.70,
      defaultDepth: 0.50,
      defaultHeight: 0.85,
      icon: Icons.wash,
    ),
    FurnitureTemplate(
      id: 'furn_shower',
      name: 'Receptáculo de Ducha',
      category: 'Baño',
      type: 'SHOWER',
      defaultWidth: 0.90,
      defaultDepth: 0.90,
      defaultHeight: 0.10,
      icon: Icons.shower,
    ),
    FurnitureTemplate(
      id: 'furn_bathtub',
      name: 'Bañera / Tina',
      category: 'Baño',
      type: 'BATHTUB',
      defaultWidth: 1.50,
      defaultDepth: 0.75,
      defaultHeight: 0.50,
      icon: Icons.bathtub,
    ),

    // 6. Lavadero / Servicios
    FurnitureTemplate(
      id: 'furn_washing_machine',
      name: 'Lavarropas / Secadora',
      category: 'Lavadero',
      type: 'WASHING_MACHINE',
      defaultWidth: 0.65,
      defaultDepth: 0.65,
      defaultHeight: 0.85,
      icon: Icons.local_laundry_service,
    ),
    FurnitureTemplate(
      id: 'furn_laundry_sink',
      name: 'Pileta de Lavar Ropa',
      category: 'Lavadero',
      type: 'LAUNDRY_SINK',
      defaultWidth: 0.70,
      defaultDepth: 0.60,
      defaultHeight: 0.85,
      icon: Icons.water_damage,
    ),
  ];

  static List<String> get categories => [
    'Todos',
    'General / Estándar',
    'Estar / Social',
    'Comedor',
    'Cocina',
    'Dormitorio',
    'Baño',
    'Lavadero',
  ];

  static double getDefaultHeight(String type) {
    final upper = type.toUpperCase();
    final matches = catalog.where((f) => f.type.toUpperCase() == upper);
    if (matches.isNotEmpty) return matches.first.defaultHeight;
    return 0.75;
  }
}
