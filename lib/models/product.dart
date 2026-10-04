import 'modifier.dart';

enum ProductCategory {
  all('Semua'),
  coffee('Kopi'),
  nonCoffee('Non-Kopi'),
  food('Makanan'),
  snack('Camilan'),
  dessert('Dessert'),
  pastry('Pastry');

  final String label;
  const ProductCategory(this.label);
}

enum StockStatus {
  inStock('IN STOCK'),
  lowStock('LOW STOCK'),
  outOfStock('OUT OF STOCK');

  final String label;
  const StockStatus(this.label);
}

class Product {
  final String id;
  final String name;
  final int price;
  final int costPrice; // HPP (Harga Pokok Penjualan)
  final ProductCategory category;
  int stock;
  final int lowStockThreshold;
  final String description;
  final String imageUrl;
  final String iconName;
  final bool isActive;
  final String sku;
  final List<ModifierGroup> modifierGroups;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0,
    required this.category,
    this.stock = 50,
    this.lowStockThreshold = 15,
    this.description = '',
    this.imageUrl = '',
    this.iconName = 'coffee',
    this.isActive = true,
    this.sku = '',
    this.modifierGroups = const [],
  });

  bool get hasModifiers => modifierGroups.any((g) => g.isEnabled);
  List<ModifierGroup> get activeModifierGroups => modifierGroups.where((g) => g.isEnabled).toList();

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= lowStockThreshold;
  bool get isInStock => stock > lowStockThreshold;

  StockStatus get stockStatus {
    if (isOutOfStock) return StockStatus.outOfStock;
    if (isLowStock) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  Product copyWith({
    String? id,
    String? name,
    int? price,
    int? costPrice,
    ProductCategory? category,
    int? stock,
    int? lowStockThreshold,
    String? description,
    String? imageUrl,
    String? iconName,
    bool? isActive,
    String? sku,
    List<ModifierGroup>? modifierGroups,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      iconName: iconName ?? this.iconName,
      isActive: isActive ?? this.isActive,
      sku: sku ?? this.sku,
      modifierGroups: modifierGroups ?? this.modifierGroups,
    );
  }
}
