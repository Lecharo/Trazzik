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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get area => geometry.area;

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
        },
        'status': status.name,
        'sub_modules': subModules.map((s) => s.toJson()).toList(),
        'is_locked': isLocked,
        'created_at': createdAt.toIso8601String(),
      };

  factory Module.fromJson(Map<String, dynamic> json) {
    final geomRaw = json['geometry'] as Map<String, dynamic>;
    return Module(
      id: json['id'] as String,
      floorId: json['floor_id'] as String,
      name: json['name'] as String,
      moduleType: json['module_type'] as String,
      geometry: Polygon2D.fromJson(geomRaw),
      status: ElementStatus.values.byName(json['status'] as String),
      subModules: (json['sub_modules'] as List<dynamic>?)
              ?.map((s) => SubModule.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      flipX: json['flip_x'] as bool? ?? geomRaw['flip_x'] as bool? ?? false,
      flipY: json['flip_y'] as bool? ?? geomRaw['flip_y'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
