import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/data/mock_data.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/screens/owner/owner_inventory_screen.dart';
import 'package:cafe_pos_demo/models/stock_adjustment.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_formatter.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/cart_view.dart';

/// Regression tests for C18: free-seating wording, honest inventory history,
/// and configuration-driven cart labels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Order orderWithTable(String table) => Order(
        orderNumber: 'ORD-TEST-0001',
        tableNumber: table,
        items: const [],
        subtotal: 50000,
        serviceCharge: 0,
        tax: 0,
        grandTotal: 50000,
        paymentMethod: PaymentMethod.cash,
        status: OrderStatus.paid,
        paidAmount: 50000,
        changeAmount: 0,
        createdAt: DateTime(2026, 10, 10, 12),
        cashierName: 'Tester',
      );

  group('free-seating labels', () {
    test('Takeaway is never labelled as a table', () {
      expect(orderWithTable('Takeaway').tableLabel, 'Takeaway');
      expect(orderWithTable('takeaway').tableLabel, 'Takeaway');
      expect(orderWithTable('').tableLabel, 'Takeaway');
      expect(orderWithTable('   ').tableLabel, 'Takeaway');
    });

    test('legacy real table numbers are preserved', () {
      expect(orderWithTable('A03').tableLabel, 'Meja A03');
      expect(orderWithTable('B01').tableLabel, 'Meja B01');
      expect(orderWithTable('VIP-1').tableLabel, 'Meja VIP-1');
    });

    test('every new POS order records Takeaway', () {
      final pos = PosProvider()..login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();
      expect(pos.prepareCheckoutOrder().tableNumber, 'Takeaway');
    });

    test('telegram notification reports Takeaway instead of a table', () {
      final text = TelegramFormatter().formatTransactionNotification(
        TransactionNotifData(
          orderNumber: 'ORD-1',
          tableNumber: 'Takeaway',
          cashierName: 'Tester',
          items: const [],
          paymentMethod: 'Tunai',
          grandTotal: 50000,
          timestamp: DateTime(2026, 10, 10, 12),
        ),
      );

      expect(text.contains('Meja:'), isFalse,
          reason: 'a takeaway order must not be shown with a Meja line');
      expect(text.contains('Tipe: Takeaway'), isTrue);
    });

    test('telegram notification still shows a legacy table', () {
      final text = TelegramFormatter().formatTransactionNotification(
        TransactionNotifData(
          orderNumber: 'ORD-2',
          tableNumber: 'A03',
          cashierName: 'Tester',
          items: const [],
          paymentMethod: 'Tunai',
          grandTotal: 50000,
          timestamp: DateTime(2026, 10, 10, 12),
        ),
      );

      expect(text.contains('Meja: A03'), isTrue);
    });
  });

  group('inventory history honesty', () {
    test('seeded rows are marked as sample data', () {
      final seeded = MockData.getInitialStockAdjustments();

      expect(seeded, isNotEmpty);
      for (final adj in seeded) {
        expect(adj.reason, startsWith(MockData.samplePrefix),
            reason: '${adj.id} must be labelled as sample data');
      }
    });

    test('real user adjustments are not labelled as sample data', () {
      final pos = PosProvider()..login('owner', 'owner123');
      final product = pos.products.first;

      pos.adjustStock(
        productId: product.id,
        type: AdjustmentType.add,
        quantity: 5,
        reason: 'Restok dari supplier',
      );

      final real = pos.stockAdjustments.first;
      expect(real.reason, isNot(startsWith(MockData.samplePrefix)),
          reason: 'a genuine adjustment must not be marked as sample data');
      expect(real.reason, 'Restok dari supplier');
    });

    test('real and sample rows coexist without confusing each other', () {
      final pos = PosProvider()..login('owner', 'owner123');
      final before = pos.stockAdjustments.length;

      pos.adjustStock(
        productId: pos.products.first.id,
        type: AdjustmentType.remove,
        quantity: 1,
        reason: 'Barang rusak',
      );

      expect(pos.stockAdjustments.length, before + 1);
      // Newest entry is the real one; seeded samples remain flagged.
      expect(pos.stockAdjustments.first.reason, isNot(contains(MockData.samplePrefix)));
      final sampleRows =
          pos.stockAdjustments.where((a) => a.reason.contains(MockData.samplePrefix));
      expect(sampleRows.length, 3, reason: 'all three seeded rows stay flagged');
    });

    testWidgets('history screen shows a Data Contoh badge for sample rows',
        (tester) async {
      final pos = PosProvider()..login('owner', 'owner123');

      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerInventoryScreen(pos: pos),
        ),
      );
      await tester.pumpAndSettle();

      // Adjustment history is its own tab; open it before asserting.
      await tester.tap(find.textContaining('Riwayat'));
      await tester.pumpAndSettle();

      // The seeded sample rows must be visibly distinguished.
      expect(find.text('Data Contoh'), findsWidgets,
          reason: 'every seeded row should carry the sample badge');

      // A real adjustment made in-session must NOT be badged as sample data.
      pos.adjustStock(
        productId: pos.products.first.id,
        type: AdjustmentType.add,
        quantity: 2,
        reason: 'Restok nyata',
      );
      // The screen registers no provider listener (it relies on the parent
      // shell rebuilding), so re-mount it to observe the new row.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerInventoryScreen(pos: pos),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Riwayat'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Restok nyata'),
        findsWidgets,
        reason: 'a genuine adjustment must appear in history',
      );
    });
  });

  group('cart tax and service labels follow configuration', () {
    Future<void> pumpCart(WidgetTester tester, PosProvider pos) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: const BoxDecoration(color: Colors.white),
                    padding: const EdgeInsets.all(14),
                    child: CartView(pos: pos, onCheckout: () {}),
                  ),
                ),
                child: const Text('cart'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('cart'));
      await tester.pumpAndSettle();
    }

    testWidgets('default rates render as 5% and 10%', (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();

      await pumpCart(tester, pos);

      expect(find.textContaining('Biaya Layanan (5%)'), findsOneWidget);
      expect(find.textContaining('Pajak PB1 (10%)'), findsOneWidget);
    });

    testWidgets('non-default rates render from businessConfig', (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();

      await pos.updateBusinessConfig(
        pos.businessConfig.copyWith(
          taxPercent: 11,
          serviceChargePercent: 6,
        ),
      );

      await pumpCart(tester, pos);

      expect(find.textContaining('Biaya Layanan (6%)'), findsOneWidget);
      expect(find.textContaining('Pajak PB1 (11%)'), findsOneWidget);
      // The hardcoded defaults must be gone.
      expect(find.textContaining('Biaya Layanan (5%)'), findsNothing);
      expect(find.textContaining('Pajak PB1 (10%)'), findsNothing);
    });

    testWidgets('zero rates render as 0% rather than a stale default',
        (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();

      await pos.updateBusinessConfig(
        pos.businessConfig.copyWith(
          taxPercent: 0,
          serviceChargePercent: 0,
        ),
      );

      await pumpCart(tester, pos);

      expect(find.textContaining('Biaya Layanan (0%)'), findsOneWidget);
      expect(find.textContaining('Pajak PB1 (0%)'), findsOneWidget);
    });

    testWidgets('disabled charges are labelled nonaktif', (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();

      await pos.updateBusinessConfig(
        pos.businessConfig.copyWith(
          isTaxEnabled: false,
          isServiceEnabled: false,
        ),
      );

      await pumpCart(tester, pos);

      expect(find.textContaining('Biaya Layanan (nonaktif)'), findsOneWidget);
      expect(find.textContaining('Pajak PB1 (nonaktif)'), findsOneWidget);
    });

    test('changing rates changes the charge, not just the label', () async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();
      final subtotal = pos.cartSubtotal;

      await pos.updateBusinessConfig(
        pos.businessConfig.copyWith(
          taxPercent: 11,
          serviceChargePercent: 6,
        ),
      );

      expect(pos.cartServiceCharge, (subtotal * 0.06).round());
      expect(pos.cartTax, (subtotal * 0.11).round());
      expect(pos.cartGrandTotal,
          subtotal + pos.cartServiceCharge + pos.cartTax);
    });
  });
}
