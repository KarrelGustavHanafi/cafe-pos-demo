enum AdjustmentType {
  add('Tambah Stok'),
  remove('Kurangi Stok'),
  set('Setel Stok'),
  sale('Penjualan Kasir');

  final String label;
  const AdjustmentType(this.label);
}

class StockAdjustment {
  final String id;
  final String productId;
  final String productName;
  final AdjustmentType type;
  final num quantity;
  final num previousStock;
  final num newStock;
  final String reason;
  final DateTime timestamp;
  final String adjustedBy;
  final String unit;
  final bool isRawMaterial;

  const StockAdjustment({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    required this.reason,
    required this.timestamp,
    this.adjustedBy = 'Owner',
    this.unit = 'unit',
    this.isRawMaterial = false,
  });

  String get formattedQuantity {
    final prefix = type == AdjustmentType.add
        ? '+'
        : (type == AdjustmentType.remove || type == AdjustmentType.sale ? '-' : '=');
    final formattedVal = quantity == quantity.roundToDouble()
        ? '${quantity.toInt()}'
        : quantity.toStringAsFixed(1);
    return '$prefix$formattedVal $unit';
  }

  String get formattedChange {
    final prevStr = previousStock == previousStock.roundToDouble()
        ? '${previousStock.toInt()}'
        : previousStock.toStringAsFixed(1);
    final newStr = newStock == newStock.roundToDouble()
        ? '${newStock.toInt()}'
        : newStock.toStringAsFixed(1);
    return '$prevStr → $newStr $unit';
  }
}
