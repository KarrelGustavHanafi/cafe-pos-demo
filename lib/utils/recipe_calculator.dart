import '../models/cart_item.dart';
import '../models/recipe.dart';

/// Pure utility for recipe-based ingredient calculations.
/// Does not depend on ChangeNotifier, storage, or side effects.
class RecipeCalculator {
  /// Computes the exact raw material consumption required for a CartItem
  /// taking into account base recipe, size/temperature/sugar overrides, and add-on additions.
  ///
  /// Parameters:
  /// - [item]: The cart item with product and selected modifiers
  /// - [recipe]: The product recipe containing base ingredient requirements
  ///
  /// Returns a Map mapping material ID to required quantity (scaled by item quantity).
  /// Returns an empty map if recipe is null or has no items.
  ///
  /// Calculation order:
  /// 1. Start with base recipe items
  /// 2. Apply modifier overrides (replaces base quantities)
  /// 3. Apply modifier additions (adds to quantities)
  /// 4. Multiply by item quantity
  static Map<String, double> getRequiredIngredientsForItem({
    required CartItem item,
    required ProductRecipe? recipe,
  }) {
    if (recipe == null || recipe.items.isEmpty) {
      return {};
    }

    final Map<String, double> requiredPerUnit = {};

    // 1. Base recipe items
    for (final ing in recipe.items) {
      requiredPerUnit[ing.materialId] = ing.quantity;
    }

    // 2. Modifier overrides (e.g. Large size, Hot 0g ice, Less sugar, No sugar)
    for (final mod in item.selectedModifiers) {
      if (mod.rawMaterialOverrides != null) {
        for (final entry in mod.rawMaterialOverrides!.entries) {
          requiredPerUnit[entry.key] = entry.value;
        }
      }
    }

    // 3. Modifier additions (e.g. Extra Shot +9g beans, Extra Milk +50ml milk, Extra Matcha +5g matcha)
    for (final mod in item.selectedModifiers) {
      for (final entry in mod.rawMaterialAdditions.entries) {
        requiredPerUnit[entry.key] = (requiredPerUnit[entry.key] ?? 0.0) + entry.value;
      }
    }

    // Multiply by item quantity
    return requiredPerUnit.map((matId, qty) => MapEntry(matId, qty * item.quantity));
  }

  /// Aggregates required ingredient quantities across multiple cart items.
  ///
  /// Parameters:
  /// - [items]: List of cart items
  /// - [recipes]: Map of product ID to ProductRecipe
  ///
  /// Returns a Map mapping material ID to total required quantity across all items.
  static Map<String, double> aggregateRequiredIngredients({
    required List<CartItem> items,
    required Map<String, ProductRecipe> recipes,
  }) {
    final Map<String, double> requiredTotals = {};

    for (final item in items) {
      final recipe = recipes[item.product.id];
      final itemIngredients = getRequiredIngredientsForItem(item: item, recipe: recipe);

      for (final entry in itemIngredients.entries) {
        requiredTotals[entry.key] = (requiredTotals[entry.key] ?? 0.0) + entry.value;
      }
    }

    return requiredTotals;
  }
}
