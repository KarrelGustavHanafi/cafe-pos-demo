import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_pos_demo/data/mock_data.dart';
import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/recipe.dart';
import 'package:cafe_pos_demo/models/stock_adjustment.dart';
import 'package:cafe_pos_demo/services/config/business_config_service.dart';
import 'package:cafe_pos_demo/services/storage/local_app_storage.dart';
import 'package:cafe_pos_demo/services/telegram/mock_telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

/// Proves [PosProvider.resetDemoData] clears every operational collection of the
/// demo session while leaving stock, catalogue and business configuration
/// exactly as the owner left them, and never reaches an external service.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// A provider whose Telegram path is an in-memory mock, so no test in this
  /// file can reach api.telegram.org or a relay webhook.
  ///
  /// Logs in as Owner, because [PosProvider.resetDemoData] is Owner-only.
  ///
  /// The constructor already starts its own persisted-config load, which swaps
  /// the Telegram service back to [TelegramBotService] when it finishes. The
  /// second load plus a short settle makes that ordering deterministic, and the
  /// identity assertion proves the mock really is the installed transport rather
  /// than assuming the timing worked out.
  Future<PosProvider> buildProvider({
    MockTelegramService? telegram,
  }) async {
    final provider = PosProvider(
      storage: LocalAppStorage(),
      configService: LocalBusinessConfigService(LocalAppStorage()),
    );
    await provider.loadPersistedConfig();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final mock = telegram ?? MockTelegramService();
    provider.setTelegramService(mock);
    expect(provider.telegramService, same(mock),
        reason: 'the in-memory mock must be the installed Telegram transport');
    expect(provider.login('owner', 'owner123'), isTrue);
    return provider;
  }

  /// Drives one real sale through checkout and payment, so the reset is proven
  /// against genuinely mutated state rather than a pristine fixture.
  ///
  /// Sells as Cashier, then returns to Owner: the reset is Owner-only, and a
  /// sale realistically happens under a different role than the one that
  /// performs the reset.
  void runSale(PosProvider pos, {int qty = 2}) {
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
    pos.login('owner', 'owner123');
  }

  ({List<int> products, List<double> materials}) snapshotStock(PosProvider pos) => (
        products: pos.products.map((p) => p.stock).toList(),
        materials: pos.rawMaterials.map((m) => m.stock).toList(),
      );

  group('Demo reset — clearing operational data', () {
    test('1. Orders are emptied, including the seeded transactions', () async {
      final pos = await buildProvider();
      expect(pos.orders, isNotEmpty, reason: 'seed orders must exist first');
      expect(pos.paidOrders, hasLength(3));

      pos.resetDemoData();

      expect(pos.orders, isEmpty);
      expect(pos.paidOrders, isEmpty);
      expect(pos.currentOrder, isNull);
    });

    test('2. Every sales and revenue report reads zero', () async {
      final pos = await buildProvider();
      expect(pos.todaySalesTotal, greaterThan(0));

      pos.resetDemoData();

      for (final period in ReportPeriod.values) {
        expect(pos.getSalesTotalForPeriod(period), 0, reason: 'sales $period');
        expect(pos.getTransactionsCountForPeriod(period), 0,
            reason: 'count $period');
        expect(pos.getAverageTransactionForPeriod(period), 0,
            reason: 'average $period');
        expect(pos.getTotalItemsSoldForPeriod(period), 0,
            reason: 'items $period');
        expect(pos.getCashSalesForPeriod(period), 0, reason: 'cash $period');
        expect(pos.getQrisSalesForPeriod(period), 0, reason: 'qris $period');
        expect(pos.getDebitSalesForPeriod(period), 0, reason: 'debit $period');
        expect(pos.getTopSellingProductsForPeriod(period), isEmpty);
      }
      expect(pos.todaySalesTotal, 0);
      expect(pos.todayTransactionsCount, 0);
      expect(pos.todayGrossSales, 0);
      expect(pos.todayTaxTotal, 0);
      expect(pos.todayServiceTotal, 0);
      expect(pos.todayTotalItemsSold, 0);
      expect(pos.unattributedCashTotal, 0);
    });

    test('3. Cart and active order are cleared', () async {
      final pos = await buildProvider();
      runSale(pos);
      expect(pos.orders, isNotEmpty);

      pos.resetDemoData();

      expect(pos.cart, isEmpty);
      expect(pos.cartItemCount, 0);
      expect(pos.currentOrder, isNull);
      expect(pos.cartGrandTotal, 0);
    });
  });

  group('Demo reset — stock is preserved, not re-seeded', () {
    test('4. Product and raw-material stock are unchanged by the reset',
        () async {
      final pos = await buildProvider();

      // Move both stocks away from seed first, so a reset that quietly
      // re-seeded them could not pass by accident.
      runSale(pos);
      final before = snapshotStock(pos);
      expect(before.products, isNot(MockData.getInitialProducts()
          .map((p) => p.stock)
          .toList()),
          reason: 'the sale must actually move product stock');
      expect(before.materials, isNot(MockData.getInitialRawMaterials()
          .map((m) => m.stock)
          .toList()),
          reason: 'the sale must actually move raw-material stock');

      pos.resetDemoData();

      expect(snapshotStock(pos).products, before.products,
          reason: 'product stock must survive the reset untouched');
      expect(snapshotStock(pos).materials, before.materials,
          reason: 'raw-material stock must survive the reset untouched');
      expect(
        pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock,
        before.materials.first,
      );
    });

    test('5. Owner stock adjustments survive the reset as stock, but leave no history',
        () async {
      final pos = await buildProvider();
      pos.login('owner', 'owner123');
      final target = pos.products.first;
      final beans = pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans');
      pos.adjustStock(
        productId: target.id,
        type: AdjustmentType.add,
        quantity: 7,
        reason: 'uji coba sesi',
      );
      pos.adjustRawMaterialStock(
        materialId: beans.id,
        type: AdjustmentType.remove,
        quantity: 250,
        reason: 'bahan bocor',
      );
      expect(pos.stockAdjustments.length, 5);

      final before = snapshotStock(pos);

      pos.resetDemoData();

      expect(snapshotStock(pos).products, before.products);
      expect(snapshotStock(pos).materials, before.materials);
      expect(pos.products.firstWhere((p) => p.id == target.id).stock,
          before.products.first);
      expect(
        pos.rawMaterials.firstWhere((m) => m.id == beans.id).stock,
        before.materials.first,
      );
      expect(pos.stockAdjustments, isEmpty,
          reason: 'the audit history is session data and must be cleared');
    });

    test('6. Seed stock is left alone when no session activity happened',
        () async {
      final pos = await buildProvider();
      final seed = snapshotStock(pos);

      pos.resetDemoData();

      expect(snapshotStock(pos).products, seed.products);
      expect(snapshotStock(pos).materials, seed.materials);
      expect(
        pos.products.map((p) => p.stock).toList(),
        MockData.getInitialProducts().map((p) => p.stock).toList(),
      );
    });
  });

  group('Demo reset — shift and adjustment history', () {
    test('7. Shift history is cleared and one open demo shift remains',
        () async {
      final pos = await buildProvider();
      expect(pos.pastShifts, isNotEmpty);

      // Close the seed shift and open a new one, so there is archived history
      // and a non-demo active shift to be discarded.
      await pos.closeShift(actualEndingCash: 300000);
      pos.startNewShift(startingCash: 500000);
      expect(pos.hasActiveShift, isTrue);
      expect(pos.currentShift.shiftId, isNot(MockData.seedActiveShiftId));
      expect(pos.pastShifts, isNotEmpty);

      pos.resetDemoData();

      expect(pos.hasActiveShift, isTrue, reason: 'sales must still be possible');
      expect(pos.currentShift.shiftId, MockData.seedActiveShiftId);
      expect(pos.currentShift.startingCash, MockData.getInitialShift().startingCash);
      expect(pos.currentShift.isClosed, isFalse);
      expect(pos.currentShift.closedAt, isNull);
      expect(pos.currentShift.summary, isNull);
      expect(pos.pastShifts, isEmpty, reason: 'no archived shift may remain');
      expect(pos.allShifts, hasLength(1));
      expect(pos.totalSalesForShift(pos.currentShift.shiftId), 0);
      expect(pos.cashSalesForShift(pos.currentShift.shiftId), 0);
    });

    test('8. Stock adjustment history is emptied', () async {
      final pos = await buildProvider();
      runSale(pos);
      expect(pos.stockAdjustments, isNotEmpty);

      pos.resetDemoData();

      expect(pos.stockAdjustments, isEmpty);
    });
  });

  group('Demo reset — catalogue and accounts are preserved', () {
    test('9. Menu, categories and recipes edited in the session survive',
        () async {
      final pos = await buildProvider();
      pos.login('owner', 'owner123');
      pos.addProduct(
        Product(
          id: 'PRD-X',
          name: 'Menu Uji Sesi',
          category: ProductCategory.nonCoffee,
          price: 10000,
          costPrice: 5000,
          stock: 5,
        ),
      );
      pos.addCategory(ProductCategory.dessert);
      pos.saveRecipe(ProductRecipe(productId: 'PRD-X', items: const []));

      final pricesBefore = pos.products.map((p) => p.price).toList();
      final idsBefore = pos.products.map((p) => p.id).toList();

      pos.resetDemoData();

      expect(pos.products.map((p) => p.id).toList(), idsBefore);
      expect(pos.products.map((p) => p.price).toList(), pricesBefore);
      expect(pos.products.any((p) => p.id == 'PRD-X'), isTrue);
      expect(pos.products.any((p) => p.name == 'Menu Uji Sesi'), isTrue);
      expect(pos.categories.contains(ProductCategory.dessert), isTrue);
      expect(pos.recipes.containsKey('PRD-X'), isTrue);
      expect(
        pos.recipes.keys.toSet().containsAll(MockData.getInitialRecipes().keys),
        isTrue,
        reason: 'seed recipes must remain',
      );
    });

    test('10. Owner and Cashier accounts still log in after a reset', () async {
      final pos = await buildProvider();
      pos.resetDemoData();

      expect(pos.login('owner', 'owner123'), isTrue);
      expect(pos.currentUser!.isOwner, isTrue);
      pos.logout();

      expect(pos.login('cashier', 'cashier123'), isTrue);
      expect(pos.currentUser!.isOwner, isFalse);
    });
  });

  group('Demo reset — configuration is preserved', () {
    test('11. Business config is identical before and after, in memory and in storage',
        () async {
      final storage = LocalAppStorage();
      final configService = LocalBusinessConfigService(storage);
      final pos = PosProvider(storage: storage, configService: configService);
      await pos.loadPersistedConfig();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      pos.setTelegramService(MockTelegramService());

      final custom = configService.config.copyWith(
        businessName: 'CAFFE RESET TEST',
        taxPercent: 11,
        serviceChargePercent: 6,
        receiptFooter: 'Footer uji reset',
        orderNumberPrefix: 'UJI',
        defaultLowStockThreshold: 9,
      );
      await pos.updateBusinessConfig(custom);

      final configBefore = pos.businessConfig;
      final storedBefore = await storage.getJson('caffe_business_config');
      expect(storedBefore, isNotNull);

      runSale(pos);
      pos.resetDemoData();

      expect(pos.businessConfig.businessName, configBefore.businessName);
      expect(pos.businessConfig.taxPercent, configBefore.taxPercent);
      expect(pos.businessConfig.serviceChargePercent,
          configBefore.serviceChargePercent);
      expect(pos.businessConfig.receiptFooter, configBefore.receiptFooter);
      expect(pos.businessConfig.orderNumberPrefix, configBefore.orderNumberPrefix);
      expect(pos.businessConfig.defaultLowStockThreshold,
          configBefore.defaultLowStockThreshold);
      expect(pos.settings.cafeName, configBefore.businessName);

      // Telegram configuration and credentials are part of that config.
      expect(pos.businessConfig.telegramConfig.integrationMode,
          configBefore.telegramConfig.integrationMode);
      expect(pos.businessConfig.telegramConfig.relaySecret,
          configBefore.telegramConfig.relaySecret);

      // The stored key must survive untouched.
      final storedAfter = await storage.getJson('caffe_business_config');
      expect(storedAfter, storedBefore);
    });

    test('12. Reset is refused outside a public demo (fail-closed)', () async {
      final storage = LocalAppStorage();
      final configService = LocalBusinessConfigService(storage);
      await configService.init();
      await configService.saveConfig(
        BusinessConfig.defaultCaffeDemo().copyWith(isPublicDemo: false),
      );

      final pos = PosProvider(storage: storage, configService: configService);
      await pos.loadPersistedConfig();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      pos.setTelegramService(MockTelegramService());
      pos.login('owner', 'owner123');
      expect(pos.canResetDemoData, isFalse);
      expect(pos.orders, isNotEmpty);

      expect(pos.resetDemoData, throwsStateError);
      expect(pos.orders, isNotEmpty, reason: 'a refused reset must change nothing');
      expect(pos.stockAdjustments, isNotEmpty);
    });

    test('12b. Reset is refused for a Cashier or an anonymous session',
        () async {
      final pos = await buildProvider();
      expect(pos.canResetDemoData, isTrue);

      pos.login('cashier', 'cashier123');
      expect(pos.canResetDemoData, isFalse);
      expect(pos.resetDemoData, throwsStateError);

      pos.logout();
      expect(pos.canResetDemoData, isFalse);
      expect(pos.resetDemoData, throwsStateError);

      expect(pos.orders, isNotEmpty, reason: 'nothing may be cleared');
      expect(pos.stockAdjustments, isNotEmpty);
    });
  });

  group('Demo reset — idempotency and side effects', () {
    test('13. Resetting twice yields the same operational state as once',
        () async {
      final pos = await buildProvider();
      runSale(pos);

      pos.resetDemoData();
      final once = _operationalFingerprint(pos);

      pos.resetDemoData();
      final twice = _operationalFingerprint(pos);

      expect(twice, once);
    });

    test('14. A reset after a reset matches a reset straight from seed',
        () async {
      final fresh = await buildProvider();
      fresh.resetDemoData();
      final expected = _operationalFingerprint(fresh);

      final busy = await buildProvider();
      runSale(busy);
      busy.resetDemoData();
      busy.resetDemoData();

      expect(_operationalFingerprint(busy), expected);
    });

    test('15. A second reset does not re-clear or re-notify anything',
        () async {
      final telegram = MockTelegramService();
      final pos = await buildProvider(telegram: telegram);
      runSale(pos);
      // The mock service holds each send for 300 ms and a sale fires three of
      // them, so wait for the sale's traffic to fully drain before sampling.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(telegram.sentMessages, isNotEmpty);

      telegram.sentMessages.clear();
      pos.resetDemoData();
      pos.resetDemoData();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(telegram.sentMessages, isEmpty);
    });

    test('16. Reset sends no notification and makes no external call', () async {
      final telegram = MockTelegramService();
      final pos = await buildProvider(telegram: telegram);

      // Prove the recording service WOULD capture a sale notification, so the
      // zero-count assertion below is meaningful rather than vacuous.
      runSale(pos);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(telegram.sentMessages, isNotEmpty);

      telegram.sentMessages.clear();

      pos.resetDemoData();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(telegram.sentMessages, isEmpty,
          reason: 'a reset must not notify, close a shift or print anything');
    });

    test('17. A failed reset leaves no partial state', () async {
      final pos = await buildProvider();
      runSale(pos);
      final before = _stateFingerprint(pos);

      pos.debugThrowBeforeResetApply = () {
        throw StateError('simulated failure mid-reset');
      };
      expect(pos.resetDemoData, throwsStateError);

      pos.debugThrowBeforeResetApply = null;
      expect(_stateFingerprint(pos), before,
          reason: 'orders, stock, shifts and catalogue must all be untouched');

      // And the provider is still usable afterwards.
      pos.resetDemoData();
      expect(pos.orders, isEmpty);
    });
  });

  group('Demo reset — the POS keeps working afterwards', () {
    test('18. A new sale after reset settles and deducts from the preserved stock',
        () async {
      final pos = await buildProvider();
      runSale(pos);
      pos.resetDemoData();

      final kopiSusu = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
      final stockBefore = kopiSusu.stock;
      final beansBefore =
          pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock;

      pos.login('cashier', 'cashier123');
      pos.addToCart(kopiSusu, qty: 2);
      final order = pos.prepareCheckoutOrder();
      expect(order.shiftId, pos.currentShift.shiftId);
      final paid = pos.completePayment(
        method: order.paymentMethod,
        paidAmount: order.grandTotal,
        changeAmount: 0,
      );

      expect(paid.status, OrderStatus.paid);
      expect(pos.orders, hasLength(1));
      expect(pos.todaySalesTotal, paid.grandTotal);
      expect(pos.todayTransactionsCount, 1);
      expect(pos.products.firstWhere((p) => p.id == kopiSusu.id).stock,
          stockBefore - 2,
          reason: 'the sale must deduct from the preserved stock, not from seed');
      expect(
        pos.rawMaterials.firstWhere((m) => m.name == 'Coffee Beans').stock,
        beansBefore - 36,
        reason: 'recipe uses 18 g of beans per cup',
      );
      expect(pos.cart, isEmpty);
      expect(pos.stockAdjustments, hasLength(5),
          reason: 'one finished-product row plus four ingredient rows '
              '(beans, milk, palm sugar, ice)');

      // Tax and service charge still apply on top of the reset state.
      expect(pos.todayTaxTotal, paid.tax);
      expect(pos.todayServiceTotal, paid.serviceCharge);
    });

    test('19. Shift reconciliation still matches its drawer after a sale',
        () async {
      final pos = await buildProvider();
      pos.resetDemoData();

      runSale(pos);

      final shift = pos.currentShift;
      expect(pos.totalSalesForShift(shift.shiftId), pos.todaySalesTotal);
      expect(pos.cashSalesForShift(shift.shiftId), pos.todayCashSales);
      expect(
        pos.expectedEndingCashForShift(shift),
        shift.startingCash + pos.todayCashSales,
      );
    });
  });

  group('Demo reset — session receipts', () {
    test('20. Session receipt history is cleared and cannot resolve a stale order',
        () async {
      final pos = await buildProvider();
      runSale(pos);
      final paid = pos.orders.first;

      // PreviewPrinterService is the default here: fully in-memory, no device.
      final result = await pos.printOrderReceipt(paid);
      expect(result.success, isTrue);
      expect(pos.receiptService.receiptHistory, isNotEmpty);
      expect(pos.receiptService.lastReceipt, isNotNull);

      pos.resetDemoData();

      expect(pos.receiptService.receiptHistory, isEmpty);
      expect(pos.receiptService.lastReceipt, isNull);
      final reprint = await pos.receiptService.reprintLastReceipt();
      expect(reprint.success, isFalse);
      expect(
        () => pos.receiptService.reprintReceipt(paid.id),
        throwsStateError,
        reason: 'a reset order must not fall back to another sale\'s receipt',
      );
    });

    test('21. A reprint still works for a sale made after the reset', () async {
      final pos = await buildProvider();
      pos.resetDemoData();

      runSale(pos);
      final paid = pos.orders.first;
      await pos.printOrderReceipt(paid);
      expect(pos.receiptService.receiptHistory, hasLength(1));

      final reprint = await pos.receiptService.reprintReceipt(paid.id);
      expect(reprint.success, isTrue);
    });
  });
}

/// Everything a reset is allowed to change, including the stock it must not.
String _stateFingerprint(PosProvider pos) =>
    '${_operationalFingerprint(pos)}~${_stockFingerprint(pos)}';

/// The cleared collections plus every figure derived from them.
String _operationalFingerprint(PosProvider pos) {
  return [
    pos.orders.map((o) => o.orderNumber).toList().join('|'),
    pos.paidOrders.map((o) => o.id).toList().join('|'),
    pos.stockAdjustments.map((a) => a.id).toList().join('|'),
    pos.categories.map((c) => c.name).toList().join('|'),
    pos.recipes.keys.toList().join('|'),
    pos.currentShift.shiftId,
    pos.currentShift.startingCash,
    pos.currentShift.isClosed,
    pos.pastShifts.map((s) => s.shiftId).join('|'),
    pos.cart.length,
    pos.currentOrder?.orderNumber ?? '',
    pos.todaySalesTotal,
    pos.todayTransactionsCount,
  ].join('~');
}

String _stockFingerprint(PosProvider pos) => [
      pos.products.map((p) => '${p.id}:${p.stock}:${p.isActive}').join('|'),
      pos.rawMaterials.map((m) => '${m.id}:${m.stock}').join('|'),
    ].join('~');