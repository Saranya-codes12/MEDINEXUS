import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'facility/face_attendance_screen.dart';
import 'facility/face_enroll_screen.dart';

/// Facility attendance: today's records, face attendance, face enrolment,
/// manual entry and correction requests.
///
/// Place it at lib/screens/attendance_screen.dart.
/// The face screens sit next to it in lib/screens/.
class AttendanceScreen extends StatefulWidget {
  /// When true the screen is shown inside another Scaffold (dashboard tab),
  /// so it does not draw its own app bar.
  final bool embedded;
  const AttendanceScreen({super.key, this.embedded = false});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  String? get _facilityId => context.read<AuthProvider>().profile?.facilityId;

  Stream<List<Map<String, dynamic>>>? _stream;

  /// The district admin has no facility and monitors every facility.
  bool get _isAdmin => context.read<AuthProvider>().profile?.facilityId == null;

  Map<String, String> _facilityNames = {};

  @override
  void initState() {
    super.initState();
    _connect();
    if (_isAdmin) _loadFacilityNames();
  }

  void _connect() {
    final id = context.read<AuthProvider>().profile?.facilityId;
    _stream = SupabaseService.attendanceStream(id);
  }

  Future<void> _loadFacilityNames() async {
    try {
      final list = await SupabaseService.fetchFacilities();
      if (!mounted) return;
      setState(() {
        _facilityNames = {
          for (final f in list) f['id'].toString(): (f['name'] ?? '').toString(),
        };
      });
    } catch (_) {}
  }

  String _subtitle(Map<String, dynamic> r) {
    final parts = <String>[];
    if (_isAdmin) {
      final name = _facilityNames[(r['facility_id'] ?? '').toString()];
      if (name != null && name.isNotEmpty) parts.add(name);
    }
    final designation = (r['designation'] ?? '').toString();
    if (designation.isNotEmpty) parts.add(designation);
    parts.add(_method(r));
    return parts.join(' • ');
  }

  /// An expired login token makes the live stream fail. Refresh the session
  /// and open the stream again.
  Future<void> _retry() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      _toast('Your login has expired. Please sign out and sign in again.');
    }
    if (!mounted) return;
    setState(_connect);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ---------------------------------------------------------------------------
  // Manual entry
  // ---------------------------------------------------------------------------

  Future<void> _manualEntry() async {
    final facilityId = _facilityId;
    final user = SupabaseService.currentUser;
    if (facilityId == null || user == null) return;

    List<Map<String, dynamic>> employees;
    try {
      employees = await SupabaseService.fetchEmployees(facilityId: facilityId);
    } catch (e) {
      _toast('Could not load employees: $e');
      return;
    }
    if (!mounted) return;
    if (employees.isEmpty) {
      _toast('No employees are registered for this facility yet.');
      return;
    }

    Map<String, dynamic>? employee;
    var status = 'present';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manual entry', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Use this only when face verification is not possible. '
                'It is recorded as a manual override and DDHS can review it.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: employee,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Employee'),
                items: [
                  for (final e in employees)
                    DropdownMenuItem(value: e, child: Text((e['full_name'] ?? '').toString())),
                ],
                onChanged: (v) => setSheet(() => employee = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  DropdownMenuItem(value: 'leave', child: Text('On leave')),
                ],
                onChanged: (v) => setSheet(() => status = v ?? 'present'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (employee == null || saving)
                      ? null
                      : () async {
                          setSheet(() => saving = true);
                          try {
                            final emp = employee!;
                            final exists = await SupabaseService.hasAttendanceToday(
                              employeeId: emp['id'].toString(),
                              date: _today,
                            );
                            if (exists) {
                              setSheet(() => saving = false);
                              _toast('Attendance is already recorded today. Use "Request correction" to change it.');
                              return;
                            }
                            await SupabaseService.recordManualOverrideAttendance(
                              facilityId: facilityId,
                              employeeId: emp['id'].toString(),
                              employeeName: (emp['full_name'] ?? '').toString(),
                              designation: emp['designation']?.toString(),
                              status: status,
                              date: _today,
                              markedBy: user.id,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _toast('Attendance recorded');
                          } catch (e) {
                            setSheet(() => saving = false);
                            _toast('Could not save: $e');
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Correction request (the original record is never edited)
  // ---------------------------------------------------------------------------

  Future<void> _requestCorrection(Map<String, dynamic> record) async {
    final facilityId = _facilityId;
    final user = SupabaseService.currentUser;
    if (facilityId == null || user == null) return;

    final original = (record['status'] ?? '').toString();

    // The sheet owns its text controller, so it is disposed safely when the
    // sheet is closed.
    final result = await showModalBottomSheet<_CorrectionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CorrectionSheet(
        name: (record['doctor_name'] ?? '').toString(),
        original: original,
        label: _label,
      ),
    );
    if (result == null) return;

    try {
      await SupabaseService.requestAttendanceCorrection(
        attendanceId: record['id'].toString(),
        facilityId: facilityId,
        originalStatus: original,
        requestedStatus: result.status,
        reason: result.reason,
        requestedBy: user.id,
      );
      _toast('Correction request sent to DDHS');
    } catch (e) {
      _toast('Could not send: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _label(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'leave':
        return 'On leave';
      default:
        return status;
    }
  }

  Color _color(String status) {
    switch (status) {
      case 'present':
        return AppColors.vital;
      case 'absent':
        return AppColors.rose;
      default:
        return AppColors.amber;
    }
  }

  Color _bg(String status) {
    switch (status) {
      case 'present':
        return AppColors.vitalLight;
      case 'absent':
        return AppColors.roseLight;
      default:
        return AppColors.amberLight;
    }
  }

  String _method(Map<String, dynamic> r) {
    switch ((r['verification_method'] ?? '').toString()) {
      case 'face':
        return 'Face verified';
      case 'manual_override':
        return 'Manual override';
      case 'biometric':
        return 'Biometric';
      default:
        return 'Manual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _stream == null
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No facility is linked to this account.', textAlign: TextAlign.center),
            ),
          )
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not load attendance. Your login may have expired.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final today = snap.data!.where((r) => (r['date'] ?? '').toString().startsWith(_today)).toList();
              int count(String s) => today.where((r) => r['status'] == s).length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _SummaryTile(label: 'Present', value: count('present'), color: AppColors.vital, bg: AppColors.vitalLight),
                      const SizedBox(width: 8),
                      _SummaryTile(label: 'Absent', value: count('absent'), color: AppColors.rose, bg: AppColors.roseLight),
                      const SizedBox(width: 8),
                      _SummaryTile(label: 'Leave', value: count('leave'), color: AppColors.amber, bg: AppColors.amberLight),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isAdmin) _AlertsCard(),
                  if (!_isAdmin) ...[
                  FilledButton.icon(
                    onPressed: () => _open(const FaceAttendanceScreen()),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Mark by face'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _open(const FaceEnrollScreen()),
                          icon: const Icon(Icons.how_to_reg),
                          label: const Text('Enrol faces'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _manualEntry,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Manual entry'),
                        ),
                      ),
                    ],
                  ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    _isAdmin ? "Today's attendance - all facilities" : "Today's attendance",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (today.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No attendance recorded yet today.', style: TextStyle(color: AppColors.muted))),
                    )
                  else
                    for (final r in today)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text((r['doctor_name'] ?? '').toString()),
                          subtitle: Text(_subtitle(r)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _bg((r['status'] ?? '').toString()),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _label((r['status'] ?? '').toString()),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _color((r['status'] ?? '').toString()),
                                  ),
                                ),
                              ),
                              if (!_isAdmin)
                              PopupMenuButton<String>(
                                tooltip: 'More',
                                onSelected: (v) {
                                  if (v == 'correct') _requestCorrection(r);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'correct', child: Text('Request correction')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              );
            },
          );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(_isAdmin ? 'Attendance - all facilities' : 'Attendance')),
      body: SafeArea(child: body),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bg;
  const _SummaryTile({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}


class _CorrectionResult {
  final String status;
  final String reason;
  const _CorrectionResult(this.status, this.reason);
}

class _CorrectionSheet extends StatefulWidget {
  final String name;
  final String original;
  final String Function(String) label;

  const _CorrectionSheet({required this.name, required this.original, required this.label});

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  final TextEditingController _reason = TextEditingController();
  late String _requested = widget.original == 'present' ? 'absent' : 'present';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final s in const ['present', 'absent', 'leave'])
        if (s != widget.original) s,
    ];
    if (!options.contains(_requested)) _requested = options.first;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request correction', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${widget.name} • currently ${widget.label(widget.original)}. '
            'The record stays unchanged; DDHS approves or rejects the request.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _requested,
            decoration: const InputDecoration(labelText: 'Correct status'),
            items: [
              for (final s in options) DropdownMenuItem(value: s, child: Text(widget.label(s))),
            ],
            onChanged: (v) => setState(() => _requested = v ?? _requested),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _reason.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(context, _CorrectionResult(_requested, _reason.text.trim())),
              child: const Text('Send request'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent face alerts (unknown face, or someone marking for another person).
/// Shown to the district admin at the top of the attendance monitor.
class _AlertsCard extends StatelessWidget {
  String _time(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.faceAlertsStream(),
      builder: (context, snap) {
        final rows = (snap.data ?? const <Map<String, dynamic>>[]).take(5).toList();
        if (rows.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.roseLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.report_gmailerrorred, color: AppColors.rose, size: 20),
                  SizedBox(width: 8),
                  Text('Face alerts', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.rose)),
                ],
              ),
              const SizedBox(height: 8),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_time(r['created_at']?.toString())}  ${(r['reason'] ?? '').toString()}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}