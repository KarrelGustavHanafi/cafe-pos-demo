import 'product.dart';

enum RawMaterialUnit {
  gram('gram'),
  kilogram('kg'),
  ml('ml'),
  liter('liter'),
  piece('pcs'),
  bottle('botol'),
  pack('pack');

  final String label;
  const RawMaterialUnit(this.label);
}

enum RawMaterialCategory {
  all('Semua'),
  coffee('Kopi & Teh'),
  dairy('Susu & Sirup'),
  powder('Bubuk & Cokelat'),
  fresh('Bahan Segar & Makanan'),
  packaging('Kemasan & Lainnya');

  final String label;
  const RawMaterialCategory(this.label);
}

class RawMaterial {
  final String id;
  final String name;
  final RawMaterialCategory category;
  final RawMaterialUnit unit;
  double stock;
  final double minimumStock;
  final bool isActive;

  RawMaterial({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.stock,
    required this.minimumStock,
    this.isActive = true,
  });

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= minimumStock;
  bool get isInStock => stock > minimumStock;

  StockStatus get status {
    if (isOutOfStock) return StockStatus.outOfStock;
    if (isLowStock) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  String get formattedStock {
    // Formats like 5,000 or 500
    if (stock == stock.roundToDouble()) {
      return '${stock.toInt()} ${unit.label}';
    }
    return '${stock.toStringAsFixed(1)} ${unit.label}';
  }

  String get formattedMinimumStock {
    if (minimumStock == minimumStock.roundToDouble()) {
      return '${minimumStock.toInt()} ${unit.label}';
    }
    return '${minimumStock.toStringAsFixed(1)} ${unit.label}';
  }

  RawMaterial copyWith({
    String? id,
    String? name,
    RawMaterialCategory? category,
    RawMaterialUnit? unit,
    double? stock,
    double? minimumStock,
    bool? isActive,
  }) {
    return RawMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      minimumStock: minimumStock ?? this.minimumStock,
      isActive: isActive ?? this.isActive,
    );
  }
}
