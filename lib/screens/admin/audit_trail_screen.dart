import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/supabase_service.dart';
import '../../widgets/chain_link_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});
  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  List<ChainVerificationResult>? results;
  bool loading = false;
  String filter = 'all';

  Future<void> _verify() async {
    setState(() => loading = true);
    final ledger = await SupabaseService.fetchChainLedger(eventType: filter == 'all' ? null : filter);
    final verified = SupabaseService.verifyChain(ledger);
    setState(() { results = verified; loading = false; });
  }

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  Widget build(BuildContext context) {
    final brokenCount = results?.where((r) => !r.valid).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Trail')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.tealDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.link, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Blockchain-Inspired Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Each record is cryptographically chained to the one before it. Any edit to a past record breaks the chain below.',
                    style: TextStyle(color: Color(0xFFB6E5D9), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  FilterBar(
                    options: const ['all', 'attendance', 'emergency', 'medicine_stock'],
                    labels: const ['All', 'Attendance', 'Emergency', 'Medicine'],
                    selected: filter,
                    onSelected: (v) { setState(() => filter = v); _verify(); },
                  ),
                ],
              ),
            ),
            if (results != null && results!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: brokenCount == 0 ? AppColors.vitalLight : AppColors.roseLight,
                child: Row(
                  children: [
                    Icon(brokenCount == 0 ? Icons.verified_outlined : Icons.error_outline, size: 16, color: brokenCount == 0 ? AppColors.vital : AppColors.rose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        brokenCount == 0 ? 'Chain verified — ${results!.length} records, no tampering' : '$brokenCount broken link(s) out of ${results!.length} records',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brokenCount == 0 ? AppColors.vital : AppColors.rose),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : (results == null || results!.isEmpty)
                      ? const EmptyState(
                          icon: Icons.link_off,
                          title: 'No ledger entries yet',
                          message: 'Attendance, emergency, and medicine records will appear here as a verifiable chain once they\'re logged.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                          itemCount: results!.length,
                          itemBuilder: (context, i) {
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
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(label: 'Re-run Verification', onPressed: _verify, loading: loading, icon: Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}