import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/supabase/supabase_providers.dart';
import 'package:trazzik/features/floors/domain/floor.dart';

final floorRepositoryProvider = Provider<SupabaseFloorRepository>((ref) {
  return SupabaseFloorRepository(ref.watch(supabaseClientProvider));
});

/// Repositorio de pisos, módulos y elementos constructivos en Supabase.
class SupabaseFloorRepository {
  final SupabaseClient _client;
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String _resolveStableUuid(
    String id,
    Map<String, String> resolvedMap,
  ) {
    if (_uuidRegex.hasMatch(id)) return id;
    return resolvedMap.putIfAbsent(id, () => const Uuid().v4());
  }

  SupabaseFloorRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  Future<void> saveProjectFloors({
    required List<Floor> dirtyFloors,
    Set<String> deletedFloorIds = const {},
  }) async {
    if (dirtyFloors.isEmpty && deletedFloorIds.isEmpty) return;

    final resolvedIds = <String, String>{};
    final floorPayloads = <Map<String, dynamic>>[];
    final resolvedFloorIds = <String>[];
    final modulePayloads = <Map<String, dynamic>>[];
    final wallPayloads = <Map<String, dynamic>>[];
    final relPayloads = <Map<String, dynamic>>[];

    for (final floor in dirtyFloors) {
      final resolvedFloorId = _resolveStableUuid(floor.id, resolvedIds);
      resolvedFloorIds.add(resolvedFloorId);

      floorPayloads.add({
        'id': resolvedFloorId,
        'building_id': floor.buildingId,
        'floor_number': floor.floorNumber,
        'name': floor.name,
        'level_meters': floor.levelMeters,
        'height_meters': floor.heightMeters,
        'boundary': floor.boundary.toJson(),
        'max_allowed_area': floor.maxAllowedArea,
      });

      for (final module in floor.modules) {
        final resolvedId = _resolveStableUuid(module.id, resolvedIds);
        modulePayloads.add({
          'id': resolvedId,
          'floor_id': resolvedFloorId,
          'name': module.name,
          'module_type': module.moduleType,
          'floor_material_id': module.floorMaterialId,
          'wall_finish_id': module.wallFinishId,
          'geometry': {
            ...module.geometry.toJson(),
            'flip_x': module.flipX,
            'flip_y': module.flipY,
            'is_locked': module.isLocked,
            if (module.floorMaterialId != null)
              'floor_material_id': module.floorMaterialId,
            if (module.wallFinishId != null)
              'wall_finish_id': module.wallFinishId,
          },
          'status': module.status.name,
          'sub_modules': module.subModules
              .map(
                (s) => {
                  ...s.toJson(),
                  'id': _resolveStableUuid(s.id, resolvedIds),
                  'module_id': resolvedId,
                },
              )
              .toList(),
        });
      }

      for (final wall in floor.walls) {
        final resolvedId = _resolveStableUuid(wall.id, resolvedIds);
        wallPayloads.add({
          'id': resolvedId,
          'floor_id': resolvedFloorId,
          'start_point': wall.startPoint.toJson(),
          'end_point': wall.endPoint.toJson(),
          'thickness': wall.thickness,
          'height': wall.height,
          'status': wall.status.name,
        });
      }

      for (final rel in floor.replacementRelationships) {
        final resolvedId = _resolveStableUuid(rel.id, resolvedIds);
        relPayloads.add({
          'id': resolvedId,
          'floor_id': resolvedFloorId,
          'existing_element_id':
              _resolveStableUuid(rel.existingElementId, resolvedIds),
          'proposed_element_id':
              _resolveStableUuid(rel.proposedElementId, resolvedIds),
          'relationship_type': rel.relationshipType.name,
          'overlap_area': rel.overlapArea,
          'expanded_area': rel.expandedArea,
          'notes': rel.notes,
        });
      }
    }

    if (dirtyFloors.isNotEmpty) {
      // 1. Consultar IDs existentes de todos los niveles modificados antes del upsert
      final existingResults = await Future.wait([
        _client
            .from('modules')
            .select('id')
            .inFilter('floor_id', resolvedFloorIds),
        _client
            .from('walls')
            .select('id')
            .inFilter('floor_id', resolvedFloorIds),
        _client
            .from('replacement_relationships')
            .select('id')
            .inFilter('floor_id', resolvedFloorIds),
      ]);

      final existingModules = existingResults[0];
      final existingWalls = existingResults[1];
      final existingRels = existingResults[2];

      // 2. Si hay pisos eliminados que puedan colisionar en (building_id, floor_number), eliminarlos
      if (deletedFloorIds.isNotEmpty) {
        await deleteFloors(deletedFloorIds);
      }

      // 3. Upsert primero (floors -> modules & walls -> relationships) para evitar pérdida ante corte de red
      await _client.from('floors').upsert(floorPayloads);

      await Future.wait([
        if (modulePayloads.isNotEmpty)
          _client.from('modules').upsert(modulePayloads),
        if (wallPayloads.isNotEmpty)
          _client.from('walls').upsert(wallPayloads),
      ]);

      if (relPayloads.isNotEmpty) {
        await _client.from('replacement_relationships').upsert(relPayloads);
      }

      // 4. Eliminar elementos obsoletos sólo después de que los upserts hayan tenido éxito
      final currentRelIds = relPayloads.map((r) => r['id'] as String).toSet();
      final removedRelIds = existingRels
          .map((row) => row['id'] as String)
          .where((id) => !currentRelIds.contains(id))
          .toList();
      if (removedRelIds.isNotEmpty) {
        await _client
            .from('replacement_relationships')
            .delete()
            .inFilter('id', removedRelIds);
      }

      final currentModuleIds =
          modulePayloads.map((m) => m['id'] as String).toSet();
      final removedModuleIds = existingModules
          .map((row) => row['id'] as String)
          .where((id) => !currentModuleIds.contains(id))
          .toList();

      final currentWallIds = wallPayloads.map((w) => w['id'] as String).toSet();
      final removedWallIds = existingWalls
          .map((row) => row['id'] as String)
          .where((id) => !currentWallIds.contains(id))
          .toList();

      await Future.wait([
        if (removedModuleIds.isNotEmpty)
          _client.from('modules').delete().inFilter('id', removedModuleIds),
        if (removedWallIds.isNotEmpty)
          _client.from('walls').delete().inFilter('id', removedWallIds),
      ]);
    } else if (deletedFloorIds.isNotEmpty) {
      await deleteFloors(deletedFloorIds);
    }
  }

  Future<void> deleteFloors(Iterable<String> floorIds) async {
    final validIds = floorIds.where(_uuidRegex.hasMatch).toList();
    if (validIds.isEmpty) return;

    // public.modules, public.walls y public.replacement_relationships tienen ON DELETE CASCADE
    await _client.from('floors').delete().inFilter('id', validIds);
  }

  Future<void> saveFloor(Floor floor) =>
      saveProjectFloors(dirtyFloors: [floor]);

  Future<Floor?> getFloorById(String id) async {
    final floorData = await _client
        .from('floors')
        .select('*, modules(*), walls(*), replacement_relationships(*)')
        .eq('id', id)
        .maybeSingle();

    if (floorData == null) return null;

    return Floor.fromJson(Map<String, dynamic>.from(floorData));
  }

  Future<List<Floor>> getFloorsByBuildingId(String buildingId) async {
    final floorsData = await _client
        .from('floors')
        .select('*, modules(*), walls(*), replacement_relationships(*)')
        .eq('building_id', buildingId)
        .order('floor_number', ascending: true);

    if (floorsData.isEmpty) return const [];

    return floorsData
        .map((fRow) => Floor.fromJson(Map<String, dynamic>.from(fRow)))
        .toList();
  }
}
