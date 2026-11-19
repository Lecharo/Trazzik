import 'dart:convert';
import 'package:trazzik/features/floors/domain/floor.dart';
import 'package:trazzik/features/lots/domain/lot.dart';
import 'package:trazzik/features/projects/domain/project.dart';

/// Complete portable snapshot of a Trazzik project (`{project, lot, floors}`)
/// suitable for local `.json` versioning, backup, and offline loading.
class ProjectJsonBundle {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime exportedAt;
  final Project project;
  final Lot lot;
  final List<Floor> floors;

  ProjectJsonBundle({
    this.schemaVersion = currentSchemaVersion,
    DateTime? exportedAt,
    required this.project,
    required this.lot,
    required this.floors,
  }) : exportedAt = exportedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'exported_at': exportedAt.toIso8601String(),
        'project': project.toJson(),
        'lot': lot.toJson(),
        'floors': floors.map((f) => f.toJson()).toList(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Parses either a local exported JSON payload or a Supabase shared-project payload.
  static ProjectJsonBundle? tryFromPayload(Map<String, dynamic> payload) {
    final projectRaw = payload['project'];
    final lotRaw = payload['lot'];
    final floorsRaw = payload['floors'];
    if (projectRaw is! Map || lotRaw is! Map || floorsRaw is! List) {
      return null;
    }

    try {
      final projectMap = Map<String, dynamic>.from(projectRaw);
      final lotMap = Map<String, dynamic>.from(lotRaw);
      lotMap['boundary'] = lotMap['boundary_polygon'] ?? lotMap['boundary'];
      lotMap['zones'] = lotMap['zoning_zones'] ?? lotMap['zones'] ?? const [];
      if (lotMap['boundary'] is! Map) return null;

      final lot = Lot.fromJson(lotMap);
      final project = Project.fromJson(projectMap, lot: lot);
      final floors = floorsRaw
          .whereType<Map>()
          .map((f) => Floor.fromJson(Map<String, dynamic>.from(f)))
          .toList();
      if (floors.isEmpty) return null;

      final version =
          (payload['schema_version'] as num?)?.toInt() ?? currentSchemaVersion;
      final exportedAt =
          DateTime.tryParse(payload['exported_at']?.toString() ?? '') ??
              DateTime.now().toUtc();

      return ProjectJsonBundle(
        schemaVersion: version,
        exportedAt: exportedAt,
        project: project,
        lot: lot,
        floors: floors,
      );
    } catch (_) {
      return null;
    }
  }

  static ProjectJsonBundle? tryFromJsonString(String rawJson) {
    final cleaned = rawJson.trim().replaceFirst('\uFEFF', '');
    if (cleaned.isEmpty) return null;
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map) return null;
      return tryFromPayload(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
