// Regression coverage for the Phase 2A.2 close-shift review findings.
//
//   1. An order prepared under shift A must not be settled while shift B is
//      open (it would post cash into a closed drawer).
//   2. A refused stale order must mutate nothing: no stock deduction, no
//      successful-sale notification.
//   3. The cashier can recover by preparing the sale again under the open
//      shift.
//   4. Re-paying an already-paid order stays idempotent.
//   5. The shift-closed report must carry shift-scoped figures.
//   6. A notification failure must not undo a completed shift close.
//   7. Counted-cash input must be parsed strictly.
//
// All Telegram interaction goes through an injected in-memory double; no test
// contacts the real Telegram API.

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/screens/shift/shift_closing_screen.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/utils/shift_sale_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory Telegram double. Records every outbound payload so tests can
/// assert on the exact figures a shift report carried, and can be told to throw
/// to prove a reporting failure cannot roll back a business operation.
class _RecordingTelegramService implements TelegramService {
  final List<ShiftReportData> shiftReports = [];
  int transactionNotifications = 0;
  int shiftOpenNotifications = 0;
  bool shouldFail = false;
  bool shouldThrow = false;

  @override
  bool get isEnabled => true;

  @override
  TelegramConfig get config => const TelegramConfig();

  Future<TelegramSendResult> _result(String label) async {
    if (shouldThrow) {
      throw StateError('simulated transport explosion ($label)');
    }
    if (shouldFail) {
      return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
    }
    return TelegramSendResult.success(message: 'ok: $label');
  }

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) =>
      _result('message');

  @override
  Future<TelegramSendResult> sendTransactionNotification(
      TransactionNotifData data) async {
    transactionNotifications++;
    return _result('transaction');
  }

  @override
  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data) =>
      _result('inventory');

  @override
  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items) =>
      _result('lowStock');

  @override
  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data) async {
    shiftOpenNotifications++;
    return _result('shiftOpen');
  }

  @override
  Future<TelegramSendResult> sendShiftReport(ShiftReportData report) async {
    shiftReports.add(report);
    return _result('shiftReport');
  }

  @override
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) =>
      _result('dailyReport');

  @override
  Future<TelegramSendResult> testConnection() => _result('testConnection');
}

void main() {
  late _RecordingTelegramService telegram;

  /// Builds a provider with an in-memory Telegram double installed.
  Future<PosProvider> newProvider() async {
    SharedPreferences.setMockInitialValues({});
    final pos = PosProvider();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    pos.login('cashier', 'cashier123');
    telegram = _RecordingTelegramService();
    pos.setTelegramService(telegram);
    return pos;
  }

  Product inStockProduct(PosProvider pos) =>
      pos.activeProducts.firstWhere((p) => p.stock > 0);

  /// Settles the cart as cash with a generous tender.
  Order payCash(PosProvider pos) => pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal + 100000,
        changeAmount: 0,
      );

  group('1-3. stale order prepared under a closed shift', () {
    test('1. cannot be paid once a different shift is active', () async {
      final pos = await newProvider();
      final shiftA = pos.currentShift.shiftId;
      // The demo seeds paid orders into the open shift, so compare deltas.
      final shiftACashBefore = pos.cashSalesForShift(shiftA);

      pos.addToCart(inStockProduct(pos));
      final stale = pos.prepareCheckoutOrder();
      expect(stale.shiftId, shiftA);

      await pos.closeShift(actualEndingCash: pos.expectedEndingCashForShift(pos.currentShift));
      pos.startNewShift(startingCash: 400000);
      final shiftB = pos.currentShift.shiftId;
      expect(shiftB, isNot(shiftA));

      // The in-flight order must be refused, not silently re-homed.
      expect(
        () => payCash(pos),
        throwsA(isA<StaleShiftOrderException>()),
      );
      // And it must not have been settled into either shift.
      expect(pos.cashSalesForShift(shiftA), shiftACashBefore);
      expect(pos.cashSalesForShift(shiftB), 0);
    });

    test('2. refusal deducts no stock and sends no sale notification',
        () async {
      final pos = await newProvider();
      final product = inStockProduct(pos);
      final stockBefore = product.stock;
      final ordersBefore = pos.orders.length;
      final txNotificationsBefore = telegram.transactionNotifications;

      pos.addToCart(product);
      pos.prepareCheckoutOrder();
      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);

      expect(() => payCash(pos), throwsA(isA<StaleShiftOrderException>()));

      // No mutation whatsoever.
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, stockBefore);
      expect(pos.orders.length, ordersBefore);
      expect(telegram.transactionNotifications, txNotificationsBefore);
    });

    test('3. cashier can prepare again under the open shift and settle',
        () async {
      final pos = await newProvider();
      final product = inStockProduct(pos);
      final stockBefore = product.stock;
      final ordersBefore = pos.orders.length;

      pos.addToCart(product);
      final stale = pos.prepareCheckoutOrder();
      final shiftACashBefore = pos.cashSalesForShift(stale.shiftId!);
      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);
      final shiftB = pos.currentShift.shiftId;

      expect(() => payCash(pos), throwsA(isA<StaleShiftOrderException>()));

      // Recovery: prepare again under the shift that is actually open.
      final fresh = pos.prepareCheckoutOrder();
      expect(fresh.shiftId, shiftB);

      final settled = payCash(pos);
      expect(settled.status, OrderStatus.paid);
      expect(settled.shiftId, shiftB);

      // Exactly one order was recorded and stock moved once.
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, stockBefore - 1);
      expect(pos.orders.length, ordersBefore + 1);
      expect(pos.cashSalesForShift(shiftB), settled.grandTotal);
      // The closed shift gained nothing from the recovered sale.
      expect(pos.cashSalesForShift(stale.shiftId!), shiftACashBefore);
    });

    test('rejected stale order leaves no dangling paid order in history',
        () async {
      final pos = await newProvider();
      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);

      final ordersBefore = pos.orders.length;
      expect(() => payCash(pos), throwsA(isA<StaleShiftOrderException>()));
      expect(pos.orders.length, ordersBefore);
      expect(pos.todayTransactionsCount,
          pos.getTransactionsCountForPeriod(ReportPeriod.today));
    });
  });

  group('4. idempotent payment', () {
    test('4. repeating payment for a paid order does not duplicate work',
        () async {
      final pos = await newProvider();
      final product = inStockProduct(pos);
      final stockBefore = product.stock;

      pos.addToCart(product);
      pos.prepareCheckoutOrder();
      final first = payCash(pos);
      expect(first.status, OrderStatus.paid);

      final stockAfterFirst = pos.products.firstWhere((p) => p.id == product.id).stock;
      final ordersAfterFirst = pos.orders.length;
      final txAfterFirst = telegram.transactionNotifications;

      // Second attempt on the same order is a no-op.
      final second = payCash(pos);

      expect(second.orderNumber, first.orderNumber);
      expect(second.status, OrderStatus.paid);
      expect(pos.products.firstWhere((p) => p.id == product.id).stock, stockAfterFirst);
      expect(pos.orders.length, ordersAfterFirst);
      expect(telegram.transactionNotifications, txAfterFirst);
      expect(stockAfterFirst, stockBefore - 1);
    });
  });

  group('5-6. shift-closed report figures', () {
    test('5. report carries shift-scoped totals, not day totals', () async {
      final pos = await newProvider();
      final shiftA = pos.currentShift.shiftId;

      // A cash sale in shift A. The seeded demo orders also belong to shift A,
      // so expectations are the shift's own aggregates, not this single sale.
      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      payCash(pos);

      final expectedTotal = pos.totalSalesForShift(shiftA);
      final expectedCash = pos.cashSalesForShift(shiftA);
      final expectedQris = pos.qrisSalesForShift(shiftA);
      final expectedDebit = pos.debitSalesForShift(shiftA);
      final expectedCount = pos.transactionCountForShift(shiftA);
      final startingCash = pos.currentShift.startingCash;

      await pos.closeShift(actualEndingCash: 0);

      expect(telegram.shiftReports.length, 1);
      final report = telegram.shiftReports.single;

      // The report must agree with the on-screen shift figures exactly.
      expect(report.totalSales, expectedTotal);
      expect(report.cashSales, expectedCash);
      expect(report.qrisSales, expectedQris);
      expect(report.debitSales, expectedDebit);
      expect(report.totalTransactions, expectedCount);

      // Non-cash tender must never reach the drawer expectation.
      expect(report.startingCash, startingCash);
      expect(report.expectedEndingCash, startingCash + report.cashSales);
      expect(report.expectedEndingCash,
          lessThan(report.startingCash + report.totalSales));

      // Payment methods partition the shift total exactly.
      expect(report.cashSales + report.qrisSales + report.debitSales,
          report.totalSales);
    });

    test('5b. a second shift does not inherit the first shift sales', () async {
      final pos = await newProvider();
      final shiftA = pos.currentShift.shiftId;
      final cashABefore = pos.cashSalesForShift(shiftA);

      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final orderA = payCash(pos);
      await pos.closeShift(actualEndingCash: 0);

      pos.startNewShift(startingCash: 500000);
      final shiftB = pos.currentShift.shiftId;
      // The new shift starts from a clean drawer.
      expect(pos.cashSalesForShift(shiftB), 0);

      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();
      final orderB = payCash(pos);
      await pos.closeShift(actualEndingCash: 0);

      expect(telegram.shiftReports.length, 2);
      // Recorded in call order: shift A was closed first.
      final reportA = telegram.shiftReports.first;
      final reportB = telegram.shiftReports.last;

      // Each report describes only its own shift.
      expect(reportA.cashSales, cashABefore + orderA.grandTotal);
      expect(reportB.cashSales, orderB.grandTotal);
      expect(reportB.totalTransactions, 1);

      // The second report must NOT repeat the first shift's sales: the old
      // day-scoped implementation would have reported both here.
      expect(reportB.totalSales, orderB.grandTotal);
      expect(reportB.totalSales, lessThan(reportA.totalSales));
      expect(shiftA, isNot(shiftB));
    });

    test('6. notification failure does not reverse the closed shift', () async {
      final pos = await newProvider();

      telegram.shouldFail = true;
      final result = await pos.closeShift(actualEndingCash: 123456);
      expect(result?.success, isFalse);

      // The shift is genuinely closed and archived.
      expect(pos.hasActiveShift, isFalse);
      expect(pos.pastShifts.first.actualEndingCash, 123456);

      telegram.shouldThrow = true;
      final result2 = await pos.closeShift(actualEndingCash: 0);
      // Already closed: no-op, and no exception escapes.
      expect(result2, isNull);
      expect(pos.pastShifts.first.actualEndingCash, 123456);
    });
  });

  group('7. counted cash parsing', () {
    test('accepts zero and valid positive amounts', () {
      expect(ShiftClosingScreen.parseActualCash('0'), 0);
      expect(ShiftClosingScreen.parseActualCash('125000'), 125000);
    });

    test('accepts formatted Rupiah input already used by this UI', () {
      expect(ShiftClosingScreen.parseActualCash('300.000'), 300000);
      expect(ShiftClosingScreen.parseActualCash('Rp 250000'), 250000);
      expect(ShiftClosingScreen.parseActualCash('1.500.000'), 1500000);
      expect(ShiftClosingScreen.parseActualCash('  400000  '), 400000);
    });

    test('rejects empty, negative, malformed, 1e5 and overflow as null', () {
      expect(ShiftClosingScreen.parseActualCash(''), isNull);
      expect(ShiftClosingScreen.parseActualCash('   '), isNull);
      expect(ShiftClosingScreen.parseActualCash('-1'), isNull);
      expect(ShiftClosingScreen.parseActualCash('-50000'), isNull);
      expect(ShiftClosingScreen.parseActualCash('abc'), isNull);
      expect(ShiftClosingScreen.parseActualCash('1e5'), isNull);
      expect(ShiftClosingScreen.parseActualCash('12abc34'), isNull);
      expect(ShiftClosingScreen.parseActualCash('99999999999999999999'), isNull);
    });

    test('opening-cash parser still rejects zero (float must be > 0)', () {
      expect(ShiftClosingScreen.parseOpeningCash('0'), isNull);
      expect(ShiftClosingScreen.parseOpeningCash('300000'), 300000);
      expect(ShiftClosingScreen.parseOpeningCash('300.000'), 300000);
    });
  });
}