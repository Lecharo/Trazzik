import 'package:trazzik/features/lots/domain/lot.dart';

enum ProjectRole { owner, editor, viewer }

class ProjectMember {
  final String projectId;
  final String userId;
  final ProjectRole role;
  final DateTime createdAt;

  const ProjectMember({
    required this.projectId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'user_id': userId,
        'role': role.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory ProjectMember.fromJson(Map<String, dynamic> json) => ProjectMember(
        projectId: json['project_id'] as String,
        userId: json['user_id'] as String,
        role: ProjectRole.values.byName(json['role'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Project {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final String? country;
  final String? stateProvince;
  final String? city;
  final String? address;
  final String? imageUrl;
  final Lot? lot;
  final List<ProjectMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    this.country,
    this.stateProvince,
    this.city,
    this.address,
    this.imageUrl,
    this.lot,
    this.members = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Project copyWith({
    String? name,
    String? description,
    String? country,
    String? stateProvince,
    String? city,
    String? address,
    String? imageUrl,
    Lot? lot,
    List<ProjectMember>? members,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      lot: lot ?? this.lot,
      members: members ?? this.members,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'owner_id': ownerId,
        'country': country,
        'state_province': stateProvince,
        'city': city,
        'address': address,
        'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json, {Lot? lot}) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        ownerId: json['owner_id'] as String,
        country: json['country'] as String?,
        stateProvince: json['state_province'] as String?,
        city: json['city'] as String?,
        address: json['address'] as String?,
        imageUrl: json['image_url'] as String?,
        lot: lot,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
