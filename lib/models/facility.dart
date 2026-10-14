enum FacilityType { phc, upgradedPhc, subCentre }

FacilityType facilityTypeFromString(String s) {
  switch (s) {
    case 'upgraded_phc': return FacilityType.upgradedPhc;
    case 'sub_centre': return FacilityType.subCentre;
    default: return FacilityType.phc;
  }
}

String facilityTypeLabel(FacilityType t) {
  switch (t) {
    case FacilityType.upgradedPhc: return 'Upgraded PHC';
    case FacilityType.subCentre: return 'Sub-Centre';
    case FacilityType.phc: return 'PHC';
  }
}

class Facility {
  final String id;
  final String name;
  final String code;
  final FacilityType type;
  final String division;
  final String? inchargeName;
  final String? contactNumber;

  Facility({
    required this.id, required this.name, required this.code,
    required this.type, required this.division, this.inchargeName, this.contactNumber,
  });

  factory Facility.fromMap(Map<String, dynamic> map) => Facility(
    id: map['id'], name: map['name'], code: map['code'],
    type: facilityTypeFromString(map['facility_type']), division: map['division'],
    inchargeName: map['incharge_name'], contactNumber: map['contact_number'],
  );
}
