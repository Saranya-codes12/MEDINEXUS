enum AttendanceStatus { present, absent, leave }

class AttendanceRecord {
  final String id;
  final String facilityId;
  final String doctorName;
  final String? designation;
  final AttendanceStatus status;
  final DateTime date;
  final String? recordHash;
  final String? previousHash;

  AttendanceRecord({
    required this.id, required this.facilityId, required this.doctorName,
    this.designation, required this.status, required this.date,
    this.recordHash, this.previousHash,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
    id: map['id'], facilityId: map['facility_id'], doctorName: map['doctor_name'],
    designation: map['designation'],
    status: AttendanceStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => AttendanceStatus.present),
    date: DateTime.parse(map['date']),
    recordHash: map['record_hash'], previousHash: map['previous_hash'],
  );
}
