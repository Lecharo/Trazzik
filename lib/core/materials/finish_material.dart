import 'package:flutter/material.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Surface category where a finish material can be applied.
enum FinishSurfaceTarget {
  floor,
  wall,
}

/// Procedural pattern rendered in 2D and 3D views for a finish material.
enum FinishPatternType {
  woodPlanks,
  porcelainGrid,
  marbleVeins,
  polishedConcrete,
  hydraulicTile,
  outdoorDeck,
  naturalGrass,
  paintedWall,
  exposedBrick,
  travertineStone,
}

/// Domain definition of an architectural finish material with visual appearance
/// and reference unit pricing for automatic BOQ calculation.
class FinishMaterial {
  final String id;
  final String nameEs;
  final String nameEn;
  final FinishSurfaceTarget target;
  final FinishPatternType pattern;
  final Color baseColor;
  final Color accentColor;
  final double pricePerM2Cop;
  final double pricePerM2Usd;
  final double boxCoverageM2;
  final String specDescriptionEs;

  const FinishMaterial({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.target,
    required this.pattern,
    required this.baseColor,
    required this.accentColor,
    required this.pricePerM2Cop,
    required this.pricePerM2Usd,
    this.boxCoverageM2 = 1.80,
    required this.specDescriptionEs,
  });

  String label(String lang) => lang == 'en' ? nameEn : nameEs;
}

/// Central catalog of floor and wall finishes available in the 2D/3D configurator.
class FinishMaterialCatalog {
  static const List<FinishMaterial> floors = [
    FinishMaterial(
      id: 'floor_oak_wood',
      nameEs: 'Madera Roble Europeo',
      nameEn: 'European Oak Wood',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.woodPlanks,
      baseColor: Color(0xFFC89F72),
      accentColor: Color(0xFF7D5632),
      pricePerM2Cop: 145000,
      pricePerM2Usd: 36.0,
      boxCoverageM2: 2.10,
      specDescriptionEs: 'Entablonado SPC / Laminado Roble Europeo 8mm biselado AC4',
    ),
    FinishMaterial(
      id: 'floor_walnut_wood',
      nameEs: 'Madera Nogal Oscuro',
      nameEn: 'Dark Walnut Wood',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.woodPlanks,
      baseColor: Color(0xFF795548),
      accentColor: Color(0xFF3E2723),
      pricePerM2Cop: 165000,
      pricePerM2Usd: 41.0,
      boxCoverageM2: 2.10,
      specDescriptionEs: 'Piso estructurado madera Nogal Americano acabado mate',
    ),
    FinishMaterial(
      id: 'floor_calacatta_marble',
      nameEs: 'Mármol Calacatta',
      nameEn: 'Calacatta Marble',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.marbleVeins,
      baseColor: Color(0xFFECEFF1),
      accentColor: Color(0xFF90A4AE),
      pricePerM2Cop: 195000,
      pricePerM2Usd: 48.0,
      boxCoverageM2: 1.44,
      specDescriptionEs: 'Porcelanato gran formato 60x120 cm rectificado veta Calacatta',
    ),
    FinishMaterial(
      id: 'floor_grey_porcelain',
      nameEs: 'Porcelanato Gris Urbano',
      nameEn: 'Urban Grey Porcelain',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.porcelainGrid,
      baseColor: Color(0xFF607D8B),
      accentColor: Color(0xFFCFD8DC),
      pricePerM2Cop: 98000,
      pricePerM2Usd: 24.5,
      boxCoverageM2: 1.80,
      specDescriptionEs: 'Porcelanato rectificado 60x60 cm tráfico residencial pesado',
    ),
    FinishMaterial(
      id: 'floor_polished_concrete',
      nameEs: 'Microcemento Pulido',
      nameEn: 'Polished Microcement',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.polishedConcrete,
      baseColor: Color(0xFF78909C),
      accentColor: Color(0xFF455A64),
      pricePerM2Cop: 130000,
      pricePerM2Usd: 32.5,
      boxCoverageM2: 1.00,
      specDescriptionEs: 'Microcemento monolítico sin juntas sellado poliuretano mate',
    ),
    FinishMaterial(
      id: 'floor_hydraulic_mosaic',
      nameEs: 'Mosaico Hidráulico',
      nameEn: 'Hydraulic Tile',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.hydraulicTile,
      baseColor: Color(0xFF00838F),
      accentColor: Color(0xFFE0F7FA),
      pricePerM2Cop: 138000,
      pricePerM2Usd: 34.5,
      boxCoverageM2: 1.20,
      specDescriptionEs: 'Baldosa hidráulica decorativa 20x20 cm antideslizante',
    ),
    FinishMaterial(
      id: 'floor_outdoor_deck',
      nameEs: 'Deck WPC Exterior',
      nameEn: 'Outdoor WPC Deck',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.outdoorDeck,
      baseColor: Color(0xFF8D6E63),
      accentColor: Color(0xFF4E342E),
      pricePerM2Cop: 185000,
      pricePerM2Usd: 46.0,
      boxCoverageM2: 1.50,
      specDescriptionEs: 'Listón deck WPC coextruido resistente a intemperie y UV',
    ),
    FinishMaterial(
      id: 'floor_natural_grass',
      nameEs: 'Grama / Jardín Natural',
      nameEn: 'Natural Grass Lawn',
      target: FinishSurfaceTarget.floor,
      pattern: FinishPatternType.naturalGrass,
      baseColor: Color(0xFF388E3C),
      accentColor: Color(0xFF81C784),
      pricePerM2Cop: 48000,
      pricePerM2Usd: 12.0,
      boxCoverageM2: 1.00,
      specDescriptionEs: 'Césped natural en rollo con sustrato orgánico drenante',
    ),
  ];

  static const List<FinishMaterial> walls = [
    FinishMaterial(
      id: 'wall_pure_white',
      nameEs: 'Blanco Arquitectónico',
      nameEn: 'Architectural White',
      target: FinishSurfaceTarget.wall,
      pattern: FinishPatternType.paintedWall,
      baseColor: Color(0xFFECEFF1),
      accentColor: Color(0xFFCFD8DC),
      pricePerM2Cop: 32000,
      pricePerM2Usd: 8.0,
      specDescriptionEs: 'Estuco plástico + 2 manos Vinilo Tipo 1 Blanco Puro lavable',
    ),
    FinishMaterial(
      id: 'wall_japandi_sand',
      nameEs: 'Arena Japandi Cálido',
      nameEn: 'Warm Japandi Sand',
      target: FinishSurfaceTarget.wall,
      pattern: FinishPatternType.paintedWall,
      baseColor: Color(0xFFE6DEC8),
      accentColor: Color(0xFFC8BCA1),
      pricePerM2Cop: 36000,
      pricePerM2Usd: 9.0,
      specDescriptionEs: 'Pintura acrílica mate tono Arena Japandi bajo VOC',
    ),
    FinishMaterial(
      id: 'wall_sage_green',
      nameEs: 'Verde Salvia Botánico',
      nameEn: 'Botanical Sage Green',
      target: FinishSurfaceTarget.wall,
      pattern: FinishPatternType.paintedWall,
      baseColor: Color(0xFFA5B8A6),
      accentColor: Color(0xFF7B907D),
      pricePerM2Cop: 38000,
      pricePerM2Usd: 9.5,
      specDescriptionEs: 'Pintura satinada lavable tono Verde Salvia acento interior',
    ),
    FinishMaterial(
      id: 'wall_stone_grey',
      nameEs: 'Gris Piedra Nórdico',
      nameEn: 'Nordic Stone Grey',
      target: FinishSurfaceTarget.wall,
      pattern: FinishPatternType.paintedWall,
      baseColor: Color(0xFFB0BEC5),
      accentColor: Color(0xFF78909C),
      pricePerM2Cop: 36000,
      pricePerM2Usd: 9.0,
      specDescriptionEs: 'Acabado mineral tono Gris Piedra contemporáneo',
    ),
    FinishMaterial(
      id: 'wall_terracotta',
      nameEs: 'Terracota Mediterráneo',
      nameEn: 'Mediterranean Terracotta',
      target: FinishSurfaceTarget.wall,
      pattern: FinishPatternType.paintedWall,
      baseColor: Color(0xFFD98A6C),
      accentColor: Color(0xFFA65B3E),
      pricePerM2Cop: 42000,
      pricePerM2Usd: 10.5,
      specDescriptionEs: 'Revestimiento texturizado tierra / Terracota cálido',
    ),
    FinishMaterial(
      id: 'wall_exposed_brick',
      nameEs: 'Ladrillo a la Vista',
      nameEn: 'Exposed Brick',
      target: FinishSurfaceTarget.wall,
      pattern: FinishPatternType.exposedBrick,
      baseColor: Color(0xFFB85D43),
      accentColor: Color(0xFFD7CCC8),
      pricePerM2Cop: 115000,
      pricePerM2Usd: 28.5,
      specDescriptionEs: 'Fachaleta de ladrillo macizo recocido hidrofugado mate',
    ),
    FinishMaterial(
      id: 'wall_travertine',
      nameEs: 'Piedra Travertino',
      nameEn: 'Travertine Stone',
      target: FinishSurfaceTarget.wall,
      pattern: FinishPatternType.travertineStone,
      baseColor: Color(0xFFD7CCC8),
      accentColor: Color(0xFF8D6E63),
      pricePerM2Cop: 168000,
      pricePerM2Usd: 42.0,
      specDescriptionEs: 'Enchape pétreo tipo Travertino apomazado en fajas horizontales',
    ),
  ];

  static FinishMaterial? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final f in floors) {
      if (f.id == id) return f;
    }
    for (final w in walls) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Resolves the active floor finish for a module, falling back to an
  /// architecturally appropriate material by room type when not explicitly set.
  static FinishMaterial resolveFloorForModule(Module mod) {
    final explicit = byId(mod.floorMaterialId);
    if (explicit != null && explicit.target == FinishSurfaceTarget.floor) {
      return explicit;
    }
    final type = mod.moduleType.toUpperCase();
    final name = mod.name.toUpperCase();

    if (type.contains('BEDROOM') ||
        type.contains('DRESSING') ||
        type.contains('STUDIO') ||
        type.contains('OFFICE') ||
        name.contains('DORMITORIO') ||
        name.contains('HABITACI') ||
        name.contains('ESTUDIO')) {
      return floors[0]; // European Oak Wood
    }
    if (type.contains('BATH') || name.contains('BAÑO') || name.contains('BANO')) {
      return floors[2]; // Calacatta Marble
    }
    if (type.contains('KITCHEN') || name.contains('COCINA')) {
      return floors[5]; // Hydraulic Mosaic
    }
    if (type.contains('GARDEN') ||
        type.contains('PATIO') ||
        name.contains('JARD') ||
        name.contains('PATIO')) {
      return floors[7]; // Natural Grass
    }
    if (type.contains('TERRACE') ||
        type.contains('DECK') ||
        name.contains('TERRAZA') ||
        name.contains('BALC')) {
      return floors[6]; // Outdoor Deck
    }
    if (type.contains('GARAGE') || name.contains('GARAJE') || name.contains('COCHERA')) {
      return floors[4]; // Polished Concrete
    }
    return floors[3]; // Urban Grey Porcelain (Living/Dining/Corridors default)
  }

  /// Resolves the active wall finish for a module, falling back to Architectural White.
  static FinishMaterial resolveWallForModule(Module mod) {
    final explicit = byId(mod.wallFinishId);
    if (explicit != null && explicit.target == FinishSurfaceTarget.wall) {
      return explicit;
    }
    return walls[0];
  }

  /// Curated 1-click whole-floor architectural style palettes ("Roomstyles").
  static const List<ArchitecturalStylePack> stylePacks = [
    ArchitecturalStylePack(
      id: 'style_japandi',
      nameEs: 'Japandi Cálido',
      nameEn: 'Japandi Warmth',
      livingFloorId: 'floor_oak_wood',
      bedroomFloorId: 'floor_oak_wood',
      livingWallId: 'wall_japandi_sand',
      wetFloorId: 'floor_grey_porcelain',
      wetWallId: 'wall_travertine',
      swatchPrimary: Color(0xFFC89D72),
      swatchSecondary: Color(0xFFE6DEC8),
    ),
    ArchitecturalStylePack(
      id: 'style_nordic',
      nameEs: 'Nórdico Minimal',
      nameEn: 'Nordic Minimal',
      livingFloorId: 'floor_oak_wood',
      bedroomFloorId: 'floor_oak_wood',
      livingWallId: 'wall_pure_white',
      wetFloorId: 'floor_hydraulic_mosaic',
      wetWallId: 'wall_sage_green',
      swatchPrimary: Color(0xFFF4F6F8),
      swatchSecondary: Color(0xFF9CAF9E),
    ),
    ArchitecturalStylePack(
      id: 'style_industrial',
      nameEs: 'Loft Industrial',
      nameEn: 'Industrial Loft',
      livingFloorId: 'floor_polished_concrete',
      bedroomFloorId: 'floor_walnut_wood',
      livingWallId: 'wall_exposed_brick',
      wetFloorId: 'floor_grey_porcelain',
      wetWallId: 'wall_stone_grey',
      swatchPrimary: Color(0xFF78909C),
      swatchSecondary: Color(0xFFB85D43),
    ),
    ArchitecturalStylePack(
      id: 'style_mediterranean',
      nameEs: 'Mediterráneo Terracota',
      nameEn: 'Mediterranean Terracotta',
      livingFloorId: 'floor_hydraulic_mosaic',
      bedroomFloorId: 'floor_oak_wood',
      livingWallId: 'wall_terracotta',
      wetFloorId: 'floor_calacatta_marble',
      wetWallId: 'wall_japandi_sand',
      swatchPrimary: Color(0xFFC97A57),
      swatchSecondary: Color(0xFF546E7A),
    ),
    ArchitecturalStylePack(
      id: 'style_calacatta_luxury',
      nameEs: 'Calacatta Luxury',
      nameEn: 'Calacatta Luxury',
      livingFloorId: 'floor_calacatta_marble',
      bedroomFloorId: 'floor_walnut_wood',
      livingWallId: 'wall_travertine',
      wetFloorId: 'floor_calacatta_marble',
      wetWallId: 'wall_travertine',
      swatchPrimary: Color(0xFFECEFF1),
      swatchSecondary: Color(0xFF6E4B35),
    ),
  ];
}

/// Coordinated whole-floor architectural finish palette ("Roomstyle") that routes
/// floor and wall materials by functional room typology in a single action.
class ArchitecturalStylePack {
  final String id;
  final String nameEs;
  final String nameEn;
  final String livingFloorId;
  final String bedroomFloorId;
  final String livingWallId;
  final String wetFloorId;
  final String wetWallId;
  final Color swatchPrimary;
  final Color swatchSecondary;

  const ArchitecturalStylePack({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.livingFloorId,
    required this.bedroomFloorId,
    required this.livingWallId,
    required this.wetFloorId,
    required this.wetWallId,
    required this.swatchPrimary,
    required this.swatchSecondary,
  });

  String label(String lang) => lang == 'en' ? nameEn : nameEs;

  /// Resolves the appropriate `(floorMaterialId, wallFinishId)` pair for [mod]
  /// based on canonical room classification.
  (String floorId, String wallId) resolveForModule(Module mod) {
    if (mod.isOutdoorUnpaved) {
      return ('floor_natural_grass', livingWallId);
    }
    final upperType = mod.moduleType.toUpperCase();
    final upperName = mod.name.toUpperCase();
    if (upperType.contains('TERRACE') ||
        upperType.contains('DECK') ||
        upperName.contains('TERRAZA') ||
        upperName.contains('BALC')) {
      return ('floor_outdoor_deck', livingWallId);
    }
    if (mod.isWetCore) {
      return (wetFloorId, wetWallId);
    }
    if (mod.isBedroom) {
      return (bedroomFloorId, livingWallId);
    }
    return (livingFloorId, livingWallId);
  }
}
