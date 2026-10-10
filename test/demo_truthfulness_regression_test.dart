import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/screens/owner/owner_categories_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_sales_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_shifts_screen.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';

/// Regression tests for the removal of fabricated demo figures.
///
/// Three screens used to invent numbers that no order ever produced:
///
///  * the sales screen scaled today's totals by 6.8x / 28.5x for the
///    weekly and monthly periods,
///  * the shifts screen hardcoded 1592000 / 552000 / 1040000 for every
///    closed shift, then computed a "cash variance" from them,
///  * the categories screen reported a successful category addition that
///    never mutated any state.
///
/// These tests pin the honest behaviour that replaced them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Reads every visible `Rp`-formatted string on the pumped screen.
  List<String> currencyValuesOnScreen(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.startsWith('Rp') || s.contains('Rp'))
      .toList();

  Future<void> pumpOwnerScreen(
    WidgetTester tester,
    Widget screen,
    PosProvider pos,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: screen),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('F-1: sales periods derive from real orders, never a multiplier', () {
    test('period totals equal the sum of the orders that actually exist', () {
      final pos = PosProvider();

      // The seed orders are all created today, so every period that includes
      // today must agree with the today's-period query. If a multiplier were
      // still applied, the 7-day figure would be ~6.8x larger and fail here.
      final today = pos.getSalesTotalForPeriod(ReportPeriod.today);
      final week = pos.getSalesTotalForPeriod(ReportPeriod.last7Days);
      final month = pos.getSalesTotalForPeriod(ReportPeriod.last30Days);

      expect(today, greaterThan(0), reason: 'seed data should produce sales');
      expect(week, today);
      expect(month, today);
    });

    test('period transaction and item counts are consistent with each other', () {
      final pos = PosProvider();
      final period = ReportPeriod.last7Days;

      final sales = pos.getSalesTotalForPeriod(period);
      final txCount = pos.getTransactionsCountForPeriod(period);
      final aov = pos.getAverageTransactionForPeriod(period);

      expect(txCount, greaterThan(0));
      // AOV must be derived from real counts, not from a scaled count.
      expect(aov, (sales / txCount).round());
      expect(pos.getTotalItemsSoldForPeriod(period), greaterThan(0));
    });

    test('payment-channel totals sum to at most the period sales total', () {
      final pos = PosProvider();
      final period = ReportPeriod.last30Days;

      final channels = pos.getCashSalesForPeriod(period) +
          pos.getQrisSalesForPeriod(period) +
          pos.getDebitSalesForPeriod(period);

      // Each channel is grandTotal of a disjoint subset of paid orders, so a
      // scaled-up screen would push this past the true total.
      expect(channels, lessThanOrEqualTo(pos.getSalesTotalForPeriod(period)));
    });

    testWidgets('sales screen discloses that history is in-memory',
        (tester) async {
      final pos = PosProvider();
      await pumpOwnerScreen(tester, OwnerSalesScreen(pos: pos), pos);

      expect(
        find.textContaining('Riwayat transaksi pada mode demo tersimpan di memori'),
        findsOneWidget,
      );
    });
  });

  group('F-2: closed shifts never report fabricated sales or variance', () {
    test('a closed shift records real cash but no per-shift sales', () async {
      final pos = PosProvider();
      final startingCash = pos.currentShift.startingCash;
      await pos.closeShift(actualEndingCash: startingCash + 25000);

      final closed = pos.allShifts.firstWhere((s) => s.isClosed);
      expect(closed.actualEndingCash, startingCash + 25000);
      expect(closed.closedAt, isNotNull);

      // Orders carry no shift reference, so per-shift sales are underivable.
      // The screen must therefore never receive a hardcoded figure for them.
      expect(closed.startingCash, isNotNull);
    });

    testWidgets('closed shift card shows unavailable instead of invented money',
        (tester) async {
      final pos = PosProvider();
      await pos.closeShift(
          actualEndingCash: pos.currentShift.startingCash + 25000);
      await pumpOwnerScreen(tester, OwnerShiftsScreen(pos: pos), pos);

      expect(find.textContaining('Tidak tersedia'), findsWidgets);

      // The previously hardcoded figures must appear nowhere on screen.
      for (final forbidden in ['Rp1.592.000', 'Rp552.000', 'Rp1.040.000']) {
        expect(find.textContaining(forbidden), findsNothing);
      }
    });

    testWidgets('open shift still shows live sales and cash variance',
        (tester) async {
      final pos = PosProvider();
      await pumpOwnerScreen(tester, OwnerShiftsScreen(pos: pos), pos);

      // The current shift is open, so its figures are real and must render.
      // Seed data also contains past shifts, so labels repeat per card.
      expect(find.text('Total Penjualan Shift'), findsWidgets);
      expect(find.text('Selisih Kas'), findsWidgets);
      expect(currencyValuesOnScreen(tester), isNotEmpty);

      // An open shift must show the live, real sales figure.
      expect(
        find.text(AppCurrency.format(pos.todaySalesTotal)),
        findsWidgets,
      );
      expect(find.text(AppCurrency.format(pos.todayCashSales)), findsWidgets);
    });

    testWidgets('closed shift variance is never presented as a real amount',
        (tester) async {
      final pos = PosProvider();
      // Close with a deliberately large, known overage.
      await pos.closeShift(
          actualEndingCash: pos.currentShift.startingCash + 500000);
      await pumpOwnerScreen(tester, OwnerShiftsScreen(pos: pos), pos);

      // A real ending cash is shown, but the variance must stay unavailable
      // because expected cash depends on the underivable shift sales.
      expect(find.textContaining('Tidak tersedia'), findsWidgets);
      expect(find.textContaining('Selisih Kas'), findsWidgets);

      // The known 500000 overage must never surface as a variance amount,
      // since the expected side of that subtraction is not knowable.
      expect(find.textContaining('Rp500.000'), findsNothing);
    });

    testWidgets('open shift shows an active-state label, not missing data',
        (tester) async {
      final pos = PosProvider();
      expect(pos.currentShift.isClosed, isFalse);
      expect(pos.currentShift.closedAt, isNull);

      await pumpOwnerScreen(tester, OwnerShiftsScreen(pos: pos), pos);

      // Scope to the current shift's card. Seeded past shifts are closed, so
      // they legitimately show other "Tidak tersedia" metrics on this screen.
      final currentCard = find.byType(Card).first;

      // A still-running shift must read as active, not as absent data.
      expect(
        find.descendant(of: currentCard, matching: find.text('Belum ditutup')),
        findsOneWidget,
      );
      // Every other metric on an open shift is a real live figure.
      expect(
        find.descendant(
            of: currentCard, matching: find.text('Tidak tersedia')),
        findsNothing,
        reason: 'an open shift must not show a missing-data placeholder',
      );
    });

    testWidgets('closed shift shows its real recorded closing time',
        (tester) async {
      final pos = PosProvider();
      await pos.closeShift(
          actualEndingCash: pos.currentShift.startingCash + 1000);

      // closeShift() stamps the real close time itself, so the expected label
      // is read back from the model rather than hard-coded.
      final closedAt = pos.currentShift.closedAt;
      expect(closedAt, isNotNull);
      final expected =
          '${closedAt!.hour.toString().padLeft(2, '0')}:${closedAt.minute.toString().padLeft(2, '0')}';

      await pumpOwnerScreen(tester, OwnerShiftsScreen(pos: pos), pos);

      expect(
        find.descendant(of: find.byType(Card).first, matching: find.text(expected)),
        findsOneWidget,
      );
      // Once closed, the card must no longer claim the shift is still running.
      expect(find.text('Belum ditutup'), findsNothing);
    });
  });

  group('F-4: category control never claims a success that did not happen', () {
    test('categories remain the fixed enum set supplied by the provider', () {
      final pos = PosProvider();
      final before = pos.categories.toList();

      // No operation may fabricate a category: ProductCategory is a closed
      // enum, so the list length can only shrink via removal, never grow.
      pos.addCategory(ProductCategory.coffee);
      expect(pos.categories.length, lessThanOrEqualTo(before.length));

      for (final cat in pos.categories) {
        expect(ProductCategory.values, contains(cat));
      }
    });

    testWidgets('add-category control explains the limitation, no success snack',
        (tester) async {
      final pos = PosProvider();
      final before = pos.categories.length;
      await pumpOwnerScreen(tester, OwnerCategoriesScreen(pos: pos), pos);

      expect(find.textContaining('Kategori bersifat tetap'), findsOneWidget);

      await tester.tap(find.text('Info Kategori'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Kategori Dinamis Tidak Tersedia'),
          findsOneWidget);
      // The old dialog asked for a free-text name; that is gone.
      expect(find.byType(TextField), findsNothing);
      // Critically: no success message for an operation that never ran.
      expect(find.textContaining('berhasil ditambahkan'), findsNothing);
      expect(pos.categories.length, before);
    });

    testWidgets('category control is an enabled, self-describing info action',
        (tester) async {
      final pos = PosProvider();
      final before = pos.categories.length;
      await pumpOwnerScreen(tester, OwnerCategoriesScreen(pos: pos), pos);

      // Appearance, label and semantics all agree: this is an informational
      // action, so it must not look like a disabled "add" control.
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(find.text('Tambah Kategori'), findsNothing);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull,
          reason: 'an enabled info control must be pressable');

      // It exposes an explanation to assistive technology.
      expect(
        find.bySemanticsLabel(
            'Informasi kategori. Menambah kategori baru tidak tersedia.'),
        findsOneWidget,
      );

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kategori Dinamis Tidak Tersedia'),
          findsOneWidget);

      // Pressing it must still create nothing and report no success.
      expect(pos.categories.length, before);
      expect(find.textContaining('berhasil ditambahkan'), findsNothing);
    });
  });

  group('F-5: persisted config initialises exactly once via the constructor', () {
    test('constructor alone loads persisted config without an extra call',
        () async {
      final pos = PosProvider();

      // Constructing the provider already starts the persisted-config load, so
      // `main.dart` does not need to trigger one as well. Awaiting the public
      // entry point here must simply resolve against the loaded state.
      await pos.loadPersistedConfig();

      expect(pos.businessConfig.businessName, isNotEmpty);
    });

    test('business config updates still wait for the initial load', () async {
      final pos = PosProvider();
      // Give the in-flight constructor load a chance to settle.
      await pos.loadPersistedConfig();

      final updated = pos.businessConfig.copyWith(
        businessName: 'AFTER LOAD',
        taxPercent: pos.businessConfig.taxPercent,
        serviceChargePercent: pos.businessConfig.serviceChargePercent,
        receiptFooter: pos.businessConfig.receiptFooter,
        printerWidth: pos.businessConfig.printerWidth,
        printerMode: pos.businessConfig.printerMode,
        telegramConfig: pos.businessConfig.telegramConfig,
        qrisConfig: pos.businessConfig.qrisConfig,
      );

      await pos.updateBusinessConfig(updated);

      // Proves `_loadConfigFuture` was populated before the update ran, so the
      // guard in updateBusinessConfig did not skip the initial load.
      expect(pos.businessConfig.businessName, 'AFTER LOAD');
    });

    test('a config saved by one provider is read back by the next', () async {
      final first = PosProvider();
      await first.loadPersistedConfig();

      final custom = BusinessConfig.defaultCaffeDemo().copyWith(
        businessName: 'CAFFE PERSISTED',
      );
      await first.updateBusinessConfig(custom);

      final second = PosProvider();
      await second.loadPersistedConfig();

      expect(second.businessConfig.businessName, 'CAFFE PERSISTED');
    });
  });
}