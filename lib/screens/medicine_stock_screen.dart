import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_header.dart';
import '../widgets/empty_state.dart';

class MedicineStockScreen extends StatefulWidget {
  final bool embedded;
  const MedicineStockScreen({super.key, this.embedded = false});
  @override
  State<MedicineStockScreen> createState() => _MedicineStockScreenState();
}

class _MedicineStockScreenState extends State<MedicineStockScreen> {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final reorderCtrl = TextEditingController();
  String movementType = 'received';
  bool submitting = false;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.profile?.facilityId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await SupabaseService.addStockMovement({
        'facility_id': auth.profile!.facilityId,
        'medicine_name': nameCtrl.text,
        'quantity': int.tryParse(qtyCtrl.text) ?? 0,
        'reorder_level': int.tryParse(reorderCtrl.text) ?? 0,
        'movement_type': movementType,
        'updated_by': auth.profile!.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock entry saved'), backgroundColor: AppColors.vital));
        nameCtrl.clear(); qtyCtrl.clear(); reorderCtrl.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.rose));
    }
    if (mounted) setState(() => submitting = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'low': return AppColors.amber;
      case 'critical': return AppColors.rose;
      case 'out_of_stock': return AppColors.rose;
      default: return AppColors.vital;
    }
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
                Text('Add / Update Stock', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Medicine Name', hintText: 'Paracetamol 500mg')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: reorderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder Level'))),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: movementType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Movement Type'),
                  items: const [
                    DropdownMenuItem(value: 'received', child: Text('Received')),
                    DropdownMenuItem(value: 'distributed', child: Text('Distributed')),
                    DropdownMenuItem(value: 'dispensed', child: Text('Dispensed')),
                  ],
                  onChanged: (v) => setState(() => movementType = v ?? 'received'),
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: submitting ? 'Saving…' : 'Save Stock Movement', onPressed: _submit, loading: submitting, icon: Icons.inventory_2_outlined),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const SectionHeader(title: 'Inventory'),
        if (auth.profile?.facilityId != null)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.medicineStockStream(auth.profile!.facilityId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const EmptyState(icon: Icons.medication_outlined, title: 'No stock entries yet', message: 'Medicine received, distributed, or dispensed will appear here.');
              }
              return Column(
                children: items.map((item) {
                  final status = item['status'] ?? 'adequate';
                  final color = _statusColor(status);
                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['medicine_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text('${item['quantity']} units · reorder at ${item['reorder_level']}', style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: status.toString().replaceAll('_', ' '), fg: color, bg: color.withValues(alpha: 0.12)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          )
        else
          const EmptyState(icon: Icons.apartment_outlined, title: 'Select a facility', message: 'Choose a facility to view its inventory.'),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Medicine Stock')), body: SafeArea(child: body));
  }
}