import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.notificationsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const EmptyState(icon: Icons.notifications_none, title: "You're all caught up", message: 'New alerts about attendance, emergencies, and stock will show up here.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = items[i];
                final isRead = n['is_read'] == true;
                final type = n['type'] ?? 'info';
                final icon = type == 'absentee' ? Icons.person_off_outlined : type == 'emergency' ? Icons.warning_amber_outlined : type == 'stock' ? Icons.medication_outlined : Icons.info_outline;
                final color = type == 'stock' ? AppColors.amber : (type == 'absentee' || type == 'emergency') ? AppColors.rose : AppColors.teal;
                return AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 2),
                            const SizedBox(height: 3),
                            Text(n['message'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd MMM, hh:mm a').format(DateTime.parse(n['created_at']).toLocal()), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      if (!isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4, left: 4), decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}