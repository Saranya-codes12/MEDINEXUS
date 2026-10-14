import 'package:flutter/material.dart';
import 'dart:math';
import '../theme.dart';
import 'app_card.dart';

class HealthScoreCard extends StatelessWidget {
  final int present;
  final int absent;
  final int openEmergencies;
  final int healthyStock;
  final int totalStock;

  const HealthScoreCard({
    super.key, required this.present, required this.absent,
    required this.openEmergencies, required this.healthyStock, required this.totalStock,
  });

  int get _score {
    final totalStaff = present + absent;
    final attendanceScore = totalStaff == 0 ? 100.0 : (present / totalStaff) * 100;
    final emergencyScore = openEmergencies == 0 ? 100.0 : max(0, 100 - (openEmergencies * 20));
    final stockScore = totalStock == 0 ? 100.0 : (healthyStock / totalStock) * 100;
    return ((attendanceScore + emergencyScore + stockScore) / 3).round();
  }

  Color get _color {
    if (_score >= 80) return AppColors.vital;
    if (_score >= 55) return AppColors.amber;
    return AppColors.rose;
  }

  String get _label {
    if (_score >= 80) return 'Excellent';
    if (_score >= 55) return 'Needs Attention';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 72, height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72, height: 72,
                  child: CircularProgressIndicator(
                    value: _score / 100,
                    strokeWidth: 6,
                    backgroundColor: _color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(_color),
                  ),
                ),
                Text('$_score%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _color)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('District Health Score', style: TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(_label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _color)),
                ]),
                const SizedBox(height: 4),
                const Text('Based on attendance, emergencies & stock', style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}