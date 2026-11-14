import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/face_service.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

enum _Phase { loading, ready, capturing, confirm, done, fatal }

/// Marks attendance by face.
///
/// Flow: choose who is marking attendance -> one photo (look straight) ->
/// the face must match that person -> confirm -> the record is saved with
/// verification method "face". If the face is not recognised, or belongs to a
/// different employee (someone marking for another), the admin is notified.
class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen> {
  _Phase _phase = _Phase.loading;
  String? _facilityId;
  CameraController? _camera;

  List<Map<String, dynamic>> _employees = [];
  List<EnrolledFace> _enrolled = [];

  String? _message;
  bool _messageIsError = false;
  MatchResult? _result;
  String? _doneText;
  String? _claimedId; // the employee who says they are marking attendance
  int _claimReset = 0; // changes to clear the dropdown

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _fatal('Face attendance works on the Android or iOS app. Please run MediNexus on a phone.');
      return;
    }

    _facilityId = context.read<AuthProvider>().profile?.facilityId;
    final facilityId = _facilityId;
    if (facilityId == null) {
      _fatal('No facility is linked to this account.');
      return;
    }

    try {
      await FaceService.instance.init();

      final results = await Future.wait<Object>([
        SupabaseService.fetchEmployees(facilityId: facilityId),
        SupabaseService.fetchFaceTemplates(facilityId),
      ]);
      _employees = results[0] as List<Map<String, dynamic>>;
      final rows = results[1] as List<Map<String, dynamic>>;
      _enrolled = _buildEnrolled(_employees, rows);

      final cams = await availableCameras();
      if (cams.isEmpty) throw FaceException('No camera was found on this device.');
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _camera = ctrl;
        _phase = _Phase.ready;
        if (_enrolled.isEmpty) {
          _message = 'No faces are enrolled yet. Enrol employees first, or use the manual override.';
          _messageIsError = true;
        }
      });
    } on CameraException catch (e) {
      _fatal('Camera problem: ${e.description ?? e.code}. Allow camera access in the phone settings.');
    } on FaceException catch (e) {
      _fatal(e.message);
    } catch (e) {
      _fatal('Could not start face attendance: $e');
    }
  }

  List<EnrolledFace> _buildEnrolled(List<Map<String, dynamic>> employees, List<Map<String, dynamic>> rows) {
    final byEmployee = <String, List<List<double>>>{};
    for (final r in rows) {
      final raw = r['embedding'];
      if (raw is! List) continue;
      byEmployee
          .putIfAbsent(r['employee_id'].toString(), () => [])
          .add([for (final v in raw) (v as num).toDouble()]);
    }

    final list = <EnrolledFace>[];
    for (final e in employees) {
      final id = e['id'].toString();
      final templates = byEmployee[id];
      if (templates == null || templates.isEmpty) continue;
      list.add(EnrolledFace(
        employeeId: id,
        name: (e['full_name'] ?? '').toString(),
        designation: e['designation']?.toString(),
        templates: templates,
      ));
    }
    return list;
  }

  void _fatal(String text) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.fatal;
      _message = text;
      _messageIsError = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  Future<void> _verify() async {
    final cam = _camera;
    if (cam == null || _phase == _Phase.capturing) return;

    setState(() {
      _phase = _Phase.capturing;
      _message = 'Look straight at the camera...';
      _messageIsError = false;
      _result = null;
    });

    final claimedId = _claimedId;
    if (claimedId == null) {
      _backToReady('Choose who is marking attendance first.', error: true);
      return;
    }
    final claimed = _employees.firstWhere((e) => e['id'].toString() == claimedId);
    final claimedName = (claimed['full_name'] ?? '').toString();

    try {
      if (!_enrolled.any((e) => e.employeeId == claimedId)) {
        throw FaceException('$claimedName has no face enrolled yet. Enrol the face first.');
      }

      final shot = await cam.takePicture();
      final sample = await FaceService.instance.processFile(shot.path);
      if (!sample.eyesOpen) throw FaceException('Keep your eyes open.');
      if (sample.yaw.abs() > FaceService.frontalYawDeg) throw FaceException('Look straight at the camera.');

      final result = FaceService.instance.match(sample.embedding, _enrolled);

      if (!result.isMatch) {
        await _raiseAlert('Unrecognised face tried to mark attendance for $claimedName', result.score);
        throw FaceException('Face not recognised for $claimedName. The admin has been notified.');
      }

      if (result.face!.employeeId != claimedId) {
        await _raiseAlert(
          "${result.face!.name}'s face was used to mark attendance for $claimedName",
          result.score,
        );
        throw FaceException('This face does not match $claimedName. The admin has been notified.');
      }

      final face = result.face!;
      final already = await SupabaseService.hasAttendanceToday(employeeId: face.employeeId, date: _today);
      if (!mounted) return;
      if (already) {
        setState(() {
          _phase = _Phase.ready;
          _message = 'Attendance for ${face.name} is already recorded today.';
          _messageIsError = false;
        });
        return;
      }

      setState(() {
        _result = result;
        _phase = _Phase.confirm;
        _message = null;
      });
    } on FaceException catch (e) {
      _backToReady(e.message, error: true);
    } catch (e) {
      _backToReady('Something went wrong: $e', error: true);
    }
  }

  /// Tells the admin that someone tried to mark attendance for another person
  /// or with an unknown face. Never blocks the screen if it fails.
  Future<void> _raiseAlert(String reason, double score) async {
    final facilityId = _facilityId;
    final user = SupabaseService.currentUser;
    if (facilityId == null || user == null) return;
    try {
      await SupabaseService.reportFaceAlert(
        facilityId: facilityId,
        reason: reason,
        bestScore: score,
        reportedBy: user.id,
      );
    } catch (_) {}
  }

  void _backToReady(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.ready;
      _message = text;
      _messageIsError = error;
    });
  }

  Future<void> _confirm() async {
    final result = _result;
    final facilityId = _facilityId;
    final user = SupabaseService.currentUser;
    if (result == null || result.face == null || facilityId == null || user == null) return;

    final face = result.face!;
    try {
      await SupabaseService.recordFaceAttendance(
        facilityId: facilityId,
        employeeId: face.employeeId,
        employeeName: face.name,
        designation: face.designation,
        date: _today,
        markedBy: user.id,
        matchScore: result.score,
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _doneText = '${face.name} marked present';
      });
    } catch (e) {
      _backToReady('Could not save the attendance: $e', error: true);
    }
  }

  void _reject() {
    setState(() {
      _result = null;
      _phase = _Phase.ready;
      _message = 'Cancelled. Nothing was saved.';
      _messageIsError = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Manual override (flagged so DDHS can review it)
  // ---------------------------------------------------------------------------

  Future<void> _manualOverride() async {
    final facilityId = _facilityId;
    final user = SupabaseService.currentUser;
    if (facilityId == null || user == null || _employees.isEmpty) return;

    String? employeeId;
    String status = 'present';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manual override', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                  'Use this only when face verification is not possible. The record is marked as a manual override.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: employeeId,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: [
                    for (final e in _employees)
                      DropdownMenuItem(value: e['id'].toString(), child: Text((e['full_name'] ?? '').toString())),
                  ],
                  onChanged: (v) => setSheet(() => employeeId = v),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: employeeId == null ? null : () => Navigator.pop(ctx, true),
                    child: const Text('Save override'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    if (ok != true || employeeId == null) return;

    final emp = _employees.firstWhere((e) => e['id'].toString() == employeeId);
    try {
      final already = await SupabaseService.hasAttendanceToday(employeeId: employeeId!, date: _today);
      if (already) {
        _backToReady('Attendance for ${emp['full_name']} is already recorded today.');
        return;
      }
      await SupabaseService.recordManualOverrideAttendance(
        facilityId: facilityId,
        employeeId: employeeId!,
        employeeName: (emp['full_name'] ?? '').toString(),
        designation: emp['designation']?.toString(),
        status: status,
        date: _today,
        markedBy: user.id,
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _doneText = '${emp['full_name']} marked $status (manual override)';
      });
    } catch (e) {
      _backToReady('Could not save the override: $e', error: true);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face attendance')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.fatal:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_message ?? 'Face attendance is not available.', textAlign: TextAlign.center),
          ),
        );
      case _Phase.done:
        return _doneView();
      case _Phase.confirm:
        return _confirmView();
      case _Phase.ready:
      case _Phase.capturing:
        return _cameraView();
    }
  }

  Widget _banner() {
    if (_message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _messageIsError ? AppColors.roseLight : AppColors.tealLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _message!,
          style: TextStyle(
            color: _messageIsError ? AppColors.rose : AppColors.teal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _cameraView() {
    final cam = _camera;
    final busy = _phase == _Phase.capturing;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_claimReset),
          initialValue: _claimedId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Who is marking attendance?'),
          items: [
            for (final e in _employees)
              DropdownMenuItem(value: e['id'].toString(), child: Text((e['full_name'] ?? '').toString())),
          ],
          onChanged: busy ? null : (v) => setState(() => _claimedId = v),
        ),
        const SizedBox(height: 4),
        Text(
          '${_enrolled.length} employee${_enrolled.length == 1 ? '' : 's'} enrolled',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        if (cam == null || !cam.value.isInitialized)
          const SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1 / cam.value.aspectRatio,
                  child: CameraPreview(cam),
                ),
              ),
            ),
          ),
        _banner(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (busy || cam == null || !cam.value.isInitialized || _enrolled.isEmpty || _claimedId == null) ? null : _verify,
          icon: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.face_retouching_natural),
          label: Text(busy ? 'Verifying...' : 'Verify face'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: busy ? null : _manualOverride,
          icon: const Icon(Icons.edit_note),
          label: const Text('Manual override'),
        ),
      ],
    );
  }

  Widget _confirmView() {
    final result = _result!;
    final face = result.face!;
    final percent = (result.score * 100).clamp(0, 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.tealLight,
            child: Icon(Icons.person, size: 40, color: AppColors.teal),
          ),
          const SizedBox(height: 16),
          Text(face.name, style: Theme.of(context).textTheme.titleLarge),
          if ((face.designation ?? '').isNotEmpty)
            Text(face.designation!, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          Text('Match $percent%', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _confirm, child: const Text('Mark present')),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: _reject, child: const Text('Not me')),
          ),
        ],
      ),
    );
  }

  Widget _doneView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: AppColors.vital),
          const SizedBox(height: 16),
          Text(_doneText ?? 'Attendance saved', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() {
              _phase = _Phase.ready;
              _message = null;
              _result = null;
              _claimedId = null;
              _claimReset++;
            }),
            child: const Text('Next employee'),
          ),
        ],
      ),
    );
  }
}