class BiometricDevice {
  final String id;
  final String deviceId;
  final String facilityId;
  final String deviceType;

  BiometricDevice({
    required this.id,
    required this.deviceId,
    required this.facilityId,
    required this.deviceType,
  });

  factory BiometricDevice.fromMap(Map<String, dynamic> map) => BiometricDevice(
        id: map['id'],
        deviceId: map['device_id'] ?? '',
        facilityId: map['facility_id'],
        deviceType: map['device_type'] ?? 'fingerprint',
      );
}