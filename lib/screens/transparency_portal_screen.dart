import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import '../widgets/chain_link_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

class TransparencyPortalScreen extends StatefulWidget {
  const TransparencyPortalScreen({super.key});
  @override
  State<TransparencyPortalScreen> createState() => _TransparencyPortalScreenState();
}

class _TransparencyPortalScreenState extends State<TransparencyPortalScreen> {
  final codeCtrl = TextEditingController();
  List<ChainVerificationResult>? results;
  bool loading = false;
  bool searched = false;

  Future<void> _lookup() async {
    if (codeCtrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { loading = true; searched = true; });
    final ledger = await SupabaseService.fetchPublicLedgerForFacility(codeCtrl.text.trim());
    final verified = SupabaseService.verifyChain(ledger);
    setState(() { results = verified; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final brokenCount = results?.where((r) => !r.valid).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Transparency Portal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.public, color: AppColors.teal),
                    SizedBox(width: 8),
                    Expanded(child: Text('Independent Verification', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'No login required. Enter any facility code to verify its records against the tamper-evident hash-chain.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Facility Code', hintText: 'e.g. PHC-AN-01')),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Verify Facility Records', onPressed: _lookup, loading: loading, icon: Icons.search),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (searched && !loading && (results == null || results!.isEmpty))
              const EmptyState(icon: Icons.search_off, title: 'No records found', message: 'Double check the facility code and try again.'),
            if (results != null && results!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: brokenCount == 0 ? AppColors.vitalLight : AppColors.roseLight, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  brokenCount == 0 ? 'All ${results!.length} records verified' : '$brokenCount broken link(s) found',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brokenCount == 0 ? AppColors.vital : AppColors.rose),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(results!.length, (i) {
                final r = results![i];
                final entry = r.entry;
                final hash = (entry['record_hash'] as String? ?? '');
                return ChainLinkCard(
                  title: entry['summary'] ?? entry['event_type'] ?? 'Ledger entry',
                  subtitle: entry['event_type'] ?? '',
                  timestamp: DateTime.parse(entry['created_at']).toLocal(),
                  hashPreview: hash.length > 16 ? hash.substring(0, 16) : hash,
                  valid: r.valid,
                  isFirst: i == 0,
                  isLast: i == results!.length - 1,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}