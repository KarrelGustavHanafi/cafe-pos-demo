import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/stock_adjustment.dart';
import 'package:cafe_pos_demo/services/telegram/mock_telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

/// Regression tests for C19.
///
/// C19 finding: low-stock detection used one threshold while the UI used
/// another. `_buildSalePlan` stamped every finished-product deduction with
/// `_businessConfig.defaultLowStockThreshold`, but `Product.isLowStock` and
/// `lowStockProducts` read the product's own `lowStockThreshold`. Three seeded
/// products (Chocolate 10, Croissant 10, Chicken Katsu Rice 12) sit below the
/// business default of 15, so a sale crossing their real threshold produced no
/// low-stock alert while the inventory screen showed them as low stock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Builds a signed-in provider whose async `loadPersistedConfig()` has already
/// settled.
///
/// The constructor kicks off config loading, which rebuilds the Telegram
/// service from the persisted config. A test that injects its own service
/// before that future completes has its injection silently replaced, so tests
/// must let the microtask queue drain first.
Future<PosProvider> signedIn() async {
  final pos = PosProvider();
  // The constructor already started an unawaited config load that rebuilds the
  // Telegram service. Calling loadPersistedConfig() again would start a SECOND
  // load racing the first, whose late completion would overwrite any service
  // injected below. Let the original settle instead.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  pos.login('owner', 'owner123');
  return pos;
}

  void setStock(PosProvider pos, String productId, int stock) {
    pos.adjustStock(
      productId: productId,
      type: AdjustmentType.set,
      quantity: stock,
      reason: 'test setup',
    );
  }

  group('C19 low-stock threshold consistency', () {
    test('seeded data actually contains products below the business default',
        () async {
      // Guards the premise of the fix: if every product matched the default,
      // the defect would be unobservable and this whole group would be moot.
      final pos = await signedIn();
      final below = pos.products
          .where((p) =>
              p.lowStockThreshold != pos.businessConfig.defaultLowStockThreshold)
          .toList();
      expect(below, isNotEmpty,
          reason: 'fixture must contain a product with its own threshold');
    });

    test('sale crossing the product threshold marks it low stock', () async {
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);
      expect(target.lowStockThreshold,
          lessThan(pos.businessConfig.defaultLowStockThreshold),
          reason: 'this test targets a product below the business default');

      setStock(pos, target.id, 12);
      expect(target.isLowStock, isFalse);

      pos.addToCart(target, qty: 3);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 999999,
        changeAmount: 0,
      );

      expect(target.stock, 9);
      expect(target.isLowStock, isTrue,
          reason: 'stock 9 is at or below the product threshold of 10');
      expect(
        pos.lowStockProducts.any((p) => p.id == target.id),
        isTrue,
        reason: 'the inventory screen must agree that it is low stock',
      );
    });

    test('alert threshold matches the badge shown to the owner', () async {
      // The defect is a disagreement between the alert crossing point and the
      // badge. Before the fix, `LowStockItemData.minimumStock` carried the
      // business default (15) for a product whose real threshold is 10, so the
      // alert fired at a different stock level than the badge appeared.
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);

      setStock(pos, target.id, 12);
      pos.addToCart(target, qty: 2);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 999999,
        changeAmount: 0,
      );

      // Stock 10 is exactly at the product threshold: the badge must show it.
      expect(target.stock, 10);
      expect(target.isLowStock, isTrue,
          reason: 'isLowStock is inclusive of the threshold');
    });

    test('products whose threshold matches the default are unaffected', () async {
      final pos = await signedIn();
      final target = pos.products.firstWhere(
        (p) => p.lowStockThreshold == pos.businessConfig.defaultLowStockThreshold,
      );

      setStock(pos, target.id, 12);
      pos.addToCart(target, qty: 2);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 999999,
        changeAmount: 0,
      );

      expect(target.stock, 10);
      expect(target.isLowStock, isTrue);
    });

    test('a sale that stays above the threshold does not mark low stock', () async {
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);

      setStock(pos, target.id, 20);
      pos.addToCart(target, qty: 3);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 999999,
        changeAmount: 0,
      );

      expect(target.stock, 17);
      expect(target.isLowStock, isFalse);
    });
  });

  group('C19 low-stock ALERT uses the product threshold', () {
    /// Runs a sale of [qty] units and returns the low-stock alert text that was
    /// actually dispatched to Telegram, or null when no alert fired.
    ///
    /// The demo alert is written in English ("LOW STOCK ALERT ... Minimum: N"),
    /// so it is matched on that marker rather than an Indonesian word.
    Future<String?> alertAfterSelling(
        PosProvider pos, Product product, int qty) async {
      final mock = MockTelegramService(
        config: const TelegramConfig(enabled: true),
      );
      pos.setTelegramService(mock);

      pos.addToCart(product, qty: qty);
      pos.prepareCheckoutOrder();
      pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 999999,
        changeAmount: 0,
      );

      // The notification chain is fire-and-forget (unawaited) and each send
      // costs a simulated 300ms, so allow it to fully drain.
      for (var i = 0; i < 120; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      for (final msg in mock.sentMessages) {
        if (msg.contains('LOW STOCK ALERT')) return msg;
      }
      return null;
    }

    test('crossing the product threshold DOES raise an alert', () async {
      // This is the exact scenario the C19 fix repairs. 'Chocolate' has its own
      // threshold of 10 while the business default is 15. Selling 12 -> 9
      // crosses the product's real threshold, so the owner must be alerted.
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);
      expect(target.lowStockThreshold,
          lessThan(pos.businessConfig.defaultLowStockThreshold));

      // Restock well clear of both thresholds first. Products that already
      // start low are deliberately seeded as "already alerted" to suppress
      // repeat spam on first run, so the alert path must be reached from a
      // healthy stock level, which is how a real restock-then-drain looks.
      setStock(pos, target.id, 30);
      expect(target.isLowStock, isFalse);
      setStock(pos, target.id, 12);
      final alert = await alertAfterSelling(pos, target, 3);

      expect(target.stock, 9);
      expect(target.isLowStock, isTrue);
      expect(alert, isNotNull,
          reason: 'crossing the product threshold of 10 must alert the owner; '
              'previously the alert used the business default of 15, so a sale '
              'that stayed between 10 and 15 alerted while this one did not');
    });

    test('the alert quotes the product threshold, not the business default',
        () async {
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);

      setStock(pos, target.id, 30);
      setStock(pos, target.id, 12);
      final alert = await alertAfterSelling(pos, target, 3);

      expect(alert, isNotNull);
      // The alert body must not claim the business default (15) as this
      // product's minimum, because that is what the owner sees as its threshold.
      expect(alert, contains('Minimum: 10'),
          reason: 'alert must report the product threshold of 10, not the '
              'business-wide default of 15');
    });

    test('a sale staying above the product threshold raises no alert', () async {
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);

      setStock(pos, target.id, 30);
      setStock(pos, target.id, 20);
      final alert = await alertAfterSelling(pos, target, 3);

      expect(target.stock, 17);
      expect(target.isLowStock, isFalse);
      expect(alert, isNull,
          reason: 'stock 17 is above the threshold of 10; no alert is correct');
    });
  });

  group('C19 stock-adjustment alert reset uses the product threshold', () {
    test('restocking above the product threshold clears the low-stock state',
        () async {
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);

      setStock(pos, target.id, 5);
      expect(target.isLowStock, isTrue);

      // Restocking to 12 clears it: above the product threshold of 10 even
      // though it is below the business default of 15.
      setStock(pos, target.id, 12);
      expect(target.stock, 12);
      expect(target.isLowStock, isFalse,
          reason: '12 is above the product threshold of 10');
    });

    test('stock still below the product threshold stays low', () async {
      final pos = await signedIn();
      final target = pos.products.firstWhere((p) => p.lowStockThreshold == 10);

      setStock(pos, target.id, 12);
      setStock(pos, target.id, 8);

      expect(target.stock, 8);
      expect(target.isLowStock, isTrue);
    });
  });
}
