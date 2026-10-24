import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/receipt_data.dart';
import 'package:cafe_pos_demo/models/user.dart';
import 'package:cafe_pos_demo/screens/owner/owner_settings_screen.dart';
import 'package:cafe_pos_demo/services/config/business_config_service.dart';
import 'package:cafe_pos_demo/services/printer/printer_service.dart';
import 'package:cafe_pos_demo/services/storage/local_app_storage.dart';
import 'package:cafe_pos_demo/services/telegram/mock_telegram_service.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

/// Recording Telegram transport with no artificial delay.
///
/// `testWidgets` runs in a fake-async zone where a real `Future.delayed` never
/// elapses unless the tester pumps past it, so the base mock's 300 ms hold would
/// deadlock any test awaiting a notification. Only the delay is dropped; the
/// recording behaviour is unchanged and stays fully in-memory.
class _InstantTelegramService extends MockTelegramService {
  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async {
    sentMessages.add(text);
    return TelegramSendResult.success(message: 'simulated', messageId: 1);
  }
}

/// Printer that resolves immediately, for the same fake-async reason.
class _InstantPrinterService implements PrinterService {
  @override
  PrinterModeType get mode => PrinterModeType.preview;

  @override
  PrinterConnectionState get connectionState => PrinterConnectionState.ready;

  @override
  Future<PrinterResult> printReceipt(ReceiptData receipt) async =>
      PrinterResult.success(message: 'preview ok');

  @override
  Future<PrinterResult> testPrint() async =>
      PrinterResult.success(message: 'test ok');

  @override
  Future<PrinterConnectionState> checkStatus() async =>
      PrinterConnectionState.ready;
}

/// Counts reset attempts and successful resets separately, so "the action was
/// refused" and "the action ran exactly once" are distinguishable. Observes
/// only; it does not alter behaviour.
class _CountingPosProvider extends PosProvider {
  int resetAttempts = 0;
  int resetCalls = 0;

  _CountingPosProvider({super.storage, super.configService});

  @override
  void resetDemoData() {
    resetAttempts++;
    super.resetDemoData();
    resetCalls++;
  }
}

Finder resetButton() => find.widgetWithText(OutlinedButton, 'Reset Data Demo');
Finder confirmButton() => find.widgetWithText(ElevatedButton, 'Reset');
Finder cancelButton() => find.widgetWithText(TextButton, 'Batal');

/// Scopes a text match to the open dialog, so the card text behind it cannot
/// satisfy a dialog-content assertion.
Finder inDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.textContaining(text),
    );

/// Proves the Owner-only "Reset Data Demo" control: who can reach it, what the
/// confirmation dialog promises, that cancelling is inert, and that confirming
/// performs exactly the reset specified on [PosProvider].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingPosProvider pos;

  /// Built in `setUp` — i.e. in real async, not the fake-async zone a
  /// `testWidgets` body runs in.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pos = await _makeProvider(isPublicDemo: true);
  });

  Future<void> pumpSettings(WidgetTester tester, PosProvider provider) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: OwnerSettingsScreen(pos: provider)));
    await tester.pumpAndSettle();
  }

  group('Access control', () {
    testWidgets('1. Owner in public demo can reach the reset control',
        (tester) async {
      pos.login('owner', 'owner123');

      await pumpSettings(tester, pos);

      expect(pos.canResetDemoData, isTrue);
      expect(resetButton(), findsOneWidget);
      expect(confirmButton(), findsNothing, reason: 'dialog not open yet');
    });

    testWidgets('2. Cashier gets no reset control and no access', (tester) async {
      pos.login('cashier', 'cashier123');

      await pumpSettings(tester, pos);

      expect(pos.canResetDemoData, isFalse);
      expect(find.text('Reset Data Demo'), findsNothing);

      // The state layer refuses even if the action is invoked directly.
      expect(pos.resetDemoData, throwsStateError);
      expect(pos.resetAttempts, 1, reason: 'it was attempted and refused');
      expect(pos.resetCalls, 0, reason: 'and never applied');
    });

    testWidgets('3. Owner in non-demo mode gets no reset control', (tester) async {
      final nonDemo = await tester.runAsync(() => _makeProvider(isPublicDemo: false));
      nonDemo!.login('owner', 'owner123');

      await pumpSettings(tester, nonDemo);

      expect(nonDemo.canResetDemoData, isFalse);
      expect(find.text('Reset Data Demo'), findsNothing);
      expect(nonDemo.resetDemoData, throwsStateError);
      expect(nonDemo.resetAttempts, 1);
      expect(nonDemo.resetCalls, 0);
    });
  });

  group('Confirmation dialog', () {
    testWidgets('4. The dialog states what is cleared and what is preserved',
        (tester) async {
      pos.login('owner', 'owner123');
      await pumpSettings(tester, pos);

      await tester.tap(resetButton());
      await tester.pumpAndSettle();

      expect(inDialog('transaksi dan omzet demo'), findsOneWidget);
      expect(inDialog('Pesanan aktif dan keranjang'), findsOneWidget);
      expect(inDialog('Riwayat shift sesi ini'), findsOneWidget);
      expect(inDialog('penyesuaian stok'), findsOneWidget);
      expect(inDialog('struk sesi ini'), findsOneWidget);

      expect(
        inDialog('Stok produk dan bahan baku (dipertahankan persis)'),
        findsOneWidget,
      );
      expect(inDialog('Menu, kategori, dan resep'), findsOneWidget);
      expect(inDialog('Akun Owner & Kasir'), findsOneWidget);
      expect(inDialog('Konfigurasi bisnis'), findsOneWidget);
      expect(inDialog('bukan untuk data operasional nyata'), findsOneWidget);

      expect(confirmButton(), findsOneWidget);
      expect(cancelButton(), findsOneWidget);
    });

    testWidgets('5. Cancelling changes nothing', (tester) async {
      pos.login('owner', 'owner123');
      _runSaleAsCashier(pos);
      pos.login('owner', 'owner123');
      final stockBefore = pos.products.map((p) => p.stock).toList();
      final ordersBefore = pos.orders.length;

      await pumpSettings(tester, pos);
      await tester.tap(resetButton());
      await tester.pumpAndSettle();
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();

      expect(pos.resetCalls, 0);
      expect(pos.orders, hasLength(ordersBefore));
      expect(pos.todaySalesTotal, greaterThan(0));
      expect(pos.products.map((p) => p.stock).toList(), stockBefore);
      expect(pos.stockAdjustments, isNotEmpty);
    });
  });

  group('Confirmed execution', () {
    testWidgets('6. Confirming resets exactly once and reports success',
        (tester) async {
      pos.login('owner', 'owner123');
      _runSaleAsCashier(pos);
      pos.login('owner', 'owner123');
      await pos.closeShift(actualEndingCash: 300000);
      await pos.printOrderReceipt(pos.orders.first);
      expect(pos.pastShifts, isNotEmpty);
      expect(pos.receiptService.receiptHistory, isNotEmpty);

      final stockBefore = pos.products.map((p) => p.stock).toList();
      final materialsBefore = pos.rawMaterials.map((m) => m.stock).toList();
      final productsBefore = pos.products.map((p) => p.id).toList();
      final pricesBefore = pos.products.map((p) => p.price).toList();
      final categoriesBefore = pos.categories.map((c) => c.name).toList();
      final recipesBefore = pos.recipes.keys.toSet();
      final configBefore = pos.businessConfig;

      await pumpSettings(tester, pos);
      await tester.tap(resetButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(pos.resetCalls, 1, reason: 'must reset exactly once');
      expect(pos.resetAttempts, 1, reason: 'no duplicate submission');
      expect(find.textContaining('berhasil dikosongkan'), findsOneWidget);

      // Transactions and revenue are zero.
      expect(pos.orders, isEmpty);
      expect(pos.todaySalesTotal, 0);
      expect(pos.todayTransactionsCount, 0);
      expect(pos.currentOrder, isNull);
      expect(pos.cart, isEmpty);

      // Stock is untouched.
      expect(pos.products.map((p) => p.stock).toList(), stockBefore);
      expect(pos.rawMaterials.map((m) => m.stock).toList(), materialsBefore);

      // Catalogue, account and configuration survive.
      expect(pos.products.map((p) => p.id).toList(), productsBefore);
      expect(pos.products.map((p) => p.price).toList(), pricesBefore);
      expect(pos.categories.map((c) => c.name).toList(), categoriesBefore);
      expect(pos.recipes.keys.toSet(), recipesBefore);
      expect(pos.currentUser!.role, UserRole.owner);
      expect(pos.businessConfig.businessName, configBefore.businessName);
      expect(pos.businessConfig.taxPercent, configBefore.taxPercent);
      expect(pos.login('cashier', 'cashier123'), isTrue);

      // Session history cleared, one open demo shift remains.
      expect(pos.stockAdjustments, isEmpty);
      expect(pos.receiptService.receiptHistory, isEmpty);
      expect(pos.pastShifts, isEmpty);
      expect(pos.hasActiveShift, isTrue);
      expect(pos.currentShift.isClosed, isFalse);
    });

    testWidgets('7. A new sale is still possible after the reset',
        (tester) async {
      pos.login('owner', 'owner123');
      await pumpSettings(tester, pos);

      await tester.tap(resetButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      final kopiSusu = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
      final stockBefore = kopiSusu.stock;

      _runSaleAsCashier(pos, qty: 2);

      expect(pos.todayTransactionsCount, 1);
      expect(pos.todaySalesTotal, greaterThan(0));
      expect(pos.products.firstWhere((p) => p.id == kopiSusu.id).stock, stockBefore - 2);
      expect(pos.orders.first.shiftId, pos.currentShift.shiftId);
    });

    testWidgets('8. A failing reset reports an error and stays usable',
        (tester) async {
      pos.login('owner', 'owner123');
      final stockBefore = pos.products.map((p) => p.stock).toList();
      final ordersBefore = pos.orders.length;

      pos.debugThrowBeforeResetApply =
          () => throw StateError('internal detail that must never be shown');

      await pumpSettings(tester, pos);
      await tester.tap(resetButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(pos.resetAttempts, 1, reason: 'one attempt, no retry loop');
      expect(pos.resetCalls, 0, reason: 'the attempt did not apply');
      expect(find.textContaining('gagal dan dibatalkan'), findsOneWidget);
      expect(find.textContaining('internal detail'), findsNothing,
          reason: 'raw error detail must not reach the UI');

      // Nothing cleared, and the control is usable again — no stuck spinner.
      expect(pos.orders, hasLength(ordersBefore));
      expect(pos.products.map((p) => p.stock).toList(), stockBefore);
      expect(find.text('Mengosongkan Data...'), findsNothing);
      expect(resetButton(), findsOneWidget);

      // Dismiss the error dialog, then retry successfully.
      await tester.tap(find.widgetWithText(TextButton, 'Tutup'));
      await tester.pumpAndSettle();

      pos.debugThrowBeforeResetApply = null;
      await tester.tap(resetButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(pos.resetCalls, 1);
      expect(pos.resetAttempts, 2);
      expect(pos.orders, isEmpty);
    });

    testWidgets('9. No external notification is emitted by the reset',
        (tester) async {
      final telegram = _InstantTelegramService();
      pos.setTelegramService(telegram);
      pos.login('owner', 'owner123');
      _runSaleAsCashier(pos);
      pos.login('owner', 'owner123');
      await tester.pump();
      expect(telegram.sentMessages, isNotEmpty,
          reason: 'the recording transport must be proven capable first');

      telegram.sentMessages.clear();

      await pumpSettings(tester, pos);
      await tester.tap(resetButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      await tester.pump();

      expect(telegram.sentMessages, isEmpty);
    });
  });
}

/// Real-async provider construction. Safe to call from `setUp` and from
/// `tester.runAsync`, unlike inside a `testWidgets` body.
Future<_CountingPosProvider> _makeProvider({required bool isPublicDemo}) async {
  final storage = LocalAppStorage();
  final configService = LocalBusinessConfigService(storage);
  await configService.init();
  await configService.saveConfig(
    BusinessConfig.defaultCaffeDemo().copyWith(isPublicDemo: isPublicDemo),
  );
  final provider =
      _CountingPosProvider(storage: storage, configService: configService);
  await provider.loadPersistedConfig();
  await Future<void>.delayed(const Duration(milliseconds: 20));
  provider.setTelegramService(_InstantTelegramService());
  provider.receiptService.setCustomPrinter(_InstantPrinterService());
  return provider;
}

/// Runs one complete sale under the Cashier role.
void _runSaleAsCashier(PosProvider pos, {int qty = 2}) {
  pos.login('cashier', 'cashier123');
  final kopiSusu = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
  pos.addToCart(kopiSusu, qty: qty);
  pos.prepareCheckoutOrder();
  final order = pos.currentOrder!;
  pos.completePayment(
    method: order.paymentMethod,
    paidAmount: order.grandTotal,
    changeAmount: 0,
  );
}