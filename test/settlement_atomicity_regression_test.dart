// Locks the settlement atomicity contract documented on
// `PosProvider.completePayment`.
//
// The rollback machinery is positional: the snapshot records list lengths and
// stock keyed by collection index, and restore truncates back to those lengths.
// That is only sound while a commit is one uninterrupted synchronous step, and
// only if a partial failure restores *everything*.
//
// These tests deliberately exercise BEHAVIOUR (state before == state after),
// not source text. The architectural rule "no `await` in the commit window" is
// documented in code comments because a test asserting the absence of a keyword
// would pass just as happily against a broken, differently-spelled commit.
//
// Existing coverage in `inventory_ledger_regression_test.dart` (H-1..H-3)
// checks lengths and counts after a rollback. This file strengthens that with
// exact VALUE equality, exception identity, notification suppression, and the
// idempotency of a successful sale.

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/repositories/order_repository.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory Telegram double: records sale notifications so a rolled-back sale
/// can be proven never to have been announced.
class _RecordingTelegramService implements TelegramService {
  final List<TransactionNotifData> transactions = [];
  int attempts = 0;

  @override
  bool get isEnabled => true;

  @override
  TelegramConfig get config => const TelegramConfig();

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendTransactionNotification(
      TransactionNotifData data) async {
    attempts++;
    transactions.add(data);
    return TelegramSendResult.success(message: 'ok');
  }

  @override
  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendShiftReport(ShiftReportData report) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) async =>
      TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> testConnection() async =>
      TelegramSendResult.success(message: 'ok');
}

/// Full observable fingerprint of everything a sale commit may mutate.
///
/// Comparing this whole object is what proves "state is exactly as before",
/// rather than merely "the counts look right".
({List<int> productStocks, List<double> materialStocks, List<String> adjustmentKeys,
  List<String> orderNumbers, int cartItemCount, String? currentOrderNumber,
  String? currentOrderStatus}) fingerprint(PosProvider pos) {
  return (
    productStocks: pos.products.map((p) => p.stock).toList(),
    materialStocks: pos.rawMaterials.map((m) => m.stock).toList(),
    adjustmentKeys: pos.stockAdjustments.map((a) => '${a.id}|${a.type}').toList(),
    orderNumbers: pos.orders.map((o) => '${o.id}|${o.orderNumber}').toList(),
    cartItemCount: pos.cartItemCount,
    currentOrderNumber: pos.currentOrder?.orderNumber,
    currentOrderStatus: pos.currentOrder?.status.name,
  );
}

void main() {
  late PosProvider pos;
  late _RecordingTelegramService telegram;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pos = PosProvider();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    pos.login('cashier', 'cashier123');
    telegram = _RecordingTelegramService();
    pos.setTelegramService(telegram);
  });

  tearDown(() {
    pos.debugThrowAfterInventoryApply = null;
  });

  /// A product that consumes a raw material, so one sale mutates BOTH
  /// finished-product and raw-material stock. `PRD-001` is the seeded coffee
  /// with a recipe (the same fixture the inventory ledger tests rely on), which
  /// is what makes the rollback assertions below meaningful rather than vacuous.
  Product recipeProduct() {
    final product = pos.products.firstWhere((p) => p.id == 'PRD-001',
        orElse: () => pos.products.first);
    expect(pos.products.firstWhere((p) => p.id == product.id).stock > 0, isTrue,
        reason: 'fixture product must be in stock');
    return product;
  }

  void armFailure() {
    pos.debugThrowAfterInventoryApply = () =>
        throw StateError('simulated apply failure');
  }

  Order pay() => pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.cartGrandTotal + 100000,
        changeAmount: 0,
      );

  group('partial apply failure restores state exactly', () {
    test('product and material stock return to their exact prior values', () {
      final product = recipeProduct();
      final productStockBefore =
          pos.products.firstWhere((p) => p.id == product.id).stock;
      final materialStocksBefore =
          pos.rawMaterials.map((m) => m.stock).toList();

      pos.addToCart(product, qty: 2);
      pos.prepareCheckoutOrder();

      armFailure();
      expect(() => pay(), throwsA(isA<StateError>()));

      // EXACT values, not just "less than" or "equal length".
      expect(
        pos.products.firstWhere((p) => p.id == product.id).stock,
        productStockBefore,
        reason: 'finished-product stock must be exactly restored',
      );
      expect(pos.rawMaterials.map((m) => m.stock).toList(),
          materialStocksBefore,
          reason: 'every raw material must be exactly restored');
    });

    test('order list, adjustments, currentOrder and cart are unchanged', () {
      final product = recipeProduct();

      pos.addToCart(product, qty: 2);
      final pending = pos.prepareCheckoutOrder();

      final before = fingerprint(pos);

      armFailure();
      expect(() => pay(), throwsA(isA<StateError>()));

      final after = fingerprint(pos);

      expect(after.orderNumbers, before.orderNumbers,
          reason: 'no order may be committed or lost');
      expect(after.adjustmentKeys, before.adjustmentKeys,
          reason: 'stock adjustment history must be exactly restored');
      expect(after.cartItemCount, before.cartItemCount,
          reason: 'cart must survive for a retry');
      expect(after.currentOrderNumber, pending.orderNumber);
      expect(after.currentOrderStatus, OrderStatus.pending.name);
      expect(pos.currentOrder, same(pending),
          reason: 'the pending order object itself must be restored');
    });

    test('the whole state fingerprint is identical after rollback', () {
      final product = recipeProduct();

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      final before = fingerprint(pos);

      armFailure();
      expect(() => pay(), throwsA(isA<StateError>()));

      expect(fingerprint(pos).toString(), before.toString(),
          reason: 'a rolled-back sale must be a no-op on observable state');
    });
  });

  group('exception propagation', () {
    test('the original exception is rethrown, not replaced', () {
      final boom = StateError('original-cause');
      pos.addToCart(recipeProduct(), qty: 1);
      pos.prepareCheckoutOrder();

      pos.debugThrowAfterInventoryApply = () => throw boom;

      Object? caught;
      try {
        pay();
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught, same(boom),
          reason: 'the real cause must survive the rollback');
      expect((caught! as StateError).message, 'original-cause');
    });

    test('rollback happens before the exception escapes', () {
      final product = recipeProduct();
      final stockBefore =
          pos.products.firstWhere((p) => p.id == product.id).stock;

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      armFailure();

      // State observed from inside the catch must already be restored.
      expect(
        () {
          try {
            pay();
          } catch (_) {
            expect(pos.products.firstWhere((p) => p.id == product.id).stock,
                stockBefore);
            expect(pos.orders.where((o) => o.status == OrderStatus.paid).length,
                greaterThanOrEqualTo(0));
            rethrow;
          }
        },
        throwsA(isA<StateError>()),
      );
    });
  });

  group('notifications never reflect a failed sale', () {
    test('no successful-sale notification is sent for a rolled-back sale',
        () async {
      final product = recipeProduct();
      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();

      armFailure();
      expect(() => pay(), throwsA(isA<StateError>()));

      // Give any fire-and-forget notification a chance to land.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(telegram.attempts, 0,
          reason: 'a sale that rolled back must never be announced');
      expect(telegram.transactions, isEmpty);
    });

    test('a successful sale does notify exactly once', () async {
      final product = recipeProduct();
      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      pay();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(telegram.attempts, 1);
      expect(telegram.transactions.single.orderNumber,
          pos.orders.first.orderNumber);
    });
  });

  group('successful settlement stays idempotent', () {
    test('repeated payment does not double-deduct stock', () {
      final product = recipeProduct();
      final stockBefore =
          pos.products.firstWhere((p) => p.id == product.id).stock;
      final materialsBefore = pos.rawMaterials.map((m) => m.stock).toList();
      final adjustmentsBefore = pos.stockAdjustments.length;
      final ordersBefore = pos.orders.length;

      pos.addToCart(product, qty: 2);
      pos.prepareCheckoutOrder();
      final first = pay();

      expect(first.status, OrderStatus.paid);
      // Capture the committed state, then repeat payment and demand no change.
      // A sale writes one adjustment row per product AND per material
      // deduction, so the count is data-driven; the invariant is that it does
      // not grow further, not that it grows by exactly one.
      final stockAfterFirst =
          pos.products.firstWhere((p) => p.id == product.id).stock;
      final materialsAfterFirst = pos.rawMaterials.map((m) => m.stock).toList();
      final adjustmentsAfterFirst = pos.stockAdjustments.length;
      expect(stockAfterFirst, stockBefore - 2);
      expect(adjustmentsAfterFirst, greaterThan(adjustmentsBefore),
          reason: 'sanity: the first sale really did write history');

      final second = pay();
      final third = pay();

      expect(second.id, first.id);
      expect(third.id, first.id);
      expect(pos.products.firstWhere((p) => p.id == product.id).stock,
          stockAfterFirst,
          reason: 'stock must be deducted exactly once');
      expect(pos.rawMaterials.map((m) => m.stock).toList(), materialsAfterFirst,
          reason: 'raw material must be deducted exactly once');
      expect(materialsAfterFirst, isNot(materialsBefore),
          reason: 'sanity: the first sale really did move materials');
      expect(pos.orders.length, ordersBefore + 1,
          reason: 'only one order may be committed');
      expect(pos.stockAdjustments.length, adjustmentsAfterFirst,
          reason: 'repeating payment must append no further history');
    });

    test('a rolled-back sale can be retried and then commits once', () {
      final product = recipeProduct();
      final stockBefore =
          pos.products.firstWhere((p) => p.id == product.id).stock;
      final ordersBefore = pos.orders.length;

      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();

      armFailure();
      expect(() => pay(), throwsA(isA<StateError>()));
      pos.debugThrowAfterInventoryApply = null;

      // Retry without re-preparing: the cart and pending order were restored.
      final settled = pay();

      expect(settled.status, OrderStatus.paid);
      expect(pos.products.firstWhere((p) => p.id == product.id).stock,
          stockBefore - 1);
      expect(pos.orders.length, ordersBefore + 1);
      expect(pos.cartItemCount, 0, reason: 'cart cleared by the real commit');
    });
  });

  group('truncateTo runtime validation', () {
    test('valid lengths keep working (behaviour unchanged)', () {
      final repo = InMemoryOrderRepository();
      for (var i = 0; i < 3; i++) {
        repo.insert(_order('A$i', i));
      }

      repo.truncateTo(3);
      expect(repo.count, 3, reason: 'truncating to current length is a no-op');
      repo.truncateTo(1);
      expect(repo.count, 1);
      repo.truncateTo(0);
      expect(repo.count, 0);
    });

    test('an out-of-range length throws RangeError, not silently', () {
      final repo = InMemoryOrderRepository([_order('A', 1)]);

      // Must throw in EVERY build mode (assert is stripped in release).
      expect(() => repo.truncateTo(5), throwsA(isA<RangeError>()));
      expect(() => repo.truncateTo(-1), throwsA(isA<RangeError>()));
      expect(repo.count, 1, reason: 'a rejected truncate must not mutate');
    });

    test('the failure carries an actionable message', () {
      final repo = InMemoryOrderRepository([_order('A', 1)]);
      try {
        repo.truncateTo(9);
        fail('expected RangeError');
      } on RangeError catch (e) {
        expect(e.message.toString(), contains('order collection changed'),
            reason: 'the message must explain the likely cause');
      }
    });
  });
}

Order _order(String number, int seed) => Order.create(
      orderNumber: number,
      tableNumber: 'Takeaway',
      items: const [],
      cashierName: 'Tester',
      createdAt: DateTime(2026, 3, 15, 12, seed),
    );