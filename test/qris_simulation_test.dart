import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/screens/checkout/payment_screen.dart';
import 'package:cafe_pos_demo/services/payment/payment_service.dart';
import 'package:cafe_pos_demo/services/payment/qris_payment_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockQrisPaymentService Unit Tests', () {
    test('transitions through waiting -> detected -> verifying -> success', () async {
      final service = MockQrisPaymentService(
        waitingDelay: const Duration(milliseconds: 50),
        detectionDelay: const Duration(milliseconds: 50),
        verificationDelay: const Duration(milliseconds: 50),
      );

      final states = <PaymentStatus>[];
      service.statusStream.listen(states.add);

      await service.createPayment(
        orderNumber: 'ORD-TEST-001',
        amount: 50000,
        method: PaymentMethod.qris,
      );

      expect(service.currentStatus, PaymentStatus.waiting);

      final completer = Completer<void>();
      service.startSimulation(onComplete: () => completer.complete());

      await completer.future;

      expect(service.currentStatus, PaymentStatus.success);
      expect(states, [
        PaymentStatus.waiting,
        PaymentStatus.detected,
        PaymentStatus.verifying,
        PaymentStatus.success,
      ]);

      service.dispose();
    });

    test('cancelPayment stops timers and transitions to cancelled without reaching success', () async {
      final service = MockQrisPaymentService(
        waitingDelay: const Duration(milliseconds: 100),
        detectionDelay: const Duration(milliseconds: 100),
        verificationDelay: const Duration(milliseconds: 100),
      );

      final states = <PaymentStatus>[];
      service.statusStream.listen(states.add);

      await service.createPayment(
        orderNumber: 'ORD-TEST-002',
        amount: 25000,
        method: PaymentMethod.qris,
      );

      service.startSimulation();

      // Cancel before waitingDelay finishes
      await Future.delayed(const Duration(milliseconds: 30));
      await service.cancelPayment('cancelled');

      // Wait past all delays to confirm no late timers fired
      await Future.delayed(const Duration(milliseconds: 350));

      expect(service.currentStatus, PaymentStatus.cancelled);
      expect(states.contains(PaymentStatus.success), isFalse);

      service.dispose();
    });
  });

  group('PaymentScreen QRIS Simulation Widget Tests', () {
    testWidgets('QRIS simulation runs through all steps and completes payment', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final pos = PosProvider();
      pos.login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();

      final initialStock = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock;
      final initialOrderCount = pos.orders.length;

      bool paymentCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            pos: pos,
            onPaymentCompleted: () => paymentCompleted = true,
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();

      // 1. Switch to QRIS Tab
      final qrisTab = find.text('QRIS Demo');
      expect(qrisTab, findsOneWidget);
      await tester.tap(qrisTab);
      await tester.pump();

      // 2. SHOW_QR state: QR code and simulation trigger button must be visible
      final simButton = find.text('Simulasi Pelanggan Scan & Bayar');
      expect(simButton, findsOneWidget);

      // Verify no inventory deducted yet
      expect(pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock, initialStock);
      expect(pos.orders.length, initialOrderCount);

      // 3. Tap simulation button to start
      await tester.tap(simButton);
      await tester.pump();

      // 4. WAITING state
      expect(find.text('Menunggu pembayaran pelanggan...'), findsOneWidget);

      // Advance through waiting -> detected (2.0s)
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.text('Pembayaran QRIS Terdeteksi!'), findsOneWidget);

      // Advance through detected -> verifying (2.0s)
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.text('Memverifikasi Settlement...'), findsOneWidget);

      // Advance through verifying -> success (1.5s)
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('Pembayaran Berhasil!'), findsOneWidget);

      // Advance through final completion delay (500ms + handlePay 350ms)
      await tester.pump(const Duration(milliseconds: 900));

      // 5. Payment Completed callback fired
      expect(paymentCompleted, isTrue);

      // 6. Verify inventory was deducted exactly once (demo quick order has 2x Kopi Susu)
      final afterStock = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock;
      expect(afterStock, initialStock - 2);

      // 7. Verify exactly one order added
      expect(pos.orders.length, initialOrderCount + 1);
      expect(pos.orders.first.paymentMethod, PaymentMethod.qris);
      expect(pos.orders.first.status, OrderStatus.paid);
    });

    testWidgets('Canceling QRIS simulation does NOT complete payment or deduct inventory', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final pos = PosProvider();
      pos.login('cashier', 'cashier123');
      pos.loadDemoQuickOrder();

      final initialStock = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock;
      final initialOrderCount = pos.orders.length;

      bool paymentCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            pos: pos,
            onPaymentCompleted: () => paymentCompleted = true,
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();

      // Switch to QRIS Tab
      await tester.tap(find.text('QRIS Demo'));
      await tester.pump();

      // Start simulation
      await tester.tap(find.text('Simulasi Pelanggan Scan & Bayar'));
      await tester.pump();

      expect(find.text('Menunggu pembayaran pelanggan...'), findsOneWidget);

      // Tap cancel button while waiting
      final cancelButton = find.text('Batalkan Simulasi');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();

      // Should return to showQr state
      expect(find.text('Simulasi Pelanggan Scan & Bayar'), findsOneWidget);

      // Wait past any simulation delay to confirm nothing fires
      await tester.pump(const Duration(seconds: 10));

      expect(paymentCompleted, isFalse);
      expect(pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock, initialStock);
      expect(pos.orders.length, initialOrderCount);
    });

    testWidgets('Consecutive QRIS payments create distinct sessions without duplicate deductions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final pos = PosProvider();
      pos.login('cashier', 'cashier123');

      // Order 1
      pos.loadDemoQuickOrder();
      final initialStock = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock;
      final initialOrderCount = pos.orders.length;

      int completedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            key: const ValueKey('payment_1'),
            pos: pos,
            onPaymentCompleted: () => completedCount++,
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();

      // Run QRIS 1
      await tester.tap(find.text('QRIS Demo'));
      await tester.pump();
      await tester.tap(find.text('Simulasi Pelanggan Scan & Bayar'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 2100)); // detected
      await tester.pump(const Duration(milliseconds: 2100)); // verifying
      await tester.pump(const Duration(milliseconds: 1600)); // success
      await tester.pump(const Duration(milliseconds: 900));  // complete

      expect(completedCount, 1);
      expect(pos.orders.length, initialOrderCount + 1);
      expect(pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock, initialStock - 2);

      // Order 2
      pos.clearCart();
      pos.loadDemoQuickOrder();

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            key: const ValueKey('payment_2'),
            pos: pos,
            onPaymentCompleted: () => completedCount++,
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();

      // Run QRIS 2
      await tester.tap(find.text('QRIS Demo'));
      await tester.pump();
      await tester.tap(find.text('Simulasi Pelanggan Scan & Bayar'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 2100)); // detected
      await tester.pump(const Duration(milliseconds: 2100)); // verifying
      await tester.pump(const Duration(milliseconds: 1600)); // success
      await tester.pump(const Duration(milliseconds: 900));  // complete

      expect(completedCount, 2);
      expect(pos.orders.length, initialOrderCount + 2);
      expect(pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren').stock, initialStock - 4);
    });
  });
}
