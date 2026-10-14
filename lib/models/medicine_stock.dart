enum StockStatus { adequate, low, critical, outOfStock }

StockStatus stockStatusFromString(String s) {
  switch (s) {
    case 'low': return StockStatus.low;
    case 'critical': return StockStatus.critical;
    case 'out_of_stock': return StockStatus.outOfStock;
    default: return StockStatus.adequate;
  }
}

class MedicineStockItem {
  final String id;
  final String facilityId;
  final String medicineName;
  final int quantity;
  final int reorderLevel;
  final StockStatus status;
  final String? recordHash;
  final String? previousHash;
  final String? movementType;

  MedicineStockItem({
    required this.id, required this.facilityId, required this.medicineName,
    required this.quantity, required this.reorderLevel, required this.status,
    this.recordHash, this.previousHash, this.movementType,
  });

  factory MedicineStockItem.fromMap(Map<String, dynamic> map) => MedicineStockItem(
    id: map['id'], facilityId: map['facility_id'], medicineName: map['medicine_name'],
    quantity: map['quantity'] ?? 0, reorderLevel: map['reorder_level'] ?? 0,
    status: stockStatusFromString(map['status']),
    recordHash: map['record_hash'], previousHash: map['previous_hash'],
    movementType: map['movement_type'],
  );
}
