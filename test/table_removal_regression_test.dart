import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/screens/cashier/cashier_shell.dart';
import 'package:cafe_pos_demo/screens/checkout/payment_success_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_shell.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/cart_view.dart';
import 'package:cafe_pos_demo/widgets/receipt_widget.dart';

/// Regression tests for C17B: removal of table selection and management.
///
/// Seating is free-choice in this cafe, so the POS must no longer ask for a
/// table. Orders are therefore always recorded as `Takeaway`. These tests pin
/// that behaviour across checkout, payment, stock deduction and the receipt,
/// and confirm the remaining navigation is intact.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  PosProvider cashier() => PosProvider()..login('cashier', 'cashier123');

  group('checkout without table selection', () {
    test('order is recorded as Takeaway', () {
      final pos = cashier();
      pos.loadDemoQuickOrder();

      final order = pos.prepareCheckoutOrder();

      expect(order.tableNumber, 'Takeaway',
          reason: 'no table can be selected, so orders are always Takeaway');
      expect(pos.currentOrder!.tableNumber, 'Takeaway');
    });

    test('cash payment completes and deducts stock exactly once', () {
      final pos = cashier();
      final product = pos.products.firstWhere((p) => p.id == 'PRD-001');
      final stockBefore = product.stock;
      final paidBefore =
          pos.orders.where((o) => o.status == OrderStatus.paid).length;

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      final total = pos.currentOrder!.grandTotal;

      final order = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: total,
        changeAmount: 0,
      );

      expect(order.status, OrderStatus.paid);
      expect(order.tableNumber, 'Takeaway');
      expect(pos.products.firstWhere((p) => p.id == 'PRD-001').stock,
          stockBefore - 1);
      // Exactly one new paid order, not zero and not two.
      expect(pos.orders.where((o) => o.status == OrderStatus.paid).length,
          paidBefore + 1);
    });

    test('cash change is computed from the order total', () {
      final pos = cashier();
      pos.loadDemoQuickOrder();
      pos.prepareCheckoutOrder();
      final total = pos.currentOrder!.grandTotal;

      final order = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: total + 50000,
        changeAmount: 50000,
      );

      expect(order.changeAmount, 50000);
      expect(order.paidAmount - order.grandTotal, order.changeAmount);
    });

    test('rollback still restores stock, orders and history', () {
      final pos = cashier();
      final stockBefore = pos.products.firstWhere((p) => p.id == 'PRD-001').stock;
      final ordersBefore = pos.orders.length;
      final adjustmentsBefore = pos.stockAdjustments.length;

      pos.addToCart(pos.products.firstWhere((p) => p.id == 'PRD-001'), qty: 1);
      pos.prepareCheckoutOrder();
      pos.debugThrowAfterInventoryApply = () => throw StateError('boom');

      expect(
        () => pos.completePayment(
          method: PaymentMethod.cash,
          paidAmount: pos.cartGrandTotal,
          changeAmount: 0,
        ),
        throwsA(isA<StateError>()),
      );
      pos.debugThrowAfterInventoryApply = null;

      expect(pos.products.firstWhere((p) => p.id == 'PRD-001').stock, stockBefore);
      expect(pos.orders.length, ordersBefore);
      expect(pos.stockAdjustments.length, adjustmentsBefore);
    });

    test('duplicate payment does not deduct stock twice', () {
      final pos = cashier();
      final product = pos.products.firstWhere((p) => p.id == 'PRD-001');
      final stockBefore = product.stock;

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      final total = pos.currentOrder!.grandTotal;

      pos.completePayment(
          method: PaymentMethod.cash, paidAmount: total, changeAmount: 0);
      final afterFirst = pos.products.firstWhere((p) => p.id == 'PRD-001').stock;

      // Second call must be idempotent.
      pos.completePayment(
          method: PaymentMethod.cash, paidAmount: total, changeAmount: 0);

      expect(pos.products.firstWhere((p) => p.id == 'PRD-001').stock, afterFirst);
      expect(afterFirst, stockBefore - 1);
    });
  });

  group('receipt does not advertise a table', () {
    testWidgets('Takeaway order hides the Meja row', (tester) async {
      final pos = cashier();
      pos.loadDemoQuickOrder();
      pos.prepareCheckoutOrder();
      final total = pos.currentOrder!.grandTotal;
      final order = pos.completePayment(
          method: PaymentMethod.cash, paidAmount: total, changeAmount: 0);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: ReceiptWidget(order: order)),
      );
      await tester.pumpAndSettle();

      // "Meja Takeaway" would be nonsense for free-choice seating.
      expect(find.textContaining('Meja'), findsNothing);
      expect(find.textContaining('Takeaway'), findsNothing);
      // Real receipt data is still shown.
      expect(find.textContaining(order.orderNumber), findsWidgets);
      expect(find.textContaining('Kasir'), findsWidgets);
    });

    testWidgets('a legacy order with a real table still shows the Meja row',
        (tester) async {
      final legacy = Order(
        orderNumber: 'ORD-LEGACY-0001',
        tableNumber: 'A03',
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

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: ReceiptWidget(order: legacy)),
      );
      await tester.pumpAndSettle();

      // Historical table data must not be erased from the contract.
      expect(find.textContaining('Meja A03'), findsWidgets);
    });

    testWidgets('success screen labels takeaway as taken at the counter',
        (tester) async {
      final pos = cashier();
      pos.loadDemoQuickOrder();
      pos.prepareCheckoutOrder();
      final total = pos.currentOrder!.grandTotal;
      pos.completePayment(
          method: PaymentMethod.cash, paidAmount: total, changeAmount: 0);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PaymentSuccessScreen(
            pos: pos,
            onViewReceipt: () {},
            onNewOrder: () {},
            onGoToCashier: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Meja Takeaway'), findsNothing);
      expect(find.textContaining('Ambil di kasir'), findsWidgets);
    });
  });

  group('navigation after removing table screens', () {
    testWidgets('cashier shell no longer offers a table tab', (tester) async {
      final pos = cashier();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CashierShell(pos: pos, onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Denah Meja'), findsNothing);
      expect(find.textContaining('Meja'), findsNothing);
      // Remaining tabs still present.
      expect(find.text('POS / Pesanan'), findsOneWidget);
      expect(find.text('Pesanan Selesai'), findsOneWidget);
      expect(find.text('Shift Kasir'), findsOneWidget);
    });

    testWidgets('owner shell no longer offers a table management entry',
        (tester) async {
      final pos = PosProvider()..login('owner', 'owner123');
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerShell(pos: pos, onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Denah & Meja'), findsNothing);
      expect(find.text('Manajemen Meja'), findsNothing);

      // Every remaining owner destination is still reachable from the sidebar.
      for (final label in [
        'Dashboard Bisnis',
        'Pesanan (Orders)',
        'Penjualan (Sales)',
        'Katalog Menu (Produk)',
        'Kategori Menu',
        'Inventaris & Stok',
        'Laporan Bisnis',
        'Monitoring Shift',
        'Pengaturan Kafe',
      ]) {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) {
          fail('owner nav item missing after table removal: $label');
        }
      }
    });
  });

  group('cart and payment no longer show a table', () {
    testWidgets('cart view shows free-choice seating text', (tester) async {
      final pos = cashier();
      pos.loadDemoQuickOrder();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CartViewHost(pos: pos),
        ),
      );
      await tester.tap(find.text('cart'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bebas pilih meja'), findsWidgets);
      expect(find.textContaining('Ganti'), findsNothing);
    });
  });
}

/// Minimal host that opens the real cart sheet used by `OrderScreen`.
class CartViewHost extends StatelessWidget {
  final PosProvider pos;
  const CartViewHost({super.key, required this.pos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(14),
              child: CartView(pos: pos, onCheckout: () {}),
            ),
          ),
          child: const Text('cart'),
        ),
      ),
    );
  }
}
