import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/core/supabase/supabase_providers.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/projects/domain/project.dart';
import 'package:trazzik/features/projects/domain/project_building.dart';

final projectRepositoryProvider = Provider<SupabaseProjectRepository>((ref) {
  return SupabaseProjectRepository(ref.watch(supabaseClientProvider));
});

/// Repositorio de proyectos, lotes y edificaciones en Supabase.
class SupabaseProjectRepository {
  final SupabaseClient _client;

  SupabaseProjectRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  Future<void> saveProject(Project project) async {
    final payload = <String, dynamic>{
      'id': project.id,
      'name': project.name,
      'description': project.description,
      'owner_id': project.ownerId,
      'country': project.country,
      'state_province': project.stateProvince,
      'city': project.city,
      'address': project.address,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (project.imageUrl != null) {
      payload['image_url'] = project.imageUrl;
    }

    try {
      await _client.from('projects').upsert(payload);
    } catch (e) {
      if (payload.containsKey('image_url')) {
        payload.remove('image_url');
        await _client.from('projects').upsert(payload);
      } else {
        rethrow;
      }
    }

    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == project.ownerId) {
      await _client.from('project_members').upsert({
        'project_id': project.id,
        'user_id': project.ownerId,
        'role': 'owner',
      });
    }

    if (project.lot != null) {
      await saveLot(project.lot!);
    }
  }

  Future<Project?> getProjectById(String id) async {
    final response =
        await _client.from('projects').select().eq('id', id).maybeSingle();

    if (response == null) return null;

    final lot = await getLotByProjectId(id);
    return Project.fromJson(response, lot: lot);
  }

  Future<List<Project>> listUserProjects() async {
    final response = await _client
        .from('projects')
        .select()
        .order('updated_at', ascending: false);

    return response.map<Project>(Project.fromJson).toList();
  }

  Future<void> deleteProject(String projectId) async {
    await _client.from('projects').delete().eq('id', projectId);
  }

  Future<Lot> saveLot(Lot lot) async {
    // 1. Buscar si ya existe un lote para este proyecto y conservar su ID real
    final existingLot = await _client
        .from('lots')
        .select('id')
        .eq('project_id', lot.projectId)
        .maybeSingle();

    final actualLotId =
        existingLot != null ? (existingLot['id'] as String) : lot.id;

    if (existingLot != null) {
      await _client.from('lots').update({
        'boundary_polygon': lot.boundary.toJson(),
        'orientation_degrees': lot.orientationDegrees,
      }).eq('id', actualLotId);
    } else {
      await _client.from('lots').insert({
        'id': actualLotId,
        'project_id': lot.projectId,
        'boundary_polygon': lot.boundary.toJson(),
        'orientation_degrees': lot.orientationDegrees,
      });
    }

    // 2. Guardar zonas asociadas mediante upsert primero y luego limpiar obsoletas
    if (lot.zones.isNotEmpty) {
      const uuid = Uuid();
      final zonePayloads = lot.zones
          .map(
            (zone) => {
              'id': zone.id.length == 36 ? zone.id : uuid.v4(),
              'lot_id': actualLotId,
              'name': zone.name,
              'type': zone.type.name,
              'boundary': zone.boundary.toJson(),
            },
          )
          .toList();
      final keptIds = zonePayloads.map((z) => z['id'] as String).toSet();
      final existingZones = await _client
          .from('zoning_zones')
          .select('id')
          .eq('lot_id', actualLotId);
      await _client.from('zoning_zones').upsert(zonePayloads);
      final removedZoneIds = existingZones
          .map((row) => row['id'] as String)
          .where((id) => !keptIds.contains(id))
          .toList();
      if (removedZoneIds.isNotEmpty) {
        await _client
            .from('zoning_zones')
            .delete()
            .inFilter('id', removedZoneIds);
      }
    } else {
      await _client.from('zoning_zones').delete().eq('lot_id', actualLotId);
    }

    return lot.copyWith(id: actualLotId);
  }

  Future<Lot?> getLotByProjectId(String projectId) async {
    final lotData = await _client
        .from('lots')
        .select('*, zoning_zones(*)')
        .eq('project_id', projectId)
        .maybeSingle();

    if (lotData == null) return null;

    final jsonMap = Map<String, dynamic>.from(lotData);
    jsonMap['boundary'] = lotData['boundary_polygon'];
    jsonMap['zones'] = lotData['zoning_zones'] ?? const [];

    return Lot.fromJson(jsonMap);
  }

  Future<ProjectBuilding?> getPrimaryBuildingByLotId(String lotId) async {
    final rows = await _client
        .from('buildings')
        .select()
        .eq('lot_id', lotId)
        .order('order_index', ascending: true)
        .limit(1);

    if (rows.isEmpty) return null;
    return ProjectBuilding.fromJson(rows.first);
  }

  Future<ProjectBuilding> savePrimaryBuilding({
    required String lotId,
    String? preferredBuildingId,
    required String name,
    required int floorsCount,
  }) async {
    final existing = await getPrimaryBuildingByLotId(lotId);
    final actualBuildingId =
        existing?.id ?? preferredBuildingId ?? const Uuid().v4();

    if (existing != null) {
      try {
        await _client.from('buildings').update({
          'name': name,
          'floors_count': floorsCount,
        }).eq('id', actualBuildingId);
      } catch (_) {
        await _client.from('buildings').update({
          'name': name,
        }).eq('id', actualBuildingId);
      }
    } else {
      try {
        await _client.from('buildings').insert({
          'id': actualBuildingId,
          'lot_id': lotId,
          'name': name,
          'floors_count': floorsCount,
          'order_index': 1,
        });
      } catch (_) {
        await _client.from('buildings').insert({
          'id': actualBuildingId,
          'lot_id': lotId,
          'name': name,
          'order_index': 1,
        });
      }
    }

    return ProjectBuilding(
      id: actualBuildingId,
      lotId: lotId,
      name: name,
      floorsCount: floorsCount,
    );
  }

  /// Guarda la configuración de propuesta de honorarios en `projects.fee_proposal_config`.
  Future<void> saveFeeProposalConfig({
    required String projectId,
    required Map<String, dynamic> config,
  }) async {
    await _client.from('projects').update({
      'fee_proposal_config': config,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  /// Obtiene la configuración de propuesta de honorarios desde `projects.fee_proposal_config`.
  Future<Map<String, dynamic>?> getFeeProposalConfig(String projectId) async {
    final row = await _client
        .from('projects')
        .select('fee_proposal_config')
        .eq('id', projectId)
        .maybeSingle();
    final raw = row?['fee_proposal_config'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Crea o reutiliza un token de enlace interactivo para cliente (vigencia 60 días).
  Future<String> createOrGetProjectShareLink({
    required String projectId,
    bool allowFinishSelection = true,
  }) async {
    final existing = await _client
        .from('project_share_links')
        .select('token, allow_finish_selection, expires_at')
        .eq('project_id', projectId)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);

    if (existing.isNotEmpty) {
      final token = existing.first['token'] as String?;
      if (token != null && token.isNotEmpty) return token;
    }

    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('Authenticated user required to create share link.');
    }

    final token = const Uuid().v4().replaceAll('-', '');
    await _client.from('project_share_links').insert({
      'project_id': projectId,
      'token': token,
      'created_by': currentUserId,
      'allow_finish_selection': allowFinishSelection,
    });
    return token;
  }

  /// Obtiene el permiso actual `allow_finish_selection` del enlace compartido activo del proyecto.
  Future<bool?> getProjectShareLinkAllowFinishes(String projectId) async {
    final existing = await _client
        .from('project_share_links')
        .select('allow_finish_selection, expires_at')
        .eq('project_id', projectId)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);

    if (existing.isNotEmpty) {
      return existing.first['allow_finish_selection'] as bool?;
    }
    return null;
  }

  /// Actualiza el permiso `allow_finish_selection` de un enlace compartido existente.
  Future<void> updateProjectShareLinkPermission({
    required String projectId,
    required String token,
    required bool allowFinishSelection,
  }) async {
    await _client
        .from('project_share_links')
        .update({'allow_finish_selection': allowFinishSelection})
        .eq('project_id', projectId)
        .eq('token', token);
  }

  /// Consulta un proyecto compartido mediante el RPC `get_shared_project_by_token`.
  Future<Map<String, dynamic>?> getSharedProjectByToken(String token) async {
    final res = await _client.rpc(
      'get_shared_project_by_token',
      params: {'p_token': token.trim()},
    );
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  /// Actualiza acabados de un módulo compartido mediante el RPC `update_shared_module_finishes`.
  Future<bool> updateSharedModuleFinishes({
    required String token,
    required String moduleId,
    String? floorMaterialId,
    String? wallFinishId,
    bool clearFinishes = false,
  }) async {
    final res = await _client.rpc(
      'update_shared_module_finishes',
      params: {
        'p_token': token.trim(),
        'p_module_id': moduleId,
        'p_floor_material_id': floorMaterialId,
        'p_wall_finish_id': wallFinishId,
        'p_clear_finishes': clearFinishes,
      },
    );
    return res == true;
  }
}
