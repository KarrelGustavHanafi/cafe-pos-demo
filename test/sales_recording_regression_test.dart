import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/repositories/order_repository.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/utils/jakarta_time.dart';
import 'package:cafe_pos_demo/utils/shift_sale_guard.dart';

/// Contract: a cashier sale that settles successfully must be visible to the
/// Owner Sales screen, the Owner Reports screen and the shift close recap, and
/// must be counted exactly once.
///
/// Every figure in those screens comes from `PosProvider`'s period/shift
/// getters, which read the single shared `OrderRepository`. These tests drive a
/// real sale through `completePayment` and assert on those same getters, so a
/// future refactor cannot make one surface diverge from another.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Order payQris(PosProvider pos) => pos.completePayment(
        method: PaymentMethod.qris,
        paidAmount: pos.cartGrandTotal,
        changeAmount: 0,
      );

  // ==========================================
  // A. A settled sale reaches Sales and Reports
  // ==========================================
  group('settled cashier sales appear in Sales and Reports', () {
    test('cash sale is counted once in the period the screens display',
        () async {
      final pos = await newProvider();

      final salesBefore = pos.getSalesTotalForPeriod(ReportPeriod.today);
      final countBefore = pos.getTransactionsCountForPeriod(ReportPeriod.today);
      final cashBefore = pos.getCashSalesForPeriod(ReportPeriod.today);

      final product = inStockProduct(pos);
      pos.addToCart(product);
      final order = payCash(pos);

      expect(order.status, OrderStatus.paid);
      expect(order.paidAmount, order.grandTotal + 100000);
      // Exactly one new transaction, worth exactly its grand total.
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today),
          salesBefore + order.grandTotal);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today),
          countBefore + 1);
      expect(pos.getCashSalesForPeriod(ReportPeriod.today),
          cashBefore + order.grandTotal);

      // The very rows both screens render come from these two getters.
      expect(
        pos.getPaidOrdersForPeriod(ReportPeriod.today).map((o) => o.id),
        contains(order.id),
      );
      expect(
        pos.getTopSellingProductsForPeriod(ReportPeriod.today)
            .firstWhere((e) => e.key == product.name)
            .value,
        greaterThanOrEqualTo(1),
      );
    });

    test('QRIS sale is counted once and lands in the QRIS channel', () async {
      final pos = await newProvider();

      final salesBefore = pos.getSalesTotalForPeriod(ReportPeriod.today);
      final qrisBefore = pos.getQrisSalesForPeriod(ReportPeriod.today);
      final cashBefore = pos.getCashSalesForPeriod(ReportPeriod.today);

      pos.addToCart(inStockProduct(pos));
      final order = payQris(pos);

      expect(order.status, OrderStatus.paid);
      expect(order.paymentMethod, PaymentMethod.qris);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today),
          salesBefore + order.grandTotal);
      expect(pos.getQrisSalesForPeriod(ReportPeriod.today),
          qrisBefore + order.grandTotal);
      // QRIS must never inflate the physical drawer.
      expect(pos.getCashSalesForPeriod(ReportPeriod.today), cashBefore);
    });
  });

  // ==========================================
  // B. Shift close recaps the right transactions
  // ==========================================
  group('shift close recap', () {
    test('archives the shift totals including the new sale', () async {
      final pos = await newProvider();

      final shiftId = pos.currentShift.shiftId;
      final salesBefore = pos.totalSalesForShift(shiftId);
      final cashBefore = pos.cashSalesForShift(shiftId);
      final countBefore = pos.transactionCountForShift(shiftId);

      pos.addToCart(inStockProduct(pos));
      final order = payCash(pos);

      await pos.closeShift(
        actualEndingCash: pos.expectedEndingCashForShift(pos.currentShift),
      );

      final archived = pos.pastShifts.first;
      expect(archived.shiftId, shiftId);
      expect(archived.summary, isNotNull);
      // Frozen at close time, so later orders cannot rewrite this history.
      expect(archived.summary!.paidTransactionCount, countBefore + 1);
      expect(archived.summary!.totalSales, salesBefore + order.grandTotal);
      expect(archived.summary!.cashSales, cashBefore + order.grandTotal);
    });

    test('a new shift starts empty and does not inherit old sales', () async {
      final pos = await newProvider();

      pos.addToCart(inStockProduct(pos));
      payCash(pos);
      await pos.closeShift(actualEndingCash: 0);

      pos.startNewShift(startingCash: 500000);
      final newShiftId = pos.currentShift.shiftId;

      expect(newShiftId, isNot('SHIFT-01'));
      expect(pos.totalSalesForShift(newShiftId), 0);
      expect(pos.transactionCountForShift(newShiftId), 0);
      // Reports are date-based, so today's sale is still reported.
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today),
          greaterThan(0));
    });
  });

  // ==========================================
  // C. Idempotency
  // ==========================================
  group('re-processing never duplicates a sale', () {
    test('paying the same order twice records it once', () async {
      final pos = await newProvider();

      final salesBefore = pos.getSalesTotalForPeriod(ReportPeriod.today);
      pos.addToCart(inStockProduct(pos));

      final first = payCash(pos);
      final ordersAfterFirst = pos.orders.length;

      final second = payCash(pos);

      expect(second.id, first.id);
      expect(pos.orders.length, ordersAfterFirst);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today),
          salesBefore + first.grandTotal);
      expect(
        pos.getPaidOrdersForPeriod(ReportPeriod.today)
            .where((o) => o.id == first.id)
            .length,
        1,
      );
    });

    test('closing the same shift twice archives it once', () async {
      final pos = await newProvider();

      pos.addToCart(inStockProduct(pos));
      payCash(pos);

      await pos.closeShift(actualEndingCash: 0);
      final archivesAfterFirst = pos.pastShifts.length;

      final second = await pos.closeShift(actualEndingCash: 999999);

      expect(second, isNull);
      expect(pos.pastShifts.length, archivesAfterFirst);
    });
  });

  // ==========================================
  // D. Unsettled money is not revenue
  // ==========================================
  group('pending, failed and unconfirmed orders are not sales', () {
    test('a prepared order is not counted until payment settles', () async {
      final pos = await newProvider();

      final salesBefore = pos.getSalesTotalForPeriod(ReportPeriod.today);
      final countBefore = pos.getTransactionsCountForPeriod(ReportPeriod.today);
      final shiftId = pos.currentShift.shiftId;
      final shiftCountBefore = pos.transactionCountForShift(shiftId);

      pos.addToCart(inStockProduct(pos));
      final pending = pos.prepareCheckoutOrder();

      expect(pending.status, OrderStatus.pending);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), salesBefore);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today), countBefore);
      expect(pos.transactionCountForShift(shiftId), shiftCountBefore);
      expect(
        pos.getPaidOrdersForPeriod(ReportPeriod.today).map((o) => o.id),
        isNot(contains(pending.id)),
      );
    });

    test('a rejected payment records nothing and deducts no stock', () async {
      final pos = await newProvider();

      final product = inStockProduct(pos);
      final stockBefore = product.stock;
      final ordersBefore = pos.orders.length;
      final salesBefore = pos.getSalesTotalForPeriod(ReportPeriod.today);

      // More than exists: the sale must be refused, not partially applied.
      pos.addToCart(product, qty: product.stock + 50);

      expect(() => payCash(pos), throwsA(isA<InsufficientStockException>()));

      expect(pos.orders.length, ordersBefore);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), salesBefore);
      expect(
        pos.products.firstWhere((p) => p.id == product.id).stock,
        stockBefore,
      );
    });

    test('paying an empty cart is refused and records nothing', () async {
      final pos = await newProvider();

      final ordersBefore = pos.orders.length;
      final salesBefore = pos.getSalesTotalForPeriod(ReportPeriod.today);

      expect(() => payCash(pos), throwsA(isA<InvalidPaymentException>()));

      expect(pos.orders.length, ordersBefore);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), salesBefore);
    });
  });

  // ==========================================
  // E. Shift attribution
  // ==========================================
  group('shift attribution', () {
    test('a sale carries the shift that was open when it was prepared',
        () async {
      final pos = await newProvider();
      final shiftId = pos.currentShift.shiftId;

      pos.addToCart(inStockProduct(pos));
      final order = payCash(pos);

      expect(order.shiftId, shiftId);
      expect(
        pos.getPaidOrdersForShift(shiftId).map((o) => o.id),
        contains(order.id),
      );
    });

    test('a sale cannot be posted into a closed shift', () async {
      final pos = await newProvider();

      pos.addToCart(inStockProduct(pos));
      pos.prepareCheckoutOrder();

      final closedShiftId = pos.currentShift.shiftId;
      final closedSalesBefore = pos.totalSalesForShift(closedShiftId);

      await pos.closeShift(actualEndingCash: 0);
      pos.startNewShift(startingCash: 400000);

      expect(() => payCash(pos), throwsA(isA<StaleShiftOrderException>()));

      expect(pos.totalSalesForShift(closedShiftId), closedSalesBefore);
      expect(pos.totalSalesForShift(pos.currentShift.shiftId), 0);
    });
  });

  // ==========================================
  // F. Jakarta calendar bucketing
  // ==========================================
  group('reports bucket orders on the Asia/Jakarta calendar', () {
    test('the Jakarta date of an instant, not the UTC date', () {
      // 16:30 UTC is 23:30 WIB on the same date.
      expect(jakartaDate(DateTime.utc(2026, 10, 24, 16, 30)),
          DateTime(2026, 10, 24));
      // 17:30 UTC is 00:30 WIB on the following date.
      expect(jakartaDate(DateTime.utc(2026, 10, 24, 17, 30)),
          DateTime(2026, 10, 25));
      // 00:30 UTC is 07:30 WIB, still the same date.
      expect(jakartaDate(DateTime.utc(2026, 10, 24, 0, 30)),
          DateTime(2026, 10, 24));
    });

    test('the repository splits orders by Jakarta date, not UTC date', () {
      final product = Product(
        id: 'P-1',
        name: 'Kopi',
        category: ProductCategory.coffee,
        price: 10000,
        costPrice: 0,
        stock: 10,
      );

      Order paid(String id, DateTime at) => Order(
            orderNumber: id,
            tableNumber: 'Takeaway',
            items: [],
            subtotal: 10000,
            serviceCharge: 0,
            tax: 0,
            grandTotal: 10000,
            paymentMethod: PaymentMethod.cash,
            status: OrderStatus.paid,
            paidAmount: 10000,
            createdAt: at,
            cashierName: 'Kasir',
            shiftId: 'SHIFT-01',
          );

      final repo = InMemoryOrderRepository([
        paid('LATE-WIB', DateTime.utc(2026, 10, 24, 16, 30)), // 23:30 WIB 24th
        paid('EARLY-WIB', DateTime.utc(2026, 10, 24, 17, 30)), // 00:30 WIB 25th
      ]);

      final day24 = repo
          .paidOrdersInDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 24))
          .map((o) => o.orderNumber);
      final day25 = repo
          .paidOrdersInDateRange(DateTime(2026, 10, 25), DateTime(2026, 10, 25))
          .map((o) => o.orderNumber);

      expect(day24, ['LATE-WIB']);
      expect(day25, ['EARLY-WIB']);
      expect(product.stock, 10);
    });
  });

  // ==========================================
  // G. Demo reset and role boundaries stay intact
  // ==========================================
  group('existing guarantees hold', () {
    test('reset demo clears sales but keeps stock', () async {
      SharedPreferences.setMockInitialValues({});
      final pos = PosProvider();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      pos.login('owner', 'owner123');

      pos.addToCart(inStockProduct(pos));
      payCash(pos);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), greaterThan(0));

      // Reset keeps stock exactly as it stands at reset time; the sale above
      // legitimately deducted it, so the snapshot is taken afterwards.
      final stockBeforeReset = {
        for (final p in pos.products) p.id: p.stock,
      };

      pos.resetDemoData();

      expect(pos.orders, isEmpty);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), 0);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today), 0);
      for (final p in pos.products) {
        expect(p.stock, stockBeforeReset[p.id],
            reason: 'stock preserved: ${p.id}');
      }
      // A fresh shift is open, so selling still works.
      expect(pos.hasActiveShift, isTrue);
    });

    test('only the Owner may reset, and only in a public demo', () async {
      SharedPreferences.setMockInitialValues({});
      final pos = PosProvider();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      pos.login('cashier', 'cashier123');
      expect(pos.canResetDemoData, isFalse);
      expect(() => pos.resetDemoData(), throwsA(isA<StateError>()));
      expect(pos.orders, isNotEmpty);

      pos.login('owner', 'owner123');
      expect(pos.canResetDemoData, isTrue);
    });
  });
}
