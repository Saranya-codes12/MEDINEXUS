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
import '../../widgets/status_badge.dart';
import '../../services/supabase_service.dart';
import '../attendance_screen.dart';
import '../patients_screen.dart';
import '../medicine_stock_screen.dart';
import '../emergency_screen.dart';
import '../notifications_screen.dart';
import '../profile_screen.dart';

class FacilityDashboardScreen extends StatefulWidget {
  const FacilityDashboardScreen({super.key});
  @override
  State<FacilityDashboardScreen> createState() => _FacilityDashboardScreenState();
}

class _FacilityDashboardScreenState extends State<FacilityDashboardScreen> {
  int tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _Overview(onNavigate: (i) => setState(() => tabIndex = i)),
      const AttendanceScreen(embedded: true),
      const PatientsScreen(embedded: true),
      const MedicineStockScreen(embedded: true),
      const EmergencyScreen(embedded: true),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediNexus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: SafeArea(child: screens[tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) => setState(() => tabIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Attend.'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Patients'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), selectedIcon: Icon(Icons.warning_amber), label: 'Emerg.'),
        ],
      ),
    );
  }
}

class _Overview extends StatefulWidget {
  final void Function(int index) onNavigate;
  const _Overview({required this.onNavigate});
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  Map<String, dynamic>? facility;
  Map<String, int> attendance = {'present': 0, 'absent': 0, 'leave': 0};
  int openEmergencies = 0;
  Map<String, int> stock = {'total': 0, 'healthy': 0, 'low': 0, 'critical': 0};
  Map<String, int> patientsToday = {'opd': 0, 'ipd': 0, 'total': 0};
  List<Map<String, dynamic>> activity = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final facilityId = auth.profile?.facilityId;
    if (facilityId == null) {
      setState(() => loading = false);
      return;
    }
    setState(() => loading = true);
    final results = await Future.wait([
      SupabaseService.fetchFacilityById(facilityId),
      SupabaseService.fetchAttendanceSummary(facilityId: facilityId),
      SupabaseService.fetchOpenEmergenciesCount(facilityId: facilityId),
      SupabaseService.fetchStockSummary(facilityId: facilityId),
      SupabaseService.fetchPatientsToday(facilityId: facilityId),
      SupabaseService.fetchRecentActivity(facilityId: facilityId),
    ]);
    if (!mounted) return;
    setState(() {
      facility = results[0] as Map<String, dynamic>?;
      attendance = results[1] as Map<String, int>;
      openEmergencies = results[2] as int;
      stock = results[3] as Map<String, int>;
      patientsToday = results[4] as Map<String, int>;
      activity = results[5] as List<Map<String, dynamic>>;
      loading = false;
    });
  }

  int get _stockAlerts => (stock['low'] ?? 0) + (stock['critical'] ?? 0);

  bool get _needsAttention => openEmergencies > 0 || (stock['critical'] ?? 0) > 0;

  String _dateLabel() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  List<Map<String, String>> get _alerts {
    final list = <Map<String, String>>[];
    if (openEmergencies > 0) {
      list.add({'text': '$openEmergencies open emergency report(s)'});
    }
    if ((stock['critical'] ?? 0) > 0) {
      list.add({'text': '${stock['critical']} medicine item(s) critically low or out of stock'});
    }
    if ((stock['low'] ?? 0) > 0) {
      list.add({'text': '${stock['low']} medicine item(s) running low'});
    }
    if ((attendance['absent'] ?? 0) > 0) {
      list.add({'text': '${attendance['absent']} doctor(s) marked absent today'});
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final statusColor = _needsAttention ? AppColors.rose : AppColors.vital;
    final alerts = _alerts;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date line (replaces the "Welcome back" greeting)
          Text(
            _dateLabel(),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: 10),

          // Facility card
          if (facility != null)
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.local_hospital, color: AppColors.teal, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (facility!['name'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            (facility!['division'] ?? '').toString(),
                            (facility!['code'] ?? '').toString(),
                          ].where((s) => s.isNotEmpty).join(' • '),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                (facility!['facility_type'] ?? '').toString().toUpperCase().replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                              ),
                            ),
                            StatusBadge(
                              label: _needsAttention ? 'Attention needed' : 'Operational',
                              fg: statusColor,
                              bg: statusColor.withValues(alpha: 0.12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Alerts first, so problems are seen immediately
          if (alerts.isNotEmpty) ...[
            const SectionHeader(title: 'Needs Attention'),
            AppCard(
              child: Column(
                children: [
                  for (int i = 0; i < alerts.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == alerts.length - 1 ? 0 : 10),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.rose),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alerts[i]['text']!,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Today's Snapshot
          const SectionHeader(title: "Today's Snapshot"),
          StatGrid(children: [
            StatCard(label: 'Doctors Present', value: '${attendance['present'] ?? 0}', icon: Icons.how_to_reg_outlined, tone: AppColors.vital, toneBg: AppColors.vitalLight),
            StatCard(label: 'Doctors Absent', value: '${attendance['absent'] ?? 0}', icon: Icons.person_off_outlined, tone: AppColors.rose, toneBg: AppColors.roseLight),
            StatCard(label: 'Patients Today', value: '${patientsToday['total'] ?? 0}', icon: Icons.groups_outlined, tone: AppColors.teal, toneBg: AppColors.tealLight),
            StatCard(label: 'Stock Alerts', value: '$_stockAlerts', icon: Icons.medication_outlined, tone: AppColors.amber, toneBg: AppColors.amberLight),
          ]),
          const SizedBox(height: 20),

          // Quick Actions (switch bottom tabs, so the nav bar stays visible)
          const SectionHeader(title: 'Quick Actions'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              QuickActionCard(icon: Icons.checklist_outlined, label: 'Attendance', subtitle: 'Mark today', color: AppColors.teal, onTap: () => widget.onNavigate(1)),
              QuickActionCard(icon: Icons.groups_outlined, label: 'Patients', subtitle: 'Log entry', color: AppColors.vital, onTap: () => widget.onNavigate(2)),
              QuickActionCard(icon: Icons.medication_outlined, label: 'Medicine', subtitle: 'Update stock', color: AppColors.amber, onTap: () => widget.onNavigate(3)),
              QuickActionCard(icon: Icons.warning_amber_outlined, label: 'Emergency', subtitle: 'Report now', color: AppColors.rose, onTap: () => widget.onNavigate(4)),
            ],
          ),
          const SizedBox(height: 20),

          // Facility Health Score
          const SectionHeader(title: 'Facility Health Score'),
          HealthScoreCard(
            present: attendance['present'] ?? 0,
            absent: attendance['absent'] ?? 0,
            openEmergencies: openEmergencies,
            healthyStock: stock['healthy'] ?? 0,
            totalStock: stock['total'] ?? 0,
          ),
          const SizedBox(height: 20),

          // Today's Activity
          const SectionHeader(title: "Today's Activity"),
          AppCard(
            child: activity.isEmpty
                ? const EmptyState(
                    icon: Icons.timeline_outlined,
                    title: 'No activity yet',
                    message: 'Attendance, stock, and emergency updates will appear here.',
                  )
                : Column(children: activity.map((a) => ActivityTile(activity: a)).toList()),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}