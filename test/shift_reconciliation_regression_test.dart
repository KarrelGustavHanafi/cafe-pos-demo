// Regression coverage for shift-scoped cash reconciliation and unified sales
// metrics (Phase 2A.1).
//
// The bug these guard against: cash reconciliation was derived from
// `todayCashSales`, a date-filtered aggregate. Two shifts on the same calendar
// day, or a shift crossing midnight, made the drawer total wrong. Reconciliation
// is now scoped by `Order.shiftId` membership.
//
// All timestamps are deterministic so the period-window assertions cannot drift.

import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/shift.dart';
import 'package:cafe_pos_demo/screens/shift/shift_closing_screen.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic reference for shift-scoped tests.
///
/// Shift reconciliation is scoped by `shiftId` membership, not by date, so an
/// exact calendar instant is irrelevant there and a fixed constant is used.
final DateTime kReference = DateTime(2026, 3, 15, 14, 0);

/// A timestamp inside the real "today" calendar window.
///
/// The `today...` / `ReportPeriod.today` metrics ARE date-filtered, so orders
/// injected for those assertions must land on the actual current date. Metrics
/// are then compared as deltas from a baseline, because the demo seeds real paid
/// orders for today and the test must not assume an empty trading day.
DateTime todayAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, 0);
}

ShiftInfo shiftWith(String id, {required int startingCash, required bool closed}) {
  return ShiftInfo(
    shiftId: id,
    shiftName: 'Shift $id',
    cashierName: 'Siti Rahma (Kasir)',
    startTime: DateTime(2026, 3, 15, 8, 0),
    startingCash: startingCash,
    isClosed: closed,
    closedAt: closed ? DateTime(2026, 3, 15, 16, 0) : null,
  );
}

void main() {
  PosProvider newProvider() => PosProvider();

  group('expectedEndingCashForShift', () {
    test('1. nonzero opening float plus multiple cash payments', () {
      final pos = newProvider();
      final shift = shiftWith('S-A', startingCash: 500000, closed: false);

      // Three cash sales: 30_000 + 45_000 + 25_000.
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 30000,
        shiftId: 'S-A',
        createdAt: kReference,
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 45000,
        shiftId: 'S-A',
        createdAt: kReference,
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 25000,
        shiftId: 'S-A',
        createdAt: kReference,
      );

      expect(pos.cashSalesForShift('S-A'), 100000);
      expect(pos.expectedEndingCashForShift(shift), 600000);
    });

    test('2. QRIS sales are excluded from expected cash', () {
      final pos = newProvider();
      final shift = shiftWith('S-B', startingCash: 300000, closed: false);

      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 40000,
        shiftId: 'S-B',
        createdAt: kReference,
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.qris,
        grandTotal: 90000,
        shiftId: 'S-B',
        createdAt: kReference,
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.debitCard,
        grandTotal: 70000,
        shiftId: 'S-B',
        createdAt: kReference,
      );

      // Only the physical till moves with cash.
      expect(pos.cashSalesForShift('S-B'), 40000);
      expect(pos.qrisSalesForShift('S-B'), 90000);
      expect(pos.debitSalesForShift('S-B'), 70000);
      expect(pos.expectedEndingCashForShift(shift), 340000);
    });

    test('3. unpaid orders are excluded entirely', () {
      final pos = newProvider();
      final shift = shiftWith('S-C', startingCash: 200000, closed: false);

      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 50000,
        shiftId: 'S-C',
        createdAt: kReference,
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 99000,
        shiftId: 'S-C',
        createdAt: kReference,
        status: OrderStatus.pending,
      );

      expect(pos.getPaidOrdersForShift('S-C').length, 1);
      expect(pos.cashSalesForShift('S-C'), 50000);
      expect(pos.expectedEndingCashForShift(shift), 250000);
    });

    test('4. orders from a previous shift are excluded', () {
      final pos = newProvider();
      final current = shiftWith('S-NEW', startingCash: 300000, closed: false);

      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 150000,
        shiftId: 'S-OLD',
        createdAt: kReference,
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 20000,
        shiftId: 'S-NEW',
        createdAt: kReference,
      );

      expect(pos.cashSalesForShift('S-OLD'), 150000);
      expect(pos.cashSalesForShift('S-NEW'), 20000);
      expect(pos.expectedEndingCashForShift(current), 320000);
    });

    test('9. unknown-origin (null shiftId) cash is excluded, not folded in', () {
      final pos = newProvider();
      final shift = shiftWith('S-D', startingCash: 300000, closed: false);

      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 10000,
        shiftId: 'S-D',
        createdAt: kReference,
      );
      // Legacy/unattributed order: must not leak into S-D's drawer total.
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 77777,
        shiftId: null,
        createdAt: kReference,
      );

      expect(pos.cashSalesForShift('S-D'), 10000);
      expect(pos.expectedEndingCashForShift(shift), 310000);
      // And it is surfaced rather than silently dropped.
      expect(pos.unattributedPaidCashOrders.length, 1);
      expect(pos.unattributedCashTotal, 77777);
    });
  });

  group('reconciliation across shifts and dates', () {
    test('5. a shift opened after a previous shift closes keeps its own drawer', () {
      final pos = newProvider();

      // First shift runs and takes cash.
      final first = shiftWith('SHIFT-FIRST', startingCash: 300000, closed: true);
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 120000,
        shiftId: 'SHIFT-FIRST',
        createdAt: DateTime(2026, 3, 15, 10, 0),
      );
      expect(pos.expectedEndingCashForShift(first), 420000);

      // Second shift opens later the SAME calendar day. This is the case that
      // the old date-scoped math got wrong.
      final second =
          shiftWith('SHIFT-SECOND', startingCash: 400000, closed: false);
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 80000,
        shiftId: 'SHIFT-SECOND',
        createdAt: DateTime(2026, 3, 15, 15, 0),
      );

      // The second shift's drawer must NOT include the first shift's sales.
      expect(pos.cashSalesForShift('SHIFT-SECOND'), 80000);
      expect(pos.expectedEndingCashForShift(second), 480000);
      // And the closed shift's recorded figure is unchanged.
      expect(pos.expectedEndingCashForShift(first), 420000);
    });

    test('6. midnight-crossing shift attribution follows shiftId, not the date', () {
      final pos = newProvider();
      // A shift that opened on the 15th and settles a sale after midnight on
      // the 16th. Membership must win over the calendar-date window.
      final overnight =
          shiftWith('SHIFT-NIGHT', startingCash: 500000, closed: false);

      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 60000,
        shiftId: 'SHIFT-NIGHT',
        createdAt: DateTime(2026, 3, 15, 23, 50),
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 30000,
        shiftId: 'SHIFT-NIGHT',
        createdAt: DateTime(2026, 3, 16, 0, 10),
      );

      // Both land in the same shift regardless of crossing midnight.
      expect(pos.cashSalesForShift('SHIFT-NIGHT'), 90000);
      expect(pos.expectedEndingCashForShift(overnight), 590000);
    });
  });

  group('unified sales metrics', () {
    test('7. dashboard and period report agree for the same range', () {
      final pos = newProvider();
      // Baseline: the demo seeds real paid orders for today.
      final baseTotal = pos.todaySalesTotal;
      final baseCount = pos.todayTransactionsCount;
      final baseCash = pos.todayCashSales;
      final baseQris = pos.todayQrisSales;

      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 35000,
        createdAt: todayAt(10),
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.qris,
        grandTotal: 45000,
        createdAt: todayAt(12),
      );

      // The reconciliation this guards: the `today...` getters the dashboard
      // renders must equal the explicit period report for the same range.
      // Previously these filtered on status alone, so the two could disagree.
      expect(pos.todaySalesTotal, pos.getSalesTotalForPeriod(ReportPeriod.today));
      expect(
        pos.todayTransactionsCount,
        pos.getTransactionsCountForPeriod(ReportPeriod.today),
      );
      expect(pos.todayCashSales, pos.getCashSalesForPeriod(ReportPeriod.today));
      expect(pos.todayQrisSales, pos.getQrisSalesForPeriod(ReportPeriod.today));

      // The injected orders are counted exactly once each.
      expect(pos.todaySalesTotal - baseTotal, 80000);
      expect(pos.todayTransactionsCount - baseCount, 2);
      expect(pos.todayCashSales - baseCash, 35000);
      expect(pos.todayQrisSales - baseQris, 45000);

      // Product counts use the same window as the money totals.
      expect(
        pos.productSalesCounts,
        pos.getProductSalesCountsForPeriod(ReportPeriod.today),
      );
    });

    test('unpaid orders are excluded from every metric family', () {
      final pos = newProvider();
      final baseTotal = pos.todaySalesTotal;
      final baseCount = pos.todayTransactionsCount;
      final baseCash = pos.todayCashSales;

      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 20000,
        createdAt: todayAt(9),
      );
      pos.debugSeedOrderForTest(
        paymentMethod: PaymentMethod.cash,
        grandTotal: 88888,
        createdAt: todayAt(11),
        status: OrderStatus.pending,
      );

      // Only the paid order moved any total.
      expect(pos.todaySalesTotal - baseTotal, 20000);
      expect(pos.todayTransactionsCount - baseCount, 1);
      expect(pos.todayCashSales - baseCash, 20000);
    });
  });

  group('opening cash validation', () {
    test('8. invalid opening cash input is rejected', () {
      expect(ShiftClosingScreen.parseOpeningCash(''), isNull);
      expect(ShiftClosingScreen.parseOpeningCash('   '), isNull);
      expect(ShiftClosingScreen.parseOpeningCash('abc'), isNull);
      expect(ShiftClosingScreen.parseOpeningCash('0'), isNull);
      expect(ShiftClosingScreen.parseOpeningCash('-50000'), isNull);
      // A minus must never be stripped into a positive float.
      expect(ShiftClosingScreen.parseOpeningCash('-1'), isNull);
      expect(ShiftClosingScreen.parseOpeningCash('  -75000  '), isNull);

      // Valid values pass through, tolerating formatting separators.
      expect(ShiftClosingScreen.parseOpeningCash('300000'), 300000);
      expect(ShiftClosingScreen.parseOpeningCash('300.000'), 300000);
      expect(ShiftClosingScreen.parseOpeningCash('Rp 250000'), 250000);
    });

    test('startNewShift refuses to replace an active shift', () {
      final pos = newProvider();
      // The seeded demo shift is already open.
      expect(pos.hasActiveShift, isTrue);
      expect(pos.startNewShift(startingCash: 500000), isFalse);
      // Opening cash must be unchanged by the rejected call.
      expect(pos.currentShift.startingCash, 300000);
    });

    test('startNewShift applies the user-entered float to a fresh shift', () {
      final pos = newProvider();
      pos.closeShift(actualEndingCash: pos.expectedEndingCashForShift(pos.currentShift));

      final before = pos.currentShift.shiftId;
      expect(pos.startNewShift(startingCash: 750000), isTrue);

      final opened = pos.currentShift;
      expect(opened.shiftId, isNot(before));
      expect(opened.startingCash, 750000);
      expect(opened.isClosed, isFalse);
      // A fresh shift draws nothing from the previous one's sales.
      expect(pos.cashSalesForShift(opened.shiftId), 0);
      expect(pos.expectedEndingCashForShift(opened), 750000);
    });
  });

  group('checkout binds orders to the active shift', () {
    test('a new paid order lands in the shift that is open', () {
      final pos = newProvider()..login('cashier', 'cashier123');
      final shift = pos.currentShift.shiftId;

      final product = pos.products.first;
      pos.addToCart(product);
      pos.prepareCheckoutOrder();

      final order = pos.currentOrder;
      expect(order, isNotNull);
      expect(order!.shiftId, shift);
    });
  });

  group('seed attribution policy', () {
    test('seeded demo orders are explicitly bound to the open demo shift', () {
      final pos = newProvider();
      final shift = pos.currentShift.shiftId;

      // Seed orders are attributed in source, not at runtime.
      final seeded = pos.orders.where((o) => o.shiftId == shift).toList();
      expect(seeded, isNotEmpty);
      // No seeded order is left unattributed.
      expect(pos.unattributedCashTotal, 0);
    });
  });
}
