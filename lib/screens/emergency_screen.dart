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

class EmergencyScreen extends StatefulWidget {
  final bool embedded;
  const EmergencyScreen({super.key, this.embedded = false});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String severity = 'medium';
  bool submitting = false;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.profile?.facilityId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await SupabaseService.reportEmergency({
        'facility_id': auth.profile!.facilityId,
        'title': titleCtrl.text,
        'description': descCtrl.text,
        'severity': severity,
        'status': 'open',
        'reported_by': auth.profile!.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency reported to DDHS'), backgroundColor: AppColors.vital));
        titleCtrl.clear(); descCtrl.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.rose));
    }
    if (mounted) setState(() => submitting = false);
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': case 'high': return AppColors.rose;
      case 'medium': return AppColors.amber;
      default: return AppColors.teal;
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
                  Icon(Icons.warning_amber_outlined, color: AppColors.rose, size: 20),
                  SizedBox(width: 8),
                  Text('Report Emergency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 14),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', hintText: 'Oxygen shortage in ward')),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: ['low', 'medium', 'high', 'critical'].map((s) {
                    final active = severity == s;
                    return ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: 11.5)),
                      selected: active,
                      onSelected: (_) => setState(() => severity = s),
                      selectedColor: AppColors.roseLight,
                      labelStyle: TextStyle(color: active ? AppColors.rose : AppColors.muted, fontWeight: FontWeight.w600),
                      side: BorderSide(color: active ? AppColors.rose : const Color(0xFFE2E8F0)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: submitting ? 'Sending…' : 'Send Emergency Alert', onPressed: _submit, loading: submitting, color: AppColors.rose, icon: Icons.send_outlined),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const SectionHeader(title: 'Recent Reports'),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.emergencyStream(auth.isAdmin ? null : auth.profile?.facilityId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const EmptyState(icon: Icons.check_circle_outline, title: 'No emergencies reported', message: 'All clear. Reports will appear here if raised.');
            }
            return Column(
              children: items.map((r) {
                final color = _severityColor(r['severity'] ?? 'medium');
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8, runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                            child: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 2),
                          ),
                          StatusBadge(label: r['severity'] ?? '', fg: color, bg: color.withValues(alpha: 0.12)),
                          StatusBadge(label: r['status'] ?? '', fg: AppColors.muted, bg: const Color(0xFFF1F5F9)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(r['description'] ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(r['created_at']).toLocal()), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Emergency Reports')), body: SafeArea(child: body));
  }
}