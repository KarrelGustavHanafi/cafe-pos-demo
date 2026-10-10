import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/cart_item.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/screens/owner/owner_dashboard.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/sales_bar_chart.dart';

/// Regression tests for Owner Dashboard truthfulness.
///
/// Two fabrications were removed:
///
///  * four hardcoded trend percentages (`+12.5%`, `+8.3%`, `+4.1%`, `+15.0%`)
///    that had no supporting calculation,
///  * a fixed 14-hour revenue baseline that was mixed into the hourly sales
///    chart, making invented bars look like real transactions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Order paidOrder({
    required String id,
    required DateTime createdAt,
    required int grandTotal,
    PaymentMethod payment = PaymentMethod.cash,
  }) {
    final product = Product(
      id: 'P-$id',
      name: 'Item $id',
      category: ProductCategory.coffee,
      price: grandTotal,
      stock: 100,
    );
    return Order(
      orderNumber: id,
      tableNumber: 'A01',
      items: [CartItem(product: product, quantity: 1)],
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

  Order pendingOrder({
    required String id,
    required DateTime createdAt,
    required int grandTotal,
  }) {
    final product = Product(
      id: 'P-$id',
      name: 'Item $id',
      category: ProductCategory.coffee,
      price: grandTotal,
      stock: 100,
    );
    return Order(
      orderNumber: id,
      tableNumber: 'A01',
      items: [CartItem(product: product, quantity: 1)],
      subtotal: grandTotal,
      serviceCharge: 0,
      tax: 0,
      grandTotal: grandTotal,
      status: OrderStatus.pending,
      createdAt: createdAt,
      cashierName: 'Tester',
    );
  }

  // ==========================================
  // A. Fabricated trend percentages
  // ==========================================
  group('dashboard KPI trends', () {
    testWidgets('renders no fabricated trend percentages', (tester) async {
      final pos = PosProvider()..login('owner', 'owner123');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerDashboard(
            pos: pos,
            onViewSalesReport: () {},
            onViewProducts: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // The four values C11-04 identified must never appear.
      for (final fabricated in ['+12.5%', '+8.3%', '+4.1%', '+15.0%']) {
        expect(find.textContaining(fabricated), findsNothing,
            reason: 'fabricated trend $fabricated must not be rendered');
      }

      // No literal percentage should decorate any KPI card at all.
      for (final text in tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => s.contains('%'))) {
        expect(text, isNot(contains('12.5')));
        expect(text, isNot(contains('8.3')));
        expect(text, isNot(contains('4.1')));
        expect(text, isNot(contains('15.0')));
      }
    });

    testWidgets('still renders the real KPI values', (tester) async {
      final pos = PosProvider()..login('owner', 'owner123');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerDashboard(
            pos: pos,
            onViewSalesReport: () {},
            onViewProducts: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Valid KPIs must survive the removal.
      expect(find.text('Total Omzet Hari Ini'), findsOneWidget);
      expect(find.text('Total Transaksi'), findsOneWidget);
      expect(find.text('Rata-rata Order (AOV)'), findsOneWidget);
      expect(find.text('Total Menu Terjual'), findsOneWidget);
      expect(
        find.textContaining(pos.todayTransactionsCount.toString()),
        findsWidgets,
      );
    });
  });

  // ==========================================
  // B. Hourly chart aggregation
  // ==========================================
  group('OwnerDashboard.buildHourlyChartData', () {
    test('returns no bars when there are no qualifying sales', () {
      expect(OwnerDashboard.buildHourlyChartData(const []), isEmpty);
    });

    test('returns no bars when every order is unpaid', () {
      final now = DateTime.now();
      final bars = OwnerDashboard.buildHourlyChartData([
        pendingOrder(id: 'P1', createdAt: now, grandTotal: 50000),
        pendingOrder(id: 'P2', createdAt: now, grandTotal: 30000),
      ]);

      // Unpaid orders are not sales, so nothing may be charted.
      expect(bars, isEmpty);
    });

    test('excludes unpaid orders but charts paid ones', () {
      final base = DateTime(2026, 10, 10, 9);
      final bars = OwnerDashboard.buildHourlyChartData([
        paidOrder(id: 'PAID', createdAt: base, grandTotal: 20000),
        pendingOrder(id: 'PEND', createdAt: base, grandTotal: 99000),
      ]);

      expect(bars.length, 1);
      expect(bars.single.value, 20000);
    });

    test('buckets each paid order into its own hour', () {
      final bars = OwnerDashboard.buildHourlyChartData([
        paidOrder(id: 'A', createdAt: DateTime(2026, 10, 10, 8), grandTotal: 10000),
        paidOrder(id: 'B', createdAt: DateTime(2026, 10, 10, 12), grandTotal: 30000),
      ]);

      expect(bars.map((b) => b.label).toList(), ['08', '12']);
      expect(bars.map((b) => b.value).toList(), [10000, 30000]);
    });

    test('sums multiple orders within the same hour', () {
      final bars = OwnerDashboard.buildHourlyChartData([
        paidOrder(id: 'A', createdAt: DateTime(2026, 10, 10, 10, 5), grandTotal: 15000),
        paidOrder(id: 'B', createdAt: DateTime(2026, 10, 10, 10, 55), grandTotal: 25000),
      ]);

      expect(bars.length, 1);
      expect(bars.single.label, '10');
      expect(bars.single.value, 40000);
    });

    test('bar values sum to the qualifying paid total', () {
      final orders = [
        paidOrder(id: 'A', createdAt: DateTime(2026, 10, 10, 8), grandTotal: 11000),
        paidOrder(id: 'B', createdAt: DateTime(2026, 10, 10, 9), grandTotal: 22000),
        paidOrder(id: 'C', createdAt: DateTime(2026, 10, 10, 9), grandTotal: 33000),
        paidOrder(id: 'D', createdAt: DateTime(2026, 10, 10, 20), grandTotal: 44000),
      ];

      final bars = OwnerDashboard.buildHourlyChartData(orders);
      final summed = bars.fold<int>(0, (s, b) => s + b.value);
      final expected = orders.fold<int>(0, (s, o) => s + o.grandTotal);

      expect(summed, expected);
    });

    test('bars are ordered by hour', () {
      final bars = OwnerDashboard.buildHourlyChartData([
        paidOrder(id: 'LATE', createdAt: DateTime(2026, 10, 10, 21), grandTotal: 1000),
        paidOrder(id: 'EARLY', createdAt: DateTime(2026, 10, 10, 6), grandTotal: 2000),
        paidOrder(id: 'MID', createdAt: DateTime(2026, 10, 10, 13), grandTotal: 3000),
      ]);

      expect(bars.map((b) => b.label).toList(), ['06', '13', '21']);
    });

    test('never produces the removed baseline value', () {
      // 320000 was the largest hardcoded baseline bucket. With no orders the
      // chart must be empty rather than inventing it.
      final bars = OwnerDashboard.buildHourlyChartData(const []);
      expect(bars.map((b) => b.value), isNot(contains(320000)));
    });
  });

  group('dashboard hourly chart wiring', () {
    testWidgets('shows the empty state when no sales qualify', (tester) async {
      final pos = PosProvider(initialOrders: [
        pendingOrder(id: 'P1', createdAt: DateTime.now(), grandTotal: 50000),
      ])..login('owner', 'owner123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerDashboard(
            pos: pos,
            onViewSalesReport: () {},
            onViewProducts: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // SalesBarChart renders its own empty state when data is empty.
      expect(find.byType(SalesBarChart), findsOneWidget);
      expect(find.text('Belum ada data.'), findsOneWidget);
    });

    testWidgets('charts deterministic paid orders placed today',
        (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final pos = PosProvider(initialOrders: [
        paidOrder(
            id: 'H1', createdAt: today.add(const Duration(hours: 9)), grandTotal: 15000),
        paidOrder(
            id: 'H2', createdAt: today.add(const Duration(hours: 14)), grandTotal: 25000),
      ])..login('owner', 'owner123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerDashboard(
            pos: pos,
            onViewSalesReport: () {},
            onViewProducts: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Both orders are today, so the chart has data and no empty state.
      final chartData =
          tester.widget<SalesBarChart>(find.byType(SalesBarChart)).data;
      expect(chartData.length, 2);
      expect(chartData.fold<int>(0, (s, b) => s + b.value), 40000);
      expect(find.text('Belum ada data.'), findsNothing);
    });

    testWidgets('excludes a paid order from yesterday via the real provider path',
        (tester) async {
      // Regression test for C13R M-1: the period exclusion used to be asserted
      // only against the pure aggregation helper, which receives an already
      // filtered list and therefore cannot prove it. If the dashboard were fed
      // `pos.orders` again, every other test here would still pass.
      //
      // PosProvider has no injectable clock: getOrdersForPeriod calls
      // DateTime.now() internally (pos_provider.dart:1569). So both orders are
      // anchored to a single captured `now`, and the midnight window is
      // eliminated by placing the orders at midday - roughly 12 hours from any
      // date boundary - rather than at 00:00.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final midday = Duration(hours: 12);

      final pos = PosProvider(initialOrders: [
        // Yesterday: paid and real, but outside the "today" window.
        paidOrder(
          id: 'YESTERDAY',
          createdAt: today.subtract(const Duration(days: 1, hours: -12)),
          grandTotal: 90000,
        ),
        // Today: the only order that may reach the chart.
        paidOrder(
          id: 'TODAY',
          createdAt: today.add(midday),
          grandTotal: 40000,
        ),
      ])..login('owner', 'owner123');

      // Guard: if the suite straddled midnight, the provider's notion of
      // "today" would shift and this assertion would be meaningless.
      expect(
        DateTime.now().day,
        today.day,
        reason: 'test ran across a date boundary; rerun',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerDashboard(
            pos: pos,
            onViewSalesReport: () {},
            onViewProducts: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final chartData =
          tester.widget<SalesBarChart>(find.byType(SalesBarChart)).data;
      final total = chartData.fold<int>(0, (s, b) => s + b.value);

      // Exactly today's 40000 - not 130000, which is what an unfiltered feed
      // would produce by also counting yesterday's 90000.
      expect(total, 40000);
      expect(total, isNot(130000));

      // Sanity-check the provider path this assertion depends on.
      expect(pos.getPaidOrdersForPeriod(ReportPeriod.today).length, 1);
      expect(pos.getSalesTotalForPeriod(ReportPeriod.today), 40000);
    });

    testWidgets('chart label describes the real data source', (tester) async {
      final pos = PosProvider()..login('owner', 'owner123');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerDashboard(
            pos: pos,
            onViewSalesReport: () {},
            onViewProducts: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Transaksi lunas hari ini'), findsOneWidget);
    });
  });
}