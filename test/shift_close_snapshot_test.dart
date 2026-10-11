// Locks the close-time shift snapshot (Phase 2C.3).
//
// The defect: a CLOSED shift's figures were recomputed from the live order list
// every time the owner screen rendered. A historical shift's totals therefore
// changed whenever an unrelated order was added or another shift was opened,
// and seeded historical shifts (which have no orders at all) showed nothing
// verifiable — only an authored `actualEndingCash` constant.
//
// Now `PosProvider.closeShift` freezes a `ShiftCloseSummary` onto the shift
// before mutating shift state, and closed-shift figures are READ from it.
//
// These tests assert observable state only. No Telegram message is sent: an
// in-memory double is injected, and failures are induced by throwing from it.

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/shift.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory Telegram double. Throws on demand to prove a reporting failure
/// cannot undo a completed close or destroy the snapshot.
class _RecordingTelegramService implements TelegramService {
  final List<ShiftReportData> shiftReports = [];
  bool shouldThrow = false;

  @override
  bool get isEnabled => true;

  @override
  TelegramConfig get config => const TelegramConfig();

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async {
    if (shouldThrow) throw StateError('simulated transport explosion');
    return TelegramSendResult.success(message: 'ok');
  }

  @override
  Future<TelegramSendResult> sendTransactionNotification(
          TransactionNotifData data) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data) async {
    if (shouldThrow) throw StateError('simulated transport explosion');
    return TelegramSendResult.success(message: 'ok');
  }

  @override
  Future<TelegramSendResult> sendShiftReport(ShiftReportData report) async {
    if (shouldThrow) throw StateError('simulated transport explosion');
    shiftReports.add(report);
    return TelegramSendResult.success(message: 'ok');
  }

  @override
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> testConnection() async =>
      TelegramSendResult.success(message: 'ok');
}

void main() {
  late PosProvider pos;
  late _RecordingTelegramService telegram;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pos = PosProvider();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    pos.login('cashier', 'cashier123');
    telegram = _RecordingTelegramService();
    pos.setTelegramService(telegram);
  });

  /// Injects an order with an exact total, shift and method.
  void seedOrder({
    required int grandTotal,
    String? shiftId,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    OrderStatus status = OrderStatus.paid,
  }) {
    pos.debugSeedOrderForTest(
      paymentMethod: paymentMethod,
      grandTotal: grandTotal,
      createdAt: DateTime.now(),
      shiftId: shiftId,
      status: status,
    );
  }

  Future<TelegramSendResult?> close() =>
      pos.closeShift(actualEndingCash: pos.currentShift.startingCash);

  /// The demo seeds real paid orders into the open shift, so every snapshot
  /// assertion is a DELTA against the figures already attributed to it.
  ({int total, int cash, int qris, int debit, int count}) baseline(String shiftId) {
    return (
      total: pos.totalSalesForShift(shiftId),
      cash: pos.cashSalesForShift(shiftId),
      qris: pos.qrisSalesForShift(shiftId),
      debit: pos.debitSalesForShift(shiftId),
      count: pos.transactionCountForShift(shiftId),
    );
  }

  group('snapshot content', () {
    test('records paid total, cash, QRIS, debit and transaction count',
        () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);

      seedOrder(grandTotal: 10000, shiftId: shiftId, paymentMethod: PaymentMethod.cash);
      seedOrder(grandTotal: 20000, shiftId: shiftId, paymentMethod: PaymentMethod.cash);
      seedOrder(grandTotal: 30000, shiftId: shiftId, paymentMethod: PaymentMethod.qris);
      seedOrder(grandTotal: 40000, shiftId: shiftId, paymentMethod: PaymentMethod.debitCard);

      await close();

      final summary = pos.pastShifts.first.summary;
      expect(summary, isNotNull);
      expect(summary!.totalSales - base.total, 100000);
      expect(summary.cashSales - base.cash, 30000);
      expect(summary.qrisSales - base.qris, 30000);
      expect(summary.debitSales - base.debit, 40000);
      expect(summary.paidTransactionCount - base.count, 4);

      // Tender must partition the total exactly.
      expect(summary.cashSales + summary.qrisSales + summary.debitSales,
          summary.totalSales);
    });

    test('unpaid orders are excluded', () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);
      seedOrder(grandTotal: 10000, shiftId: shiftId);
      seedOrder(
          grandTotal: 99000,
          shiftId: shiftId,
          status: OrderStatus.pending);

      await close();

      final summary = pos.pastShifts.first.summary!;
      expect(summary.totalSales - base.total, 10000);
      expect(summary.paidTransactionCount - base.count, 1);
    });

    test('orders belonging to another shift are excluded', () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);
      seedOrder(grandTotal: 10000, shiftId: shiftId);
      seedOrder(grandTotal: 70000, shiftId: 'SOME-OTHER-SHIFT');

      await close();

      final summary = pos.pastShifts.first.summary!;
      expect(summary.totalSales - base.total, 10000,
          reason: 'a foreign shift must not inflate this snapshot');
      expect(summary.paidTransactionCount - base.count, 1);
    });

    test('orders with no shift are excluded, not folded in', () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);
      final orphanBefore = pos.unattributedCashTotal;
      seedOrder(grandTotal: 10000, shiftId: shiftId);
      seedOrder(grandTotal: 55555, shiftId: null);

      await close();

      final summary = pos.pastShifts.first.summary!;
      expect(summary.totalSales - base.total, 10000);
      // The orphan stays visible through the dedicated diagnostic.
      expect(pos.unattributedCashTotal - orphanBefore, 55555);
    });

    test('expected ending cash derives from the snapshot, not the live list',
        () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);
      final float = pos.currentShift.startingCash;
      seedOrder(grandTotal: 25000, shiftId: shiftId);

      await close();

      final closed = pos.pastShifts.first;
      expect(closed.summary!.cashSales - base.cash, 25000);
      expect(closed.expectedEndingCash, float + closed.summary!.cashSales);
    });
  });

  group('snapshot is recorded before archival and is immutable afterwards', () {
    test('the closed shift carries a snapshot at the moment of close',
        () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);
      seedOrder(grandTotal: 30000, shiftId: shiftId);

      await close();

      // Archived shift is the first entry, and already summarised.
      final closed = pos.pastShifts.first;
      expect(closed.isClosed, isTrue);
      expect(closed.summary, isNotNull);
      expect(closed.summary!.cashSales - base.cash, 30000);
      expect(closed.closedAt, isNotNull);
    });

    test('opening a new shift does not alter a closed shift snapshot',
        () async {
      final shiftId = pos.currentShift.shiftId;
      seedOrder(grandTotal: 30000, shiftId: shiftId);
      await close();

      final closedId = pos.pastShifts.first.shiftId;
      final before = pos.pastShifts.first.summary;

      pos.startNewShift(startingCash: 900000);

      final after = pos.pastShifts.firstWhere((s) => s.shiftId == closedId);
      expect(after.summary!.totalSales, before!.totalSales);
      expect(after.summary!.cashSales, before.cashSales);
      expect(after.summary!.paidTransactionCount, before.paidTransactionCount);
      // And the new shift starts from a clean slate.
      expect(pos.currentShift.summary, isNull);
    });

    test('orders added after close do not change the closed snapshot',
        () async {
      final shiftId = pos.currentShift.shiftId;
      seedOrder(grandTotal: 30000, shiftId: shiftId);
      await close();

      final closedId = pos.pastShifts.first.shiftId;
      final before = pos.pastShifts.first.summary!.totalSales;
      final liveBefore = pos.totalSalesForShift(closedId);

      // A later order that still carries the OLD shift id.
      seedOrder(grandTotal: 500000, shiftId: closedId);

      final after = pos.pastShifts.firstWhere((s) => s.shiftId == closedId);
      expect(after.summary!.totalSales, before,
          reason: 'the frozen snapshot must not recompute from later orders');
      // The live aggregate did move; the snapshot deliberately did not.
      expect(pos.totalSalesForShift(closedId), liveBefore + 500000);
    });

    test('a second shift closing does not disturb the first snapshot',
        () async {
      final firstShiftId = pos.currentShift.shiftId;
      seedOrder(grandTotal: 10000, shiftId: firstShiftId);
      await close();

      final firstBefore = pos.pastShifts.first.summary!;

      pos.startNewShift(startingCash: 400000);
      final secondShiftId = pos.currentShift.shiftId;
      seedOrder(grandTotal: 90000, shiftId: secondShiftId);
      await close();

      final firstAfter =
          pos.pastShifts.firstWhere((s) => s.shiftId == firstShiftId).summary!;
      expect(firstAfter.totalSales, firstBefore.totalSales);
      expect(firstAfter.cashSales, firstBefore.cashSales);
      expect(firstShiftId, isNot(secondShiftId));

      // The newest shift carries its own distinct snapshot.
      expect(pos.pastShifts.first.summary!.totalSales, 90000);
    });
  });

  group('notification failure cannot undo the close', () {
    test('a throwing notification leaves the shift closed with its snapshot',
        () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);
      seedOrder(grandTotal: 30000, shiftId: shiftId);

      telegram.shouldThrow = true;
      final result = await close();

      // The failure is surfaced as a failed result, never as a thrown
      // exception that could be mistaken for a broken close.
      expect(result, isNotNull);
      expect(result!.success, isFalse);

      // Critically: the business operation still completed.
      expect(pos.hasActiveShift, isFalse);
      expect(pos.pastShifts.first.isClosed, isTrue);
      expect(pos.pastShifts.first.summary, isNotNull,
          reason: 'the snapshot survives a reporting failure');
      expect(pos.pastShifts.first.summary!.cashSales - base.cash, 30000);
      expect(pos.pastShifts.first.closedAt, isNotNull);
    });
  });

  group('seeded historical shifts without a snapshot', () {
    test('have summary == null rather than invented zeros', () {
      final seeded = pos.pastShifts;
      expect(seeded, isNotEmpty, reason: 'demo seeds historical shifts');

      for (final shift in seeded) {
        expect(shift.isClosed, isTrue);
        expect(shift.summary, isNull,
            reason: 'seed shifts have no recorded breakdown and must not fake one');
        // Expected cash cannot be derived without a snapshot, so it stays null
        // and the UI renders "not available".
        expect(shift.expectedEndingCash, isNull);
      }
    });

    test('an open shift has no snapshot until it is closed', () {
      expect(pos.currentShift.isClosed, isFalse);
      expect(pos.currentShift.summary, isNull);
      expect(pos.currentShift.expectedEndingCash, isNull);
    });
  });

  group('telegram report and snapshot agree', () {
    test('the notification carries the same figures the snapshot froze',
        () async {
      final shiftId = pos.currentShift.shiftId;
      final base = baseline(shiftId);
      final float = pos.currentShift.startingCash;
      seedOrder(grandTotal: 15000, shiftId: shiftId, paymentMethod: PaymentMethod.cash);
      seedOrder(grandTotal: 25000, shiftId: shiftId, paymentMethod: PaymentMethod.qris);

      await close();

      final summary = pos.pastShifts.first.summary!;
      expect(telegram.shiftReports.length, 1);
      final report = telegram.shiftReports.first;

      expect(report.totalSales, summary.totalSales);
      expect(report.cashSales, summary.cashSales);
      expect(report.qrisSales, summary.qrisSales);
      expect(report.debitSales, summary.debitSales);
      expect(report.totalTransactions, summary.paidTransactionCount);
      // The drawer expectation is float + cash only; QRIS never enters it.
      expect(report.expectedEndingCash, float + summary.cashSales);
      expect(summary.cashSales - base.cash, 15000);
    });
  });

  group('model invariants', () {
    test('copyWith carries the summary forward unchanged', () {
      const summary = ShiftCloseSummary(
        totalSales: 100,
        cashSales: 40,
        qrisSales: 30,
        debitSales: 30,
        paidTransactionCount: 3,
      );
      final shift = ShiftInfo(
        shiftId: 'S1',
        shiftName: 'Test',
        cashierName: 'Tester',
        startTime: DateTime(2026, 3, 15, 8),
        startingCash: 500000,
        isClosed: true,
        summary: summary,
      );

      final copied = shift.copyWith(closingNotes: 'ok');
      expect(copied.summary, same(summary));
      expect(copied.expectedEndingCash, 500040);
    });

    test('expectedEndingCash is null when there is no snapshot', () {
      final shift = ShiftInfo(
        shiftId: 'S1',
        shiftName: 'Test',
        cashierName: 'Tester',
        startTime: DateTime(2026, 3, 15, 8),
        startingCash: 500000,
        actualEndingCash: 852000,
      );

      expect(shift.summary, isNull);
      expect(shift.expectedEndingCash, isNull,
          reason: 'a missing snapshot must never read as a balanced drawer');
    });
  });
}