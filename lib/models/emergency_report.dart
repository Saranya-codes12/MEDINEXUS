enum EmergencySeverity { low, medium, high, critical }
enum EmergencyStatus { open, acknowledged, resolved }

class EmergencyReport {
  final String id;
  final String facilityId;
  final String title;
  final String description;
  final EmergencySeverity severity;
  final EmergencyStatus status;
  final DateTime createdAt;
  final String? recordHash;
  final String? previousHash;

  EmergencyReport({
    required this.id, required this.facilityId, required this.title, required this.description,
    required this.severity, required this.status, required this.createdAt,
    this.recordHash, this.previousHash,
  });

  factory EmergencyReport.fromMap(Map<String, dynamic> map) => EmergencyReport(
    id: map['id'], facilityId: map['facility_id'], title: map['title'], description: map['description'],
    severity: EmergencySeverity.values.firstWhere((s) => s.name == map['severity'], orElse: () => EmergencySeverity.medium),
    status: EmergencyStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => EmergencyStatus.open),
    createdAt: DateTime.parse(map['created_at']),
    recordHash: map['record_hash'], previousHash: map['previous_hash'],
  );
}
