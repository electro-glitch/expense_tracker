class InvitationModel {
  final String id;
  final String toEmail;
  final String? familyId;
  final String? familyName;
  final String? groupId;
  final String? groupName;
  final String fromName;
  final String? relationship;
  final String status; // 'pending', 'accepted', 'declined'
  final String type; // 'family' or 'group'

  InvitationModel({
    required this.id,
    required this.toEmail,
    this.familyId,
    this.familyName,
    this.groupId,
    this.groupName,
    required this.fromName,
    this.relationship,
    required this.status,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'toEmail': toEmail,
        'familyId': familyId,
        'familyName': familyName,
        'groupId': groupId,
        'groupName': groupName,
        'fromName': fromName,
        'relationship': relationship,
        'status': status,
        'type': type,
      };

  factory InvitationModel.fromJson(Map<String, dynamic> json) => InvitationModel(
        id: json['id'] as String,
        toEmail: json['toEmail'] as String,
        familyId: json['familyId'] as String?,
        familyName: json['familyName'] as String?,
        groupId: json['groupId'] as String?,
        groupName: json['groupName'] as String?,
        fromName: json['fromName'] as String,
        relationship: json['relationship'] as String?,
        status: json['status'] as String,
        type: json['type'] as String? ?? 'family',
      );
}
