import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cafe_pos_demo/models/modifier.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/stock_adjustment.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/utils/shift_sale_guard.dart';

/// Regression tests for inventory-ledger identity, stock validation and
/// partial-commit rollback (Stage A6.5).
void main() {
  group('Inventory Ledger & Checkout Consistency', () {
    late PosProvider pos;

    setUpAll(() async {
      await initializeDateFormatting('id_ID');
    });

    setUp(() {
      pos = PosProvider();
    });

    Product coffee() =>
        pos.products.firstWhere((p) => p.id == 'PRD-001', orElse: () => pos.products.first);

    Product customProduct({
      required String id,
      required String name,
      int stock = 50,
      int price = 15000,
    }) =>
        Product(
          id: id,
          name: name,
          price: price,
          category: ProductCategory.snack,
          stock: stock,
          lowStockThreshold: 10,
        );

    /// Payment adjustment rows belonging to [orderNumber].
    List<StockAdjustment> saleAdjustmentsFor(String orderNumber) => pos.stockAdjustments
        .where((a) => a.type == AdjustmentType.sale && a.reason.contains(orderNumber))
        .toList();

    double sumQuantity(Iterable<StockAdjustment> rows) =>
        rows.fold<double>(0, (sum, a) => sum + a.quantity);

    // ================================================================
    // Task 1 - Adjustment history identity (H-1)
    // ================================================================

    test('H-1: two cart lines of the same product with different modifiers get distinct history rows', () {
      final product = coffee();
      final extraShot = const ModifierOption(
        id: 'mod-extra-shot',
        name: 'Extra Shot',
        priceAdjustment: 5000,
        rawMaterialOverrides: {},
        rawMaterialAdditions: {'MAT-001': 9.0},
      );

      // Absolute baseline captured BEFORE checkout. Deliberately not derived
      // from the post-payment value, so this can actually fail.
      final stockBefore = product.stock;

      // Two lines: plain, then extra shot (different customKey => separate lines).
      pos.addToCart(product, qty: 1);
      pos.addToCart(product, qty: 1, modifiers: [extraShot]);
      expect(pos.cart.length, 2, reason: 'Precondition: two distinct cart lines');

      final order = pos.prepareCheckoutOrder();
      final paid = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      // Both lines must deduct from the running balance.
      expect(
        pos.products.firstWhere((p) => p.id == product.id).stock,
        stockBefore - 2,
        reason: 'Each cart line must deduct its own quantity',
      );

      // Finished-product history: one row per line, distinct ids, total = 2.
      final rows = saleAdjustmentsFor(paid.orderNumber)
          .where((a) => !a.isRawMaterial)
          .toList();
      expect(rows.length, 2, reason: 'Each cart line must have its own history row');
      expect(rows.map((r) => r.id).toSet().length, 2, reason: 'History ids must be unique');
      expect(sumQuantity(rows), 2, reason: 'History total must equal units sold');

      // History deltas must chain and agree with the real stock transition.
      // Chronological order: each line starts where the previous one ended,
      // so previousStock DESCENDS along the chain.
      final byLine = [...rows]..sort((a, b) => b.previousStock.compareTo(a.previousStock));
      expect(byLine.first.previousStock, stockBefore.toDouble(),
          reason: 'First line starts from the real pre-sale stock');
      expect(byLine.last.newStock, (stockBefore - 2).toDouble(),
          reason: 'Last line ends at the real post-sale stock');
      expect(
        byLine.fold<double>(0, (s, a) => s + (a.previousStock - a.newStock)),
        2.0,
        reason: 'Summed ledger deltas must equal the actual deduction',
      );
      expect(order.items.length, 2);
    });

    // ================================================================
    // Stage A6.7 - Multi-line same-product deduction regression (C-1)
    // ================================================================

    group('C-1: multiple cart lines of the same product', () {
      const extraShot = ModifierOption(
        id: 'mod-extra-shot',
        name: 'Extra Shot',
        priceAdjustment: 5000,
        rawMaterialOverrides: {},
        rawMaterialAdditions: {'MAT-001': 9.0},
      );

      test('two lines of qty 1 each deduct 2 units and reconcile with the ledger', () {
        final product = coffee();
        // Absolute baseline read BEFORE any cart or checkout work.
        final stockBefore = product.stock;

        pos.addToCart(product, qty: 1);
        pos.addToCart(product, qty: 1, modifiers: [extraShot]);
        expect(pos.cart.length, 2, reason: 'Precondition: two separate cart lines');

        final paid = pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        );

        // 1. Final stock reflects BOTH lines.
        final stockAfter = pos.products.firstWhere((p) => p.id == product.id).stock;
        expect(stockAfter, stockBefore - 2,
            reason: 'Actual bug: stock was left at stockBefore - 1');

        // 2. Exactly two finished-product ledger entries for this order.
        final rows = saleAdjustmentsFor(paid.orderNumber)
            .where((a) => !a.isRawMaterial && a.productId == product.id)
            .toList();
        expect(rows.length, 2, reason: 'One ledger row per cart line');

        // 3. Ledger quantity total equals units sold.
        expect(rows.fold<num>(0, (s, a) => s + a.quantity), 2);

        // 4. Ledger transitions chain and match the real stock transitions.
        final chain = [...rows]
          ..sort((a, b) => b.previousStock.compareTo(a.previousStock));
        expect(chain.first.previousStock, stockBefore.toDouble(),
            reason: 'First line previousStock == real pre-sale stock');
        expect(chain.last.newStock, stockAfter.toDouble(),
            reason: 'Last line newStock == real post-sale stock');
        expect(chain[0].previousStock - chain[0].newStock, 1);
        expect(chain[1].previousStock - chain[1].newStock, 1);
        expect(chain[1].previousStock, chain[0].newStock,
            reason: 'Ledger transitions must chain without a gap or overlap');
        expect(
          rows.fold<double>(0, (s, a) => s + (a.previousStock - a.newStock)),
          (stockBefore - stockAfter).toDouble(),
          reason: 'Ledger must not claim more than was actually deducted',
        );
      });

      test('control: a single line of qty 2 deducts exactly 2', () {
        final product = coffee();
        final stockBefore = product.stock;

        pos.addToCart(product, qty: 2);
        expect(pos.cart.length, 1, reason: 'Precondition: exactly one cart line');

        final paid = pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        );

        final stockAfter = pos.products.firstWhere((p) => p.id == product.id).stock;
        expect(stockAfter, stockBefore - 2);

        final rows = saleAdjustmentsFor(paid.orderNumber)
            .where((a) => !a.isRawMaterial && a.productId == product.id)
            .toList();
        expect(rows.length, 1);
        expect(rows.single.quantity, 2);
        expect(rows.single.previousStock, stockBefore.toDouble());
        expect(rows.single.newStock, stockAfter.toDouble());
      });

      test('control: three lines deduct 3 units and reconcile', () {
        final product = coffee();
        final stockBefore = product.stock;

        pos.addToCart(product, qty: 1);
        pos.addToCart(product, qty: 1, modifiers: [extraShot]);
        pos.addToCart(product, qty: 1, notes: 'third line');

        final paid = pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        );

        final stockAfter = pos.products.firstWhere((p) => p.id == product.id).stock;
        expect(stockAfter, stockBefore - 3);

        final rows = saleAdjustmentsFor(paid.orderNumber)
            .where((a) => !a.isRawMaterial && a.productId == product.id)
            .toList();
        expect(rows.length, 3);
        expect(rows.fold<num>(0, (s, a) => s + a.quantity), 3);
        expect(rows.map((r) => r.id).toSet().length, 3, reason: 'Ids stay unique');

        final chain = [...rows]
          ..sort((a, b) => b.previousStock.compareTo(a.previousStock));
        expect(chain.first.previousStock, stockBefore.toDouble());
        expect(chain.last.newStock, stockAfter.toDouble());
        expect(
          rows.fold<double>(0, (s, a) => s + (a.previousStock - a.newStock)),
          (stockBefore - stockAfter).toDouble(),
        );
      });

      test('mixed: two lines of one product plus a different product stay correct', () {
        final product = coffee();
        final other = pos.products.firstWhere((p) => p.id == 'PRD-005');
        final beforeA = product.stock;
        final beforeB = other.stock;

        pos.addToCart(product, qty: 1);
        pos.addToCart(product, qty: 1, modifiers: [extraShot]);
        pos.addToCart(other, qty: 3);

        pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        );

        expect(pos.products.firstWhere((p) => p.id == product.id).stock, beforeA - 2);
        expect(pos.products.firstWhere((p) => p.id == 'PRD-005').stock, beforeB - 3);
      });

      test('multi-line order still aggregates its shared raw material', () {
        final product = coffee();
        final beans = pos.rawMaterials.firstWhere((m) => m.id == 'MAT-001');
        final beansBefore = beans.stock;

        pos.addToCart(product, qty: 1);
        pos.addToCart(product, qty: 1, modifiers: [extraShot]);

        final paid = pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        );

        final beanRows = saleAdjustmentsFor(paid.orderNumber)
            .where((a) => a.isRawMaterial && a.productId == 'MAT-001')
            .toList();
        expect(beanRows.length, 1, reason: 'Shared ingredient aggregates into one row');
        expect(beanRows.single.quantity, 45.0, reason: '18g base + 9g extra shot, x2 units');
        expect(beansBefore - beans.stock, 45.0);
        expect(beanRows.single.previousStock - beanRows.single.newStock, 45.0);
      });

      test('low-stock crossing is detected once across multi-line deductions', () {
        final product = customProduct(id: 'PRD-LOW', name: 'Low Item', stock: 3);
        pos.addProduct(product);

        pos.addToCart(product, qty: 1);
        pos.addToCart(product, qty: 1, modifiers: [
          const ModifierOption(
            id: 'mod-note',
            name: 'Note',
            priceAdjustment: 0,
            rawMaterialOverrides: {},
            rawMaterialAdditions: {},
          ),
        ]);

        pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        );

        expect(product.stock, 1, reason: 'Both lines deducted from the running balance');

        final rows = pos.stockAdjustments
            .where((a) => !a.isRawMaterial && a.productId == 'PRD-LOW')
            .toList();
        final chain = [...rows]
          ..sort((a, b) => b.previousStock.compareTo(a.previousStock));
        expect(chain.map((r) => r.previousStock.toInt()).toList(), [3, 2]);
        expect(chain.map((r) => r.newStock.toInt()).toList(), [2, 1]);
      });
    });

    test('H-1: two lines sharing an ingredient record one aggregated raw-material row', () {
      final product = coffee();

      pos.addToCart(product, qty: 2);
      pos.addToCart(product, qty: 3, modifiers: [
        const ModifierOption(
          id: 'mod-hot',
          name: 'Hot',
          priceAdjustment: 0,
          rawMaterialOverrides: {},
          rawMaterialAdditions: {},
        ),
      ]);

      final paid = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final coffeeRows =
          saleAdjustmentsFor(paid.orderNumber).where((a) => a.productId == 'MAT-001').toList();
      expect(coffeeRows.length, 1, reason: 'One aggregated row per material per order');

      final coffeeBefore = coffeeRows.first.previousStock;
      final coffeeAfter = pos.rawMaterials.firstWhere((m) => m.id == 'MAT-001').stock;
      // 18g per unit * 5 units.
      expect(coffeeRows.first.quantity, 90.0);
      expect(coffeeBefore - coffeeAfter, 90.0,
          reason: 'History quantity must equal the real ingredient deduction');
    });

    test('H-1: adjustment ids are stable across a retry and never duplicate history', () {
      final product = coffee();
      pos.addToCart(product, qty: 2);
      final first = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );
      final rowsAfterFirst = saleAdjustmentsFor(first.orderNumber).length;

      // Duplicate payment is idempotent.
      final second = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      expect(second.orderNumber, first.orderNumber);
      expect(saleAdjustmentsFor(first.orderNumber).length, rowsAfterFirst,
          reason: 'Retry must not append duplicate history rows');
      expect(pos.stockAdjustments.where((a) => a.id == 'ADJ-SALE-${first.orderNumber}-${product.id}-L1').length, 1);
    });

    test('H-1: a second, distinct order produces distinct adjustment ids', () {
      final product = coffee();

      pos.addToCart(product, qty: 1);
      final first = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );
      pos.clearCart();

      pos.addToCart(product, qty: 1);
      final second = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      expect(first.orderNumber, isNot(second.orderNumber));
      final ids = pos.stockAdjustments.map((a) => a.id).toSet();
      expect(ids.length, pos.stockAdjustments.length, reason: 'Adjustment ids are globally unique');
    });

    // ================================================================
    // Task 2 - Stock validation before deduction (M-1)
    // ================================================================

    test('M-1: payment is rejected when finished-product stock is insufficient', () {
      final scarce = customProduct(id: 'PRD-SCARCE', name: 'Scarce Item', stock: 2);
      pos.addProduct(scarce);

      pos.addToCart(scarce, qty: 5);
      pos.prepareCheckoutOrder();

      final ordersBefore = pos.orders.length;
      final adjustmentsBefore = pos.stockAdjustments.length;

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      expect(scarce.stock, 2, reason: 'Stock must not be clamped or deducted');
      expect(pos.orders.length, ordersBefore, reason: 'No paid order may be created');
      expect(pos.stockAdjustments.length, adjustmentsBefore, reason: 'No history may be appended');
      expect(pos.currentOrder!.status, OrderStatus.pending, reason: 'Order stays unpaid');
      expect(pos.cartItemCount, 5, reason: 'Cart is preserved for correction');
    });

    test('M-1: rejection reason names the shortage to the cashier', () {
      final scarce = customProduct(id: 'PRD-SCARCE', name: 'Scarce Item', stock: 1);
      pos.addProduct(scarce);
      pos.addToCart(scarce, qty: 4);
      pos.prepareCheckoutOrder();

      try {
        pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        );
        fail('Expected InsufficientStockException');
      } on InsufficientStockException catch (e) {
        expect(e.issues.join(), contains('Scarce Item'));
        expect(e.message, contains('Stok tidak mencukupi'));
      }
    });

    test('M-1: aggregated demand across lines is validated as a total', () {
      final limited = customProduct(id: 'PRD-LIMIT', name: 'Limited Item', stock: 5);
      pos.addProduct(limited);

      // Each line alone would fit, but together they exceed stock.
      pos.addToCart(limited, qty: 3);
      pos.addToCart(limited, qty: 3, notes: 'varian lain');
      pos.prepareCheckoutOrder();

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(limited.stock, 5);
    });

    test('M-1: insufficient raw-material stock rejects the sale before any deduction', () {
      final beans = pos.rawMaterials.firstWhere((m) => m.id == 'MAT-001');
      final before = beans.stock;

      // 18g beans per unit; force demand beyond the available stock.
      final units = (before ~/ 18) + 50;
      pos.addToCart(coffee(), qty: units);
      pos.prepareCheckoutOrder();

      final adjustmentsBefore = pos.stockAdjustments.length;

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      expect(beans.stock, before, reason: 'Ingredient stock must be untouched');
      expect(pos.stockAdjustments.length, adjustmentsBefore);
      expect(pos.orders.where((o) => o.status == OrderStatus.paid).length,
          pos.orders.length, reason: 'No extra paid order created');
    });

    test('M-1: a modifier that removes an ingredient lets a borderline sale succeed', () {
      // Make every ingredient plentiful EXCEPT ice, which becomes the only
      // binding constraint: 2 cups need 200g, only 100g on hand.
      for (final m in pos.rawMaterials) {
        m.stock = 100000.0;
      }
      pos.rawMaterials.firstWhere((m) => m.id == 'MAT-010').stock = 100.0;

      const noIce = ModifierOption(
        id: 'mod-no-ice',
        name: 'Hot (No Ice)',
        priceAdjustment: 0,
        rawMaterialOverrides: {'MAT-010': 0.0},
        rawMaterialAdditions: {},
      );

      // Without the override the sale is short on ice and must be refused.
      pos.addToCart(coffee(), qty: 2);
      pos.prepareCheckoutOrder();
      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      // Same demand, but the modifier zeroes the ice requirement.
      pos.clearCart();
      pos.addToCart(coffee(), qty: 2, modifiers: [noIce]);
      pos.prepareCheckoutOrder();

      final paid = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      expect(paid.status, OrderStatus.paid);
      expect(pos.rawMaterials.firstWhere((m) => m.id == 'MAT-010').stock, 100.0,
          reason: 'Overridden ingredient must not be deducted');
      expect(
        pos.rawMaterials.firstWhere((m) => m.id == 'MAT-001').stock,
        100000.0 - 36.0,
        reason: 'Non-overridden ingredients are still deducted',
      );
    });

    test('M-1: exact-stock sale is allowed and lands at zero', () {
      final exact = customProduct(id: 'PRD-EXACT', name: 'Exact Item', stock: 3);
      pos.addProduct(exact);
      pos.addToCart(exact, qty: 3);
      pos.prepareCheckoutOrder();

      final paid = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      expect(paid.status, OrderStatus.paid);
      expect(exact.stock, 0);
      expect(exact.isOutOfStock, isTrue);
    });

    // ================================================================
    // Task 3 - Partial-commit rollback (H-2)
    // ================================================================

    test('H-2: failure after inventory apply rolls back stock, order, history and cart', () {
      final product = coffee();
      final beans = pos.rawMaterials.firstWhere((m) => m.id == 'MAT-001');

      final productStockBefore = pos.products.firstWhere((p) => p.id == product.id).stock;
      final beansBefore = beans.stock;
      final ordersBefore = pos.orders.length;
      final adjustmentsBefore = pos.stockAdjustments.length;

      pos.addToCart(product, qty: 2);
      pos.prepareCheckoutOrder();
      final pendingOrder = pos.currentOrder!;

      // Deterministic failure seam: throws after inventory is mutated but
      // before the order is committed.
      pos.debugThrowAfterInventoryApply = () {
        throw StateError('simulated failure after inventory apply');
      };

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<StateError>()),
      );

      pos.debugThrowAfterInventoryApply = null;

      expect(pos.products.firstWhere((p) => p.id == product.id).stock, productStockBefore,
          reason: 'Finished-product stock restored');
      expect(beans.stock, beansBefore, reason: 'Raw-material stock restored');
      expect(pos.orders.length, ordersBefore, reason: 'No paid order committed');
      expect(pos.stockAdjustments.length, adjustmentsBefore, reason: 'No history appended');
      expect(pos.currentOrder, same(pendingOrder), reason: 'Pending order preserved');
      expect(pos.currentOrder!.status, OrderStatus.pending);
      expect(pos.cartItemCount, 2, reason: 'Cart restored for retry');
    });

    test('H-2: a failed sale can be retried successfully afterwards', () {
      final product = coffee();
      final stockBefore = pos.products.firstWhere((p) => p.id == product.id).stock;

      pos.addToCart(product, qty: 2);
      pos.prepareCheckoutOrder();

      pos.debugThrowAfterInventoryApply = () => throw StateError('boom');
      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<StateError>()),
      );
      pos.debugThrowAfterInventoryApply = null;

      // Retry on the same restored pending order now succeeds.
      final paid = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );
      expect(paid.status, OrderStatus.paid);
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, stockBefore - 2);

      // Exactly one history row per line, no leftovers from the failed attempt.
      final rows = saleAdjustmentsFor(paid.orderNumber).where((a) => !a.isRawMaterial).toList();
      expect(rows.length, 1);
    });

    test('H-2: rollback restores the dine-in table to its pre-sale state', () {
      final table = pos.tables.firstWhere((t) => t.number == 'A02');
      pos.selectTable(table);
      final statusBefore = table.status;
      final orderIdBefore = table.currentOrderId;

      pos.addToCart(coffee(), qty: 1);
      pos.prepareCheckoutOrder();

      pos.debugThrowAfterInventoryApply = () => throw StateError('boom');
      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<StateError>()),
      );
      pos.debugThrowAfterInventoryApply = null;

      expect(table.status, statusBefore);
      expect(table.currentOrderId, orderIdBefore);
    });

    // ================================================================
    // Task 4 - Defensive payment checks
    // ================================================================

    test('completePayment rejects an order with no items', () {
      // No cart items: prepareCheckoutOrder produces an empty pending order.
      pos.prepareCheckoutOrder();
      expect(pos.currentOrder!.items, isEmpty);

      final ordersBefore = pos.orders.length;
      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: 0,
          changeAmount: 0,
        ),
        throwsA(isA<InvalidPaymentException>()),
      );
      expect(pos.orders.length, ordersBefore, reason: 'No zero-value paid order is created');
    });

    test('cash below the grand total is rejected', () {
      pos.addToCart(coffee(), qty: 2);
      pos.prepareCheckoutOrder();
      final total = pos.currentOrder!.grandTotal;

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: total - 1000,
          changeAmount: 0,
        ),
        throwsA(isA<InvalidPaymentException>()),
      );
      expect(pos.currentOrder!.status, OrderStatus.pending);
    });

    test('cash exactly equal to the grand total is accepted', () {
      pos.addToCart(coffee(), qty: 2);
      pos.prepareCheckoutOrder();
      final total = pos.currentOrder!.grandTotal;

      final paid = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: total,
        changeAmount: 0,
      );
      expect(paid.status, OrderStatus.paid);
    });

    test('cash-only validation does not apply to QRIS or debit', () {
      for (final method in [PaymentMethod.qris, PaymentMethod.debitCard]) {
        final fresh = PosProvider();
        final product = fresh.products.firstWhere((p) => p.id == 'PRD-001');
        fresh.addToCart(product, qty: 1);
        fresh.prepareCheckoutOrder();

        // Deliberately under the total: gateways settle the exact amount, so
        // the provider must not apply the cash rule here.
        final paid = fresh.completePayment(
          method: method,
          paidAmount: 0,
          changeAmount: 0,
        );
        expect(paid.status, OrderStatus.paid, reason: '$method must not be cash-validated');
      }
    });

    test('blocked guards keep precedence: closed shift beats insufficient stock', () async {
      final scarce = customProduct(id: 'PRD-SCARCE', name: 'Scarce Item', stock: 1);
      pos.addProduct(scarce);
      pos.addToCart(scarce, qty: 9);

      await pos.closeShift(actualEndingCash: pos.currentShift.startingCash);

      expect(
        () => pos.prepareCheckoutOrder(),
        throwsA(isA<ShiftSaleBlockedException>()),
      );
      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: 999999,
          changeAmount: 0,
        ),
        throwsA(isA<ShiftSaleBlockedException>()),
      );
    });

    test('normal demo sale flow is unaffected by the new guards', () {
      pos.loadDemoQuickOrder();
      final total = pos.cartGrandTotal;
      expect(total, 60950);

      final paid = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 100000,
        changeAmount: 100000 - total,
      );

      expect(paid.status, OrderStatus.paid);
      expect(paid.grandTotal, 60950);
      expect(pos.cart, isEmpty);
      expect(pos.products.firstWhere((p) => p.id == 'PRD-001').stock, 38 - 2);
    });
  });
}