import 'package:flutter/material.dart';
import '../theme.dart';

class FilterBar extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterBar({
    super.key, required this.options, required this.labels,
    required this.selected, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final value = options[i];
          final active = selected == value;
          return GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600,
                  color: active ? AppColors.tealDark : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}