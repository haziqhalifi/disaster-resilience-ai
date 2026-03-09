class FamilyInvite {
  final String id;
  final String requesterUsername;
  final String requesterEmail;
  final String status;

  const FamilyInvite({
    required this.id,
    required this.requesterUsername,
    required this.requesterEmail,
    required this.status,
  });

  factory FamilyInvite.fromJson(Map<String, dynamic> json) {
    return FamilyInvite(
      id: json['id'] as String,
      requesterUsername: json['requester_username'] as String,
      requesterEmail: json['requester_email'] as String,
      status: json['status'] as String,
    );
  }
}

class FamilyMemberLocation {
  final String userId;
  final String username;
  final String email;
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  const FamilyMemberLocation({
    required this.userId,
    required this.username,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory FamilyMemberLocation.fromJson(Map<String, dynamic> json) {
    return FamilyMemberLocation(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}
