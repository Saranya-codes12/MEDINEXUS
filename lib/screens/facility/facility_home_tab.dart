import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

/// Home tab for facility users.
/// Self-contained: only depends on Flutter + SupabaseService.
///
/// [onNavigate] receives the bottom-nav index:
/// 0 Home, 1 Attendance, 2 Patients, 3 Stock, 4 Emergency.
class FacilityHomeTab extends StatefulWidget {
  final void Function(int index)? onNavigate;

  const FacilityHomeTab({super.key, this.onNavigate});

  @override
  State<FacilityHomeTab> createState() => _FacilityHomeTabState();
}

class _FacilityHomeTabState extends State<FacilityHomeTab> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _facility;
  Map<String, int> _attendance = {'present': 0, 'absent': 0, 'leave': 0};
  Map<String, int> _patients = {'opd': 0, 'ipd': 0, 'total': 0};
  Map<String, int> _stock = {'total': 0, 'healthy': 0, 'low': 0, 'critical': 0};
  int _openEmergencies = 0;
  List<Map<String, dynamic>> _activity = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = SupabaseService.currentUser;
      if (user == null) throw Exception('Not signed in');

      final profile = await SupabaseService.fetchProfile(user.id);
      final facilityId = profile?['facility_id']?.toString();
      if (facilityId == null) throw Exception('No facility linked to this user');

      final results = await Future.wait([
        SupabaseService.fetchFacilityById(facilityId),
        SupabaseService.fetchAttendanceSummary(facilityId: facilityId),
        SupabaseService.fetchPatientsToday(facilityId: facilityId),
        SupabaseService.fetchStockSummary(facilityId: facilityId),
        SupabaseService.fetchOpenEmergenciesCount(facilityId: facilityId),
        SupabaseService.fetchRecentActivity(facilityId: facilityId, limit: 6),
      ]);

      if (!mounted) return;
      setState(() {
        _facility = results[0] as Map<String, dynamic>?;
        _attendance = results[1] as Map<String, int>;
        _patients = results[2] as Map<String, int>;
        _stock = results[3] as Map<String, int>;
        _openEmergencies = results[4] as int;
        _activity = results[5] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _dateLabel() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  bool get _needsAttention => _openEmergencies > 0 || (_stock['critical'] ?? 0) > 0;

  int get _stockAlerts => (_stock['low'] ?? 0) + (_stock['critical'] ?? 0);

  String _timeAgo(dynamic value) {
    if (value == null) return '';
    final t = DateTime.tryParse(value.toString())?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          const pad = 16.0;
          final inner = constraints.maxWidth - pad * 2;
          final cols = constraints.maxWidth >= 900 ? 4 : 2;
          final tileWidth = (inner - gap * (cols - 1)) / cols;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(pad),
            children: [
              _facilityHeader(context),
              const SizedBox(height: 20),
              _sectionTitle(context, "Today's Snapshot"),
              const SizedBox(height: 10),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _statTile(context, tileWidth, Icons.how_to_reg, '${_attendance['present']}', 'Doctors Present', Colors.green),
                  _statTile(context, tileWidth, Icons.person_off, '${_attendance['absent']}', 'Doctors Absent', Colors.red),
                  _statTile(context, tileWidth, Icons.groups, '${_patients['total']}', 'Patients Today', Colors.teal),
                  _statTile(context, tileWidth, Icons.medication, '$_stockAlerts', 'Stock Alerts', Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Quick Actions'),
              const SizedBox(height: 10),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _actionTile(context, tileWidth, Icons.checklist, 'Attendance', 'Mark today', 1),
                  _actionTile(context, tileWidth, Icons.groups, 'Patients', 'Log entry', 2),
                  _actionTile(context, tileWidth, Icons.inventory_2, 'Stock', 'Update medicines', 3),
                  _actionTile(context, tileWidth, Icons.warning_amber_rounded, 'Emergency', 'Report / view', 4),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Recent Activity'),
              const SizedBox(height: 10),
              _activityList(context),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _facilityHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _facility?['name']?.toString() ?? 'Your facility';
    final division = _facility?['division']?.toString() ?? '';
    final type = _facility?['facility_type']?.toString() ?? '';
    final code = _facility?['code']?.toString() ?? '';

    final badgeColor = _needsAttention ? Colors.red : Colors.green;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.local_hospital, color: cs.primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [division, if (code.isNotEmpty) code].where((s) => s.isNotEmpty).join(' • '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (type.isNotEmpty) _chip(type, cs.onSurface.withValues(alpha: 0.08), cs.onSurface),
                      _chip(
                        _needsAttention ? 'Attention needed' : 'All good',
                        badgeColor.withValues(alpha: 0.12),
                        badgeColor.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_dateLabel(), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statTile(BuildContext context, double width, IconData icon, String value, String label, MaterialColor color) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 116,
      child: Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color.shade700),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context, double width, IconData icon, String title, String subtitle, int index) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 92,
      child: Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onNavigate?.call(index),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_activity.isEmpty) {
      return Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No activity yet')),
        ),
      );
    }

    IconData iconFor(String kind) {
      switch (kind) {
        case 'attendance':
          return Icons.how_to_reg;
        case 'emergency':
          return Icons.warning_amber_rounded;
        case 'stock':
          return Icons.medication;
        default:
          return Icons.circle;
      }
    }

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          for (int i = 0; i < _activity.length; i++) ...[
            ListTile(
              leading: Icon(iconFor(_activity[i]['kind']?.toString() ?? ''), color: cs.primary),
              title: Text(_activity[i]['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(_timeAgo(_activity[i]['time']), style: Theme.of(context).textTheme.bodySmall),
            ),
            if (i < _activity.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}