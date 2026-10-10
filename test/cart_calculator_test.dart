import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_pos_demo/models/cart_item.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/modifier.dart';
import 'package:cafe_pos_demo/utils/cart_calculator.dart';

void main() {
  group('CartCalculator Tests', () {
    test('Empty cart', () {
      final totals = CartCalculator.calculate(
        items: [],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: true,
      );

      expect(totals.subtotal, 0);
      expect(totals.serviceCharge, 0);
      expect(totals.tax, 0);
      expect(totals.grandTotal, 0);
    });

    test('Subtotal with multiple items and quantities', () {
      final product1 = Product(
        id: 'PRD-001',
        name: 'Product 1',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final product2 = Product(
        id: 'PRD-002',
        name: 'Product 2',
        price: 15000,
        category: ProductCategory.coffee,
      );

      final items = [
        CartItem(product: product1, quantity: 2),
        CartItem(product: product2, quantity: 1),
      ];

      final totals = CartCalculator.calculate(
        items: items,
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: false,
        isServiceEnabled: false,
      );

      expect(totals.subtotal, 35000); // (10000 * 2) + (15000 * 1)
      expect(totals.serviceCharge, 0);
      expect(totals.tax, 0);
      expect(totals.grandTotal, 35000);
    });

    test('Tax enabled with a custom rate', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.12,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: false,
      );

      expect(totals.subtotal, 20000);
      expect(totals.serviceCharge, 0);
      expect(totals.tax, 2400); // 20000 * 0.12
      expect(totals.grandTotal, 22400);
    });

    test('Service charge enabled with a custom rate', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.07,
        isTaxEnabled: false,
        isServiceEnabled: true,
      );

      expect(totals.subtotal, 20000);
      expect(totals.serviceCharge, 1400); // 20000 * 0.07
      expect(totals.tax, 0);
      expect(totals.grandTotal, 21400);
    });

    test('Tax disabled', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: false,
        isServiceEnabled: true,
      );

      expect(totals.subtotal, 20000);
      expect(totals.serviceCharge, 1000); // 20000 * 0.05
      expect(totals.tax, 0); // Disabled
      expect(totals.grandTotal, 21000);
    });

    test('Service charge disabled', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: false,
      );

      expect(totals.subtotal, 20000);
      expect(totals.serviceCharge, 0); // Disabled
      expect(totals.tax, 2000); // 20000 * 0.10
      expect(totals.grandTotal, 22000);
    });

    test('Both charges disabled', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: false,
        isServiceEnabled: false,
      );

      expect(totals.subtotal, 20000);
      expect(totals.serviceCharge, 0); // Disabled
      expect(totals.tax, 0); // Disabled
      expect(totals.grandTotal, 20000);
    });

    test('Both charges enabled with custom rates', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.12,
        serviceChargeRate: 0.07,
        isTaxEnabled: true,
        isServiceEnabled: true,
      );

      expect(totals.subtotal, 20000);
      expect(totals.serviceCharge, 1400); // 20000 * 0.07
      expect(totals.tax, 2400); // 20000 * 0.12
      expect(totals.grandTotal, 23800);
    });

    test('Rounding behavior', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 3333,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 3);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: true,
      );

      expect(totals.subtotal, 9999);
      expect(totals.serviceCharge, 500); // 9999 * 0.05 = 499.95 -> round to 500
      expect(totals.tax, 1000); // 9999 * 0.10 = 999.9 -> round to 1000
      expect(totals.grandTotal, 11499); // 9999 + 500 + 1000
    });

    test('Grand total consistency', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: true,
      );

      expect(totals.grandTotal, totals.subtotal + totals.serviceCharge + totals.tax);
    });

    test('Inputs remain unchanged after calculation', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);
      final originalQuantity = item.quantity;
      final originalNotes = item.notes;

      CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: true,
      );

      expect(item.quantity, originalQuantity);
      expect(item.notes, originalNotes);
      expect(item.product.price, 10000);
    });

    test('Subtotal with modifiers included', () {
      final modifier = const ModifierOption(
        id: 'mod-001',
        name: 'Extra Shot',
        priceAdjustment: 5000,
      );
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(
        product: product,
        quantity: 1,
        selectedModifiers: [modifier],
      );

      final totals = CartCalculator.calculate(
        items: [item],
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: true,
      );

      expect(totals.subtotal, 15000); // 10000 + 5000
      expect(totals.serviceCharge, 750); // 15000 * 0.05
      expect(totals.tax, 1500); // 15000 * 0.10
      expect(totals.grandTotal, 17250); // 15000 + 750 + 1500
    });
  });
}
