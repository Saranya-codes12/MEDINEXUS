class Employee {
  final String id;
  final String employeeId;
  final String facilityId;
  final String fullName;
  final String? designation;
  final bool active;

  Employee({
    required this.id,
    required this.employeeId,
    required this.facilityId,
    required this.fullName,
    this.designation,
    required this.active,
  });

  factory Employee.fromMap(Map<String, dynamic> map) => Employee(
        id: map['id'],
        employeeId: map['employee_id'] ?? '',
        facilityId: map['facility_id'],
        fullName: map['full_name'] ?? '',
        designation: map['designation'],
        active: map['active'] ?? true,
      );
}