import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/cart_item.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/modifier.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

void main() {
  group('Order Calculation Tests', () {
    test('Order.create() with default rates (10% tax, 5% service charge)', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final order = Order.create(
        orderNumber: 'ORD-TEST-001',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.10,
        serviceChargeRate: 0.05,
      );

      expect(order.subtotal, 20000);
      expect(order.serviceCharge, 1000); // 20000 * 0.05
      expect(order.tax, 2000); // 20000 * 0.10
      expect(order.grandTotal, 23000); // 20000 + 1000 + 2000
    });

    test('Order.create() with custom rates (11% tax, 6% service charge)', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final order = Order.create(
        orderNumber: 'ORD-TEST-002',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.11,
        serviceChargeRate: 0.06,
      );

      expect(order.subtotal, 20000);
      expect(order.serviceCharge, 1200); // 20000 * 0.06
      expect(order.tax, 2200); // 20000 * 0.11
      expect(order.grandTotal, 23400); // 20000 + 1200 + 2200
    });

    test('Order.create() with zero tax and service charge', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final order = Order.create(
        orderNumber: 'ORD-TEST-003',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.0,
        serviceChargeRate: 0.0,
      );

      expect(order.subtotal, 20000);
      expect(order.serviceCharge, 0);
      expect(order.tax, 0);
      expect(order.grandTotal, 20000);
    });

    test('Order.create() with modifiers included in subtotal', () {
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

      final order = Order.create(
        orderNumber: 'ORD-TEST-004',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.10,
        serviceChargeRate: 0.05,
      );

      expect(order.subtotal, 15000); // 10000 + 5000
      expect(order.serviceCharge, 750); // 15000 * 0.05
      expect(order.tax, 1500); // 15000 * 0.10
      expect(order.grandTotal, 17250); // 15000 + 750 + 1500
    });

    test('Order.create() empty cart', () {
      final order = Order.create(
        orderNumber: 'ORD-TEST-005',
        tableNumber: 'A01',
        items: [],
        cashierName: 'Test Cashier',
        taxRate: 0.10,
        serviceChargeRate: 0.05,
      );

      expect(order.subtotal, 0);
      expect(order.serviceCharge, 0);
      expect(order.tax, 0);
      expect(order.grandTotal, 0);
    });

    test('Order.create() rounding behavior', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 3333,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 3);

      final order = Order.create(
        orderNumber: 'ORD-TEST-006',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.10,
        serviceChargeRate: 0.05,
      );

      expect(order.subtotal, 9999);
      expect(order.serviceCharge, 500); // 9999 * 0.05 = 499.95 -> round to 500
      expect(order.tax, 1000); // 9999 * 0.10 = 999.9 -> round to 1000
      expect(order.grandTotal, 11499); // 9999 + 500 + 1000
    });

    test('Consistency between cart totals and order totals via prepareCheckoutOrder', () async {
      final pos = PosProvider();
      await pos.loadPersistedConfig();

      // Update config to custom rates
      final customConfig = pos.businessConfig.copyWith(
        taxPercent: 11.0,
        serviceChargePercent: 6.0,
      );
      await pos.updateBusinessConfig(customConfig);

      // Add item to cart
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 2);

      // Get cart totals before checkout
      final cartSubtotal = pos.cartSubtotal;
      final cartServiceCharge = pos.cartServiceCharge;
      final cartTax = pos.cartTax;
      final cartGrandTotal = pos.cartGrandTotal;

      // Create order via real checkout flow
      final order = pos.prepareCheckoutOrder();

      // Verify consistency - real production flow passes config rates and flags
      expect(order.subtotal, cartSubtotal);
      expect(order.serviceCharge, cartServiceCharge);
      expect(order.tax, cartTax);
      expect(order.grandTotal, cartGrandTotal);
    });

    test('Order.create() with tax disabled', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final order = Order.create(
        orderNumber: 'ORD-TEST-008',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: false,
        isServiceEnabled: true,
      );

      expect(order.subtotal, 20000);
      expect(order.serviceCharge, 1000); // 20000 * 0.05
      expect(order.tax, 0); // Disabled
      expect(order.grandTotal, 21000); // 20000 + 1000 + 0
    });

    test('Order.create() with service charge disabled', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final order = Order.create(
        orderNumber: 'ORD-TEST-009',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: true,
        isServiceEnabled: false,
      );

      expect(order.subtotal, 20000);
      expect(order.serviceCharge, 0); // Disabled
      expect(order.tax, 2000); // 20000 * 0.10
      expect(order.grandTotal, 22000); // 20000 + 0 + 2000
    });

    test('Order.create() with both charges disabled', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final order = Order.create(
        orderNumber: 'ORD-TEST-010',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.10,
        serviceChargeRate: 0.05,
        isTaxEnabled: false,
        isServiceEnabled: false,
      );

      expect(order.subtotal, 20000);
      expect(order.serviceCharge, 0); // Disabled
      expect(order.tax, 0); // Disabled
      expect(order.grandTotal, 20000); // 20000 + 0 + 0
    });

    test('Order.create() with custom rates and both charges enabled', () {
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      final item = CartItem(product: product, quantity: 2);

      final order = Order.create(
        orderNumber: 'ORD-TEST-011',
        tableNumber: 'A01',
        items: [item],
        cashierName: 'Test Cashier',
        taxRate: 0.12,
        serviceChargeRate: 0.07,
        isTaxEnabled: true,
        isServiceEnabled: true,
      );

      expect(order.subtotal, 20000);
      expect(order.serviceCharge, 1400); // 20000 * 0.07
      expect(order.tax, 2400); // 20000 * 0.12
      expect(order.grandTotal, 23800); // 20000 + 1400 + 2400
    });

    test('Consistency via prepareCheckoutOrder with tax disabled', () async {
      final pos = PosProvider();
      await pos.loadPersistedConfig();

      // Disable tax
      final customConfig = pos.businessConfig.copyWith(
        isTaxEnabled: false,
      );
      await pos.updateBusinessConfig(customConfig);

      // Add item to cart
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 2);

      // Get cart totals
      final cartSubtotal = pos.cartSubtotal;
      final cartServiceCharge = pos.cartServiceCharge;
      final cartTax = pos.cartTax;
      final cartGrandTotal = pos.cartGrandTotal;

      // Create order via checkout flow
      final order = pos.prepareCheckoutOrder();

      // Verify consistency with tax disabled
      expect(order.subtotal, cartSubtotal);
      expect(order.serviceCharge, cartServiceCharge);
      expect(order.tax, cartTax);
      expect(order.tax, 0); // Explicitly verify tax is zero
      expect(order.grandTotal, cartGrandTotal);
    });

    test('Consistency via prepareCheckoutOrder with service charge disabled', () async {
      final pos = PosProvider();
      await pos.loadPersistedConfig();

      // Disable service charge
      final customConfig = pos.businessConfig.copyWith(
        isServiceEnabled: false,
      );
      await pos.updateBusinessConfig(customConfig);

      // Add item to cart
      final product = Product(
        id: 'PRD-001',
        name: 'Test Product',
        price: 10000,
        category: ProductCategory.coffee,
      );
      pos.addToCart(product, qty: 2);

      // Get cart totals
      final cartSubtotal = pos.cartSubtotal;
      final cartServiceCharge = pos.cartServiceCharge;
      final cartTax = pos.cartTax;
      final cartGrandTotal = pos.cartGrandTotal;

      // Create order via checkout flow
      final order = pos.prepareCheckoutOrder();

      // Verify consistency with service charge disabled
      expect(order.subtotal, cartSubtotal);
      expect(order.serviceCharge, cartServiceCharge);
      expect(order.serviceCharge, 0); // Explicitly verify service charge is zero
      expect(order.tax, cartTax);
      expect(order.grandTotal, cartGrandTotal);
    });
  });
}
