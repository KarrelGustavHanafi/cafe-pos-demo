// Locks the cashier order-history contract (Phase 2C.4).
//
// `CashierOrdersScreen` used to re-state the paid rule inline
// (`pos.orders.where((o) => o.status == OrderStatus.paid)`). It now reads
// `pos.paidOrders`, which delegates to `OrderRepository.paidOrders`.
//
// The screen's contract is deliberately NARROW: completed sales across the WHOLE
// history — no date window, no shift scoping, newest first. The tests below pin
// that, because the two neighbouring APIs that look similar are not
// interchangeable:
//
//   * getPaidOrdersForPeriod(period) -> paid AND inside a date window
//   * getPaidOrdersForShift(id)      -> paid AND attributed to one shift
//
// Substituting either would silently change what the cashier sees.

import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/screens/cashier/cashier_orders_screen.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PosProvider pos;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pos = PosProvider();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    pos.login('cashier', 'cashier123');
  });

  /// Injects an order with an exact total, status and shift.
  void seedOrder({
    required int grandTotal,
    OrderStatus status = OrderStatus.paid,
    String? shiftId,
    DateTime? createdAt,
  }) {
    pos.debugSeedOrderForTest(
      paymentMethod: PaymentMethod.cash,
      grandTotal: grandTotal,
      createdAt: createdAt ?? DateTime.now(),
      shiftId: shiftId,
      status: status,
    );
  }

  /// The exact expression the screen used before this change.
  List<Order> previousScreenExpression() =>
      pos.orders.where((o) => o.status == OrderStatus.paid).toList();

  group('paidOrders preserves the previous screen behaviour exactly', () {
    test('returns the identical set and ordering as the old inline filter',
        () {
      seedOrder(grandTotal: 1000);
      seedOrder(grandTotal: 2000, status: OrderStatus.pending);
      seedOrder(grandTotal: 3000);

      expect(
        pos.paidOrders.map((o) => o.id).toList(),
        previousScreenExpression().map((o) => o.id).toList(),
        reason: 'same members, same order',
      );
    });

    test('excludes unpaid orders', () {
      seedOrder(grandTotal: 1000);
      seedOrder(grandTotal: 2000, status: OrderStatus.pending);

      expect(pos.paidOrders.every((o) => o.status == OrderStatus.paid), isTrue);
      expect(pos.paidOrders.length, previousScreenExpression().length);
      expect(pos.paidOrders.any((o) => o.status == OrderStatus.pending), isFalse);
    });

    test('is newest-first', () {
      seedOrder(grandTotal: 1000);
      seedOrder(grandTotal: 2000);
      seedOrder(grandTotal: 3000);

      // `insert` prepends, so the most recently added must lead.
      expect(pos.paidOrders.first.grandTotal, 3000);
      expect(pos.paidOrders.map((o) => o.grandTotal).toList(),
          previousScreenExpression().map((o) => o.grandTotal).toList());
    });

    test('has NO date constraint: history from other days is included', () {
      final now = DateTime.now();
      // The demo seeds paid orders into the open shift, so measure a delta.
      final before = pos.paidOrders.length;

      seedOrder(
          grandTotal: 1000,
          createdAt: now.subtract(const Duration(days: 9)));
      seedOrder(grandTotal: 2000, createdAt: now);

      expect(pos.paidOrders.length - before, 2,
          reason: 'a 9-day-old sale is still part of order history');
      // Contrast with the period API, which would return only today's sale.
      expect(pos.getPaidOrdersForPeriod(ReportPeriod.today).length,
          lessThan(pos.paidOrders.length),
          reason: 'the period API is a DIFFERENT question and must not be used');
    });

    test('has NO shift constraint: other shifts are included', () {
      final mine = pos.currentShift.shiftId;
      final before = pos.paidOrders.length;

      seedOrder(grandTotal: 1000, shiftId: mine);
      seedOrder(grandTotal: 2000, shiftId: 'SOME-OTHER-SHIFT');
      seedOrder(grandTotal: 3000, shiftId: null);

      expect(pos.paidOrders.length - before, 3,
          reason: 'history spans every shift, including unattributed orders');
      // Contrast with the shift API, which would return only this shift's sale.
      expect(pos.getPaidOrdersForShift(mine).length, lessThan(pos.paidOrders.length));
    });
  });

  group('CashierOrdersScreen consumes the same set', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CashierOrdersScreen(pos: pos, onViewReceipt: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('header count equals the paid order count', (tester) async {
      seedOrder(grandTotal: 1000);
      seedOrder(grandTotal: 2000, status: OrderStatus.pending);
      seedOrder(grandTotal: 3000);

      await pump(tester);

      // The seeded demo orders are also paid, so compare against the same
      // source of truth the screen renders rather than a hand-counted number.
      expect(
        find.text('Pesanan Selesai (${pos.paidOrders.length})'),
        findsOneWidget,
      );
    });

    testWidgets('pending orders are not listed', (tester) async {
      seedOrder(grandTotal: 1000, status: OrderStatus.pending);
      // Ensure at least one paid order exists so the list renders.
      seedOrder(grandTotal: 2000);

      await pump(tester);

      expect(find.text('Pesanan Selesai (${pos.paidOrders.length})'),
          findsOneWidget);
    });
  });
}