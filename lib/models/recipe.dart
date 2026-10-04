import 'raw_material.dart';

class RecipeItem {
  final String materialId;
  final String materialName;
  final double quantity;
  final RawMaterialUnit unit;

  const RecipeItem({
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unit,
  });

  RecipeItem copyWith({
    String? materialId,
    String? materialName,
    double? quantity,
    RawMaterialUnit? unit,
  }) {
    return RecipeItem(
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }

  String get formattedQuantity {
    if (quantity == quantity.roundToDouble()) {
      return '${quantity.toInt()} ${unit.label}';
    }
    return '${quantity.toStringAsFixed(1)} ${unit.label}';
  }
}

class ProductRecipe {
  final String productId;
  final List<RecipeItem> items;

  ProductRecipe({
    required this.productId,
    required this.items,
  });

  ProductRecipe copyWith({
    String? productId,
    List<RecipeItem>? items,
  }) {
    return ProductRecipe(
      productId: productId ?? this.productId,
      items: items ?? List.from(this.items),
    );
  }
}
