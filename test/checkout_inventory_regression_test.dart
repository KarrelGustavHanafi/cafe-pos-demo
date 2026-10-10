import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/modifier.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/raw_material.dart';
import 'package:cafe_pos_demo/models/stock_adjustment.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

void main() {
  group('Checkout & Inventory Regression Tests', () {
    late PosProvider pos;

    setUp(() {
      pos = PosProvider();
    });

    // ==========================================
    // A. Checkout Totals
    // ==========================================
    test('Order subtotal matches cart subtotal', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 2);

      final cartSubtotal = pos.cartSubtotal;
      final order = pos.prepareCheckoutOrder();

      expect(order.subtotal, cartSubtotal);
      expect(order.subtotal, 50000); // 25000 * 2
    });

    test('Custom tax and service-charge rates are respected', () async {
      final customConfig = pos.businessConfig.copyWith(
        taxPercent: 12.0,
        serviceChargePercent: 8.0,
      );
      await pos.updateBusinessConfig(customConfig);

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 1);

      final order = pos.prepareCheckoutOrder();

      expect(order.tax, 3000); // 25000 * 0.12
      expect(order.serviceCharge, 2000); // 25000 * 0.08
    });

    test('Disabled tax contributes zero', () async {
      final customConfig = pos.businessConfig.copyWith(
        isTaxEnabled: false,
      );
      await pos.updateBusinessConfig(customConfig);

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 1);

      final order = pos.prepareCheckoutOrder();

      expect(order.tax, 0);
      expect(order.grandTotal, order.subtotal + order.serviceCharge);
    });

    test('Disabled service charge contributes zero', () async {
      final customConfig = pos.businessConfig.copyWith(
        isServiceEnabled: false,
      );
      await pos.updateBusinessConfig(customConfig);

      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 1);

      final order = pos.prepareCheckoutOrder();

      expect(order.serviceCharge, 0);
      expect(order.grandTotal, order.subtotal + order.tax);
    });

    test('Final order total matches expected total', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Kopi Susu',
        price: 25000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 2);

      final order = pos.prepareCheckoutOrder();

      expect(order.grandTotal, order.subtotal + order.serviceCharge + order.tax);
    });

    // ==========================================
    // B. Recipe-based Stock Deduction
    // ==========================================
    test('Checkout deducts expected quantity of each ingredient', () {
      // Find a product with a recipe
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001', // Kopi Susu Gula Aren
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        // Skip if no recipe
        return;
      }

      // Get initial stock
      final initialStocks = <String, double>{};
      for (final item in recipe.items) {
        final mat = pos.rawMaterials.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => RawMaterial(
            id: item.materialId,
            name: item.materialName,
            category: RawMaterialCategory.coffee,
            unit: item.unit,
            stock: 1000.0,
            minimumStock: 100.0,
          ),
        );
        initialStocks[item.materialId] = mat.stock;
      }

      // Add to cart and checkout
      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      // Verify stock was deducted
      for (final item in recipe.items) {
        final mat = pos.rawMaterials.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => RawMaterial(
            id: item.materialId,
            name: item.materialName,
            category: RawMaterialCategory.coffee,
            unit: item.unit,
            stock: 1000.0,
            minimumStock: 100.0,
          ),
        );
        final expectedStock = initialStocks[item.materialId]! - item.quantity;
        expect(mat.stock, closeTo(expectedStock, 0.01));
      }
    });

    test('Ordered quantity scales ingredient consumption correctly', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        return;
      }

      final ingredientId = recipe.items.first.materialId;
      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => RawMaterial(
          id: ingredientId,
          name: 'Test Material',
          category: RawMaterialCategory.coffee,
          unit: RawMaterialUnit.gram,
          stock: 1000.0,
          minimumStock: 100.0,
        ),
      );
      final initialStock = initialMat.stock;
      final requiredPerUnit = recipe.items.first.quantity;

      // Order 3 units
      pos.addToCart(product, qty: 3);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final finalMat = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => initialMat,
      );
      final expectedDeduction = requiredPerUnit * 3;
      expect(initialStock - finalMat.stock, closeTo(expectedDeduction, 0.01));
    });

    test('Modifier overrides change ingredient quantity according to rules', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        return;
      }

      // Find ingredient that can be overridden (e.g., Ice)
      final iceItem = recipe.items.firstWhere(
        (i) => i.materialId == 'MAT-010',
        orElse: () => recipe.items.first,
      );

      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == iceItem.materialId,
        orElse: () => RawMaterial(
          id: iceItem.materialId,
          name: iceItem.materialName,
          category: RawMaterialCategory.fresh,
          unit: iceItem.unit,
          stock: 1000.0,
          minimumStock: 100.0,
        ),
      );
      final initialStock = initialMat.stock;

      // Add modifier that overrides ice to 0
      final hotModifier = const ModifierOption(
        id: 'mod-hot',
        name: 'Hot (No Ice)',
        priceAdjustment: 0,
        rawMaterialOverrides: {'MAT-010': 0.0},
        rawMaterialAdditions: {},
      );

      pos.addToCart(product, qty: 1, modifiers: [hotModifier]);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final finalMat = pos.rawMaterials.firstWhere(
        (m) => m.id == iceItem.materialId,
        orElse: () => initialMat,
      );

      // Should deduct 0 instead of base quantity
      expect(initialStock - finalMat.stock, closeTo(0.0, 0.01));
    });

    test('Modifier additions increase ingredient consumption', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        return;
      }

      final coffeeItem = recipe.items.firstWhere(
        (i) => i.materialId == 'MAT-001',
        orElse: () => recipe.items.first,
      );

      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == coffeeItem.materialId,
        orElse: () => RawMaterial(
          id: coffeeItem.materialId,
          name: coffeeItem.materialName,
          category: RawMaterialCategory.coffee,
          unit: coffeeItem.unit,
          stock: 1000.0,
          minimumStock: 100.0,
        ),
      );
      final initialStock = initialMat.stock;
      final baseQuantity = coffeeItem.quantity;

      // Add modifier that adds extra coffee
      final extraShotModifier = const ModifierOption(
        id: 'mod-extra-shot',
        name: 'Extra Shot',
        priceAdjustment: 5000,
        rawMaterialOverrides: {},
        rawMaterialAdditions: {'MAT-001': 9.0},
      );

      pos.addToCart(product, qty: 1, modifiers: [extraShotModifier]);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final finalMat = pos.rawMaterials.firstWhere(
        (m) => m.id == coffeeItem.materialId,
        orElse: () => initialMat,
      );

      // Should deduct base + addition
      final expectedDeduction = baseQuantity + 9.0;
      expect(initialStock - finalMat.stock, closeTo(expectedDeduction, 0.01));
    });

    test('Menu item without recipe follows existing behavior', () {
      // Create a custom product without a recipe
      final customProduct = Product(
        id: 'PRD-CUSTOM-NO-RECIPE',
        name: 'Custom Item No Recipe',
        price: 15000,
        category: ProductCategory.snack,
        stock: 50,
        lowStockThreshold: 10,
      );

      // Get initial stock for all materials
      final initialStocks = <String, double>{};
      for (final mat in pos.rawMaterials) {
        initialStocks[mat.id] = mat.stock;
      }

      pos.addToCart(customProduct, qty: 1);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      // Verify no raw material stock was deducted (no recipe)
      for (final mat in pos.rawMaterials) {
        expect(mat.stock, initialStocks[mat.id]);
      }
    });

    // ==========================================
    // C. Shared Ingredients and Multiple Items
    // ==========================================
    test('Two different menu items using same raw material deduct combined quantity', () {
      // Find two products that share an ingredient (e.g., Coffee Beans MAT-001)
      final product1 = pos.products.firstWhere(
        (p) => p.id == 'PRD-001', // Kopi Susu
        orElse: () => pos.products.first,
      );
      final product2 = pos.products.firstWhere(
        (p) => p.id == 'PRD-002', // Americano
        orElse: () => pos.products.skip(1).first,
      );

      final recipe1 = pos.recipes[product1.id];
      final recipe2 = pos.recipes[product2.id];

      if (recipe1 == null || recipe2 == null) {
        return;
      }

      // Find shared ingredient
      String? sharedIngredientId;
      for (final item in recipe1.items) {
        if (recipe2.items.any((i) => i.materialId == item.materialId)) {
          sharedIngredientId = item.materialId;
          break;
        }
      }

      if (sharedIngredientId == null) {
        return;
      }

      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == sharedIngredientId!,
        orElse: () => RawMaterial(
          id: sharedIngredientId!,
          name: 'Shared',
          category: RawMaterialCategory.coffee,
          unit: RawMaterialUnit.gram,
          stock: 1000.0,
          minimumStock: 100.0,
        ),
      );
      final initialStock = initialMat.stock;

      // Get required quantities
      final req1 = recipe1.items.firstWhere((i) => i.materialId == sharedIngredientId).quantity;
      final req2 = recipe2.items.firstWhere((i) => i.materialId == sharedIngredientId).quantity;

      pos.addToCart(product1, qty: 1);
      pos.addToCart(product2, qty: 1);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final finalMat = pos.rawMaterials.firstWhere(
        (m) => m.id == sharedIngredientId!,
        orElse: () => initialMat,
      );

      // Should deduct combined quantity
      final expectedDeduction = req1 + req2;
      expect(initialStock - finalMat.stock, closeTo(expectedDeduction, 0.01));
    });

    test('Same product with different modifiers uses correct quantity for each', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        return;
      }

      final coffeeItem = recipe.items.firstWhere(
        (i) => i.materialId == 'MAT-001',
        orElse: () => recipe.items.first,
      );

      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == coffeeItem.materialId,
        orElse: () => RawMaterial(
          id: coffeeItem.materialId,
          name: coffeeItem.materialName,
          category: RawMaterialCategory.coffee,
          unit: coffeeItem.unit,
          stock: 1000.0,
          minimumStock: 100.0,
        ),
      );
      final initialStock = initialMat.stock;
      final baseQuantity = coffeeItem.quantity;

      // One normal, one with extra shot
      final extraShotModifier = const ModifierOption(
        id: 'mod-extra-shot',
        name: 'Extra Shot',
        priceAdjustment: 5000,
        rawMaterialOverrides: {},
        rawMaterialAdditions: {'MAT-001': 9.0},
      );

      pos.addToCart(product, qty: 1);
      pos.addToCart(product, qty: 1, modifiers: [extraShotModifier]);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final finalMat = pos.rawMaterials.firstWhere(
        (m) => m.id == coffeeItem.materialId,
        orElse: () => initialMat,
      );

      // Should deduct base + (base + addition) = 2*base + addition
      final expectedDeduction = (baseQuantity * 2) + 9.0;
      expect(initialStock - finalMat.stock, closeTo(expectedDeduction, 0.01));
    });

    test('Ingredient requirements not multiplied by item quantity more than once', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        return;
      }

      final ingredientId = recipe.items.first.materialId;
      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => RawMaterial(
          id: ingredientId,
          name: 'Test',
          category: RawMaterialCategory.coffee,
          unit: RawMaterialUnit.gram,
          stock: 1000.0,
          minimumStock: 100.0,
        ),
      );
      final initialStock = initialMat.stock;
      final requiredPerUnit = recipe.items.first.quantity;

      // Order 5 units
      pos.addToCart(product, qty: 5);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final finalMat = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => initialMat,
      );

      // Should deduct exactly: requiredPerUnit * 5 (not multiplied again)
      final expectedDeduction = requiredPerUnit * 5;
      expect(initialStock - finalMat.stock, closeTo(expectedDeduction, 0.01));
    });

    test('Fractional ingredient quantities retain current precision', () {
      // Manually set up a scenario with fractional quantities
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        return;
      }

      final ingredientId = recipe.items.first.materialId;
      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => RawMaterial(
          id: ingredientId,
          name: 'Test',
          category: RawMaterialCategory.coffee,
          unit: RawMaterialUnit.gram,
          stock: 1000.5, // Fractional initial stock
          minimumStock: 100.0,
        ),
      );
      initialMat.stock = 1000.5; // Set fractional stock

      final initialStock = initialMat.stock;
      final requiredPerUnit = recipe.items.first.quantity;

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final finalMat = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => initialMat,
      );

      // Should preserve fractional precision
      final expectedStock = initialStock - requiredPerUnit;
      expect(finalMat.stock, closeTo(expectedStock, 0.001));
    });

    // ==========================================
    // D. Repeated Checkout and Duplicate Deduction
    // ==========================================
    test('Repeated completePayment call is idempotent - no duplicate deduction', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final recipe = pos.recipes[product.id];
      if (recipe == null || recipe.items.isEmpty) {
        return;
      }

      final ingredientId = recipe.items.first.materialId;
      final initialMat = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => RawMaterial(
          id: ingredientId,
          name: 'Test',
          category: RawMaterialCategory.coffee,
          unit: RawMaterialUnit.gram,
          stock: 1000.0,
          minimumStock: 100.0,
        ),
      );
      final initialStock = initialMat.stock;
      final requiredPerUnit = recipe.items.first.quantity;

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();

      // First payment
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final stockAfterFirst = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => initialMat,
      ).stock;

      // Second payment on same order - should be idempotent
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final stockAfterSecond = pos.rawMaterials.firstWhere(
        (m) => m.id == ingredientId,
        orElse: () => initialMat,
      ).stock;

      // Verify no second deduction occurred (idempotent behavior)
      expect(initialStock - stockAfterFirst, closeTo(requiredPerUnit, 0.01));
      expect(stockAfterFirst, stockAfterSecond, reason: 'Stock should not change on second payment');
    });

    test('Finished-product stock adjustment history is recorded correctly', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      final initialStock = product.stock;
      final initialAdjustmentCount = pos.stockAdjustments.length;

      pos.addToCart(product, qty: 2);
      pos.prepareCheckoutOrder();
      final order = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      // Verify stock was deducted
      expect(product.stock, initialStock - 2);

      // Verify stock adjustment was recorded (count should increase by 1)
      expect(pos.stockAdjustments.length, greaterThan(initialAdjustmentCount));

      // Find the adjustment for this product/order
      final adjustment = pos.stockAdjustments.firstWhere(
        (adj) => adj.productId == product.id && adj.reason.contains(order.orderNumber),
      );

      expect(adjustment.productName, product.name);
      expect(adjustment.type, AdjustmentType.sale);
      expect(adjustment.quantity, 2);
      expect(adjustment.previousStock, initialStock);
      expect(adjustment.newStock, initialStock - 2);
      expect(adjustment.isRawMaterial, false, reason: 'Should be marked as finished product');
      expect(adjustment.reason, contains(order.orderNumber), reason: 'Should reference order number');
      expect(adjustment.adjustedBy, 'Sistem POS (Kasir)');
    });

    test('Finished-product stock adjustment prevents duplicate entries on retry', () {
      final product = pos.products.firstWhere(
        (p) => p.id == 'PRD-001',
        orElse: () => pos.products.first,
      );

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final adjustmentCountAfterFirst = pos.stockAdjustments.length;

      // Retry payment - should not create duplicate adjustment
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final adjustmentCountAfterSecond = pos.stockAdjustments.length;

      expect(adjustmentCountAfterSecond, adjustmentCountAfterFirst,
          reason: 'Should not create duplicate stock adjustment entries');
    });
  });
}
