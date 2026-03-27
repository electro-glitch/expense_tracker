class FamilyModel {
  final String id;
  final String name;
  final List<String> members;
  final List<String> admins;
  final String creatorId;
  final Map<String, String> relationships; // UID -> Relationship label

  FamilyModel({
    required this.id,
    required this.name,
    required this.members,
    required this.admins,
    required this.creatorId,
    required this.relationships,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'admins': admins,
        'creatorId': creatorId,
        'relationships': relationships,
      };

  factory FamilyModel.fromJson(Map<String, dynamic> json) => FamilyModel(
        id: json['id'] as String,
        name: json['name'] as String,
        members: List<String>.from(json['members'] ?? []),
        admins: List<String>.from(json['admins'] ?? []),
        creatorId: json['creatorId'] as String,
        relationships: Map<String, String>.from(json['relationships'] ?? {}),
      );
}
