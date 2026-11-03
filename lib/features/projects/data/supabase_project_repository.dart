import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/projects/domain/project.dart';

/// Repositorio de proyectos y lotes en Supabase.
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

    await _client.from('project_members').upsert({
      'project_id': project.id,
      'user_id': project.ownerId,
      'role': 'owner',
    });

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

    final list = <Project>[];
    for (final item in response) {
      list.add(Project.fromJson(item));
    }
    return list;
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

    // 2. Eliminar zonas anteriores para reescribir limpiamente
    await _client.from('zoning_zones').delete().eq('lot_id', actualLotId);

    // 3. Guardar zonas asociadas
    for (final zone in lot.zones) {
      await _client.from('zoning_zones').insert({
        'id': zone.id.length == 36 ? zone.id : const Uuid().v4(),
        'lot_id': actualLotId,
        'name': zone.name,
        'type': zone.type.name,
        'boundary': zone.boundary.toJson(),
      });
    }

    return lot.copyWith(id: actualLotId);
  }

  Future<Lot?> getLotByProjectId(String projectId) async {
    final lotData = await _client
        .from('lots')
        .select()
        .eq('project_id', projectId)
        .maybeSingle();

    if (lotData == null) return null;

    final zonesData =
        await _client.from('zoning_zones').select().eq('lot_id', lotData['id']);

    final jsonMap = Map<String, dynamic>.from(lotData);
    jsonMap['boundary'] = lotData['boundary_polygon'];
    jsonMap['zones'] = zonesData;

    return Lot.fromJson(jsonMap);
  }
}
