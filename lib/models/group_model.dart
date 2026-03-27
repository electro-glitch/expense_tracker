class GroupModel {
  final String id;
  final String name;
  final List<String> members;
  final Map<String, double> balances;

  GroupModel({
    required this.id,
    required this.name,
    required this.members,
    this.balances = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'balances': balances,
      };

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        name: json['name'] as String,
        members: List<String>.from(json['members'] ?? []),
        balances: (json['balances'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            ) ??
            {},
      );
}
