import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/stock_adjustment.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/utils/shift_sale_guard.dart';

/// Regression tests for the closed-shift guard.
///
/// The POS always holds exactly one current shift. There is no separate
/// "never started" representation, so "no active shift" is expressed by the
/// current shift being closed (`ShiftInfo.isClosed == true`).
void main() {
  group('Closed-Shift Guard', () {
    late PosProvider pos;

    setUpAll(() async {
      // Shift-open/close notifications format dates; keep test output clean.
      await initializeDateFormatting('id_ID');
    });

    setUp(() {
      pos = PosProvider();
    });

    Product coffeeProduct() => pos.products.firstWhere(
          (p) => p.id == 'PRD-001',
          orElse: () => pos.products.first,
        );

    /// Closes the current shift, producing the "no active shift" state.
    Future<void> closeCurrentShift() async {
      await pos.closeShift(actualEndingCash: pos.currentShift.startingCash);
    }

    // ==========================================
    // A. Cart / checkout / payment rejection
    // ==========================================

    test('1. Adding a product with no active shift is rejected', () async {
      await closeCurrentShift();
      expect(pos.hasActiveShift, isFalse);

      expect(
        () => pos.addToCart(coffeeProduct()),
        throwsA(isA<ShiftSaleBlockedException>()),
      );
      expect(pos.cart, isEmpty, reason: 'No item may enter the cart');
      expect(pos.currentOrder, isNull, reason: 'No order may be created');
    });

    test('2. Adding a product after shift closure is rejected', () async {
      pos.addToCart(coffeeProduct(), qty: 1);
      expect(pos.cartItemCount, 1);

      await closeCurrentShift();

      expect(
        () => pos.addToCart(coffeeProduct(), qty: 3),
        throwsA(isA<ShiftSaleBlockedException>()),
      );
      expect(pos.cartItemCount, 1, reason: 'Existing cart must be untouched');
    });

    test('3. Checkout without an active shift is rejected', () async {
      await closeCurrentShift();

      expect(
        () => pos.prepareCheckoutOrder(),
        throwsA(isA<ShiftSaleBlockedException>()),
      );
      expect(pos.currentOrder, isNull);
    });

    test('4. Payment after shift closure is rejected', () async {
      final product = coffeeProduct();
      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();

      await closeCurrentShift();

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<ShiftSaleBlockedException>()),
      );
    });

    test('5. Rejected payment does not change order, stock or adjustment history', () async {
      final product = coffeeProduct();
      pos.addToCart(product, qty: 2);
      final pendingOrder = pos.prepareCheckoutOrder();

      final orderCountBefore = pos.orders.length;
      final productStockBefore = pos.products.firstWhere((p) => p.id == product.id).stock;
      final rawMaterialStocksBefore = <String, double>{
        for (final m in pos.rawMaterials) m.id: m.stock,
      };
      final adjustmentCountBefore = pos.stockAdjustments.length;

      await closeCurrentShift();

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<ShiftSaleBlockedException>()),
      );

      expect(pos.orders.length, orderCountBefore, reason: 'No order may be added');
      expect(pos.currentOrder!.status, OrderStatus.pending, reason: 'Order stays unpaid');
      expect(pos.currentOrder!.orderNumber, pendingOrder.orderNumber);
      expect(
        pos.products.firstWhere((p) => p.id == product.id).stock,
        productStockBefore,
        reason: 'Finished-product stock must be untouched',
      );
      for (final m in pos.rawMaterials) {
        expect(m.stock, rawMaterialStocksBefore[m.id], reason: 'Raw material stock untouched');
      }
      expect(
        pos.stockAdjustments.length,
        adjustmentCountBefore,
        reason: 'No sale stock adjustment may be appended',
      );
      expect(
        pos.stockAdjustments.where((a) => a.type == AdjustmentType.sale && a.reason.contains(pendingOrder.orderNumber)),
        isEmpty,
        reason: 'Rejected payment must not append sale adjustments',
      );
    });

    test('6. Duplicate payment for an already-paid order remains idempotent', () async {
      final product = coffeeProduct();
      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();

      final firstOrder = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      final adjustmentCountAfterFirst = pos.stockAdjustments.length;
      final stockAfterFirst = pos.products.firstWhere((p) => p.id == product.id).stock;
      final ordersAfterFirst = pos.orders.length;

      final secondOrder = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      expect(secondOrder.orderNumber, firstOrder.orderNumber);
      expect(secondOrder.status, OrderStatus.paid);
      expect(pos.orders.length, ordersAfterFirst, reason: 'No duplicate order row');
      expect(pos.stockAdjustments.length, adjustmentCountAfterFirst, reason: 'No duplicate adjustment');
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, stockAfterFirst);
    });

    test('7. Normal sale flow succeeds with an active shift', () {
      final product = coffeeProduct();
      final initialStock = pos.products.firstWhere((p) => p.id == product.id).stock;
      expect(pos.hasActiveShift, isTrue);

      pos.addToCart(product, qty: 2);
      expect(pos.cartItemCount, 2);

      final order = pos.prepareCheckoutOrder();
      expect(order.status, OrderStatus.pending);

      final paidOrder = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      expect(paidOrder.status, OrderStatus.paid);
      expect(pos.cart, isEmpty, reason: 'Cart is cleared after a successful sale');
      expect(pos.orders.first.orderNumber, paidOrder.orderNumber);
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, initialStock - 2);
    });

    test('8. A new shift can be started after closing the previous one', () async {
      final firstShiftId = pos.currentShift.shiftId;
      await closeCurrentShift();
      expect(pos.currentShift.isClosed, isTrue);

      final started = pos.startNewShift(startingCash: 500000);

      expect(started, isTrue);
      expect(pos.hasActiveShift, isTrue);
      expect(pos.currentShift.shiftId, isNot(firstShiftId));
      expect(pos.currentShift.startingCash, 500000);
      expect(pos.currentShift.isClosed, isFalse);

      // The closed shift stays archived and is not mutated by the new shift.
      expect(
        pos.pastShifts.any((s) => s.shiftId == firstShiftId && s.isClosed),
        isTrue,
      );

      // Sales work again under the new shift.
      pos.addToCart(coffeeProduct(), qty: 1);
      final order = pos.prepareCheckoutOrder();
      expect(order.status, OrderStatus.pending);
    });

    test('9. Payment begun before closure is still blocked after closure', () async {
      final product = coffeeProduct();
      pos.addToCart(product, qty: 1);
      // Checkout has begun: a pending order exists for the cart.
      final pendingOrder = pos.prepareCheckoutOrder();
      expect(pendingOrder.status, OrderStatus.pending);

      final productStockBefore = pos.products.firstWhere((p) => p.id == product.id).stock;

      // Shift closes while the payment has not been settled yet.
      await closeCurrentShift();

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<ShiftSaleBlockedException>()),
      );

      // Once a new shift is opened, the same cart can still be settled
      // normally (the in-flight order is not corrupted by the block).
      pos.startNewShift(startingCash: 300000);
      final settled = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

      expect(settled.status, OrderStatus.paid);
      expect(settled.orderNumber, pendingOrder.orderNumber);
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, productStockBefore - 1);
    });

    // ==========================================
    // C. Shift lifecycle
    // ==========================================
    test('Closing an already-closed shift is a no-op', () async {
      await closeCurrentShift();
      final pastCount = pos.pastShifts.length;
      final closedAt = pos.currentShift.closedAt;
      final actualEndingCash = pos.currentShift.actualEndingCash;

      final result = await pos.closeShift(actualEndingCash: 999999, notes: 'duplikat');

      expect(result, isNull, reason: 'No Telegram report for a duplicate closure');
      expect(pos.pastShifts.length, pastCount, reason: 'Shift must not be archived twice');
      expect(pos.currentShift.actualEndingCash, actualEndingCash, reason: 'Archived shift must not be mutated');
      expect(pos.currentShift.closedAt, closedAt);
    });

    test('Starting a new shift while a shift is active does not discard it', () {
      final activeShiftId = pos.currentShift.shiftId;

      final started = pos.startNewShift(startingCash: 750000);

      expect(started, isFalse);
      expect(pos.currentShift.shiftId, activeShiftId);
      expect(pos.currentShift.startingCash, 300000);
    });

    test('Closed-shift guard does not block non-sale owner operations', () async {
      await closeCurrentShift();

      // Owner operations are unrelated to the cashier sale flow and must keep working.
      pos.adjustStock(
        productId: 'PRD-001',
        type: AdjustmentType.add,
        quantity: 5,
        reason: 'Uji regression shift guard',
      );
      expect(pos.stockAdjustments, isNotEmpty);
    });

    test('Demo quick order is also blocked without an active shift', () async {
      await closeCurrentShift();

      expect(pos.loadDemoQuickOrder, throwsA(isA<ShiftSaleBlockedException>()));
      expect(pos.cart, isEmpty);
    });
  });
}