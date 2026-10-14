import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_header.dart';
import '../widgets/empty_state.dart';

class AttendanceScreen extends StatefulWidget {
  final bool embedded;
  const AttendanceScreen({super.key, this.embedded = false});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final nameCtrl = TextEditingController();
  final designationCtrl = TextEditingController();
  String status = 'present';
  bool submitting = false;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.profile?.facilityId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await SupabaseService.markAttendance(
        facilityId: auth.profile!.facilityId!,
        doctorName: nameCtrl.text,
        designation: designationCtrl.text.isEmpty ? null : designationCtrl.text,
        status: status,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        markedBy: auth.profile!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded'), backgroundColor: AppColors.vital),
        );
        nameCtrl.clear();
        designationCtrl.clear();
        setState(() => status = 'present');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.rose),
        );
      }
    }
    if (mounted) setState(() => submitting = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'present': return AppColors.vital;
      case 'absent': return AppColors.rose;
      default: return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!auth.isAdmin) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.checklist_outlined, color: AppColors.teal, size: 20),
                  SizedBox(width: 8),
                  Text('Mark Attendance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Doctor Name', hintText: 'Dr. Anita Sharma'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: designationCtrl,
                  decoration: const InputDecoration(labelText: 'Designation', hintText: 'Medical Officer'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['present', 'absent', 'leave'].map((s) {
                    final active = status == s;
                    final color = _statusColor(s);
                    return ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      selected: active,
                      onSelected: (_) => setState(() => status = s),
                      selectedColor: color.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: active ? color : AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(color: active ? color : const Color(0xFFE2E8F0)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: submitting ? 'Saving…' : 'Record Attendance',
                  onPressed: _submit,
                  loading: submitting,
                  icon: Icons.check,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'This record is automatically added to the blockchain-inspired hash-chain ledger — visible in Audit Trail.',
            style: TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
        ],
        SectionHeader(title: auth.isAdmin ? "Today's Attendance — All Facilities" : "Today's Attendance"),
        if (auth.profile?.facilityId != null)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.attendanceStream(auth.profile!.facilityId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final items = snapshot.data!.where((r) => r['date'] == today).toList();
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.checklist_outlined,
                  title: 'No attendance marked yet',
                  message: 'Doctor attendance recorded today will appear here.',
                );
              }
              return Column(
                children: items.map((r) {
                  final color = _statusColor(r['status'] ?? 'present');
                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(
                            r['status'] == 'present' ? Icons.how_to_reg_outlined : Icons.person_off_outlined,
                            size: 18, color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['doctor_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((r['designation'] ?? '').toString().isNotEmpty)
                                Text(
                                  r['designation'],
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: r['status'] ?? '', fg: color, bg: color.withValues(alpha: 0.12)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          )
        else
          const EmptyState(
            icon: Icons.apartment_outlined,
            title: 'Select a facility',
            message: 'Choose a facility to view its attendance records.',
          ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Attendance')),
      body: SafeArea(child: body),
    );
  }
}