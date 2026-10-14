import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class ChainLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String hashPreview;
  final bool valid;
  final bool isFirst;
  final bool isLast;

  const ChainLinkCard({
    super.key, required this.title, required this.subtitle, required this.timestamp,
    required this.hashPreview, required this.valid, this.isFirst = false, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = valid ? AppColors.vital : AppColors.rose;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : lineColor.withValues(alpha: 0.4))),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: valid ? AppColors.vitalLight : AppColors.roseLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: lineColor, width: 1.5),
                  ),
                  child: Icon(valid ? Icons.link : Icons.link_off, size: 12, color: lineColor),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : lineColor.withValues(alpha: 0.4))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: valid ? const Color(0xFFE3E8EF) : AppColors.rose.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8, runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
                          child: Text(title, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis, maxLines: 2),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: valid ? AppColors.vitalLight : AppColors.roseLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            valid ? 'Verified' : 'Broken link',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: valid ? AppColors.vital : AppColors.rose),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(DateFormat('dd MMM yyyy, hh:mm a').format(timestamp), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text('hash: $hashPreview…', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.muted), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}