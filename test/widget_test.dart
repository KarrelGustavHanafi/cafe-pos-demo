import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_pos_demo/main.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/stock_adjustment.dart';

void main() {
  group('POS Business Logic & Math Verification', () {
    test('Calculates demo order subtotal, service charge (5%), and tax (10%) accurately', () {
      final pos = PosProvider();

      // Load demo order: 2x Kopi Susu Gula Aren (18k each) + 1x French Fries (17k)
      pos.loadDemoQuickOrder();

      expect(pos.cart.length, 2);
      expect(pos.cartSubtotal, 53000); // 36.000 + 17.000
      expect(pos.cartServiceCharge, 2650); // 5% of 53.000
      expect(pos.cartTax, 5300); // 10% of 53.000
      expect(pos.cartGrandTotal, 60950); // 53.000 + 2.650 + 5.300
    });

    test('Generates order number with ORD-YYYYMMDD-NNNN format', () {
      final pos = PosProvider();
      final orderNumber = pos.generateOrderNumber();
      final regex = RegExp(r'^ORD-\d{8}-\d{4}$');

      expect(regex.hasMatch(orderNumber), isTrue);
    });

    test('Completing payment reduces product inventory and logs transaction', () {
      final pos = PosProvider();
      pos.login('cashier', 'cashier123');

      final tableA01 = pos.tables.firstWhere((t) => t.number == 'A01');
      pos.selectTable(tableA01);
      pos.loadDemoQuickOrder();

      final kopiSusuBefore = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock;
      final friesBefore = pos.products.firstWhere((p) => p.name == 'French Fries').stock;

      final finishedOrder = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 100000,
        changeAmount: 39050,
      );

      expect(finishedOrder.status, OrderStatus.paid);
      expect(finishedOrder.grandTotal, 60950);

      // Verify stock depletion
      final kopiSusuAfter = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock;
      final friesAfter = pos.products.firstWhere((p) => p.name == 'French Fries').stock;

      expect(kopiSusuAfter, kopiSusuBefore - 2);
      expect(friesAfter, friesBefore - 1);

      // Verify table A01 status is now occupied
      final tableA01After = pos.tables.firstWhere((t) => t.number == 'A01');
      expect(tableA01After.isOccupied, isTrue);
    });
  });

  group('Widget Role Separation & Presentation Test', () {
    testWidgets('Renders Login Screen with Kopi Senja brand and demo login options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();

      expect(find.text('CAFFE'), findsOneWidget);
      expect(find.text('Sistem Kasir & Manajemen Kafe'), findsOneWidget);
      expect(find.text('Kasir (POS)'), findsOneWidget);
      expect(find.text('Owner (Bisnis)'), findsOneWidget);
    });

    testWidgets('Logging in as Cashier routes to Cashier Shell with POS and operational tabs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();

      final cashierButton = find.text('Kasir (POS)');
      await tester.ensureVisible(cashierButton);
      await tester.tap(cashierButton);
      await tester.pumpAndSettle();

      // Should land on Cashier Shell
      expect(find.text('Kasir POS'), findsOneWidget);
      expect(find.text('Role: Kasir'), findsOneWidget);
      expect(find.text('POS / Pesanan'), findsOneWidget);
      expect(find.text('Denah Meja'), findsOneWidget);
      expect(find.text('Shift Kasir'), findsOneWidget);

      // Should NOT see Owner Dashboard or Owner business analytics
      expect(find.text('Dashboard Bisnis'), findsNothing);
      expect(find.text('Owner Portal'), findsNothing);
    });

    testWidgets('Logging in as Owner routes to Owner Shell with business dashboard', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();

      final ownerButton = find.text('Owner (Bisnis)');
      await tester.ensureVisible(ownerButton);
      await tester.tap(ownerButton);
      await tester.pumpAndSettle();

      // Should land on Owner Shell
      expect(find.text('Owner Portal'), findsOneWidget);
      expect(find.text('Dashboard Bisnis'), findsWidgets);
      expect(find.text('Total Omzet Hari Ini'), findsOneWidget);
      expect(find.text('MENU & INVENTARIS'), findsOneWidget);

      // Should NOT see Cashier POS shell
      expect(find.text('Kasir POS'), findsNothing);
    });

    test('Connected Demo Flow: Owner adds Strawberry Matcha, Cashier buys via QRIS, Inventory updates & Owner reflects', () {
      final pos = PosProvider();

      // Step 1-8: Owner adds "Strawberry Matcha"
      final strawberryMatcha = Product(
        id: 'PRD-STM-08',
        name: 'Strawberry Matcha',
        price: 22000,
        costPrice: 9500,
        category: ProductCategory.nonCoffee,
        stock: 20,
        lowStockThreshold: 15,
        description: 'Matcha latte lembut dengan puree stroberi segar dan susu creamy',
        imageUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87',
        sku: 'NC-STM-08',
        isActive: true,
      );
      pos.addProduct(strawberryMatcha);

      // Verify product is present in catalog and available to Cashier
      expect(pos.products.any((p) => p.name == 'Strawberry Matcha'), isTrue);
      expect(pos.activeProducts.any((p) => p.name == 'Strawberry Matcha'), isTrue);
      final addedProduct = pos.products.firstWhere((p) => p.name == 'Strawberry Matcha');
      expect(addedProduct.stock, 20);
      expect(addedProduct.price, 22000);

      // Step 9-15: Cashier opens POS, selects table, adds Strawberry Matcha + French Fries
      pos.login('cashier', 'cashier123');
      final tableB02 = pos.tables.firstWhere((t) => t.number == 'B02');
      pos.selectTable(tableB02);

      final fries = pos.products.firstWhere((p) => p.name == 'French Fries');
      pos.addToCart(addedProduct, qty: 1);
      pos.addToCart(fries, qty: 1);

      expect(pos.cart.length, 2);
      expect(pos.cartSubtotal, 22000 + 17000); // 39000

      // Step 16-21: Cashier pays via QRIS
      final grandTotal = pos.cartGrandTotal;
      final completedOrder = pos.completePayment(
        method: PaymentMethod.qris,
        paidAmount: grandTotal,
        changeAmount: 0,
      );

      expect(completedOrder.status, OrderStatus.paid);
      expect(completedOrder.paymentMethod, PaymentMethod.qris);

      // Step 21: Stock decreases (Strawberry Matcha: 20 -> 19, French Fries: 8 -> 7)
      final matchaAfter = pos.products.firstWhere((p) => p.name == 'Strawberry Matcha');
      final friesAfter = pos.products.firstWhere((p) => p.name == 'French Fries');
      expect(matchaAfter.stock, 19);
      expect(friesAfter.stock, 7);

      // Step 22-26: Owner views Orders and Sales
      pos.login('owner', 'owner123');
      expect(pos.orders.first.orderNumber, completedOrder.orderNumber);
      expect(pos.orders.first.items.any((i) => i.product.name == 'Strawberry Matcha'), isTrue);
      expect(pos.todayQrisSales >= grandTotal, isTrue);

      // Step 28: Owner Inventory shows Strawberry Matcha with 19 stock
      final inventoryMatcha = pos.products.firstWhere((p) => p.name == 'Strawberry Matcha');
      expect(inventoryMatcha.stock, 19);

      // Extra demonstration: Owner updates French Fries stock (+20) -> 27
      pos.adjustStock(
        productId: friesAfter.id,
        type: AdjustmentType.add,
        quantity: 20,
        reason: 'Restok supplier kentang',
        adjustedBy: 'Owner Budi',
      );

      final friesUpdated = pos.products.firstWhere((p) => p.name == 'French Fries');
      expect(friesUpdated.stock, 27);
      expect(pos.stockAdjustments.first.productName, 'French Fries');
      expect(pos.stockAdjustments.first.quantity, 20);
      expect(pos.stockAdjustments.first.newStock, 27);
    });
  });

  group('Raw Material & Recipe Inventory System Verification', () {
    test('Initializes with 10 demo raw materials and realistic statuses', () {
      final pos = PosProvider();
      expect(pos.rawMaterials.length, 10);

      final coffeeBeans = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans');
      expect(coffeeBeans.stock, 5000);
      expect(coffeeBeans.minimumStock, 1000);
      expect(coffeeBeans.isInStock, isTrue);

      final palmSugar = pos.rawMaterials.firstWhere((m) => m.name == 'Palm Sugar');
      expect(palmSugar.stock, 2000);
      expect(palmSugar.minimumStock, 500);
      expect(palmSugar.isInStock, isTrue);
    });

    test('Recipe mapping matches demo specifications (Kopi Susu Gula Aren)', () {
      final pos = PosProvider();
      final kopiSusu = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
      final recipe = pos.getRecipeForProduct(kopiSusu.id);

      expect(recipe, isNotNull);
      expect(recipe!.items.length, 4);

      final coffeeItem = recipe.items.firstWhere((i) => i.materialName == 'Coffee Beans');
      expect(coffeeItem.quantity, 18);

      final milkItem = recipe.items.firstWhere((i) => i.materialName == 'UHT Milk');
      expect(milkItem.quantity, 120);

      final sugarItem = recipe.items.firstWhere((i) => i.materialName == 'Palm Sugar');
      expect(sugarItem.quantity, 25);

      final iceItem = recipe.items.firstWhere((i) => i.materialName == 'Ice');
      expect(iceItem.quantity, 100);
    });

    test('Customer buys 2x Kopi Susu: automatic deduction matches exact demo scenario', () {
      final pos = PosProvider();
      pos.login('cashier', 'cashier123');

      final kopiSusu = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
      pos.addToCart(kopiSusu, qty: 2);

      // Verify no deduction BEFORE payment completes
      final coffeeBefore = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock;
      expect(coffeeBefore, 5000);

      // Complete payment
      pos.completePayment(
        method: PaymentMethod.qris,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      // Verify exact stock deductions:
      // Coffee Beans: 5,000 - 36 = 4,964
      // UHT Milk: 8,000 - 240 = 7,760
      // Palm Sugar: 2,000 - 50 = 1,950
      // Ice: 10,000 - 200 = 9,800
      final coffeeAfter = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock;
      final milkAfter = pos.rawMaterials.firstWhere((m) => m.name == 'UHT Milk').stock;
      final sugarAfter = pos.rawMaterials.firstWhere((m) => m.name == 'Palm Sugar').stock;
      final iceAfter = pos.rawMaterials.firstWhere((m) => m.name == 'Ice').stock;

      expect(coffeeAfter, 4964.0);
      expect(milkAfter, 7760.0);
      expect(sugarAfter, 1950.0);
      expect(iceAfter, 9800.0);

      // Verify stock adjustment history logged
      final auditLog = pos.stockAdjustments.where((a) => a.isRawMaterial).toList();
      expect(auditLog.isNotEmpty, isTrue);
      expect(auditLog.any((a) => a.productName == 'Coffee Beans' && a.quantity == 36), isTrue);
    });

    test('Multi-product transaction correctly deducts all combined ingredients', () {
      final pos = PosProvider();
      pos.login('cashier', 'cashier123');

      final kopiSusu = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
      final fries = pos.products.firstWhere((p) => p.name == 'French Fries');

      pos.addToCart(kopiSusu, qty: 2);
      pos.addToCart(fries, qty: 1);

      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 100000,
        changeAmount: 100000 - pos.cartGrandTotal,
      );

      // Potatoes: 10,000 - 180 = 9,820
      // Cooking Oil: 5,000 - 20 = 4,980
      final potatoesAfter = pos.rawMaterials.firstWhere((m) => m.name == 'Potatoes').stock;
      final oilAfter = pos.rawMaterials.firstWhere((m) => m.name == 'Cooking Oil').stock;

      expect(potatoesAfter, 9820.0);
      expect(oilAfter, 4980.0);
    });

    test('Stock safety: stock cannot become negative', () {
      final pos = PosProvider();
      final coffee = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans');

      // Adjust with excessive removal
      pos.adjustRawMaterialStock(
        materialId: coffee.id,
        type: AdjustmentType.remove,
        quantity: 999999,
        reason: 'Pengurangan berlebih untuk uji safety',
      );

      final coffeeAfter = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans');
      expect(coffeeAfter.stock, 0.0);
      expect(coffeeAfter.isOutOfStock, isTrue);
      expect(coffeeAfter.stock >= 0, isTrue);
    });

    test('Low-stock and out-of-stock transitions update immediately', () {
      final pos = PosProvider();
      final palmSugar = pos.rawMaterials.firstWhere((m) => m.name == 'Palm Sugar');

      // Set to 450 (below minimum 500) -> LOW STOCK
      pos.adjustRawMaterialStock(
        materialId: palmSugar.id,
        type: AdjustmentType.set,
        quantity: 450,
        reason: 'Uji low stock threshold',
      );

      final sugarLow = pos.rawMaterials.firstWhere((m) => m.name == 'Palm Sugar');
      expect(sugarLow.isLowStock, isTrue);
      expect(sugarLow.isOutOfStock, isFalse);

      // Set to 0 -> OUT OF STOCK
      pos.adjustRawMaterialStock(
        materialId: palmSugar.id,
        type: AdjustmentType.set,
        quantity: 0,
        reason: 'Uji out of stock',
      );

      final sugarOut = pos.rawMaterials.firstWhere((m) => m.name == 'Palm Sugar');
      expect(sugarOut.isOutOfStock, isTrue);
    });

    test('Pending or canceled order does not deduct stock', () {
      final pos = PosProvider();
      final coffeeBefore = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock;

      final kopiSusu = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
      pos.addToCart(kopiSusu, qty: 5);
      pos.prepareCheckoutOrder(paymentMethod: PaymentMethod.cash);

      // Order is pending, NOT yet paid
      final coffeePending = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock;
      expect(coffeePending, coffeeBefore);

      // Customer cancels cart
      pos.clearCart();
      final coffeeAfterClear = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock;
      expect(coffeeAfterClear, coffeeBefore);
    });
  });
}
