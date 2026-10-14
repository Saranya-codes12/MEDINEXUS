import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  const ActivityTile({super.key, required this.activity});

  IconData get _icon {
    switch (activity['kind']) {
      case 'attendance': return Icons.checklist_outlined;
      case 'emergency': return Icons.warning_amber_outlined;
      case 'stock': return Icons.medication_outlined;
      default: return Icons.info_outline;
    }
  }

  Color get _color {
    switch (activity['kind']) {
      case 'attendance': return activity['status'] == 'absent' ? AppColors.rose : AppColors.vital;
      case 'emergency': return AppColors.rose;
      case 'stock': return AppColors.amber;
      default: return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = activity['time'] != null ? DateTime.tryParse(activity['time'])?.toLocal() : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(_icon, size: 15, color: _color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 2),
                if (time != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(DateFormat('dd MMM, hh:mm a').format(time), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}