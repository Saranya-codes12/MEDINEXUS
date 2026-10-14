import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/empty_state.dart';

class EmployeeRegistryScreen extends StatefulWidget {
  const EmployeeRegistryScreen({super.key});
  @override
  State<EmployeeRegistryScreen> createState() => _EmployeeRegistryScreenState();
}

class _EmployeeRegistryScreenState extends State<EmployeeRegistryScreen> {
  final nameCtrl = TextEditingController();
  final designationCtrl = TextEditingController();
  bool submitting = false;
  List<Map<String, dynamic>> employees = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    final data = await SupabaseService.fetchEmployees(
      facilityId: auth.isAdmin ? null : auth.profile?.facilityId,
    );
    if (mounted) setState(() { employees = data; loading = false; });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final facilityId = auth.profile?.facilityId;
    if (facilityId == null || nameCtrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await SupabaseService.registerEmployee(
        facilityId: facilityId,
        fullName: nameCtrl.text.trim(),
        designation: designationCtrl.text.trim().isEmpty ? null : designationCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee registered'), backgroundColor: AppColors.vital),
        );
        nameCtrl.clear();
        designationCtrl.clear();
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.rose));
      }
    }
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Registry')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!auth.isAdmin) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.badge_outlined, color: AppColors.teal, size: 20),
                        SizedBox(width: 8),
                        Text('Register New Employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Dr. Anita Sharma'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: designationCtrl,
                        decoration: const InputDecoration(labelText: 'Designation', hintText: 'Medical Officer'),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: submitting ? 'Registering…' : 'Register Employee',
                        onPressed: _submit,
                        loading: submitting,
                        icon: Icons.person_add_alt_1,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'An Employee ID is generated automatically upon registration.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              SectionHeader(title: auth.isAdmin ? 'All Registered Employees' : 'Facility Employees'),
              if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              if (!loading && employees.isEmpty)
                const EmptyState(
                  icon: Icons.badge_outlined,
                  title: 'No employees registered yet',
                  message: 'Registered doctors and staff will appear here with their unique Employee ID.',
                ),
              if (!loading)
                ...employees.map((e) => AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.person_outline, size: 18, color: AppColors.teal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(e['designation'] ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              e['employee_id'] ?? '—',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}