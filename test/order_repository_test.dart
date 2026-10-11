// Tests for the OrderRepository contract (Phase 2B).
//
// The repository owns storage and SELECTION of orders. These tests pin the
// query semantics that PosProvider previously re-implemented inline seven
// times, where a divergence between two reports was possible.
//
// Everything is deterministic: fixed timestamps, no clock reads.

import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/repositories/order_repository.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an order with an exact, caller-controlled total.
///
/// Constructed directly (tax/service zeroed) so the grand total the test states
/// is the grand total the model stores.
Order makeOrder({
  required String orderNumber,
  required int grandTotal,
  PaymentMethod paymentMethod = PaymentMethod.cash,
  OrderStatus status = OrderStatus.paid,
  String? shiftId,
  required DateTime createdAt,
  String? id,
}) {
  return Order(
    id: id ?? 'id-$orderNumber-$createdAt.microsecondsSinceEpoch',
    orderNumber: orderNumber,
    tableNumber: 'Takeaway',
    items: const [],
    subtotal: grandTotal,
    serviceCharge: 0,
    tax: 0,
    grandTotal: grandTotal,
    paymentMethod: paymentMethod,
    status: status,
    paidAmount: status == OrderStatus.paid ? grandTotal : 0,
    createdAt: createdAt,
    cashierName: 'Siti Rahma (Kasir)',
    shiftId: shiftId,
  );
}

DateTime at(int day, [int hour = 12]) => DateTime(2026, 3, day, hour, 0);

void main() {
  group('storage contract', () {
    test('starts empty', () {
      final repo = InMemoryOrderRepository();
      expect(repo.all, isEmpty);
      expect(repo.count, 0);
    });

    test('insert stores newest first', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(orderNumber: 'A', grandTotal: 10, createdAt: at(1)));
      repo.insert(makeOrder(orderNumber: 'B', grandTotal: 20, createdAt: at(2)));

      expect(repo.count, 2);
      expect(repo.all.first.orderNumber, 'B');
      expect(repo.all.last.orderNumber, 'A');
    });

    test('replaceAll seeds and overwrites', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(orderNumber: 'OLD', grandTotal: 5, createdAt: at(1)));

      repo.replaceAll([
        makeOrder(orderNumber: 'N1', grandTotal: 1, createdAt: at(2)),
        makeOrder(orderNumber: 'N2', grandTotal: 2, createdAt: at(3)),
      ]);

      expect(repo.count, 2);
      // Order is preserved: first supplied becomes newest (index 0).
      expect(repo.all.first.orderNumber, 'N1');
      expect(
        repo.all.any((o) => o.orderNumber == 'OLD'),
        isFalse,
        reason: 'replaceAll must overwrite, not append',
      );
    });

    test('all is unmodifiable so callers cannot corrupt storage', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(orderNumber: 'A', grandTotal: 10, createdAt: at(1)));

      expect(() => repo.all.add(
          makeOrder(orderNumber: 'X', grandTotal: 1, createdAt: at(1))),
          throwsUnsupportedError);
      expect(repo.count, 1);
    });

    test('truncateTo drops the newest entries (rollback seam)', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(orderNumber: 'A', grandTotal: 1, createdAt: at(1)));
      repo.insert(makeOrder(orderNumber: 'B', grandTotal: 2, createdAt: at(2)));
      repo.insert(makeOrder(orderNumber: 'C', grandTotal: 3, createdAt: at(3)));
      expect(repo.count, 3);

      repo.truncateTo(1);
      expect(repo.count, 1);
      expect(repo.all.single.orderNumber, 'C',
          reason: 'truncation must remove the newest entries');

      // Truncating to the current length is a no-op, not an error.
      repo.truncateTo(1);
      expect(repo.count, 1);
    });

    test('findById resolves by stable identity', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(
          id: 'stable-1', orderNumber: 'A', grandTotal: 10, createdAt: at(1)));

      expect(repo.findById('stable-1')?.orderNumber, 'A');
      expect(repo.findById('missing'), isNull);
    });

    test('two orders may share a display number but not an identity', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(
          id: 'id-1', orderNumber: 'ORD-DUP', grandTotal: 10, createdAt: at(1)));
      repo.insert(makeOrder(
          id: 'id-2', orderNumber: 'ORD-DUP', grandTotal: 20, createdAt: at(2)));

      expect(repo.count, 2);
      expect(repo.findById('id-1')?.grandTotal, 10);
      expect(repo.findById('id-2')?.grandTotal, 20);
    });
  });

  group('paid-only query', () {
    test('excludes pending and cancelled orders', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(
          orderNumber: 'P', grandTotal: 10, createdAt: at(1)));
      repo.insert(makeOrder(
          orderNumber: 'Q',
          grandTotal: 20,
          status: OrderStatus.pending,
          createdAt: at(1)));
      repo.insert(makeOrder(
          orderNumber: 'C',
          grandTotal: 30,
          status: OrderStatus.cancelled,
          createdAt: at(1)));

      final paid = repo.paidOrders;
      expect(paid.length, 1);
      expect(paid.single.orderNumber, 'P');
    });

    test('paidOrders does not filter by shift or date', () {
      final repo = InMemoryOrderRepository();
      repo.insert(makeOrder(
          orderNumber: 'A', grandTotal: 1, shiftId: 'S1', createdAt: at(1)));
      repo.insert(makeOrder(
          orderNumber: 'B',
          grandTotal: 2,
          shiftId: null,
          createdAt: DateTime(2020, 1, 1)));

      expect(repo.paidOrders.length, 2,
          reason: 'paid-only is a status question, not a scope question');
    });
  });

  group('shift filter', () {
    late OrderRepository repo;

    setUp(() {
      repo = InMemoryOrderRepository([
        makeOrder(
            orderNumber: 'A',
            grandTotal: 10000,
            shiftId: 'SHIFT-A',
            createdAt: at(15)),
        makeOrder(
            orderNumber: 'B',
            grandTotal: 20000,
            shiftId: 'SHIFT-B',
            createdAt: at(15)),
        makeOrder(
            orderNumber: 'C',
            grandTotal: 30000,
            shiftId: 'SHIFT-A',
            createdAt: at(16, 0)),
        makeOrder(
            orderNumber: 'D',
            grandTotal: 40000,
            shiftId: null,
            createdAt: at(15)),
        makeOrder(
            orderNumber: 'E',
            grandTotal: 50000,
            shiftId: 'SHIFT-A',
            status: OrderStatus.pending,
            createdAt: at(15)),
      ]);
    });

    test('returns only paid orders of that shift', () {
      final forA = repo.paidOrdersForShift('SHIFT-A');
      expect(forA.map((o) => o.orderNumber).toSet(), {'A', 'C'});
      expect(forA.every((o) => o.status == OrderStatus.paid), isTrue);
    });

    test('a midnight-crossing shift keeps both its sales', () {
      // Order C is dated the 16th yet belongs to SHIFT-A. Membership must win
      // over the calendar date, which is what a date-window filter cannot do.
      final forA = repo.paidOrdersForShift('SHIFT-A');
      expect(forA.any((o) => o.createdAt.day == 16), isTrue);
      expect(forA.fold<int>(0, (s, o) => s + o.grandTotal), 40000);
    });

    test('a null shiftId query returns nothing rather than everything', () {
      expect(repo.paidOrdersForShift(null), isEmpty);
      expect(
        repo.paidOrdersForShift(null).any((o) => o.orderNumber == 'D'),
        isFalse,
      );
    });

    test('unattributed orders are excluded from every shift total', () {
      final forA = repo.paidOrdersForShift('SHIFT-A');
      final forB = repo.paidOrdersForShift('SHIFT-B');

      expect(forA.any((o) => o.shiftId == null), isFalse);
      expect(forB.any((o) => o.shiftId == null), isFalse);
      // Order D (null shift) is reachable only via the explicit query.
      expect(
        repo.unattributedPaidCashOrders.map((o) => o.orderNumber),
        contains('D'),
      );
    });

    test('unknown shift id yields an empty result', () {
      expect(repo.paidOrdersForShift('NOPE'), isEmpty);
    });

    test('whitespace-padded shift id still resolves', () {
      expect(repo.paidOrdersForShift('  SHIFT-A  ').length, 2);
    });

    test('unattributed query is paid + cash + null shift only', () {
      final repo2 = InMemoryOrderRepository([
        makeOrder(
            orderNumber: 'CASH',
            grandTotal: 100,
            paymentMethod: PaymentMethod.cash,
            shiftId: null,
            createdAt: at(1)),
        makeOrder(
            orderNumber: 'QRIS',
            grandTotal: 200,
            paymentMethod: PaymentMethod.qris,
            shiftId: null,
            createdAt: at(1)),
        makeOrder(
            orderNumber: 'ATTRIBUTED',
            grandTotal: 300,
            paymentMethod: PaymentMethod.cash,
            shiftId: 'S1',
            createdAt: at(1)),
        makeOrder(
            orderNumber: 'PENDING',
            grandTotal: 400,
            paymentMethod: PaymentMethod.cash,
            shiftId: null,
            status: OrderStatus.pending,
            createdAt: at(1)),
      ]);

      expect(
        repo2.unattributedPaidCashOrders.map((o) => o.orderNumber),
        ['CASH'],
      );
    });
  });

  group('payment method partitioning', () {
    late OrderRepository repo;

    setUp(() {
      repo = InMemoryOrderRepository([
        makeOrder(
            orderNumber: 'C1',
            grandTotal: 10000,
            paymentMethod: PaymentMethod.cash,
            shiftId: 'S1',
            createdAt: at(15)),
        makeOrder(
            orderNumber: 'Q1',
            grandTotal: 20000,
            paymentMethod: PaymentMethod.qris,
            shiftId: 'S1',
            createdAt: at(15)),
        makeOrder(
            orderNumber: 'D1',
            grandTotal: 30000,
            paymentMethod: PaymentMethod.debitCard,
            shiftId: 'S1',
            createdAt: at(15)),
      ]);
    });

    test('cash, QRIS and debit queries are disjoint and complete', () {
      final cash = repo.paidOrdersForShiftAndMethod('S1', PaymentMethod.cash);
      final qris = repo.paidOrdersForShiftAndMethod('S1', PaymentMethod.qris);
      final debit =
          repo.paidOrdersForShiftAndMethod('S1', PaymentMethod.debitCard);

      expect(cash.map((o) => o.orderNumber), ['C1']);
      expect(qris.map((o) => o.orderNumber), ['Q1']);
      expect(debit.map((o) => o.orderNumber), ['D1']);

      // Disjoint, and together they account for the whole shift.
      final ids = {...cash, ...qris, ...debit}.map((o) => o.id).toSet();
      expect(ids.length, 3);
      expect(
        cash.length + qris.length + debit.length,
        repo.paidOrdersForShift('S1').length,
      );
    });

    test('method query still enforces paid + shift + null-exclusion', () {
      final repo2 = InMemoryOrderRepository([
        makeOrder(
            orderNumber: 'PENDING',
            grandTotal: 1,
            paymentMethod: PaymentMethod.cash,
            shiftId: 'S1',
            status: OrderStatus.pending,
            createdAt: at(1)),
        makeOrder(
            orderNumber: 'NULLSHIFT',
            grandTotal: 2,
            paymentMethod: PaymentMethod.cash,
            shiftId: null,
            createdAt: at(1)),
      ]);

      expect(repo2.paidOrdersForShiftAndMethod('S1', PaymentMethod.cash),
          isEmpty);
      expect(repo2.paidOrdersForShiftAndMethod(null, PaymentMethod.cash),
          isEmpty);
    });
  });

  group('date range with inclusive bounds', () {
    late OrderRepository repo;

    setUp(() {
      repo = InMemoryOrderRepository([
        makeOrder(orderNumber: 'D13', grandTotal: 1, createdAt: at(13)),
        makeOrder(orderNumber: 'D14L', grandTotal: 2, createdAt: at(14, 0)),
        makeOrder(orderNumber: 'D14E', grandTotal: 3, createdAt: at(14, 23)),
        makeOrder(orderNumber: 'D15L', grandTotal: 4, createdAt: at(15, 0)),
        makeOrder(orderNumber: 'D15E', grandTotal: 5, createdAt: at(15, 23)),
        makeOrder(orderNumber: 'D16L', grandTotal: 6, createdAt: at(16, 0)),
      ]);
    });

    test('both endpoints are inclusive', () {
      final range = repo.ordersInDateRange(at(14), at(15));
      expect(range.map((o) => o.orderNumber).toSet(),
          {'D14L', 'D14E', 'D15L', 'D15E'});
    });

    test('a single-day range still includes that whole day', () {
      final range = repo.ordersInDateRange(at(15), at(15));
      expect(range.map((o) => o.orderNumber).toSet(), {'D15L', 'D15E'});
    });

    test('midnight boundaries land on the correct side', () {
      // 14th 23:00 is in the 14th; 16th 00:00 is in the 16th.
      expect(
        repo.ordersInDateRange(at(14), at(14)).map((o) => o.orderNumber),
        containsAll(<String>['D14L', 'D14E']),
      );
      expect(
        repo.ordersInDateRange(at(16), at(16)).map((o) => o.orderNumber),
        ['D16L'],
      );
    });

    test('time-of-day on the bounds does not exclude that date', () {
      // A window ending at 15th 00:00 must still include a 15th 23:00 sale,
      // because only the calendar date is compared.
      final range = repo.ordersInDateRange(at(13), DateTime(2026, 3, 15, 0, 0));
      expect(range.map((o) => o.orderNumber), contains('D15E'));
    });

    test('does not filter by status', () {
      final repo2 = InMemoryOrderRepository([
        makeOrder(
            orderNumber: 'PAID',
            grandTotal: 1,
            createdAt: at(10)),
        makeOrder(
            orderNumber: 'PENDING',
            grandTotal: 2,
            status: OrderStatus.pending,
            createdAt: at(10)),
      ]);
      expect(
        repo2.ordersInDateRange(at(10), at(10)).length,
        2,
        reason: '"in range" and "paid in range" are different questions',
      );
    });

    test('a range with no orders returns empty', () {
      expect(repo.ordersInDateRange(at(1), at(2)), isEmpty);
    });

    test('paidOrdersInDateRange composes both filters', () {
      final repo2 = InMemoryOrderRepository([
        makeOrder(
            orderNumber: 'PAID_IN',
            grandTotal: 10,
            shiftId: 'S',
            createdAt: at(15)),
        makeOrder(
            orderNumber: 'PENDING_IN',
            grandTotal: 20,
            shiftId: 'S',
            status: OrderStatus.pending,
            createdAt: at(15)),
        makeOrder(
            orderNumber: 'PAID_OUT',
            grandTotal: 30,
            shiftId: 'S',
            createdAt: at(20)),
      ]);

      final result = repo2.paidOrdersInDateRange(at(14), at(16));
      expect(result.map((o) => o.orderNumber), ['PAID_IN'],
          reason: 'must be paid AND in range');
    });

    test('paidOrdersInDateRange bounds are inclusive like the base query', () {
      final result = repo.paidOrdersInDateRange(at(14), at(15));
      expect(result.map((o) => o.orderNumber).toSet(),
          {'D14L', 'D14E', 'D15L', 'D15E'});
    });
  });

  group('PosProvider integration still honours the contract', () {
    test('reports route through the repository without changing results', () {
      final pos = PosProvider();

      // Seeded demo orders must all be reachable through the repository-backed
      // getters, and the seed shift must own them.
      expect(pos.orders, isNotEmpty);
      expect(pos.getOrdersForPeriod(ReportPeriod.today), isNotEmpty);
      expect(pos.unattributedCashTotal, 0,
          reason: 'seed orders are attributed in source, never at runtime');
    });

    test('injected orders replace the mock set', () {
      final injected = [
        makeOrder(
            orderNumber: 'X1',
            grandTotal: 5000,
            shiftId: 'SHIFT-X',
            createdAt: DateTime.now()),
      ];
      final pos = PosProvider(initialOrders: injected);

      expect(pos.orders.length, 1);
      expect(pos.orders.single.orderNumber, 'X1');
      expect(pos.cashSalesForShift('SHIFT-X'), 5000);
    });

    test('shift totals exclude null-shift orders end to end', () {
      final now = DateTime.now();
      final pos = PosProvider(initialOrders: [
        makeOrder(
            orderNumber: 'A',
            grandTotal: 10000,
            shiftId: 'SHIFT-A',
            createdAt: now),
        makeOrder(
            orderNumber: 'ORPHAN',
            grandTotal: 40000,
            shiftId: null,
            createdAt: now),
      ]);

      expect(pos.cashSalesForShift('SHIFT-A'), 10000);
      expect(pos.cashSalesForShift('SHIFT-B'), 0);
      expect(pos.unattributedCashTotal, 40000);
      // The orphan is reported, never silently folded in.
      expect(pos.unattributedPaidCashOrders.single.orderNumber, 'ORPHAN');
    });

    test('payment methods partition a shift total exactly', () {
      final now = DateTime.now();
      final pos = PosProvider(initialOrders: [
        makeOrder(
            orderNumber: 'C',
            grandTotal: 10000,
            paymentMethod: PaymentMethod.cash,
            shiftId: 'S',
            createdAt: now),
        makeOrder(
            orderNumber: 'Q',
            grandTotal: 20000,
            paymentMethod: PaymentMethod.qris,
            shiftId: 'S',
            createdAt: now),
        makeOrder(
            orderNumber: 'D',
            grandTotal: 30000,
            paymentMethod: PaymentMethod.debitCard,
            shiftId: 'S',
            createdAt: now),
      ]);

      expect(pos.cashSalesForShift('S'), 10000);
      expect(pos.qrisSalesForShift('S'), 20000);
      expect(pos.debitSalesForShift('S'), 30000);
      expect(pos.totalSalesForShift('S'), 60000);
      expect(pos.transactionCountForShift('S'), 3);
    });

    test('internal identity is unchanged when an order is updated', () {
      final original = makeOrder(
        id: 'identity-1',
        orderNumber: 'ORD-1',
        grandTotal: 10000,
        shiftId: 'S',
        createdAt: at(15),
      );
      final repo = InMemoryOrderRepository([original]);
      expect(repo.findById('identity-1')!.id, 'identity-1');

      // The update path used by settlement is copyWith.
      final settled = original.copyWith(
        status: OrderStatus.paid,
        paidAmount: 10000,
      );
      expect(settled.id, 'identity-1',
          reason: 'settlement must not mint a new identity');
      expect(settled.orderNumber, 'ORD-1',
          reason: 'the display number is carried through unchanged too');
      expect(repo.findById('identity-1')!.id, 'identity-1');
    });
  });
}