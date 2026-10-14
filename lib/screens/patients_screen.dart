import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import '../widgets/empty_state.dart';

class PatientsScreen extends StatefulWidget {
  final bool embedded;
  const PatientsScreen({super.key, this.embedded = false});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final maleCtrl = TextEditingController();
  final femaleCtrl = TextEditingController();
  final opdCtrl = TextEditingController();
  final ipdCtrl = TextEditingController();
  bool submitting = false;
  List<Map<String, dynamic>>? entries;
  bool loadingEntries = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final auth = context.read<AuthProvider>();
    final data = await SupabaseService.fetchPatients(auth.isAdmin ? null : auth.profile?.facilityId);
    if (mounted) setState(() { entries = data; loadingEntries = false; });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.profile?.facilityId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await SupabaseService.savePatientEntry({
        'facility_id': auth.profile!.facilityId,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'male_count': int.tryParse(maleCtrl.text) ?? 0,
        'female_count': int.tryParse(femaleCtrl.text) ?? 0,
        'opd_count': int.tryParse(opdCtrl.text) ?? 0,
        'ipd_count': int.tryParse(ipdCtrl.text) ?? 0,
        'entered_by': auth.profile!.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved for today'), backgroundColor: AppColors.vital));
        _loadEntries();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.rose));
    }
    if (mounted) setState(() => submitting = false);
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
                Text("Today's Patient Entry", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextField(controller: maleCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Male'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: femaleCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Female'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: opdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'OPD Count'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: ipdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'IPD Count'))),
                ]),
                const SizedBox(height: 16),
                PrimaryButton(label: submitting ? 'Saving…' : "Save Today's Count", onPressed: _submit, loading: submitting, icon: Icons.save_outlined),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        SectionHeader(title: auth.isAdmin ? 'Patient Records — All Facilities' : 'Recent Entries'),
        if (loadingEntries) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        if (!loadingEntries && (entries == null || entries!.isEmpty))
          const EmptyState(icon: Icons.groups_outlined, title: 'No patient records yet', message: 'Daily patient counts logged by facility staff will appear here.'),
        if (!loadingEntries && entries != null)
          ...entries!.map((e) {
            final total = (e['male_count'] ?? 0) + (e['female_count'] ?? 0) + (e['other_count'] ?? 0);
            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.groups_outlined, size: 18, color: AppColors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(DateTime.parse(e['date'])), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('OPD ${e['opd_count'] ?? 0} · IPD ${e['ipd_count'] ?? 0}', style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$total', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.teal)),
                ],
              ),
            );
          }),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Patient Records')), body: SafeArea(child: body));
  }
}