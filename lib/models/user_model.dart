class UserModel {
  final String uid;
  final String name;
  final String email;
  final List<String> friends;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.friends = const [],
    this.fcmToken,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'friends': friends,
        'fcmToken': fcmToken,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        friends: List<String>.from(json['friends'] ?? []),
        fcmToken: json['fcmToken'] as String?,
      );
}
