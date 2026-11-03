/// Tipos de relación de reemplazo entre lo existente y lo propuesto.
enum RelationshipType {
  replace,
  expand,
  modify,
  remove,
  relocate;
}

/// Registro formal de la relación de reemplazo / demolición / ampliación entre elementos.
class ReplacementRelationship {
  final String id;
  final String floorId;
  final String existingElementId;
  final String proposedElementId;
  final RelationshipType relationshipType;
  final double overlapArea;
  final double expandedArea;
  final String? notes;

  const ReplacementRelationship({
    required this.id,
    required this.floorId,
    required this.existingElementId,
    required this.proposedElementId,
    required this.relationshipType,
    required this.overlapArea,
    this.expandedArea = 0.0,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor_id': floorId,
        'existing_element_id': existingElementId,
        'proposed_element_id': proposedElementId,
        'relationship_type': relationshipType.name,
        'overlap_area': overlapArea,
        'expanded_area': expandedArea,
        'notes': notes,
      };

  factory ReplacementRelationship.fromJson(Map<String, dynamic> json) =>
      ReplacementRelationship(
        id: json['id'] as String,
        floorId: json['floor_id'] as String,
        existingElementId: json['existing_element_id'] as String,
        proposedElementId: json['proposed_element_id'] as String,
        relationshipType:
            RelationshipType.values.byName(json['relationship_type'] as String),
        overlapArea: (json['overlap_area'] as num).toDouble(),
        expandedArea: (json['expanded_area'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'] as String?,
      );
}
