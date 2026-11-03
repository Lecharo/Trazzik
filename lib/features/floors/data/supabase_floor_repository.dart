import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/features/demolition/domain/replacement_relationship.dart';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/modules/domain/module.dart';
import 'package:trazzik/features/walls/domain/wall.dart';

/// Repositorio de pisos, módulos y elementos constructivos en Supabase.
class SupabaseFloorRepository {
  final SupabaseClient _client;
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String _ensureUuid(String id) {
    return _uuidRegex.hasMatch(id) ? id : const Uuid().v4();
  }

  SupabaseFloorRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  Future<void> saveFloor(Floor floor) async {
    // 1. Guardar entidad Floor
    await _client.from('floors').upsert({
      'id': floor.id,
      'building_id': floor.buildingId,
      'floor_number': floor.floorNumber,
      'name': floor.name,
      'level_meters': floor.levelMeters,
      'height_meters': floor.heightMeters,
      'boundary': floor.boundary.toJson(),
      'max_allowed_area': floor.maxAllowedArea,
    });

    // 2. Guardar Módulos y limpiar eliminados
    final existingModules =
        await _client.from('modules').select('id').eq('floor_id', floor.id);
    final currentModuleIds = floor.modules.map((m) => m.id).toSet();
    for (final row in existingModules) {
      final dbId = row['id'] as String;
      if (!currentModuleIds.contains(dbId)) {
        await _client.from('modules').delete().eq('id', dbId);
      }
    }

    for (final module in floor.modules) {
      await _client.from('modules').upsert({
        'id': _ensureUuid(module.id),
        'floor_id': floor.id,
        'name': module.name,
        'module_type': module.moduleType,
        'geometry': module.geometry.toJson(),
        'status': module.status.name,
        'sub_modules': module.subModules.map((s) => s.toJson()).toList(),
      });
    }

    // 3. Guardar Muros y limpiar muros eliminados o sustituidos en la base de datos
    final existingWalls =
        await _client.from('walls').select('id').eq('floor_id', floor.id);
    final currentWallIds = floor.walls.map((w) => w.id).toSet();
    for (final row in existingWalls) {
      final dbId = row['id'] as String;
      if (!currentWallIds.contains(dbId)) {
        await _client.from('walls').delete().eq('id', dbId);
      }
    }

    for (final wall in floor.walls) {
      await _client.from('walls').upsert({
        'id': _ensureUuid(wall.id),
        'floor_id': floor.id,
        'start_point': wall.startPoint.toJson(),
        'end_point': wall.endPoint.toJson(),
        'thickness': wall.thickness,
        'height': wall.height,
        'status': wall.status.name,
      });
    }

    // 4. Guardar Relaciones de Reemplazo y limpiar eliminadas
    final existingRels = await _client
        .from('replacement_relationships')
        .select('id')
        .eq('floor_id', floor.id);
    final currentRelIds =
        floor.replacementRelationships.map((r) => r.id).toSet();
    for (final row in existingRels) {
      final dbId = row['id'] as String;
      if (!currentRelIds.contains(dbId)) {
        await _client
            .from('replacement_relationships')
            .delete()
            .eq('id', dbId);
      }
    }

    for (final rel in floor.replacementRelationships) {
      await _client.from('replacement_relationships').upsert({
        'id': _ensureUuid(rel.id),
        'floor_id': floor.id,
        'existing_element_id': _ensureUuid(rel.existingElementId),
        'proposed_element_id': _ensureUuid(rel.proposedElementId),
        'relationship_type': rel.relationshipType.name,
        'overlap_area': rel.overlapArea,
        'expanded_area': rel.expandedArea,
        'notes': rel.notes,
      });
    }
  }

  Future<Floor?> getFloorById(String id) async {
    final floorData =
        await _client.from('floors').select().eq('id', id).maybeSingle();

    if (floorData == null) return null;

    final modulesData =
        await _client.from('modules').select().eq('floor_id', id);
    final wallsData =
        await _client.from('walls').select().eq('floor_id', id);
    final replacementsData =
        await _client.from('replacement_relationships').select().eq('floor_id', id);

    final jsonMap = Map<String, dynamic>.from(floorData);
    jsonMap['modules'] = modulesData;
    jsonMap['walls'] = wallsData;
    jsonMap['replacement_relationships'] = replacementsData;

    return Floor.fromJson(jsonMap);
  }

  Future<List<Floor>> getFloorsByBuildingId(String buildingId) async {
    final floorsData = await _client
        .from('floors')
        .select()
        .eq('building_id', buildingId)
        .order('floor_number', ascending: true);

    final floors = <Floor>[];
    for (final fRow in floorsData) {
      final id = fRow['id'] as String;
      final modulesData =
          await _client.from('modules').select().eq('floor_id', id);
      final wallsData =
          await _client.from('walls').select().eq('floor_id', id);
      final replacementsData = await _client
          .from('replacement_relationships')
          .select()
          .eq('floor_id', id);

      final jsonMap = Map<String, dynamic>.from(fRow);
      jsonMap['modules'] = modulesData;
      jsonMap['walls'] = wallsData;
      jsonMap['replacement_relationships'] = replacementsData;

      floors.add(Floor.fromJson(jsonMap));
    }
    return floors;
  }
}
