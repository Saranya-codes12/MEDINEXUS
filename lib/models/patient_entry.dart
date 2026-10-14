class PatientEntry {
  final String id;
  final String facilityId;
  final DateTime date;
  final int maleCount;
  final int femaleCount;
  final int otherCount;
  final int opdCount;
  final int ipdCount;

  PatientEntry({
    required this.id, required this.facilityId, required this.date,
    required this.maleCount, required this.femaleCount, required this.otherCount,
    required this.opdCount, required this.ipdCount,
  });

  int get total => maleCount + femaleCount + otherCount;

  factory PatientEntry.fromMap(Map<String, dynamic> map) => PatientEntry(
    id: map['id'], facilityId: map['facility_id'], date: DateTime.parse(map['date']),
    maleCount: map['male_count'] ?? 0, femaleCount: map['female_count'] ?? 0,
    otherCount: map['other_count'] ?? 0, opdCount: map['opd_count'] ?? 0, ipdCount: map['ipd_count'] ?? 0,
  );
}
