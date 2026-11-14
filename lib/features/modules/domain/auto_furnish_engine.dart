import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/geometry/bounding_box_2d.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/geometry_engine.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/modules/domain/module.dart';

/// Deterministic parametric layout engine ("Magic Layout") that populates
/// rooms with ergonomically spaced, collision-free furniture and sanitary
/// fixture ensembles based on canonical room classification and dimensions.
class AutoFurnishEngine {
  static const Uuid _uuid = Uuid();

  static double _snap(double v) => (v * 20.0).round() / 20.0;

  /// Generates a complete, wall-aligned furniture ensemble for [module].
  ///
  /// Enforces full [GeometryEngine.polygonContainsPolygon] containment (including
  /// concave L-shaped rooms), avoids all door clearance zones across the floor,
  /// avoids overlapping any already-placed or locked furniture items, and uses
  /// canonical [FurnitureTemplate] types (`VANITY`, `WASHING_MACHINE`, `LAUNDRY_SINK`).
  static List<SubModule> generateFurnitureForModule(
    Module module, {
    List<Module> allFloorModules = const [],
    List<SubModule> lockedObstacles = const [],
  }) {
    if (module.isLocked ||
        module.isOpening ||
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

    // Collect door/gate clearance zones intersecting this room so fixtures never block swings
    final doorBoxes = allFloorModules
        .where(
          (m) =>
              m.isDoorOrGate && m.geometry.boundingBox.inflate(0.15).intersects(bb),
        )
        .map((m) => m.geometry.boundingBox.inflate(0.25))
        .toList();

    final occupiedBoxes = lockedObstacles
        .where((s) => s.elevation < 1.0)
        .map((s) => s.geometry.boundingBox)
        .toList();

    final placed = <SubModule>[];

    if (module.isBedroom) {
      _furnishBedroom(module, bb, doorBoxes, occupiedBoxes, placed);
    } else if (module.isFullBathroom) {
      _furnishFullBathroom(module, bb, doorBoxes, occupiedBoxes, placed);
    } else if (module.isBathroom) {
      _furnishHalfBathroom(module, bb, doorBoxes, occupiedBoxes, placed);
    } else if (module.isKitchen) {
      _furnishKitchen(module, bb, doorBoxes, occupiedBoxes, placed);
    } else if (module.isLaundry) {
      _furnishLaundry(module, bb, doorBoxes, occupiedBoxes, placed);
    } else {
      final upperType = module.moduleType.toUpperCase();
      final upperName = module.name.toUpperCase();

      if (upperType.contains('LIVING_DINING') ||
          (upperName.contains('SALA') && upperName.contains('COMEDOR'))) {
        _furnishLivingDining(module, bb, doorBoxes, occupiedBoxes, placed);
      } else if (upperType.contains('LIVING') ||
          upperName.contains('SALA') ||
          upperName.contains('ESTAR')) {
        _furnishLivingRoom(module, bb, doorBoxes, occupiedBoxes, placed);
      } else if (upperType.contains('DINING') || upperName.contains('COMEDOR')) {
        _furnishDiningRoom(module, bb, doorBoxes, occupiedBoxes, placed);
      } else if (upperType.contains('STUDIO') ||
          upperType.contains('STUDY') ||
          upperType.contains('OFFICE') ||
          upperName.contains('ESTUDIO') ||
          upperName.contains('OFICINA')) {
        _furnishStudio(module, bb, doorBoxes, occupiedBoxes, placed);
      }
    }

    return placed;
  }

  static bool _boxesOverlapArea(BoundingBox2D a, BoundingBox2D b) {
    final overlapX = math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX);
    final overlapY = math.min(a.maxY, b.maxY) - math.max(a.minY, b.minY);
    return overlapX > 0.02 && overlapY > 0.02;
  }

  /// Builds a candidate [SubModule] with snap-before-clamp coordinates strictly
  /// bounded inside [roomBb].
  static SubModule _buildCandidate({
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
    final availW = math.max(0.20, roomBb.width - 0.10);
    final availD = math.max(0.20, roomBb.height - 0.10);
    final safeW = math.min(_snap(math.max(0.20, width)), availW);
    final safeD = math.min(_snap(math.max(0.20, depth)), availD);

    final minX = roomBb.minX + 0.05;
    final minY = roomBb.minY + 0.05;
    final maxX = math.max(minX, roomBb.maxX - safeW - 0.05);
    final maxY = math.max(minY, roomBb.maxY - safeD - 0.05);

    // Snap BEFORE clamping so odd-sized rooms never push vertices past boundaries
    final snappedX = _snap(x).clamp(minX, maxX);
    final snappedY = _snap(y).clamp(minY, maxY);

    return SubModule(
      id: _uuid.v4(),
      moduleId: moduleId,
      name: name,
      type: type,
      geometry: Polygon2D.fromRect(snappedX, snappedY, safeW, safeD),
      status: ElementStatus.isNew,
      height: height,
      elevation: elevation,
    );
  }

  static bool _isCandidateValid(
    Module module,
    SubModule candidate,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
  ) {
    if (!GeometryEngine.polygonContainsPolygon(
      module.geometry,
      candidate.geometry,
    )) {
      return false;
    }

    if (candidate.elevation < 1.0) {
      final cBb = candidate.geometry.boundingBox;
      if (doorBoxes.any((d) => _boxesOverlapArea(d, cBb))) {
        return false;
      }
      if (occupiedBoxes.any((o) => _boxesOverlapArea(o, cBb))) {
        return false;
      }
    }
    return true;
  }

  static void _tryPlace({
    required Module module,
    required BoundingBox2D roomBb,
    required List<BoundingBox2D> doorBoxes,
    required List<BoundingBox2D> occupiedBoxes,
    required List<SubModule> target,
    required String name,
    required String type,
    required double x,
    required double y,
    required double width,
    required double depth,
    required double height,
    double elevation = 0.0,
    bool allowGridRelocation = true,
  }) {
    final initial = _buildCandidate(
      moduleId: module.id,
      name: name,
      type: type,
      x: x,
      y: y,
      width: width,
      depth: depth,
      height: height,
      elevation: elevation,
      roomBb: roomBb,
    );
    if (_isCandidateValid(module, initial, doorBoxes, occupiedBoxes)) {
      target.add(initial);
      if (elevation < 1.0) {
        occupiedBoxes.add(initial.geometry.boundingBox);
      }
      return;
    }

    if (!allowGridRelocation) return;

    // Fallback search inside the room polygon ordered by closeness to target (x, y),
    // accommodating L-shaped notches, doors, or locked existing fixtures.
    final step = 0.25;
    final candidates = <(double distSq, SubModule sub)>[];
    final maxX = math.max(roomBb.minX + 0.05, roomBb.maxX - 0.25);
    final maxY = math.max(roomBb.minY + 0.05, roomBb.maxY - 0.25);
    for (double cy = roomBb.minY + 0.08; cy <= maxY; cy += step) {
      for (double cx = roomBb.minX + 0.08; cx <= maxX; cx += step) {
        final c = _buildCandidate(
          moduleId: module.id,
          name: name,
          type: type,
          x: cx,
          y: cy,
          width: width,
          depth: depth,
          height: height,
          elevation: elevation,
          roomBb: roomBb,
        );
        if (_isCandidateValid(module, c, doorBoxes, occupiedBoxes)) {
          final dx = cx - x;
          final dy = cy - y;
          candidates.add((dx * dx + dy * dy, c));
        }
      }
    }

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => a.$1.compareTo(b.$1));
      final chosen = candidates.first.$2;
      target.add(chosen);
      if (elevation < 1.0) {
        occupiedBoxes.add(chosen.geometry.boundingBox);
      }
    }
  }

  static void _furnishBedroom(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    final isMaster = bb.width >= 3.20 && bb.height >= 3.00;
    final isStandard = bb.width >= 2.40 && bb.height >= 2.40;

    final bedW = isMaster ? 2.00 : (isStandard ? 1.60 : 1.00);
    final bedD = isMaster ? 2.00 : (isStandard ? 2.00 : 1.90);
    final bedH = isMaster ? 0.55 : (isStandard ? 0.50 : 0.45);
    final bedName = isMaster
        ? 'Cama King Size'
        : (isStandard ? 'Cama Queen Size' : 'Cama Individual');

    final topCheck = BoundingBox2D(
      minX: bb.minX + (bb.width - bedW) / 2,
      minY: bb.minY + 0.05,
      maxX: bb.minX + (bb.width + bedW) / 2,
      maxY: bb.minY + 0.60,
    );
    final topBlocked = doorBoxes.any((d) => d.intersects(topCheck));

    final bedX = bb.minX + (bb.width - bedW) / 2;
    final bedY = topBlocked ? (bb.maxY - bedD - 0.08) : (bb.minY + 0.08);

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: bedName,
      type: 'BED',
      x: bedX,
      y: bedY,
      width: bedW,
      depth: bedD,
      height: bedH,
    );

    final nightY = topBlocked ? (bb.maxY - 0.53) : (bb.minY + 0.08);
    if (bb.width >= bedW + 0.65) {
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Mesa de Noche Izq.',
        type: 'NIGHTSTAND',
        x: bedX - 0.50,
        y: nightY,
        width: 0.45,
        depth: 0.45,
        height: 0.55,
        allowGridRelocation: false,
      );
    }
    if (bb.width >= bedW + 1.20) {
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Mesa de Noche Der.',
        type: 'NIGHTSTAND',
        x: bedX + bedW + 0.05,
        y: nightY,
        width: 0.45,
        depth: 0.45,
        height: 0.55,
        allowGridRelocation: false,
      );
    }

    if (bb.height >= bedD + 1.25) {
      final closetW = math.min(1.80, bb.width - 0.60);
      final closetY = topBlocked ? (bb.minY + 0.08) : (bb.maxY - 0.68);
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Clóset de Piso a Techo',
        type: 'WARDROBE',
        x: bb.minX + 0.15,
        y: closetY,
        width: closetW,
        depth: 0.60,
        height: 2.20,
      );
    }
  }

  static void _furnishFullBathroom(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    final horizontalLayout = bb.width >= bb.height;

    if (horizontalLayout) {
      final showerW = math.min(0.95, bb.width * 0.36);
      final showerD = math.min(0.95, bb.height - 0.16);
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Cabina de Ducha Templada',
        type: 'SHOWER',
        x: bb.maxX - showerW - 0.08,
        y: bb.minY + 0.08,
        width: showerW,
        depth: showerD,
        height: 2.00,
      );

      final vanityW = math.min(0.75, math.max(0.45, (bb.width - showerW) * 0.40));
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Mueble Lavamanos (Vanity)',
        type: 'VANITY',
        x: bb.minX + 0.08,
        y: bb.minY + 0.08,
        width: vanityW,
        depth: 0.50,
        height: 0.85,
      );

      final toiletX = bb.minX + 0.08 + vanityW + 0.12;
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Inodoro / Sanitario',
        type: 'TOILET',
        x: toiletX,
        y: bb.minY + 0.08,
        width: 0.45,
        depth: 0.65,
        height: 0.78,
      );
    } else {
      final showerW = math.min(0.95, bb.width - 0.16);
      final showerD = math.min(0.90, bb.height * 0.34);
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Cabina de Ducha Templada',
        type: 'SHOWER',
        x: bb.minX + 0.08,
        y: bb.minY + 0.08,
        width: showerW,
        depth: showerD,
        height: 2.00,
      );

      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Inodoro / Sanitario',
        type: 'TOILET',
        x: bb.minX + 0.08,
        y: bb.minY + showerD + 0.18,
        width: 0.65,
        depth: 0.45,
        height: 0.78,
      );

      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Mueble Lavamanos (Vanity)',
        type: 'VANITY',
        x: bb.minX + 0.08,
        y: bb.maxY - 0.85,
        width: 0.50,
        depth: math.min(0.75, bb.height * 0.28),
        height: 0.85,
      );
    }
  }

  static void _furnishHalfBathroom(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Inodoro Social',
      type: 'TOILET',
      x: bb.maxX - 0.55,
      y: bb.minY + 0.08,
      width: 0.45,
      depth: 0.65,
      height: 0.78,
    );
    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Mueble Lavamanos Social',
      type: 'VANITY',
      x: bb.minX + 0.08,
      y: bb.minY + 0.08,
      width: math.min(0.65, math.max(0.45, bb.width - 0.70)),
      depth: 0.48,
      height: 0.85,
    );
  }

  static void _furnishKitchen(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    const fridgeW = 0.75;
    const stoveW = 0.60;
    final remaining = math.max(0.50, bb.width - fridgeW - stoveW - 0.30);
    final availSinkW = math.min(1.80, remaining);

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Refrigerador',
      type: 'REFRIGERATOR',
      x: bb.minX + 0.08,
      y: bb.minY + 0.08,
      width: fridgeW,
      depth: 0.72,
      height: 1.85,
    );

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Mesón con Lavaplatos',
      type: 'SINK_COUNTER',
      x: bb.minX + 0.08 + fridgeW + 0.05,
      y: bb.minY + 0.08,
      width: availSinkW,
      depth: 0.60,
      height: 0.90,
    );

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Estufa 4 Puestos',
      type: 'STOVE',
      x: bb.minX + 0.08 + fridgeW + availSinkW + 0.10,
      y: bb.minY + 0.08,
      width: stoveW,
      depth: 0.60,
      height: 0.90,
    );

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Alacena Superior',
      type: 'WALL_CABINET',
      x: bb.minX + 0.08 + fridgeW + 0.05,
      y: bb.minY + 0.08,
      width: availSinkW,
      depth: 0.35,
      height: 0.65,
      elevation: 1.50,
    );

    if (bb.height >= 2.80 && bb.width >= 2.60) {
      final islandW = math.min(1.60, bb.width - 1.00);
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Isla Desayunadora de Cuarzo',
        type: 'KITCHEN_ISLAND',
        x: bb.minX + (bb.width - islandW) / 2,
        y: bb.maxY - 1.05,
        width: islandW,
        depth: 0.80,
        height: 0.90,
      );
    }
  }

  static void _furnishLivingRoom(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    final sofaW = math.min(2.10, bb.width - 0.60);
    final sofaX = bb.minX + (bb.width - sofaW) / 2;

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Sofá 3 Puestos',
      type: 'SOFA',
      x: sofaX,
      y: bb.minY + 0.12,
      width: sofaW,
      depth: 0.90,
      height: 0.80,
    );

    if (bb.height >= 2.30) {
      final tableW = math.min(1.10, sofaW * 0.65);
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Mesa de Centro',
        type: 'COFFEE_TABLE',
        x: bb.minX + (bb.width - tableW) / 2,
        y: bb.minY + 1.25,
        width: tableW,
        depth: 0.60,
        height: 0.45,
      );
    }

    if (bb.height >= 2.80) {
      final tvW = math.min(1.80, bb.width - 0.80);
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Mueble TV Modular',
        type: 'TV_UNIT',
        x: bb.minX + (bb.width - tvW) / 2,
        y: bb.maxY - 0.55,
        width: tvW,
        depth: 0.45,
        height: 0.60,
      );
    }
  }

  static void _furnishDiningRoom(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    final isLarge = bb.width >= 3.00 && bb.height >= 2.60;
    final tableW = isLarge ? 1.60 : 1.20;
    final tableD = isLarge ? 0.90 : 0.80;
    final tableX = bb.minX + (bb.width - tableW) / 2;
    final tableY = bb.minY + (bb.height - tableD) / 2;

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: isLarge ? 'Mesa Comedor 6 Puestos' : 'Mesa Comedor 4 Puestos',
      type: 'DINING_TABLE',
      x: tableX,
      y: tableY,
      width: tableW,
      depth: tableD,
      height: 0.75,
    );

    if (bb.height >= tableD + 1.30) {
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Silla Comedor Norte',
        type: 'CHAIR',
        x: tableX + (tableW - 0.45) / 2,
        y: tableY - 0.50,
        width: 0.45,
        depth: 0.45,
        height: 0.85,
      );
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Silla Comedor Sur',
        type: 'CHAIR',
        x: tableX + (tableW - 0.45) / 2,
        y: tableY + tableD + 0.05,
        width: 0.45,
        depth: 0.45,
        height: 0.85,
      );
    }
  }

  static void _furnishLivingDining(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    final halfW = bb.width / 2;
    final sofaW = math.min(1.90, halfW - 0.30);

    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Sofá Social',
      type: 'SOFA',
      x: bb.minX + 0.15,
      y: bb.minY + 0.12,
      width: sofaW,
      depth: 0.85,
      height: 0.80,
    );

    if (bb.height >= 2.40) {
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Mesa de Centro',
        type: 'COFFEE_TABLE',
        x: bb.minX + 0.35,
        y: bb.minY + 1.15,
        width: math.min(1.00, sofaW * 0.7),
        depth: 0.55,
        height: 0.45,
      );
    }

    final tableW = math.min(1.50, halfW - 0.40);
    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Mesa Comedor Principal',
      type: 'DINING_TABLE',
      x: bb.minX + halfW + 0.20,
      y: bb.minY + (bb.height - 0.85) / 2,
      width: tableW,
      depth: 0.85,
      height: 0.75,
    );
  }

  static void _furnishStudio(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    final deskW = math.min(1.40, bb.width - 0.40);
    final deskX = bb.minX + (bb.width - deskW) / 2;
    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Escritorio Ejecutivo',
      type: 'DESK',
      x: deskX,
      y: bb.minY + 0.12,
      width: deskW,
      depth: 0.65,
      height: 0.75,
    );
    if (bb.height >= 1.60) {
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Silla Ergonómica',
        type: 'CHAIR',
        x: bb.minX + (bb.width - 0.50) / 2,
        y: bb.minY + 0.82,
        width: 0.50,
        depth: 0.50,
        height: 0.90,
      );
    }
    if (bb.height >= 2.20) {
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Biblioteca Modular',
        type: 'BOOKSHELF',
        x: bb.minX + 0.12,
        y: bb.maxY - 0.45,
        width: math.min(1.20, bb.width - 0.30),
        depth: 0.35,
        height: 1.80,
      );
    }
  }

  static void _furnishLaundry(
    Module mod,
    BoundingBox2D bb,
    List<BoundingBox2D> doorBoxes,
    List<BoundingBox2D> occupiedBoxes,
    List<SubModule> items,
  ) {
    _tryPlace(
      module: mod,
      roomBb: bb,
      doorBoxes: doorBoxes,
      occupiedBoxes: occupiedBoxes,
      target: items,
      name: 'Lavadora / Torre de Lavado',
      type: 'WASHING_MACHINE',
      x: bb.minX + 0.08,
      y: bb.minY + 0.08,
      width: 0.65,
      depth: 0.65,
      height: 0.90,
    );
    if (bb.width >= 1.50) {
      _tryPlace(
        module: mod,
        roomBb: bb,
        doorBoxes: doorBoxes,
        occupiedBoxes: occupiedBoxes,
        target: items,
        name: 'Lavadero de Ropas',
        type: 'LAUNDRY_SINK',
        x: bb.minX + 0.80,
        y: bb.minY + 0.08,
        width: math.min(0.65, bb.width - 0.90),
        depth: 0.60,
        height: 0.88,
      );
    }
  }
}
