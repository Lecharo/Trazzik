import 'package:trazzik/core/geometry/polygon_2d.dart';

enum ValidationSeverity {
  error,
  warning,
  info;

  bool get isBlocking => this == ValidationSeverity.error;
}

/// Registro estructurado de un hallazgo del motor de validación.
class ValidationIssue {
  final String code;
  final ValidationSeverity severity;
  final String message;
  final String affectedElementId;
  final String? relatedElementId;
  final Polygon2D? conflictGeometry;

  const ValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    required this.affectedElementId,
    this.relatedElementId,
    this.conflictGeometry,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'severity': severity.name,
        'message': message,
        'affected_element_id': affectedElementId,
        'related_element_id': relatedElementId,
        'conflict_geometry': conflictGeometry?.toJson(),
      };

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $code: $message (Element: $affectedElementId)';
}
