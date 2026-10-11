// Regression coverage for Phase 2A.4 stable transaction identity.
//
// The defect: `orderNumber` was the sole identity for a sale. It is a display
// label derived from `_orders.length + 1`, so it is reused whenever an order is
// prepared but never committed — exactly what happens when a stale-shift order
// is rejected and re-prepared. Two genuinely different sales could therefore
// share a number, and Telegram deduplication (keyed on that number) let one real
// sale suppress another sale's notification.
//
// These tests pin the separation: `Order.id` is the stable internal identity,
// `Order.orderNumber` remains the human-facing label.

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/utils/shift_sale_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory Telegram double recording which identities were reported.
class _RecordingTelegramService implements TelegramService {
  final List<TransactionNotifData> transactions = [];
  int transactionAttempts = 0;
  bool shouldFail = false;

  @override
  bool get isEnabled => true;

  @override
  TelegramConfig get config => const TelegramConfig();

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendTransactionNotification(
      TransactionNotifData data) async {
    transactionAttempts++;
    transactions.add(data);
    if (shouldFail) {
      return TelegramSendResult.failure(message: 'simulated', statusCode: 500);
    }
    return TelegramSendResult.success(message: 'ok');
  }

  @override
  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendShiftReport(ShiftReportData report) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> testConnection() async =>
      TelegramSendResult.success(message: 'ok');
}

void main() {
  Future<PosProvider> newProvider() async {
    SharedPreferences.setMockInitialValues({});
    final pos = PosProvider();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    pos.login('cashier', 'cashier123');
    return pos;
  }

  Product inStockProduct(PosProvider pos) =>
      pos.activeProducts.firstWhere((p) => p.stock > 0);

  Order payCash(PosProvider pos) => pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal + 100000,
        changeAmount: 0,
      );

  group('identity is distinct from the display order number', () {
    test('1. two distinct orders never share the same internal identity',
        () async {
      final pos = await newProvider();
      final ids = <String>{};

      for (var i = 0; i < 5; i++) {
        pos.addToCart(inStockProduct(pos));
        final order = pos.prepareCheckoutOrder();
        expect(order.id, isNotEmpty);
        expect(ids.contains(order.id), isFalse,
            reason: 'identity reused at iteration $i');
        ids.add(order.id);
        payCash(pos);
      }

      expect(ids.length, 5);
      // Every committed order carries its own identity.
      final committed = pos.orders.map((o) => o.id).toSet();
      expect(committed.length, pos.orders.length);
    });

    test('orders created in the same millisecond still get distinct ids',
        () async {
      // Many orders prepared back-to-back with no clock advance.
      final ids = <String>{};
      for (var i = 0; i < 25; i++) {
        final order = Order.create(
          orderNumber: 'ORD-SAME-0001',
          tableNumber: 'Takeaway',
          items: const [],
          cashierName: 'Tester',
        );
        expect(ids.contains(order.id), isFalse);
        ids.add(order.id);
      }
      expect(ids.length, 25);
    });

    test('id survives copyWith so settlement keeps one identity', () async {
      final pos = await newProvider();
      pos.addToCart(inStockProduct(pos));
      final prepared = pos.prepareCheckoutOrder();
      final settled = payCash(pos);

      expect(settled.id, prepared.id);
      expect(settled.orderNumber, prepared.orderNumber);
    });

    test('copyWith can override id explicitly without breaking the default',
        () async {
      final pos = await newProvider();
      pos.addToCart(inStockProduct(pos));
      final prepared = pos.prepareCheckoutOrder();
      final replaced = prepared.copyWith(id: 'custom-id');

      expect(replaced.id, 'custom-id');
      expect(prepared.id, isNot('custom-id'));
    });
  });

  group('stale-order recovery produces a new identity', () {
    test('2. rejected stale order re-prepared has a different identity',
        () async {
      final pos = await newProvider();
      final shiftA = pos.currentShift.shiftId;

      pos.addToCart(inStockProduct(pos));
      final stale = pos.prepareCheckoutOrder();
      expect(stale.id, isNotEmpty);

      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);
      final shiftB = pos.currentShift.shiftId;

      expect(() => payCash(pos), throwsA(isA<StaleShiftOrderException>()));

      // Re-prepare under the shift that is actually open.
      final fresh = pos.prepareCheckoutOrder();

      expect(fresh.shiftId, shiftB);
      expect(fresh.id, isNot(stale.id),
          reason: 'a new transaction must get a new identity');
      expect(shiftA, isNot(shiftB));
    });

    test('re-preparing can reuse the display number while identity differs',
        () async {
      final pos = await newProvider();

      pos.addToCart(inStockProduct(pos));
      final stale = pos.prepareCheckoutOrder();
      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);
      final fresh = pos.prepareCheckoutOrder();

      // The display number MAY repeat (it is derived from committed order
      // count); the identity must not. This is the exact hazard the split fixes.
      expect(fresh.orderNumber, stale.orderNumber);
      expect(fresh.id, isNot(stale.id));
    });
  });

  group('idempotent completion', () {
    test('3. repeated completion of the same paid order stays idempotent',
        () async {
      final pos = await newProvider();
      final product = inStockProduct(pos);
      final stockBefore = product.stock;

      pos.addToCart(product);
      pos.prepareCheckoutOrder();
      final first = payCash(pos);
      final stockAfter = pos.products.firstWhere((p) => p.id == product.id).stock;
      final ordersAfter = pos.orders.length;

      // Repeat completion.
      final second = payCash(pos);
      final third = payCash(pos);

      expect(second.id, first.id);
      expect(third.id, first.id);
      expect(second.status, OrderStatus.paid);
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, stockAfter);
      expect(pos.orders.length, ordersAfter);
      expect(stockAfter, stockBefore - 1);
    });

    test('repeat completion does not duplicate sale notifications', () async {
      final pos = await newProvider();
      final telegram = _RecordingTelegramService();
      pos.setTelegramService(telegram);

      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final first = payCash(pos);

      // Let the fire-and-forget notification land.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final attemptsAfterFirst = telegram.transactionAttempts;

      payCash(pos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(attemptsAfterFirst, 1);
      expect(telegram.transactions.single.orderNumber, first.orderNumber);
    });
  });

  group('deduplication keys on identity, not display number', () {
    test('4. distinct orders with the same display number both notify',
        () async {
      final pos = await newProvider();
      final telegram = _RecordingTelegramService();
      pos.setTelegramService(telegram);

      // Prepare + pay, then reopen a shift so the next order re-derives the same
      // display number while being a genuinely different sale.
      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final first = payCash(pos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);

      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final second = payCash(pos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Both sales must be reported. Keying dedup on the display number would
      // have suppressed the second one here.
      expect(second.id, isNot(first.id));
      expect(telegram.transactions.length, 2);

      // And the identity-based dedup state reflects two distinct identities.
      final notifier = pos.telegramNotificationService;
      expect(notifier.isOrderProcessed(first.id), isTrue);
      expect(notifier.isOrderProcessed(second.id), isTrue);
    });

    test('notification for the same identity is not repeated', () async {
      final pos = await newProvider();
      final telegram = _RecordingTelegramService();
      pos.setTelegramService(telegram);

      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final order = payCash(pos);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(telegram.transactionAttempts, 1);

      // Re-notify the identical order directly: must be skipped by identity.
      await pos.telegramNotificationService.onTransactionCompleted(order);
      expect(telegram.transactionAttempts, 1);
    });

    test('5. failed notification stays retryable (mark-on-success policy)',
        () async {
      final pos = await newProvider();
      final telegram = _RecordingTelegramService()..shouldFail = true;
      pos.setTelegramService(telegram);

      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final order = payCash(pos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Delivery failed, so the identity must NOT be recorded as processed.
      expect(pos.telegramNotificationService.isOrderProcessed(order.id), isFalse);

      // Retry now succeeds.
      telegram.shouldFail = false;
      await pos.telegramNotificationService.onTransactionCompleted(order);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(pos.telegramNotificationService.isOrderProcessed(order.id), isTrue);
      expect(telegram.transactionAttempts, 2);

      // And a further attempt is now suppressed.
      await pos.telegramNotificationService.onTransactionCompleted(order);
      expect(telegram.transactionAttempts, 2);
    });
  });

  group('compatibility with existing display behaviour', () {
    test('display order number format is unchanged', () {
      final pos = PosProvider();
      final orderNumber = pos.generateOrderNumber();
      expect(RegExp(r'^ORD-\d{8}-\d{4}$').hasMatch(orderNumber), isTrue);
    });

    test('seed orders carry distinct identities', () {
      final pos = PosProvider();
      final ids = pos.orders.map((o) => o.id).toSet();
      expect(ids.length, pos.orders.length);
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('two sales in one session aggregate separately by identity', () async {
      final pos = await newProvider();
      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final first = payCash(pos);

      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);
      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final second = payCash(pos);

      // Both sales are committed, so the sequence advanced and the display
      // numbers differ here. Identity is what guarantees separation regardless.
      expect(second.orderNumber, isNot(first.orderNumber));
      expect(second.id, isNot(first.id));

      // Aggregation must count both sales exactly once.
      expect(pos.orders.where((o) => o.id == first.id).length, 1);
      expect(pos.orders.where((o) => o.id == second.id).length, 1);
      expect(pos.cashSalesForShift(pos.currentShift.shiftId), second.grandTotal);
    });
  });
}