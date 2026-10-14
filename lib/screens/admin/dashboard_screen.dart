import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/stat_grid.dart';
import '../../widgets/section_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/health_score_card.dart';
import '../../widgets/quick_action_card.dart';
import '../../widgets/activity_tile.dart';
import '../../widgets/app_card.dart';
import '../../services/supabase_service.dart';
import 'audit_trail_screen.dart';
import '../attendance_screen.dart';
import '../patients_screen.dart';
import '../medicine_stock_screen.dart';
import '../emergency_screen.dart';
import '../notifications_screen.dart';
import '../transparency_portal_screen.dart';
import '../settings_screen.dart';
import '../profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> facilities = [];
  Map<String, int> attendance = {'present': 0, 'absent': 0, 'leave': 0};
  int openEmergencies = 0;
  Map<String, int> stock = {'total': 0, 'healthy': 0, 'low': 0, 'critical': 0};
  List<Map<String, dynamic>> activity = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final results = await Future.wait([
      SupabaseService.fetchFacilities(),
      SupabaseService.fetchAttendanceSummary(),
      SupabaseService.fetchOpenEmergenciesCount(),
      SupabaseService.fetchStockSummary(),
      SupabaseService.fetchRecentActivity(),
    ]);
    if (!mounted) return;
    setState(() {
      facilities = results[0] as List<Map<String, dynamic>>;
      attendance = results[1] as Map<String, int>;
      openEmergencies = results[2] as int;
      stock = results[3] as Map<String, int>;
      activity = results[4] as List<Map<String, dynamic>>;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final divisions = facilities.map((f) => f['division']).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('District Overview'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  context.read<AuthProvider>().signOut()),
        ],
      ),
      drawer: const _AdminDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Welcome back, ${auth.profile?.fullName.split(' ').first ?? 'District'} 👋',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Here's what's happening across your healthcare facilities today.",
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    StatGrid(children: [
                      StatCard(
                          label: 'Total Facilities',
                          value: '${facilities.length}',
                          icon: Icons.apartment_outlined,
                          tone: AppColors.teal,
                          toneBg: AppColors.tealLight),
                      StatCard(
                          label: 'Doctors Present',
                          value: '${attendance['present']}',
                          icon: Icons.how_to_reg_outlined,
                          tone: AppColors.vital,
                          toneBg: AppColors.vitalLight),
                      StatCard(
                          label: 'Doctors Absent',
                          value: '${attendance['absent']}',
                          icon: Icons.person_off_outlined,
                          tone: AppColors.rose,
                          toneBg: AppColors.roseLight),
                      StatCard(
                          label: 'Emergency Alerts',
                          value: '$openEmergencies',
                          icon: Icons.warning_amber_outlined,
                          tone: AppColors.amber,
                          toneBg: AppColors.amberLight),
                    ]),
                    const SizedBox(height: 16),
                    HealthScoreCard(
                      present: attendance['present'] ?? 0,
                      absent: attendance['absent'] ?? 0,
                      openEmergencies: openEmergencies,
                      healthyStock: stock['healthy'] ?? 0,
                      totalStock: stock['total'] ?? 0,
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Quick Actions'),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.9,
                      children: [
                        QuickActionCard(
                            icon: Icons.checklist_outlined,
                            label: 'Attendance',
                            subtitle: 'Monitor doctors',
                            color: AppColors.teal,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AttendanceScreen()))),
                        QuickActionCard(
                            icon: Icons.warning_amber_outlined,
                            label: 'Emergency',
                            subtitle: 'View alerts',
                            color: AppColors.rose,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const EmergencyScreen()))),
                        QuickActionCard(
                            icon: Icons.medication_outlined,
                            label: 'Medicines',
                            subtitle: 'Stock status',
                            color: AppColors.amber,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const MedicineStockScreen()))),
                        QuickActionCard(
                            icon: Icons.groups_outlined,
                            label: 'Patients',
                            subtitle: 'Patient records',
                            color: AppColors.vital,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PatientsScreen()))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(
                        title: 'Facilities by Division',
                        trailing: Text(
                            '${facilities.length} across $divisions divisions',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted))),
                    if (facilities.isEmpty)
                      const EmptyState(
                          icon: Icons.apartment_outlined,
                          title: 'No facilities yet',
                          message:
                              'Facilities added in Supabase will appear here.')
                    else
                      ...facilities.map((f) => AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color: AppColors.tealLight,
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  child: const Icon(
                                      Icons.local_hospital,
                                      color: AppColors.teal,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(f['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(f['division'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                            color:
                                                const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    999)),
                                        child: Text(
                                          (f['facility_type'] ?? '')
                                              .toString()
                                              .toUpperCase()
                                              .replaceAll('_', ' '),
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.muted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    size: 18, color: AppColors.muted),
                              ],
                            ),
                          )),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Facility Status'),
                    AppCard(
                      child: Column(
                        children: [
                          _statusRow(
                              'Healthy',
                              facilities.length -
                                  (openEmergencies > 0 ? 1 : 0),
                              AppColors.vital),
                          const Divider(height: 20),
                          _statusRow(
                              'Needs Review',
                              (stock['low'] ?? 0) > 0 ? 1 : 0,
                              AppColors.amber),
                          const Divider(height: 20),
                          _statusRow(
                              'Critical',
                              openEmergencies > 0 ? 1 : 0,
                              AppColors.rose),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Recent Activity'),
                    AppCard(
                      child: activity.isEmpty
                          ? const Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 12),
                              child: Text('No recent activity',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.muted)))
                          : Column(
                              children: activity
                                  .map((a) =>
                                      ActivityTile(activity: a))
                                  .toList()),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _statusRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
        Text('$count',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.monitor_heart_outlined,
                        color: Colors.white, size: 18)),
                const SizedBox(width: 10),
                const Text('MediNexus',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ),
            const Divider(height: 1),
            _tile(context, Icons.dashboard_outlined, 'Overview',
                () => Navigator.pop(context)),
            _tile(context, Icons.link, 'Attendance Audit Trail',
                () => _push(context, const AuditTrailScreen())),
            _tile(context, Icons.checklist_outlined, 'Attendance',
                () => _push(context, const AttendanceScreen())),
            _tile(context, Icons.groups_outlined, 'Patients',
                () => _push(context, const PatientsScreen())),
            _tile(context, Icons.medication_outlined, 'Medicine Stock',
                () => _push(context, const MedicineStockScreen())),
            _tile(context, Icons.warning_amber_outlined, 'Emergency',
                () => _push(context, const EmergencyScreen())),
            _tile(context, Icons.notifications_outlined, 'Notifications',
                () => _push(context, const NotificationsScreen())),
            _tile(context, Icons.public, 'Transparency Portal',
                () => _push(context, const TransparencyPortalScreen())),
            const Divider(height: 1),
            _tile(context, Icons.settings_outlined, 'Settings',
                () => _push(context, const SettingsScreen())),
            _tile(context, Icons.person_outline, 'Profile',
                () => _push(context, const ProfileScreen())),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
        leading: Icon(icon, size: 20, color: AppColors.muted),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        onTap: onTap);
  }
}