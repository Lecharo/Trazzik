import 'package:trazzik/core/geometry/element_status.dart';
import 'package:trazzik/core/geometry/polygon_2d.dart';
import 'package:trazzik/features/demolition/domain/replacement_relationship.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

/// Nivel o Piso independiente de una edificación.
class Floor {
  final String id;
  final String buildingId;
  final int floorNumber;
  final String name;
  final double levelMeters;
  final double heightMeters;
  final Polygon2D boundary;
  final double maxAllowedArea;
  final List<Module> modules;
  final List<Wall> walls;
  final List<ReplacementRelationship> replacementRelationships;

  Floor({
    required this.id,
    required this.buildingId,
    required this.floorNumber,
    required this.name,
    this.levelMeters = 0.0,
    this.heightMeters = 2.60,
    required this.boundary,
    required this.maxAllowedArea,
    this.modules = const [],
    this.walls = const [],
    this.replacementRelationships = const [],
  });

  double get floorGeometricArea => boundary.area;

  /// Superficie útil interior habitable (módulos propuestos o conservados que no son vanos de puertas o ventanas)
  late final double usableSpacesArea = modules
      .where(
        (m) =>
            (m.status == ElementStatus.isNew ||
                m.status == ElementStatus.preserved) &&
            !m.isOpening,
      )
      .fold(0.0, (acc, m) => acc + m.area);

  /// Superficie en planta ocupada por la huella de muros y tabiques en m²
  late final double wallsFootprintArea = walls
      .where(
        (w) =>
            w.status == ElementStatus.isNew ||
            w.status == ElementStatus.preserved,
      )
      .fold(0.0, (acc, w) => acc + (w.length * w.thickness));

  /// Longitud lineal total de muros y tabiques en metros
  late final double wallsTotalLinearMeters = walls
      .where(
        (w) =>
            w.status == ElementStatus.isNew ||
            w.status == ElementStatus.preserved,
      )
      .fold(0.0, (acc, w) => acc + w.length);

  /// Área construida total (ambientes útiles + huella de muros si existen)
  late final double calculatedBuiltArea = usableSpacesArea + wallsFootprintArea;

  Floor copyWith({
    String? id,
    String? buildingId,
    int? floorNumber,
    String? name,
    double? levelMeters,
    double? heightMeters,
    Polygon2D? boundary,
    double? maxAllowedArea,
    List<Module>? modules,
    List<Wall>? walls,
    List<ReplacementRelationship>? replacementRelationships,
  }) {
    return Floor(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      floorNumber: floorNumber ?? this.floorNumber,
      name: name ?? this.name,
      levelMeters: levelMeters ?? this.levelMeters,
      heightMeters: heightMeters ?? this.heightMeters,
      boundary: boundary ?? this.boundary,
      maxAllowedArea: maxAllowedArea ?? this.maxAllowedArea,
      modules: modules ?? this.modules,
      walls: walls ?? this.walls,
      replacementRelationships:
          replacementRelationships ?? this.replacementRelationships,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'building_id': buildingId,
        'floor_number': floorNumber,
        'name': name,
        'level_meters': levelMeters,
        'height_meters': heightMeters,
        'boundary': boundary.toJson(),
        'max_allowed_area': maxAllowedArea,
        'modules': modules.map((m) => m.toJson()).toList(),
        'walls': walls.map((w) => w.toJson()).toList(),
        'replacement_relationships':
            replacementRelationships.map((r) => r.toJson()).toList(),
      };

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
        id: json['id'] as String,
        buildingId: json['building_id'] as String,
        floorNumber: json['floor_number'] as int,
        name: json['name'] as String,
        levelMeters: (json['level_meters'] as num?)?.toDouble() ?? 0.0,
        heightMeters: (json['height_meters'] as num?)?.toDouble() ?? 2.60,
        boundary: Polygon2D.fromJson(json['boundary'] as Map<String, dynamic>),
        maxAllowedArea: (json['max_allowed_area'] as num).toDouble(),
        modules: (json['modules'] as List<dynamic>?)
                ?.map((m) => Module.fromJson(m as Map<String, dynamic>))
                .toList() ??
            const [],
        walls: Wall.deduplicate(
          (json['walls'] as List<dynamic>?)
                  ?.map((w) => Wall.fromJson(w as Map<String, dynamic>)) ??
              const [],
        ),
        replacementRelationships: (json['replacement_relationships'] as List<dynamic>?)
                ?.map((r) =>
                    ReplacementRelationship.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
