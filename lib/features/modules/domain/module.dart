import 'package:flutter/material.dart';
import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/modules/domain/furniture_template.dart';

/// Submódulo o componente interno de un espacio (p. ej. Sanitario, Ducha, Mesón, Mueble).
class SubModule {
  final String id;
  final String moduleId;
  final String name;
  final String type;
  final Polygon2D geometry;
  final ElementStatus status;
  final double? height; // Altura propia del mueble (m) personalizada
  final double elevation; // Elevación sobre el piso terminado (m)
  final bool isLocked;

  const SubModule({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.type,
    required this.geometry,
    required this.status,
    this.height,
    this.elevation = 0.0,
    this.isLocked = false,
  });

  /// Altura arquitectónica efectiva (usa la personalizada o el estándar del catálogo)
  double get resolvedHeight => height ?? FurnitureTemplate.getDefaultHeight(type);

  /// Effective floor-to-base elevation in meters (wall cabinets default to 1.50m above finished floor).
  double get resolvedElevation =>
      (type.toUpperCase() == 'WALL_CABINET' && elevation <= 0.01)
          ? 1.50
          : elevation;

  /// Canonical 3D volume color for this furniture piece.
  Color get default3dColor => FurnitureTemplate.getDefault3dColor(type);

  SubModule copyWith({
    String? id,
    String? moduleId,
    String? name,
    String? type,
    Polygon2D? geometry,
    ElementStatus? status,
    double? height,
    double? elevation,
    bool? isLocked,
  }) {
    return SubModule(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      name: name ?? this.name,
      type: type ?? this.type,
      geometry: geometry ?? this.geometry,
      status: status ?? this.status,
      height: height ?? this.height,
      elevation: elevation ?? this.elevation,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_id': moduleId,
        'name': name,
        'type': type,
        'geometry': geometry.toJson(),
        'status': status.name,
        if (height != null) 'height': height,
        'elevation': elevation,
        'is_locked': isLocked,
      };

  factory SubModule.fromJson(Map<String, dynamic> json) => SubModule(
        id: json['id'] as String,
        moduleId: json['module_id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        geometry: Polygon2D.fromJson(json['geometry'] as Map<String, dynamic>),
        status: ElementStatus.values.byName(json['status'] as String),
        height: (json['height'] as num?)?.toDouble(),
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        isLocked: json['is_locked'] as bool? ?? false,
      );
}

/// Módulo arquitectónico (Espacio funcional: Cocina, Sala, Habitación, Baño).
class Module {
  final String id;
  final String floorId;
  final String name;
  final String moduleType;
  final Polygon2D geometry;
  final ElementStatus status;
  final List<SubModule> subModules;
  final bool flipX;
  final bool flipY;
  final bool isLocked;
  final String? floorMaterialId;
  final String? wallFinishId;
  final DateTime createdAt;

  Module({
    required this.id,
    required this.floorId,
    required this.name,
    required this.moduleType,
    required this.geometry,
    required this.status,
    this.subModules = const [],
    this.flipX = false,
    this.flipY = false,
    this.isLocked = false,
    this.floorMaterialId,
    this.wallFinishId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get area => geometry.area;

  /// Whether this module represents a wall/perimeter opening (door, window, or gate).
  late final bool isOpening = _computeIsOpening();

  bool _computeIsOpening() {
    final normalizedType = moduleType.toUpperCase();
    return normalizedType.contains('DOOR') ||
        normalizedType.contains('WINDOW') ||
        normalizedType.contains('GATE');
  }

  late final bool isDoor = moduleType.toUpperCase().contains('DOOR');
  late final bool isSlidingDoor =
      isDoor && moduleType.toUpperCase().contains('SLIDING');
  late final bool isSwingDoor = isDoor && !isSlidingDoor;
  late final bool isWindow = moduleType.toUpperCase().contains('WINDOW');
  late final bool isGate = moduleType.toUpperCase().contains('GATE');
  late final bool isDoorOrGate = isDoor || isGate;
  late final bool isStairs = moduleType.toUpperCase().contains('STAIR');

  /// Canonical room-type helpers used across 2D, 3D, PDF export, and AI BOQ.
  late final bool isBathroom = () {
    final t = moduleType.toUpperCase();
    final n = name.toUpperCase();
    return t.contains('BATH') ||
        t.contains('TOILET') ||
        n.contains('BAÑO') ||
        n.contains('BANO') ||
        n.contains('TOILETTE');
  }();

  late final bool isFullBathroom = () {
    final n = name.toUpperCase();
    return isBathroom &&
        !n.contains('SOCIAL') &&
        !n.contains('VISITA') &&
        !n.contains('MEDIO') &&
        !n.contains('TOILETTE');
  }();

  late final bool isKitchen = () {
    final t = moduleType.toUpperCase();
    final n = name.toUpperCase();
    return t.contains('KITCHEN') || n.contains('COCINA');
  }();

  late final bool isLaundry = () {
    final t = moduleType.toUpperCase();
    final n = name.toUpperCase();
    return t.contains('LAUNDRY') ||
        n.contains('LAVAD') ||
        n.contains('LAVANDER') ||
        n.contains('ROPAS');
  }();

  late final bool isWetCore = isBathroom || isKitchen || isLaundry;

  late final bool isBedroom = () {
    final t = moduleType.toUpperCase();
    final n = name.toUpperCase();
    return t.contains('BEDROOM') ||
        n.contains('DORMITORIO') ||
        n.contains('ALCOBA') ||
        n.contains('HABITACI');
  }();

  late final bool isOutdoorUnpaved = () {
    final t = moduleType.toUpperCase();
    final n = name.toUpperCase();
    return t == 'POOL' ||
        t == 'GARDEN' ||
        n.contains('PISCINA') ||
        n.contains('JARDÍN') ||
        n.contains('JARDIN');
  }();

  /// Whether this module is a primary habitable space subject to natural light/ventilation rules.
  late final bool isHabitableRoom = () {
    final t = moduleType.toUpperCase();
    return t == 'BEDROOM' ||
        t == 'LIVING_ROOM' ||
        t == 'DINING_ROOM' ||
        t == 'LIVING_DINING' ||
        t == 'STUDIO' ||
        t == 'STUDY' ||
        t == 'OFFICE';
  }();

  /// Whether this module is a circulation/distribution space.
  late final bool isCirculation = () {
    final t = moduleType.toUpperCase();
    final n = name.toUpperCase();
    return t == 'CORRIDOR' ||
        t == 'HALLWAY' ||
        t == 'FOYER' ||
        n.contains('PASILLO') ||
        n.contains('HALL') ||
        n.contains('DISTRIBUIDOR') ||
        n.contains('CIRCULACION');
  }();

  /// Compact architectural room code used in 2D and 3D badges.
  late final String shortCode = compactRoomCode(name);

  static String compactRoomCode(String rawName) {
    final upper = rawName.toUpperCase();
    if (upper.contains('LAVAD') ||
        upper.contains('LAVANDER') ||
        upper.contains('ROPAS')) {
      return 'LAV.';
    }
    if (upper.contains('BAÑO') || upper.contains('TOILET')) return 'BAÑO';
    if (upper.contains('COCINA')) return 'COCINA';
    if (upper.contains('ESCALERA')) return 'ESC.';
    if (upper.contains('ESTAR') ||
        upper.contains('SALA') ||
        upper.contains('LIVING')) {
      return 'ESTAR';
    }
    if (upper.contains('COMEDOR')) return 'COMEDOR';
    if (upper.contains('DORMITORIO') || upper.contains('HABITACI')) {
      return 'DORM.';
    }
    if (upper.contains('GARAJE') || upper.contains('COCHERA')) return 'GAR.';
    if (upper.contains('ESTUDIO') || upper.contains('OFICINA')) {
      return 'ESTUDIO';
    }
    if (upper.contains('PATIO') || upper.contains('JARD')) return 'PATIO';
    if (upper.contains('TERRAZA') || upper.contains('BALC')) return 'BALCÓN';
    return rawName.length > 7 ? '${rawName.substring(0, 6)}.' : rawName;
  }

  Module copyWith({
    String? id,
    String? floorId,
    String? name,
    String? moduleType,
    Polygon2D? geometry,
    ElementStatus? status,
    List<SubModule>? subModules,
    bool? flipX,
    bool? flipY,
    bool? isLocked,
    String? floorMaterialId,
    String? wallFinishId,
    bool clearFloorMaterial = false,
    bool clearWallFinish = false,
  }) {
    return Module(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      name: name ?? this.name,
      moduleType: moduleType ?? this.moduleType,
      geometry: geometry ?? this.geometry,
      status: status ?? this.status,
      subModules: subModules ?? this.subModules,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      isLocked: isLocked ?? this.isLocked,
      floorMaterialId:
          clearFloorMaterial ? null : (floorMaterialId ?? this.floorMaterialId),
      wallFinishId:
          clearWallFinish ? null : (wallFinishId ?? this.wallFinishId),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor_id': floorId,
        'name': name,
        'module_type': moduleType,
        'geometry': {
          ...geometry.toJson(),
          'flip_x': flipX,
          'flip_y': flipY,
          'is_locked': isLocked,
          if (floorMaterialId != null) 'floor_material_id': floorMaterialId,
          if (wallFinishId != null) 'wall_finish_id': wallFinishId,
        },
        'status': status.name,
        'sub_modules': subModules.map((s) => s.toJson()).toList(),
        'is_locked': isLocked,
        if (floorMaterialId != null) 'floor_material_id': floorMaterialId,
        if (wallFinishId != null) 'wall_finish_id': wallFinishId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Module.fromJson(Map<String, dynamic> json) {
    final geomRaw =
        (json['geometry'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final statusName = json['status']?.toString();
    final parsedStatus = ElementStatus.values
            .where((e) => e.name == statusName)
            .firstOrNull ??
        ElementStatus.existing;
    final rawCreatedAt = json['created_at']?.toString();
    return Module(
      id: json['id']?.toString() ?? '',
      floorId: json['floor_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Espacio',
      moduleType: json['module_type']?.toString() ?? 'ROOM',
      geometry: Polygon2D.fromJson(geomRaw),
      status: parsedStatus,
      subModules: (json['sub_modules'] as List<dynamic>?)
              ?.map((s) => SubModule.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      flipX: json['flip_x'] as bool? ?? geomRaw['flip_x'] as bool? ?? false,
      flipY: json['flip_y'] as bool? ?? geomRaw['flip_y'] as bool? ?? false,
      isLocked:
          json['is_locked'] as bool? ?? geomRaw['is_locked'] as bool? ?? false,
      floorMaterialId: json['floor_material_id'] as String? ??
          geomRaw['floor_material_id'] as String?,
      wallFinishId: json['wall_finish_id'] as String? ??
          geomRaw['wall_finish_id'] as String?,
      createdAt:
          (rawCreatedAt != null ? DateTime.tryParse(rawCreatedAt) : null) ??
              DateTime.now(),
    );
  }
}
