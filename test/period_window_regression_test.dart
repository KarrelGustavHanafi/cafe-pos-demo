import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/cart_item.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/screens/owner/owner_orders_screen.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/utils/jakarta_time.dart';

/// Regression tests for the canonical period windows.
///
/// The POS derives every period total from one shared helper,
/// `PosProvider.periodWindow`. Before it existed, the windows were computed as
/// `today.subtract(Duration(days: 7))` with inclusive endpoints, which spans
/// **eight** calendar dates, and `days: 30` which spans **thirty-one**.
///
/// These tests pin the corrected windows (7 and 30 calendar dates, today
/// included) and prove `getOrdersForPeriod` applies them to real orders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Fixed reference date so window maths never depends on the real clock.
  final reference = DateTime(2026, 10, 10);

  /// The UTC instant for [hour]:00 WIB on the Jakarta calendar date [day].
  ///
  /// Orders are built as real instants; report buckets are Jakarta dates. Making
  /// the intended WIB wall-clock time explicit keeps these tests independent of
  /// the machine's own timezone.
  DateTime wib(DateTime day, int hour) =>
      DateTime.utc(day.year, day.month, day.day, hour).subtract(jakartaOffset);

  /// The Jakarta date [daysAgo] days before [today], computed on UTC so no
  /// device daylight-saving transition can move it by an hour.
  DateTime dayBefore(DateTime today, int daysAgo) {
    final base =
        DateTime.utc(today.year, today.month, today.day).subtract(Duration(days: daysAgo));
    return DateTime(base.year, base.month, base.day);
  }

  // ==========================================
  // A. Pure window helper
  // ==========================================
  group('periodWindow', () {
    test('today spans exactly one calendar date', () {
      final w = PosProvider.periodWindow(ReportPeriod.today, reference);

      expect(w.start, DateTime(2026, 10, 10));
      expect(w.end, DateTime(2026, 10, 10));
      expect(w.start, w.end);
    });

    test('last7Days starts 6 days before the reference date', () {
      final w = PosProvider.periodWindow(ReportPeriod.last7Days, reference);

      // Minus 6, not minus 7: inclusive endpoints make this exactly 7 dates.
      expect(w.start, DateTime(2026, 10, 4));
      expect(w.end, DateTime(2026, 10, 10));
    });

    test('last30Days starts 29 days before the reference date', () {
      final w = PosProvider.periodWindow(ReportPeriod.last30Days, reference);

      expect(w.start, DateTime(2026, 9, 11));
      expect(w.end, DateTime(2026, 10, 10));
    });

    test('window date spans equal the advertised count', () {
      // Guards the regression directly: 7 dates, not 8; 30 dates, not 31.
      int spanInDays(ReportPeriod period) {
        final w = PosProvider.periodWindow(period, reference);
        return w.end.difference(w.start).inDays + 1; // inclusive both ends
      }

      expect(spanInDays(ReportPeriod.today), 1);
      expect(spanInDays(ReportPeriod.last7Days), 7);
      expect(spanInDays(ReportPeriod.last30Days), 30);
    });

    test('the time-of-day of the reference is discarded', () {
      final w = PosProvider.periodWindow(
        ReportPeriod.last7Days,
        DateTime(2026, 10, 10, 23, 59, 59),
      );

      // Comparisons are by calendar date, so both endpoints land at midnight.
      expect(w.start, DateTime(2026, 10, 4));
      expect(w.end, DateTime(2026, 10, 10));
    });

    test('windows cross month boundaries correctly', () {
      final w = PosProvider.periodWindow(
        ReportPeriod.last30Days,
        DateTime(2026, 3, 1),
      );

      expect(w.start, DateTime(2026, 1, 31));
      expect(w.end, DateTime(2026, 3, 1));
    });
  });

  // ==========================================
  // B. Provider integration with real orders
  // ==========================================

  /// Builds one paid order with an explicit timestamp and total.
  ///
  /// `reference` must be the provider's own "today" so the window maths under
  /// test matches the real clock the provider reads.
  Order makeOrder(
    String id,
    DateTime createdAt,
    int grandTotal, {
    PaymentMethod payment = PaymentMethod.cash,
    int quantity = 1,
  }) {
    final product = Product(
      id: 'P-$id',
      name: 'Item $id',
      category: ProductCategory.coffee,
      price: grandTotal,
      costPrice: 0,
      stock: 100,
    );

    return Order(
      orderNumber: id,
      tableNumber: 'A01',
      items: [CartItem(product: product, quantity: quantity)],
      subtotal: grandTotal,
      serviceCharge: 0,
      tax: 0,
      grandTotal: grandTotal,
      paymentMethod: payment,
      status: OrderStatus.paid,
      paidAmount: grandTotal,
      createdAt: createdAt,
      cashierName: 'Tester',
    );
  }

  /// Runs every scenario against a fixed reference "today".
  ///
  /// The provider always filters from [DateTime.now], so the reference is
  /// derived from the current clock rather than hard-coded. That keeps the
  /// expected boundary relationships exact while staying clock-independent in
  /// shape: O3/O4/O5/O6 are always placed relative to today.
  group('getOrdersForPeriod with orders on distinct dates', () {
    late DateTime today;

    setUp(() {
      today = jakartaDate(DateTime.now());
    });

    test('each period includes exactly its own orders', () {
      DateTime at(int daysAgo, int hour) => wib(dayBefore(today, daysAgo), hour);

      final orders = [
        makeOrder('O1', at(0, 9), 10000),
        makeOrder('O2', at(0, 23), 20000),
        makeOrder('O3', at(6, 0), 30000),
        makeOrder('O4', at(7, 12), 40000),
        makeOrder('O5', at(29, 0), 50000),
        makeOrder('O6', at(30, 12), 60000),
        makeOrder('O7', at(9, 8), 70000),
      ];

      final pos = PosProvider(initialOrders: orders);

      final todayIds =
          pos.getOrdersForPeriod(ReportPeriod.today).map((o) => o.orderNumber).toSet();
      final weekIds = pos
          .getOrdersForPeriod(ReportPeriod.last7Days)
          .map((o) => o.orderNumber)
          .toSet();
      final monthIds = pos
          .getOrdersForPeriod(ReportPeriod.last30Days)
          .map((o) => o.orderNumber)
          .toSet();

      // Today: both of today's orders, including the 23:00 one.
      expect(todayIds, {'O1', 'O2'});

      // 7 days: today plus the preceding 6 calendar dates.
      // O4 (7 days ago) is exactly the extra date the old bug included.
      expect(weekIds, {'O1', 'O2', 'O3'});
      expect(weekIds, isNot(contains('O4')));

      // 30 days: today plus the preceding 29 calendar dates.
      // O6 (30 days ago) is the extra date the old bug included.
      expect(monthIds, {'O1', 'O2', 'O3', 'O4', 'O5', 'O7'});
      expect(monthIds, isNot(contains('O6')));
    });

    test('injected orders fully replace the mock seed orders', () {
      final pos = PosProvider(initialOrders: [
        makeOrder('O1', wib(today, 9), 10000),
      ]);

      // If the three mock orders were still present, this would be 4.
      expect(pos.orders.length, 1);
      expect(pos.orders.single.orderNumber, 'O1');
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today), 1);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), 10000);
    });

    test('totals and counts match the included order set', () {
      DateTime at(int daysAgo, int hour) => wib(dayBefore(today, daysAgo), hour);

      final pos = PosProvider(initialOrders: [
        makeOrder('O1', at(0, 9), 10000),
        makeOrder('O2', at(0, 23), 20000),
        makeOrder('O3', at(6, 0), 30000),
        makeOrder('O4', at(7, 12), 40000),
        makeOrder('O5', at(29, 0), 50000),
        makeOrder('O6', at(30, 12), 60000),
        makeOrder('O7', at(9, 8), 70000),
      ]);

      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), 30000);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today), 2);

      expect(pos.getSalesTotalForPeriod(ReportPeriod.last7Days), 60000);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.last7Days), 3);

      expect(pos.getSalesTotalForPeriod(ReportPeriod.last30Days), 220000);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.last30Days), 6);

      // Average order value stays derived from the filtered set.
      expect(pos.getAverageTransactionForPeriod(ReportPeriod.last7Days), 20000);
    });

    test('a filter ignoring dates entirely would be detected', () {
      final pos = PosProvider(initialOrders: [
        makeOrder('O1', wib(today, 12), 10000),
        makeOrder('OLD', wib(dayBefore(today, 40), 12), 99000),
      ]);

      // A date-blind filter would return both and report 109000.
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), 10000);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today), 1);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.last30Days), 10000);
    });

    test('payment channels and item counts follow the same window', () {
      DateTime at(int daysAgo, int hour) => wib(dayBefore(today, daysAgo), hour);

      final pos = PosProvider(initialOrders: [
        makeOrder('O1', at(0, 9), 10000, payment: PaymentMethod.cash),
        makeOrder('O2', at(0, 23), 20000, payment: PaymentMethod.qris),
        makeOrder('O3', at(6, 0), 30000, payment: PaymentMethod.debitCard),
        makeOrder('O4', at(7, 12), 40000, payment: PaymentMethod.cash),
      ]);

      // O4 falls outside the 7-day window, so its cash must not be counted.
      expect(pos.getCashSalesForPeriod(ReportPeriod.last7Days), 10000);
      expect(pos.getQrisSalesForPeriod(ReportPeriod.last7Days), 20000);
      expect(pos.getDebitSalesForPeriod(ReportPeriod.last7Days), 30000);

      expect(pos.getCashSalesForPeriod(ReportPeriod.last30Days), 50000);

      expect(pos.getTotalItemsSoldForPeriod(ReportPeriod.last7Days), 3);
      expect(pos.getTotalItemsSoldForPeriod(ReportPeriod.today), 2);
    });

    test('unpaid orders stay excluded regardless of the window', () {
      final pending = Order(
        orderNumber: 'P1',
        tableNumber: 'A01',
        items: [
          CartItem(product: pos0Product(), quantity: 1),
        ],
        subtotal: 77777,
        serviceCharge: 0,
        tax: 0,
        grandTotal: 77777,
        status: OrderStatus.pending,
        createdAt: wib(today, 12),
        cashierName: 'Tester',
      );

      final pos = PosProvider(initialOrders: [pending]);

      expect(pos.getOrdersForPeriod(ReportPeriod.today).length, 1);
      // Sales/count metrics filter to paid orders only.
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), 0);
      expect(pos.getTransactionsCountForPeriod(ReportPeriod.today), 0);
      expect(pos.getPaidOrdersForPeriod(ReportPeriod.today), isEmpty);
    });
  });

  // ==========================================
  // C. Owner orders screen "Hari Ini" filter
  // ==========================================
  group('OwnerOrdersScreen today-only filter', () {
    testWidgets('shows only orders dated today', (tester) async {
      final today = jakartaDate(DateTime.now());

      final pos = PosProvider(initialOrders: [
        makeOrder('TODAY-EARLY', wib(today, 1), 10000),
        makeOrder('TODAY-LATE', wib(today, 22), 20000),
        makeOrder('YESTERDAY', wib(dayBefore(today, 1), 12), 30000),
        makeOrder('OLD', wib(dayBefore(today, 40), 12), 40000),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerOrdersScreen(pos: pos),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // The header shows the filtered count, so it proves the filter applied.
      expect(find.textContaining('Daftar Transaksi (2)'), findsOneWidget);
      expect(find.text('TODAY-EARLY'), findsOneWidget);
      expect(find.text('TODAY-LATE'), findsOneWidget);
      // A 23:00-style order still belongs to today, and older dates are out.
      expect(find.text('YESTERDAY'), findsNothing);
      expect(find.text('OLD'), findsNothing);
    });
  });
}

/// Smallest valid product for constructing a pending order.
Product pos0Product() => Product(
      id: 'P-PEND',
      name: 'Pending Item',
      category: ProductCategory.coffee,
      price: 77777,
      costPrice: 0,
      stock: 100,
    );