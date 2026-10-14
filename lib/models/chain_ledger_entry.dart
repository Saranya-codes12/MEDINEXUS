/// Represents one link in the blockchain-inspired tamper-evident ledger.
/// Covers attendance, emergency, and medicine-provenance events in one shared table.
class ChainLedgerEntry {
  final String id;
  final String eventType; // 'attendance' | 'emergency' | 'medicine_stock'
  final String referenceId;
  final String recordHash;
  final String? previousHash;
  final DateTime createdAt;
  final String facilityId;
  final String summary;

  ChainLedgerEntry({
    required this.id, required this.eventType, required this.referenceId,
    required this.recordHash, this.previousHash, required this.createdAt,
    required this.facilityId, required this.summary,
  });

  factory ChainLedgerEntry.fromMap(Map<String, dynamic> map) => ChainLedgerEntry(
    id: map['id'], eventType: map['event_type'], referenceId: map['reference_id'],
    recordHash: map['record_hash'], previousHash: map['previous_hash'],
    createdAt: DateTime.parse(map['created_at']), facilityId: map['facility_id'],
    summary: map['summary'] ?? '',
  );
}
