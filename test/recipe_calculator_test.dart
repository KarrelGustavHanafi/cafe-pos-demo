import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_pos_demo/models/cart_item.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/modifier.dart';
import 'package:cafe_pos_demo/models/recipe.dart';
import 'package:cafe_pos_demo/models/raw_material.dart';
import 'package:cafe_pos_demo/utils/recipe_calculator.dart';

void main() {
  group('RecipeCalculator Tests', () {
    test('Single recipe ingredient requirement', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 1);

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result.length, 1);
      expect(result['MAT-001'], 18.0);
    });

    test('Quantity scaling for multiple ordered units', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 3);

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result['MAT-001'], 54.0); // 18.0 * 3
    });

    test('Multiple ingredients in one recipe', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
          const RecipeItem(
            materialId: 'MAT-002',
            materialName: 'UHT Milk',
            quantity: 120.0,
            unit: RawMaterialUnit.ml,
          ),
          const RecipeItem(
            materialId: 'MAT-003',
            materialName: 'Palm Sugar',
            quantity: 25.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 1);

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result.length, 3);
      expect(result['MAT-001'], 18.0);
      expect(result['MAT-002'], 120.0);
      expect(result['MAT-003'], 25.0);
    });

    test('Fractional ingredient quantities', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.5,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result['MAT-001'], 37.0); // 18.5 * 2
    });

    test('Modifier overrides replace base quantities', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-010',
            materialName: 'Ice',
            quantity: 100.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final modifier = const ModifierOption(
        id: 'mod-hot',
        name: 'Hot (No Ice)',
        priceAdjustment: 0,
        rawMaterialOverrides: {'MAT-010': 0.0},
        rawMaterialAdditions: {},
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(
        product: product,
        quantity: 1,
        selectedModifiers: [modifier],
      );

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result['MAT-010'], 0.0); // Overridden to 0
    });

    test('Modifier additions add to base quantities', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final modifier = const ModifierOption(
        id: 'mod-extra-shot',
        name: 'Extra Shot',
        priceAdjustment: 5000,
        rawMaterialOverrides: {},
        rawMaterialAdditions: {'MAT-001': 9.0},
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(
        product: product,
        quantity: 1,
        selectedModifiers: [modifier],
      );

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result['MAT-001'], 27.0); // 18.0 + 9.0
    });

    test('Multiple modifiers with overrides and additions', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
          const RecipeItem(
            materialId: 'MAT-010',
            materialName: 'Ice',
            quantity: 100.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final hotModifier = const ModifierOption(
        id: 'mod-hot',
        name: 'Hot (No Ice)',
        priceAdjustment: 0,
        rawMaterialOverrides: {'MAT-010': 0.0},
        rawMaterialAdditions: {},
      );

      final extraShotModifier = const ModifierOption(
        id: 'mod-extra-shot',
        name: 'Extra Shot',
        priceAdjustment: 5000,
        rawMaterialOverrides: {},
        rawMaterialAdditions: {'MAT-001': 9.0},
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(
        product: product,
        quantity: 1,
        selectedModifiers: [hotModifier, extraShotModifier],
      );

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result['MAT-001'], 27.0); // 18.0 + 9.0
      expect(result['MAT-010'], 0.0); // Overridden to 0
    });

    test('Empty input (null recipe)', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 1);

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: null,
      );

      expect(result, isEmpty);
    });

    test('Empty input (recipe with no items)', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [],
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 1);

      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result, isEmpty);
    });

    test('Aggregation across multiple order items', () {
      final recipe1 = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final recipe2 = ProductRecipe(
        productId: 'PRD-002',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product1 = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final product2 = Product(
        id: 'PRD-002',
        name: 'Americano',
        price: 20000,
        category: ProductCategory.coffee,
      );

      final items = [
        CartItem(product: product1, quantity: 2),
        CartItem(product: product2, quantity: 1),
      ];

      final recipes = {
        'PRD-001': recipe1,
        'PRD-002': recipe2,
      };

      final result = RecipeCalculator.aggregateRequiredIngredients(
        items: items,
        recipes: recipes,
      );

      expect(result['MAT-001'], 54.0); // (18.0 * 2) + (18.0 * 1)
    });

    test('Multiple recipes requiring the same ingredient', () {
      final recipe1 = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final recipe2 = ProductRecipe(
        productId: 'PRD-002',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product1 = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final product2 = Product(
        id: 'PRD-002',
        name: 'Americano',
        price: 20000,
        category: ProductCategory.coffee,
      );

      final items = [
        CartItem(product: product1, quantity: 2),
        CartItem(product: product2, quantity: 3),
      ];

      final recipes = {
        'PRD-001': recipe1,
        'PRD-002': recipe2,
      };

      final result = RecipeCalculator.aggregateRequiredIngredients(
        items: items,
        recipes: recipes,
      );

      expect(result['MAT-001'], 90.0); // (18.0 * 2) + (18.0 * 3)
    });

    test('Input immutability - item not mutated', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);
      final originalQuantity = item.quantity;

      RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(item.quantity, originalQuantity);
    });

    test('Input immutability - recipe not mutated', () {
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final originalItemCount = recipe.items.length;

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 1);

      RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(recipe.items.length, originalItemCount);
    });

    test('Regression - calculator does not mutate inventory state', () {
      // This test confirms the calculator is pure and doesn't depend on or mutate state
      final recipe = ProductRecipe(
        productId: 'PRD-001',
        items: [
          const RecipeItem(
            materialId: 'MAT-001',
            materialName: 'Coffee Beans',
            quantity: 18.0,
            unit: RawMaterialUnit.gram,
          ),
        ],
      );

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 1);

      // Calculator should work without any inventory state
      final result = RecipeCalculator.getRequiredIngredientsForItem(
        item: item,
        recipe: recipe,
      );

      expect(result['MAT-001'], 18.0);
      // No state was accessed or mutated
    });
  });
}
