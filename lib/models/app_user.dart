enum UserRole { admin, facilityUser }

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String? facilityId;
  final String? designation;

  AppUser({
    required this.id, required this.fullName, required this.email,
    required this.role, this.facilityId, this.designation,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'], fullName: map['full_name'], email: map['email'],
    role: map['role'] == 'admin' ? UserRole.admin : UserRole.facilityUser,
    facilityId: map['facility_id'], designation: map['designation'],
  );
}
