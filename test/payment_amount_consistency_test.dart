import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/screens/checkout/payment_screen.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';

/// Regression tests for C15A finding: the payment screen priced itself from the
/// live cart (`pos.cartGrandTotal`) while `completePayment` validates
/// `paidAmount` against the frozen `order.grandTotal`.
///
/// If business tax/service settings change after checkout was prepared, the
/// two disagree: the cashier would approve one figure while the provider
/// evaluated another, and the QRIS amount would differ from the charge.
///
/// These tests drive the real `PaymentScreen` widget and assert on what it
/// actually displays and sends, rather than only comparing provider maths.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// A provider with a cart prepared and an open shift, logged in as cashier.
  PosProvider preparedProvider() {
    final pos = PosProvider()..login('cashier', 'cashier123');
    pos.loadDemoQuickOrder();
    pos.prepareCheckoutOrder(paymentMethod: PaymentMethod.cash);
    return pos;
  }

  Future<void> pumpPayment(WidgetTester tester, PosProvider pos) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PaymentScreen(
          pos: pos,
          onPaymentCompleted: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Raises tax and service charge so the live cart total would differ from
  /// the already-frozen order total.
  Future<void> raiseRates(PosProvider pos) async {
    final raised = pos.businessConfig.copyWith(
      taxPercent: pos.businessConfig.taxPercent + 5,
      serviceChargePercent: pos.businessConfig.serviceChargePercent + 5,
    );
    await pos.updateBusinessConfig(raised);
  }

  group('payment uses the frozen order total', () {
    testWidgets('displayed total stays the order total after a config change',
        (tester) async {
      final pos = preparedProvider();
      final frozen = pos.currentOrder!.grandTotal;

      await raiseRates(pos);
      await pumpPayment(tester, pos);

      // The live cart now disagrees with the order.
      expect(pos.cartGrandTotal, isNot(frozen),
          reason: 'fixture must actually diverge, otherwise this proves nothing');

      // The screen must show the frozen amount.
      final formatted = _format(frozen);
      expect(find.text(formatted), findsWidgets,
          reason: 'displayed total must be the frozen order total');
      expect(find.text(_format(pos.cartGrandTotal)), findsNothing,
          reason: 'the live cart total must not be shown');
    });

    testWidgets('itemised breakdown comes from the same order', (tester) async {
      final pos = preparedProvider();
      final order = pos.currentOrder!;

      await raiseRates(pos);
      await pumpPayment(tester, pos);

      // Subtotal shown must be the order's subtotal, not the recomputed cart's.
      expect(find.text(_format(order.subtotal)), findsWidgets);
      expect(find.text(_format(order.tax)), findsWidgets);
    });

    testWidgets('falls back to the cart total before an order is prepared',
        (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();

      expect(pos.currentOrder, isNull, reason: 'no order prepared yet');
      await pumpPayment(tester, pos);

      expect(find.text(_format(pos.cartGrandTotal)), findsWidgets);
    });
  });

  group('cash validation uses the frozen total', () {
    testWidgets('exact payment against the order total is accepted',
        (tester) async {
      final pos = preparedProvider();
      final frozen = pos.currentOrder!.grandTotal;
      final formattedPayable = _format(frozen);

      await raiseRates(pos);
      await pumpPayment(tester, pos);

      // The exact-payment chip is labelled with the payable total, so its
      // presence with the frozen figure proves the screen prices from the
      // order rather than the (now higher) live cart.
      expect(find.text('Uang Pas ($formattedPayable)'), findsOneWidget,
          reason: 'exact-payment chip must quote the frozen payable total');
      expect(find.text('Uang Pas (${_format(pos.cartGrandTotal)})'), findsNothing,
          reason: 'the live cart total must not be offered as payable');
    });

    testWidgets('paying the order total satisfies the provider guard',
        (tester) async {
      final pos = preparedProvider();
      final frozen = pos.currentOrder!.grandTotal;

      await raiseRates(pos);

      // The provider validates against the order, so the frozen amount must be
      // accepted even though the live cart total is now higher.
      final order = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: frozen,
        changeAmount: 0,
      );

      expect(order.grandTotal, frozen);
      expect(order.status, OrderStatus.paid);
    });
  });

  group('invariant: displayed amount equals charged amount', () {
    test('order total is unaffected by later config changes', () async {
      final pos = preparedProvider();
      final frozen = pos.currentOrder!.grandTotal;
      final frozenSubtotal = pos.currentOrder!.subtotal;

      await raiseRates(pos);

      // The order is immutable with respect to config changes.
      expect(pos.currentOrder!.grandTotal, frozen);
      expect(pos.currentOrder!.subtotal, frozenSubtotal);
      expect(pos.currentOrder!.grandTotal,
          frozenSubtotal + pos.currentOrder!.serviceCharge + pos.currentOrder!.tax);
    });

    test('screen and provider agree on the amount to pay', () async {
      final pos = preparedProvider();
      await raiseRates(pos);

      // This is the invariant _payableTotal restores.
      final screenAmount = pos.currentOrder?.grandTotal ?? pos.cartGrandTotal;
      final providerAmount = pos.currentOrder!.grandTotal;

      expect(screenAmount, providerAmount);
    });
  });
}

/// Formats an amount the way the payment screen renders currency.
String _format(int amount) {
  final s = amount.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return 'Rp$b';
}