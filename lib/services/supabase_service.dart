import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Supabase
  // ---------------------------------------------------------------------------

  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://ijubhgnbikwanofgtqxu.supabase.co',
      publishableKey: 'sb_publishable_llkOHsl2-dLam05cHwk14w_kqZ6bMFY',
    );
  }

  static User? get currentUser => client.auth.currentUser;

  static Future<AuthResponse> signIn(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() {
    return client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final data = await client.from('users').select().eq('id', userId).maybeSingle();
    return data;
  }

  // ---------------------------------------------------------------------------
  // Facilities
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchFacilities() async {
    final data = await client.from('facilities').select().order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> fetchFacilityById(String id) async {
    final data = await client.from('facilities').select().eq('id', id).maybeSingle();
    return data;
  }

  static Future<void> registerFacility({
    required String name,
    required String code,
    required String facilityType,
    required String division,
    String? inchargeName,
    String? contactNumber,
  }) async {
    await client.from('facilities').insert({
      'name': name,
      'code': code,
      'facility_type': facilityType,
      'division': division,
      'incharge_name': inchargeName,
      'contact_number': contactNumber,
    });
  }

  // ---------------------------------------------------------------------------
  // Attendance (basic CRUD — used by dashboards/other screens)
  // ---------------------------------------------------------------------------

  /// A facility user passes the facility id. The district admin passes null
  /// to follow the latest attendance of every facility.
  static Stream<List<Map<String, dynamic>>> attendanceStream(String? facilityId) {
    if (facilityId == null) {
      return client
          .from('doctor_attendance')
          .stream(primaryKey: ['id'])
          .order('date', ascending: false)
          .limit(300);
    }
    return client
        .from('doctor_attendance')
        .stream(primaryKey: ['id'])
        .eq('facility_id', facilityId)
        .order('date', ascending: false);
  }

  static Future<void> markAttendance({
    required String facilityId,
    required String doctorName,
    String? designation,
    required String status,
    required String date,
    required String markedBy,
  }) async {
    await client.from('doctor_attendance').insert({
      'facility_id': facilityId,
      'doctor_name': doctorName,
      'designation': designation,
      'status': status,
      'date': date,
      'marked_by': markedBy,
    });
  }

  // ---------------------------------------------------------------------------
  // Patients
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchPatients(String? facilityId) async {
    if (facilityId != null) {
      final data = await client
          .from('patients')
          .select()
          .eq('facility_id', facilityId)
          .order('date', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(data);
    }

    final data = await client.from('patients').select().order('date', ascending: false).limit(30);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> savePatientEntry(Map<String, dynamic> entry) async {
    await client.from('patients').upsert(entry, onConflict: 'facility_id,date');
  }

  // ---------------------------------------------------------------------------
  // Medicine stock
  // ---------------------------------------------------------------------------

  static Stream<List<Map<String, dynamic>>> medicineStockStream(String facilityId) {
    return client
        .from('medicine_stock')
        .stream(primaryKey: ['id'])
        .eq('facility_id', facilityId)
        .order('updated_at', ascending: false);
  }

  static Future<void> addStockMovement(Map<String, dynamic> entry) async {
    await client.from('medicine_stock').insert(entry);
  }

  // ---------------------------------------------------------------------------
  // Emergency reports
  // ---------------------------------------------------------------------------

  static Stream<List<Map<String, dynamic>>> emergencyStream(String? facilityId) {
    if (facilityId != null) {
      return client
          .from('emergency_reports')
          .stream(primaryKey: ['id'])
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false);
    }

    return client.from('emergency_reports').stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  static Future<void> reportEmergency(Map<String, dynamic> entry) async {
    await client.from('emergency_reports').insert(entry);
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  static Stream<List<Map<String, dynamic>>> notificationsStream() {
    return client.from('notifications').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(50);
  }

  // ---------------------------------------------------------------------------
  // Blockchain-inspired hash-chain ledger (general — patients/emergency/stock)
  // ---------------------------------------------------------------------------

  // NOTE: change 'event_type' below if your chain_ledger column has a different name.
  static Future<List<Map<String, dynamic>>> fetchChainLedger({String? eventType}) async {
    var query = client.from('chain_ledger').select();
    if (eventType != null) query = query.eq('event_type', eventType);
    final data = await query.order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  static List<ChainVerificationResult> verifyChain(List<Map<String, dynamic>> ledger) {
    final results = <ChainVerificationResult>[];
    String expectedPrevious = 'GENESIS';

    for (final entry in ledger) {
      final storedHash = entry['record_hash']?.toString() ?? '';
      final storedPrevious = entry['previous_hash']?.toString() ?? 'GENESIS';
      final storedInput = entry['hash_input']?.toString();

      bool valid = false;

      if (storedInput != null && storedInput.isNotEmpty) {
        final computedHash = sha256.convert(utf8.encode(storedInput)).toString();
        valid = computedHash == storedHash && storedPrevious == expectedPrevious;
      }

      results.add(ChainVerificationResult(entry: entry, valid: valid));
      expectedPrevious = storedHash;
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // ATTENDANCE MODULE — dedicated hash-chain + correction workflow
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchAttendanceChain({String? facilityId}) async {
    if (facilityId != null) {
      final data = await client
          .from('doctor_attendance')
          .select()
          .eq('facility_id', facilityId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    }
    final data = await client.from('doctor_attendance').select().order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  static List<ChainVerificationResult> verifyAttendanceChain(List<Map<String, dynamic>> chain) {
    final results = <ChainVerificationResult>[];
    String expectedPrevious = 'GENESIS';

    for (final entry in chain) {
      final storedHash = entry['current_hash']?.toString() ?? '';
      final storedPrevious = entry['previous_hash']?.toString() ?? 'GENESIS';
      final storedInput = entry['hash_input']?.toString();

      bool valid = false;
      if (storedInput != null && storedInput.isNotEmpty) {
        final computed = sha256.convert(utf8.encode(storedInput)).toString();
        valid = computed == storedHash && storedPrevious == expectedPrevious;
      }
      results.add(ChainVerificationResult(entry: entry, valid: valid));
      expectedPrevious = storedHash;
    }
    return results;
  }

  static Future<void> requestAttendanceCorrection({
    required String attendanceId,
    required String facilityId,
    required String originalStatus,
    required String requestedStatus,
    required String reason,
    required String requestedBy,
  }) async {
    await client.from('attendance_correction_requests').insert({
      'attendance_id': attendanceId,
      'facility_id': facilityId,
      'original_status': originalStatus,
      'requested_status': requestedStatus,
      'reason': reason,
      'requested_by': requestedBy,
    });
  }

  // FIXED: filter (.eq) first, transform (.order) last.
  static Future<List<Map<String, dynamic>>> fetchCorrectionRequests({String? status}) async {
    var query = client.from('attendance_correction_requests').select();
    if (status != null) query = query.eq('status', status);
    final data = await query.order('requested_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> approveCorrection({
    required Map<String, dynamic> request,
    required String reviewerId,
  }) async {
    final original = await client
        .from('doctor_attendance')
        .select()
        .eq('id', request['attendance_id'])
        .single();

    await client.from('doctor_attendance').insert({
      'facility_id': request['facility_id'],
      'doctor_name': original['doctor_name'],
      'designation': original['designation'],
      'status': request['requested_status'],
      'date': original['date'],
      'marked_by': reviewerId,
      'is_correction': true,
      'corrects_record_id': request['attendance_id'],
      'correction_request_id': request['id'],
    });

    await client.from('attendance_correction_requests').update({
      'status': 'approved',
      'reviewed_by': reviewerId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', request['id']);
  }

  static Future<void> rejectCorrection({required String requestId, required String reviewerId}) async {
    await client.from('attendance_correction_requests').update({
      'status': 'rejected',
      'reviewed_by': reviewerId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  // ---------------------------------------------------------------------------
  // Employee Registry
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchEmployees({String? facilityId}) async {
    if (facilityId != null) {
      final data = await client.from('employees').select().eq('facility_id', facilityId).order('full_name');
      return List<Map<String, dynamic>>.from(data);
    }
    final data = await client.from('employees').select().order('full_name');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> registerEmployee({
    required String facilityId,
    required String fullName,
    String? designation,
  }) async {
    await client.from('employees').insert({
      'facility_id': facilityId,
      'full_name': fullName,
      'designation': designation,
    });
  }

  // ---------------------------------------------------------------------------
  // Biometric Devices
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchDevices({String? facilityId}) async {
    if (facilityId != null) {
      final data = await client.from('biometric_devices').select().eq('facility_id', facilityId);
      return List<Map<String, dynamic>>.from(data);
    }
    final data = await client.from('biometric_devices').select();
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> registerDevice({required String facilityId, String deviceType = 'face'}) async {
    await client.from('biometric_devices').insert({'facility_id': facilityId, 'device_type': deviceType});
  }

  // ---------------------------------------------------------------------------
  // Duty Roster
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchDutyRoster({required String facilityId, required String date}) async {
    final data = await client.from('duty_roster').select().eq('facility_id', facilityId).eq('date', date);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> assignDuty({required String employeeId, required String facilityId, required String date, String? shift}) async {
    await client.from('duty_roster').upsert({
      'employee_id': employeeId,
      'facility_id': facilityId,
      'date': date,
      'expected_shift': shift,
    }, onConflict: 'employee_id,date');
  }

  // ---------------------------------------------------------------------------
  // Attendance with verification method (face / manual override)
  // ---------------------------------------------------------------------------

  /// Kept for older screens. Face-verified records use [recordFaceAttendance];
  /// anything without a device is stored as a manual override.
  static Future<void> recordBiometricAttendance({
    required String facilityId,
    required String employeeId,
    required String employeeName,
    String? designation,
    required String status,
    required String date,
    String? deviceId,
    required String markedBy,
  }) async {
    await client.from('doctor_attendance').insert({
      'facility_id': facilityId,
      'employee_id': employeeId,
      'doctor_name': employeeName,
      'designation': designation,
      'status': status,
      'date': date,
      'device_id': deviceId,
      'verification_method': deviceId != null ? 'face' : 'manual_override',
      'marked_by': markedBy,
    });
  }

  /// Attendance that was verified by face recognition.
  /// [matchScore] is the cosine similarity of the match, stored for audit.
  static Future<void> recordFaceAttendance({
    required String facilityId,
    required String employeeId,
    required String employeeName,
    String? designation,
    required String date,
    required String markedBy,
    required double matchScore,
    String status = 'present',
  }) async {
    await client.from('doctor_attendance').insert({
      'facility_id': facilityId,
      'employee_id': employeeId,
      'doctor_name': employeeName,
      'designation': designation,
      'status': status,
      'date': date,
      'verification_method': 'face',
      'face_match_score': double.parse(matchScore.toStringAsFixed(4)),
      'marked_by': markedBy,
    });
  }

  /// Attendance entered by hand when face verification is not possible.
  /// It is stored with its own verification method so DDHS can review it.
  static Future<void> recordManualOverrideAttendance({
    required String facilityId,
    required String employeeId,
    required String employeeName,
    String? designation,
    required String status,
    required String date,
    required String markedBy,
  }) async {
    await client.from('doctor_attendance').insert({
      'facility_id': facilityId,
      'employee_id': employeeId,
      'doctor_name': employeeName,
      'designation': designation,
      'status': status,
      'date': date,
      'verification_method': 'manual_override',
      'marked_by': markedBy,
    });
  }

  /// True when the employee already has an attendance record for [date].
  static Future<bool> hasAttendanceToday({required String employeeId, required String date}) async {
    final data = await client
        .from('doctor_attendance')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('date', date)
        .limit(1);
    return (data as List).isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Face templates (numeric face embeddings, no photos are stored)
  // ---------------------------------------------------------------------------

  /// Replaces all templates of an employee with [embeddings].
  static Future<void> saveFaceTemplates({
    required String employeeId,
    required String facilityId,
    required List<List<double>> embeddings,
    required String enrolledBy,
    String modelName = 'mobilefacenet',
  }) async {
    await client.from('face_templates').delete().eq('employee_id', employeeId);
    await client.from('face_templates').insert([
      for (final e in embeddings)
        {
          'employee_id': employeeId,
          'facility_id': facilityId,
          'embedding': e,
          'model_name': modelName,
          'enrolled_by': enrolledBy,
        },
    ]);
  }

  static Future<List<Map<String, dynamic>>> fetchFaceTemplates(String facilityId) async {
    final data = await client
        .from('face_templates')
        .select('employee_id, embedding')
        .eq('facility_id', facilityId);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Set<String>> fetchEnrolledEmployeeIds(String facilityId) async {
    final rows = await fetchFaceTemplates(facilityId);
    return rows.map((r) => r['employee_id'].toString()).toSet();
  }

  /// Withdraws consent: removes every face template of the employee.
  static Future<void> deleteFaceTemplates(String employeeId) async {
    await client.from('face_templates').delete().eq('employee_id', employeeId);
  }

  // ---------------------------------------------------------------------------
  // Face alerts (unrecognised face tried to mark attendance)
  // ---------------------------------------------------------------------------

  static Future<void> reportFaceAlert({
    required String facilityId,
    required String reason,
    required double bestScore,
    required String reportedBy,
  }) async {
    await client.from('face_alerts').insert({
      'facility_id': facilityId,
      'reason': reason,
      'best_score': double.parse(bestScore.toStringAsFixed(4)),
      'reported_by': reportedBy,
    });
  }

  static Stream<List<Map<String, dynamic>>> faceAlertsStream() {
    return client
        .from('face_alerts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(20);
  }

  // ---------------------------------------------------------------------------
  // Transparency Portal (ONE definition only)
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> fetchPublicLedgerForFacility(String facilityCode) async {
    final facility = await client
        .from('facilities')
        .select('id')
        .eq('code', facilityCode)
        .maybeSingle();

    if (facility == null) {
      return [];
    }

    final facilityId = facility['id'] as String;

    final data = await client
        .from('chain_ledger')
        .select()
        .eq('facility_id', facilityId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  // ---------------------------------------------------------------------------
  // Dashboard aggregates
  // ---------------------------------------------------------------------------

  static Future<Map<String, int>> fetchAttendanceSummary({String? facilityId}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    List<Map<String, dynamic>> rows;

    if (facilityId != null) {
      final data = await client
          .from('doctor_attendance')
          .select('status')
          .eq('date', today)
          .eq('facility_id', facilityId);
      rows = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await client.from('doctor_attendance').select('status').eq('date', today);
      rows = List<Map<String, dynamic>>.from(data);
    }

    return {
      'present': rows.where((r) => r['status'] == 'present').length,
      'absent': rows.where((r) => r['status'] == 'absent').length,
      'leave': rows.where((r) => r['status'] == 'leave').length,
    };
  }

  static Future<int> fetchOpenEmergenciesCount({String? facilityId}) async {
    List<Map<String, dynamic>> rows;

    if (facilityId != null) {
      final data = await client
          .from('emergency_reports')
          .select('id')
          .neq('status', 'resolved')
          .eq('facility_id', facilityId);
      rows = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await client.from('emergency_reports').select('id').neq('status', 'resolved');
      rows = List<Map<String, dynamic>>.from(data);
    }

    return rows.length;
  }

  static Future<Map<String, int>> fetchStockSummary({String? facilityId}) async {
    List<Map<String, dynamic>> rows;

    if (facilityId != null) {
      final data = await client.from('medicine_stock').select('status').eq('facility_id', facilityId);
      rows = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await client.from('medicine_stock').select('status');
      rows = List<Map<String, dynamic>>.from(data);
    }

    return {
      'total': rows.length,
      'healthy': rows.where((r) => r['status'] == 'adequate').length,
      'low': rows.where((r) => r['status'] == 'low').length,
      'critical': rows.where((r) => r['status'] == 'critical' || r['status'] == 'out_of_stock').length,
    };
  }

  static Future<Map<String, int>> fetchPatientsToday({String? facilityId}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    List<Map<String, dynamic>> rows;

    if (facilityId != null) {
      final data = await client
          .from('patients')
          .select('opd_count, ipd_count, male_count, female_count, other_count')
          .eq('date', today)
          .eq('facility_id', facilityId);
      rows = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await client
          .from('patients')
          .select('opd_count, ipd_count, male_count, female_count, other_count')
          .eq('date', today);
      rows = List<Map<String, dynamic>>.from(data);
    }

    int opd = 0;
    int ipd = 0;
    int total = 0;

    for (final r in rows) {
      opd += _toInt(r['opd_count']);
      ipd += _toInt(r['ipd_count']);
      total += _toInt(r['male_count']) + _toInt(r['female_count']) + _toInt(r['other_count']);
    }

    return {'opd': opd, 'ipd': ipd, 'total': total};
  }

  static Future<List<Map<String, dynamic>>> fetchRecentActivity({String? facilityId, int limit = 6}) async {
    final List<Map<String, dynamic>> attendanceRows;
    final List<Map<String, dynamic>> emergencyRows;
    final List<Map<String, dynamic>> stockRows;

    if (facilityId != null) {
      final data = await client
          .from('doctor_attendance')
          .select()
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false)
          .limit(limit);
      attendanceRows = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await client.from('doctor_attendance').select().order('created_at', ascending: false).limit(limit);
      attendanceRows = List<Map<String, dynamic>>.from(data);
    }

    if (facilityId != null) {
      final data = await client
          .from('emergency_reports')
          .select()
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false)
          .limit(limit);
      emergencyRows = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await client.from('emergency_reports').select().order('created_at', ascending: false).limit(limit);
      emergencyRows = List<Map<String, dynamic>>.from(data);
    }

    if (facilityId != null) {
      final data = await client
          .from('medicine_stock')
          .select()
          .eq('facility_id', facilityId)
          .order('updated_at', ascending: false)
          .limit(limit);
      stockRows = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await client.from('medicine_stock').select().order('updated_at', ascending: false).limit(limit);
      stockRows = List<Map<String, dynamic>>.from(data);
    }

    final activity = <Map<String, dynamic>>[];

    for (final r in attendanceRows) {
      activity.add({
        'kind': 'attendance',
        'title': '${r['doctor_name']} marked ${r['status']}',
        'time': r['created_at'],
        'status': r['status'],
      });
    }

    for (final r in emergencyRows) {
      activity.add({
        'kind': 'emergency',
        'title': 'Emergency: ${r['title'] ?? 'Emergency reported'}',
        'time': r['created_at'],
        'status': r['severity'],
      });
    }

    for (final r in stockRows) {
      activity.add({
        'kind': 'stock',
        'title': '${r['medicine_name'] ?? 'Medicine'} — ${r['movement_type'] ?? 'updated'}',
        'time': r['updated_at'],
        'status': r['status'],
      });
    }

    activity.sort((a, b) {
      final aTime = a['time']?.toString() ?? '';
      final bTime = b['time']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    return activity.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

// -----------------------------------------------------------------------------
// Chain verification result
// -----------------------------------------------------------------------------

class ChainVerificationResult {
  final Map<String, dynamic> entry;
  final bool valid;

  ChainVerificationResult({required this.entry, required this.valid});
}