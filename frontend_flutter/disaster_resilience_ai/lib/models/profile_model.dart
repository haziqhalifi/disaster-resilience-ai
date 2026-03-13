/// Data model for user profile and emergency information.
library;

class UserProfile {
  final String userId;
  final String? fullName;
  final String? phoneNumber;
  final String? bloodType;
  final String? profilePhotoUrl;
  final String allergies;
  final String medicalConditions;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactPhone;

  const UserProfile({
    required this.userId,
    this.fullName,
    this.phoneNumber,
    this.bloodType,
    this.profilePhotoUrl,
    this.allergies = '',
    this.medicalConditions = '',
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      bloodType: json['blood_type'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      allergies: json['allergies'] as String? ?? '',
      medicalConditions: json['medical_conditions'] as String? ?? '',
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactRelationship:
          json['emergency_contact_relationship'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone_number': phoneNumber,
      'blood_type': bloodType,
      'profile_photo_url': profilePhotoUrl,
      'allergies': allergies,
      'medical_conditions': medicalConditions,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_relationship': emergencyContactRelationship,
      'emergency_contact_phone': emergencyContactPhone,
    };
  }
}
