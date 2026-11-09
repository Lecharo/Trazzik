import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/bounding_box_2d.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Deterministic parametric layout engine ("Magic Layout") that populates
/// rooms with ergonomically spaced, collision-free furniture and sanitary
/// fixture ensembles based on canonical room classification and dimensions.
class AutoFurnishEngine {
  static const Uuid _uuid = Uuid();

  static double _snap(double v) => (v * 20.0).round() / 20.0;

  /// Generates a complete, wall-aligned furniture ensemble for [module].
  /// Returns an empty list for openings, stairs, demolished rooms, or outdoor unpaved areas.
  static List<SubModule> generateFurnitureForModule(
    Module module, {
    List<Module> allFloorModules = const [],
  }) {
    if (module.isOpening ||
        module.isStairs ||
        module.isOutdoorUnpaved ||
        module.status == ElementStatus.toDemolish ||
        module.isCirculation) {
      return const [];
    }

    final bb = module.geometry.boundingBox;
    if (bb.width < 1.10 || bb.height < 1.10) {
      return const [];
    }

    // Collect bounding boxes of doors/windows touching this room so we avoid blocking doors
    final doorBoxes = allFloorModules
        .where((m) => m.isDoorOrGate && m.geometry.boundingBox.inflate(0.15).intersects(bb))
        .map((m) => m.geometry.boundingBox.inflate(0.25))
        .toList();

    if (module.isBedroom) {
      return _furnishBedroom(module, bb, doorBoxes);
    }
    if (module.isFullBathroom) {
      return _furnishFullBathroom(module, bb);
    }
    if (module.isBathroom) {
      return _furnishHalfBathroom(module, bb);
    }
    if (module.isKitchen) {
      return _furnishKitchen(module, bb);
    }
    if (module.isLaundry) {
      return _furnishLaundry(module, bb);
    }

    final upperType = module.moduleType.toUpperCase();
    final upperName = module.name.toUpperCase();

    if (upperType.contains('LIVING_DINING') ||
        (upperName.contains('SALA') && upperName.contains('COMEDOR'))) {
      return _furnishLivingDining(module, bb);
    }
    if (upperType.contains('LIVING') ||
        upperName.contains('SALA') ||
        upperName.contains('ESTAR')) {
      return _furnishLivingRoom(module, bb);
    }
    if (upperType.contains('DINING') || upperName.contains('COMEDOR')) {
      return _furnishDiningRoom(module, bb);
    }
    if (upperType.contains('STUDIO') ||
        upperType.contains('STUDY') ||
        upperType.contains('OFFICE') ||
        upperName.contains('ESTUDIO') ||
        upperName.contains('OFICINA')) {
      return _furnishStudio(module, bb);
    }

    return const [];
  }

  static SubModule _makeSub({
    required String moduleId,
    required String name,
    required String type,
    required double x,
    required double y,
    required double width,
    required double depth,
    required double height,
    double elevation = 0.0,
    required BoundingBox2D roomBb,
  }) {
    final safeW = math.max(0.20, math.min(width, roomBb.width - 0.10));
    final safeD = math.max(0.20, math.min(depth, roomBb.height - 0.10));
    final maxX = math.max(roomBb.minX + 0.05, roomBb.maxX - safeW - 0.05);
    final maxY = math.max(roomBb.minY + 0.05, roomBb.maxY - safeD - 0.05);
    final clampedX = _snap(x.clamp(roomBb.minX + 0.05, maxX));
    final clampedY = _snap(y.clamp(roomBb.minY + 0.05, maxY));

    return SubModule(
      id: _uuid.v4(),
      moduleId: moduleId,
      name: name,
      type: type,
      geometry: Polygon2D.fromRect(
        clampedX,
        clampedY,
        _snap(safeW),
        _snap(safeD),
      ),
      status: ElementStatus.isNew,
      height: height,
      elevation: elevation,
    );
  }

  static List<SubModule> _furnishBedroom(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
  ) {
    final items = <SubModule>[];
    final isMaster = bb.width >= 3.20 && bb.height >= 3.00;
    final isStandard = bb.width >= 2.40 && bb.height >= 2.40;

    final bedW = isMaster ? 2.00 : (isStandard ? 1.60 : 1.00);
    final bedD = isMaster ? 2.00 : (isStandard ? 2.00 : 1.90);
    final bedH = isMaster ? 0.55 : (isStandard ? 0.50 : 0.45);
    final bedName = isMaster
        ? 'Cama King Size'
        : (isStandard ? 'Cama Queen Size' : 'Cama Individual');

    // Place headboard against top wall unless a door is on top wall
    final topCheck = BoundingBox2D(
      minX: bb.minX + (bb.width - bedW) / 2,
      minY: bb.minY + 0.05,
      maxX: bb.minX + (bb.width + bedW) / 2,
      maxY: bb.minY + 0.60,
    );
    final topBlocked = doorBoxes.any((d) => d.intersects(topCheck));

    final bedX = bb.minX + (bb.width - bedW) / 2;
    final bedY = topBlocked ? (bb.maxY - bedD - 0.08) : (bb.minY + 0.08);

    items.add(
      _makeSub(
        moduleId: mod.id,
        name: bedName,
        type: 'BED',
        x: bedX,
        y: bedY,
        width: bedW,
        depth: bedD,
        height: bedH,
        roomBb: bb,
      ),
    );

    // Nightstands flanking the headboard
    final nightY = topBlocked ? (bb.maxY - 0.53) : (bb.minY + 0.08);
    if (bb.width >= bedW + 0.65) {
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Mesa de Noche Izq.',
          type: 'NIGHTSTAND',
          x: bedX - 0.50,
          y: nightY,
          width: 0.45,
          depth: 0.45,
          height: 0.55,
          roomBb: bb,
        ),
      );
    }
    if (bb.width >= bedW + 1.20) {
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Mesa de Noche Der.',
          type: 'NIGHTSTAND',
          x: bedX + bedW + 0.05,
          y: nightY,
          width: 0.45,
          depth: 0.45,
          height: 0.55,
          roomBb: bb,
        ),
      );
    }

    // Closet on opposite wall if depth allows >= 0.70m passage
    if (bb.height >= bedD + 1.25) {
      final closetW = math.min(1.80, bb.width - 0.60);
      final closetY = topBlocked ? (bb.minY + 0.08) : (bb.maxY - 0.68);
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Clóset de Piso a Techo',
          type: 'WARDROBE',
          x: bb.minX + 0.15,
          y: closetY,
          width: closetW,
          depth: 0.60,
          height: 2.20,
          roomBb: bb,
        ),
      );
    }

    return items;
  }

  static List<SubModule> _furnishFullBathroom(Module mod, BoundingBox2D bb) {
    final items = <SubModule>[];
    final horizontalLayout = bb.width >= bb.height;

    if (horizontalLayout) {
      // Shower in top-right corner
      final showerW = math.min(0.95, bb.width * 0.36);
      final showerD = math.min(0.95, bb.height - 0.16);
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Cabina de Ducha Templada',
          type: 'SHOWER',
          x: bb.maxX - showerW - 0.08,
          y: bb.minY + 0.08,
          width: showerW,
          depth: showerD,
          height: 2.00,
          roomBb: bb,
        ),
      );

      // Toilet in middle along top wall
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Inodoro / Sanitario',
          type: 'TOILET',
          x: bb.minX + (bb.width - showerW) * 0.52,
          y: bb.minY + 0.08,
          width: 0.45,
          depth: 0.65,
          height: 0.78,
          roomBb: bb,
        ),
      );

      // Vanity sink near left wall
      final vanityW = math.min(0.85, (bb.width - showerW) * 0.45);
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Mueble Lavamanos (Vanity)',
          type: 'SINK',
          x: bb.minX + 0.08,
          y: bb.minY + 0.08,
          width: vanityW,
          depth: 0.50,
          height: 0.85,
          roomBb: bb,
        ),
      );
    } else {
      // Vertical bathroom layout
      final showerW = math.min(0.95, bb.width - 0.16);
      final showerD = math.min(0.90, bb.height * 0.34);
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Cabina de Ducha Templada',
          type: 'SHOWER',
          x: bb.minX + 0.08,
          y: bb.minY + 0.08,
          width: showerW,
          depth: showerD,
          height: 2.00,
          roomBb: bb,
        ),
      );

      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Inodoro / Sanitario',
          type: 'TOILET',
          x: bb.minX + 0.08,
          y: bb.minY + showerD + 0.18,
          width: 0.65,
          depth: 0.45,
          height: 0.78,
          roomBb: bb,
        ),
      );

      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Mueble Lavamanos (Vanity)',
          type: 'SINK',
          x: bb.minX + 0.08,
          y: bb.maxY - 0.85,
          width: 0.50,
          depth: math.min(0.75, bb.height * 0.28),
          height: 0.85,
          roomBb: bb,
        ),
      );
    }

    return items;
  }

  static List<SubModule> _furnishHalfBathroom(Module mod, BoundingBox2D bb) {
    return [
      _makeSub(
        moduleId: mod.id,
        name: 'Inodoro Social',
        type: 'TOILET',
        x: bb.maxX - 0.55,
        y: bb.minY + 0.08,
        width: 0.45,
        depth: 0.65,
        height: 0.78,
        roomBb: bb,
      ),
      _makeSub(
        moduleId: mod.id,
        name: 'Mueble Lavamanos Social',
        type: 'SINK',
        x: bb.minX + 0.08,
        y: bb.minY + 0.08,
        width: math.min(0.70, bb.width * 0.45),
        depth: 0.48,
        height: 0.85,
        roomBb: bb,
      ),
    ];
  }

  static List<SubModule> _furnishKitchen(Module mod, BoundingBox2D bb) {
    final items = <SubModule>[];

    // Linear counter + stove + fridge along top wall
    final fridgeW = 0.75;
    final stoveW = 0.60;
    final availSinkW = math.max(0.90, math.min(1.80, bb.width - fridgeW - stoveW - 0.30));

    items.add(
      _makeSub(
        moduleId: mod.id,
        name: 'Refrigerador / Heladera',
        type: 'REFRIGERATOR',
        x: bb.minX + 0.08,
        y: bb.minY + 0.08,
        width: fridgeW,
        depth: 0.72,
        height: 1.85,
        roomBb: bb,
      ),
    );

    items.add(
      _makeSub(
        moduleId: mod.id,
        name: 'Mesada con Lavaplatos',
        type: 'SINK_COUNTER',
        x: bb.minX + 0.08 + fridgeW + 0.05,
        y: bb.minY + 0.08,
        width: availSinkW,
        depth: 0.60,
        height: 0.90,
        roomBb: bb,
      ),
    );

    items.add(
      _makeSub(
        moduleId: mod.id,
        name: 'Cocina / Anafe 4 Hornallas',
        type: 'STOVE',
        x: bb.minX + 0.08 + fridgeW + availSinkW + 0.10,
        y: bb.minY + 0.08,
        width: stoveW,
        depth: 0.60,
        height: 0.90,
        roomBb: bb,
      ),
    );

    // Upper wall cabinet above sink counter
    items.add(
      _makeSub(
        moduleId: mod.id,
        name: 'Alacena Superior',
        type: 'WALL_CABINET',
        x: bb.minX + 0.08 + fridgeW + 0.05,
        y: bb.minY + 0.08,
        width: availSinkW,
        depth: 0.35,
        height: 0.65,
        elevation: 1.50,
        roomBb: bb,
      ),
    );

    // Kitchen island if room depth >= 2.80m
    if (bb.height >= 2.80 && bb.width >= 2.60) {
      final islandW = math.min(1.60, bb.width - 1.00);
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Isla Desayunadora de Cuarzo',
          type: 'KITCHEN_ISLAND',
          x: bb.minX + (bb.width - islandW) / 2,
          y: bb.maxY - 1.05,
          width: islandW,
          depth: 0.80,
          height: 0.90,
          roomBb: bb,
        ),
      );
    }

    return items;
  }

  static List<SubModule> _furnishLivingRoom(Module mod, BoundingBox2D bb) {
    final items = <SubModule>[];
    final sofaW = math.min(2.10, bb.width - 0.60);
    final sofaX = bb.minX + (bb.width - sofaW) / 2;

    items.add(
      _makeSub(
        moduleId: mod.id,
        name: 'Sofá 3 Puestos',
        type: 'SOFA',
        x: sofaX,
        y: bb.minY + 0.12,
        width: sofaW,
        depth: 0.90,
        height: 0.80,
        roomBb: bb,
      ),
    );

    if (bb.height >= 2.30) {
      final tableW = math.min(1.10, sofaW * 0.65);
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Mesa de Centro',
          type: 'COFFEE_TABLE',
          x: bb.minX + (bb.width - tableW) / 2,
          y: bb.minY + 1.25,
          width: tableW,
          depth: 0.60,
          height: 0.45,
          roomBb: bb,
        ),
      );
    }

    if (bb.height >= 2.80) {
      final tvW = math.min(1.80, bb.width - 0.80);
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Mueble TV Modular',
          type: 'TV_UNIT',
          x: bb.minX + (bb.width - tvW) / 2,
          y: bb.maxY - 0.55,
          width: tvW,
          depth: 0.45,
          height: 0.60,
          roomBb: bb,
        ),
      );
    }

    return items;
  }

  static List<SubModule> _furnishDiningRoom(Module mod, BoundingBox2D bb) {
    final isLarge = bb.width >= 3.00 && bb.height >= 2.60;
    final tableW = isLarge ? 1.60 : 1.20;
    final tableD = isLarge ? 0.90 : 0.80;
    final tableX = bb.minX + (bb.width - tableW) / 2;
    final tableY = bb.minY + (bb.height - tableD) / 2;

    final items = <SubModule>[
      _makeSub(
        moduleId: mod.id,
        name: isLarge ? 'Mesa Comedor 6 Puestos' : 'Mesa Comedor 4 Puestos',
        type: 'DINING_TABLE',
        x: tableX,
        y: tableY,
        width: tableW,
        depth: tableD,
        height: 0.75,
        roomBb: bb,
      ),
    ];

    if (bb.height >= tableD + 1.30) {
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Silla Comedor Norte',
          type: 'CHAIR',
          x: tableX + (tableW - 0.45) / 2,
          y: tableY - 0.50,
          width: 0.45,
          depth: 0.45,
          height: 0.85,
          roomBb: bb,
        ),
      );
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Silla Comedor Sur',
          type: 'CHAIR',
          x: tableX + (tableW - 0.45) / 2,
          y: tableY + tableD + 0.05,
          width: 0.45,
          depth: 0.45,
          height: 0.85,
          roomBb: bb,
        ),
      );
    }

    return items;
  }

  static List<SubModule> _furnishLivingDining(Module mod, BoundingBox2D bb) {
    final items = <SubModule>[];
    final halfW = bb.width / 2;

    // Left half: Living zone
    final sofaW = math.min(1.90, halfW - 0.30);
    items.add(
      _makeSub(
        moduleId: mod.id,
        name: 'Sofá Social',
        type: 'SOFA',
        x: bb.minX + 0.15,
        y: bb.minY + 0.12,
        width: sofaW,
        depth: 0.85,
        height: 0.80,
        roomBb: bb,
      ),
    );

    if (bb.height >= 2.40) {
      items.add(
        _makeSub(
          moduleId: mod.id,
          name: 'Mesa de Centro',
          type: 'COFFEE_TABLE',
          x: bb.minX + 0.35,
          y: bb.minY + 1.15,
          width: math.min(1.00, sofaW * 0.7),
          depth: 0.55,
          height: 0.45,
          roomBb: bb,
        ),
      );
    }

    // Right half: Dining zone
    final tableW = math.min(1.50, halfW - 0.40);
    items.add(
      _makeSub(
        moduleId: mod.id,
        name: 'Mesa Comedor Principal',
        type: 'DINING_TABLE',
        x: bb.minX + halfW + 0.20,
        y: bb.minY + (bb.height - 0.85) / 2,
        width: tableW,
        depth: 0.85,
        height: 0.75,
        roomBb: bb,
      ),
    );

    return items;
  }

  static List<SubModule> _furnishStudio(Module mod, BoundingBox2D bb) {
    final deskW = math.min(1.40, bb.width - 0.40);
    final deskX = bb.minX + (bb.width - deskW) / 2;
    return [
      _makeSub(
        moduleId: mod.id,
        name: 'Escritorio Ejecutivo',
        type: 'DESK',
        x: deskX,
        y: bb.minY + 0.12,
        width: deskW,
        depth: 0.65,
        height: 0.75,
        roomBb: bb,
      ),
      if (bb.height >= 1.60)
        _makeSub(
          moduleId: mod.id,
          name: 'Silla Ergonómica',
          type: 'CHAIR',
          x: bb.minX + (bb.width - 0.50) / 2,
          y: bb.minY + 0.82,
          width: 0.50,
          depth: 0.50,
          height: 0.90,
          roomBb: bb,
        ),
      if (bb.height >= 2.20)
        _makeSub(
          moduleId: mod.id,
          name: 'Biblioteca Modular',
          type: 'BOOKSHELF',
          x: bb.minX + 0.12,
          y: bb.maxY - 0.45,
          width: math.min(1.20, bb.width - 0.30),
          depth: 0.35,
          height: 1.80,
          roomBb: bb,
        ),
    ];
  }

  static List<SubModule> _furnishLaundry(Module mod, BoundingBox2D bb) {
    return [
      _makeSub(
        moduleId: mod.id,
        name: 'Lavadora / Torre de Lavado',
        type: 'WASHER',
        x: bb.minX + 0.08,
        y: bb.minY + 0.08,
        width: 0.65,
        depth: 0.65,
        height: 0.90,
        roomBb: bb,
      ),
      if (bb.width >= 1.50)
        _makeSub(
          moduleId: mod.id,
          name: 'Lavadero / Bacha de Ropas',
          type: 'SINK',
          x: bb.minX + 0.80,
          y: bb.minY + 0.08,
          width: math.min(0.65, bb.width - 0.90),
          depth: 0.60,
          height: 0.88,
          roomBb: bb,
        ),
    ];
  }
}
