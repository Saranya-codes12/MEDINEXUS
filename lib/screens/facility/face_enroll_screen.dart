import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/face_service.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

/// Lets a facility user enrol the face of an employee.
/// Three photos are turned into numeric templates; the photos are not stored.
class FaceEnrollScreen extends StatefulWidget {
  const FaceEnrollScreen({super.key});

  @override
  State<FaceEnrollScreen> createState() => _FaceEnrollScreenState();
}

class _FaceEnrollScreenState extends State<FaceEnrollScreen> {
  static const int _samplesNeeded = 3;

  String? _facilityId;
  bool _loading = true;
  String? _fatal;

  List<Map<String, dynamic>> _employees = [];
  Set<String> _enrolled = {};

  Map<String, dynamic>? _selected;
  CameraController? _camera;
  bool _consent = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  final List<List<double>> _samples = [];

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

  Future<void> _init() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      setState(() {
        _fatal = 'Face enrolment works on the Android or iOS app. Please run MediNexus on a phone.';
        _loading = false;
      });
      return;
    }

    _facilityId = context.read<AuthProvider>().profile?.facilityId;
    if (_facilityId == null) {
      setState(() {
        _fatal = 'No facility is linked to this account.';
        _loading = false;
      });
      return;
    }
    await _reload();
  }

  Future<void> _reload() async {
    final id = _facilityId!;
    try {
      final results = await Future.wait<Object>([
        SupabaseService.fetchEmployees(facilityId: id),
        SupabaseService.fetchEnrolledEmployeeIds(id),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = results[0] as List<Map<String, dynamic>>;
        _enrolled = results[1] as Set<String>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fatal = 'Could not load employees: $e';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Enrolment flow
  // ---------------------------------------------------------------------------

  Future<void> _startEnrol(Map<String, dynamic> employee) async {
    setState(() {
      _selected = employee;
      _samples.clear();
      _consent = false;
      _message = null;
    });

    try {
      await FaceService.instance.init();
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
      setState(() => _camera = ctrl);
    } on CameraException catch (e) {
      _fail('Camera problem: ${e.description ?? e.code}. Allow camera access in the phone settings.');
    } on FaceException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Could not start the camera: $e');
    }
  }

  Future<void> _closeEnrol() async {
    final cam = _camera;
    setState(() {
      _camera = null;
      _selected = null;
      _samples.clear();
      _message = null;
    });
    await cam?.dispose();
  }

  Future<void> _capture() async {
    final cam = _camera;
    if (cam == null || _busy || !_consent) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final shot = await cam.takePicture();
      final sample = await FaceService.instance.processFile(shot.path);

      if (sample.yaw.abs() > FaceService.frontalYawDeg) {
        throw FaceException('Look straight at the camera.');
      }
      if (!sample.eyesOpen) {
        throw FaceException('Keep your eyes open.');
      }
      if (_samples.isNotEmpty &&
          FaceService.instance.similarity(_samples.first, sample.embedding) < 0.6) {
        throw FaceException('This photo does not look like the earlier ones. Only one person should be enrolled at a time.');
      }

      _samples.add(sample.embedding);

      if (_samples.length >= _samplesNeeded) {
        await _save();
      } else {
        _info('Photo ${_samples.length} of $_samplesNeeded saved. Change your expression slightly and take the next one.');
      }
    } on FaceException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final employee = _selected!;
    final user = SupabaseService.currentUser;
    if (user == null) throw FaceException('You are signed out. Please sign in again.');

    await SupabaseService.saveFaceTemplates(
      employeeId: employee['id'].toString(),
      facilityId: _facilityId!,
      embeddings: List.of(_samples),
      enrolledBy: user.id,
    );

    final name = (employee['full_name'] ?? 'Employee').toString();
    await _closeEnrol();
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Face enrolled for $name')));
  }

  Future<void> _confirmDelete(Map<String, dynamic> employee) async {
    final name = (employee['full_name'] ?? 'this employee').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove face data?'),
        content: Text('This deletes the stored face template of $name. They will have to enrol again to use face attendance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.deleteFaceTemplates(employee['id'].toString());
    await _reload();
  }

  void _fail(String text) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = true;
    });
  }

  void _info(String text) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = false;
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected == null ? 'Enrol faces' : 'Enrol ${_selected!['full_name'] ?? ''}'),
        leading: _selected == null
            ? null
            : IconButton(icon: const Icon(Icons.close), onPressed: _busy ? null : _closeEnrol),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_fatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_fatal!, textAlign: TextAlign.center),
        ),
      );
    }
    return _selected == null ? _employeeList() : _captureView();
  }

  Widget _employeeList() {
    if (_employees.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No employees are registered for this facility yet. Add employees to the registry first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final e = _employees[i];
          final enrolled = _enrolled.contains(e['id'].toString());
          return Card(
            elevation: 0,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: enrolled ? AppColors.vitalLight : AppColors.roseLight,
                child: Icon(
                  enrolled ? Icons.verified_user_outlined : Icons.face_retouching_off,
                  color: enrolled ? AppColors.vital : AppColors.rose,
                ),
              ),
              title: Text((e['full_name'] ?? '').toString()),
              subtitle: Text(
                '${(e['designation'] ?? '').toString()}${(e['designation'] ?? '').toString().isEmpty ? '' : ' • '}'
                '${enrolled ? 'Face enrolled' : 'Not enrolled'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (enrolled)
                    IconButton(
                      tooltip: 'Remove face data',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(e),
                    ),
                  FilledButton.tonal(
                    onPressed: () => _startEnrol(e),
                    child: Text(enrolled ? 'Re-enrol' : 'Enrol'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _captureView() {
    final cam = _camera;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CheckboxListTile(
          value: _consent,
          onChanged: _busy ? null : (v) => setState(() => _consent = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'The employee agrees that a numeric face template is stored and used only for attendance. '
            'No photos are kept.',
            style: TextStyle(fontSize: 13),
          ),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _samplesNeeded; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < _samples.length ? Icons.check_circle : Icons.circle_outlined,
                  color: i < _samples.length ? AppColors.vital : AppColors.muted,
                ),
              ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _messageIsError ? AppColors.roseLight : AppColors.vitalLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _message!,
              style: TextStyle(color: _messageIsError ? AppColors.rose : AppColors.vital, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_busy || !_consent || cam == null || !cam.value.isInitialized) ? null : _capture,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt_outlined),
          label: Text(_busy ? 'Processing...' : 'Take photo ${_samples.length + 1} of $_samplesNeeded'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Look straight at the camera, in good light, with no mask, cap or sunglasses.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}