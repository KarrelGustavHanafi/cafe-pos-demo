import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/data/mock_data.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/screens/order/order_screen.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/product_form_dialog.dart';

/// Focused regression tests closing two gaps raised in the C16C review.
///
///  1. `ProductFormDialog` renders a *different* form below 640px
///     (`product_form_dialog.dart:161`, `isWide = screenWidth >= 640`). The
///     C16B tests all ran at the default 800x600 test viewport, so only the
///     wide branch's validators were exercised end-to-end. These force a
///     genuinely narrow viewport and repeat the critical cases.
///  2. The cashier grid switched from `pos.products` to `pos.activeProducts`
///     (`order_screen.dart:97`). Filtering by search text and category is
///     applied *inside* that same `where` closure, so it needed explicit
///     coverage to prove it still composes correctly with the active filter.
///
/// No production behaviour is changed by this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// A viewport comfortably below the 640px wide/narrow breakpoint.
  const narrowSize = Size(390, 1400);

  void useNarrowViewport(WidgetTester tester) {
    tester.view.physicalSize = narrowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('narrow layout numeric validation (<640px)', () {
    /// Opens the dialog at a narrow viewport, applies [mutate], taps Simpan and
    /// returns the Product handed to onSave (null when blocked).
    Future<Product?> submit(
      WidgetTester tester,
      Future<void> Function(WidgetTester tester, Future<void> Function(
        String, String,
      ) setField) mutate, {
      Product? product,
    }) async {
      useNarrowViewport(tester);
      Product? saved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ProductFormDialog(
              productToEdit: product ?? MockData.getInitialProducts().first,
              onSave: (p) => saved = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Prove we really are on the narrow branch before asserting on it.
      expect(
        find.byType(SingleChildScrollView),
        findsWidgets,
        reason: 'dialog body should be scrollable in the stacked layout',
      );

      Future<void> setField(String label, String value) async {
        final finder = find.widgetWithText(TextFormField, label).first;
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.enterText(finder, value);
        await tester.pumpAndSettle();
      }

      await mutate(tester, setField);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Simpan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      return saved;
    }

    testWidgets('zero selling price is blocked in the narrow layout',
        (tester) async {
      final saved = await submit(tester, (t, setField) async {
        await setField('Harga Jual (Rp) *', '0');
      });

      expect(saved, isNull);
      expect(find.textContaining('lebih besar dari 0'), findsOneWidget);
    });

    testWidgets('nonnumeric selling price is blocked in the narrow layout',
        (tester) async {
      final saved = await submit(tester, (t, setField) async {
        await setField('Nama Produk *', 'Menu Baru');
        await setField('Harga Jual (Rp) *', 'abc');
      });

      expect(saved, isNull);
      expect(find.textContaining('harus berupa angka'), findsOneWidget);
    });

    testWidgets('negative stock is blocked in the narrow layout',
        (tester) async {
      final saved = await submit(tester, (t, setField) async {
        await setField('Stok *', '-5');
      });

      expect(saved, isNull);
      expect(find.textContaining('tidak boleh negatif'), findsOneWidget);
    });

    testWidgets('negative low-stock threshold is blocked in the narrow layout',
        (tester) async {
      final saved = await submit(tester, (t, setField) async {
        await setField('Batas Rendah', '-2');
      });

      expect(saved, isNull);
      expect(find.textContaining('tidak boleh negatif'), findsOneWidget);
    });

    testWidgets('zero cost price is accepted in the narrow layout',
        (tester) async {
      final saved = await submit(tester, (t, setField) async {
        await setField('HPP (Rp)', '0');
      });

      expect(saved, isNotNull, reason: 'zero HPP is a confirmed valid value');
      expect(saved!.costPrice, 0);
    });

    testWidgets('zero stock is accepted in the narrow layout', (tester) async {
      final saved = await submit(tester, (t, setField) async {
        await setField('Stok *', '0');
      });

      expect(saved, isNotNull,
          reason: 'zero stock is confirmed valid; checkout enforces sufficiency');
      expect(saved!.stock, 0);
    });

    testWidgets('zero low-stock threshold is accepted in the narrow layout',
        (tester) async {
      final saved = await submit(tester, (t, setField) async {
        await setField('Batas Rendah', '0');
      });

      expect(saved, isNotNull);
      expect(saved!.lowStockThreshold, 0);
    });

    testWidgets('a valid narrow-layout edit saves and keeps modifier groups',
        (tester) async {
      final original = MockData.getInitialProducts()
          .firstWhere((p) => p.modifierGroups.isNotEmpty);

      final saved = await submit(
        tester,
        (t, setField) async {
          await setField('Harga Jual (Rp) *', '29500');
        },
        product: original,
      );

      expect(saved, isNotNull);
      expect(saved!.price, 29500);
      // C14B guarantee must hold in the narrow layout too.
      expect(saved.modifierGroups.length, original.modifierGroups.length);
      for (var i = 0; i < original.modifierGroups.length; i++) {
        expect(saved.modifierGroups[i].id, original.modifierGroups[i].id);
      }
    });
  });

  group('cashier grid filtering composes with the active filter', () {
    Future<void> showGrid(WidgetTester tester, PosProvider pos) async {
      // The product grid is a virtualized GridView.builder
      // (order_screen.dart:384) with ~215px rows, so a short viewport never
      // builds the later products. Use a tall window so every seeded product
      // is present and the filter assertions cannot pass vacuously.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OrderScreen(
            pos: pos,
            onCheckout: () {}
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    PosProvider cashierProvider() {
      final pos = PosProvider()..login('cashier', 'cashier123');
      return pos;
    }

    /// Distinct seeded fixtures so each assertion is non-vacuous:
    ///   coffee      -> 'Kopi Susu Gula Aren'
    ///   nonCoffee   -> 'Matcha Latte'
    ///   food        -> 'French Fries'
    testWidgets('search narrows the active list', (tester) async {
      final pos = cashierProvider();
      await showGrid(tester, pos);

      expect(find.text('Kopi Susu Gula Aren'), findsWidgets);
      expect(find.text('French Fries'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'Matcha');
      await tester.pumpAndSettle();

      expect(find.text('Matcha Latte'), findsWidgets,
          reason: 'the matching product must remain visible');
      expect(find.text('Kopi Susu Gula Aren'), findsNothing,
          reason: 'non-matching products must be filtered out');
      expect(find.text('French Fries'), findsNothing);
    });

    testWidgets('category filter narrows the active list', (tester) async {
      final pos = cashierProvider();
      await showGrid(tester, pos);

      await tester.enterText(find.byType(TextField).first, ' ');
      await tester.pumpAndSettle();

      // At desktop width the sidebar chip list is not rendered; the category
      // control is the ShadcnTabs strip (order_screen.dart:354). Tap the food
      // tab by its label.
      await tester.tap(find.text(ProductCategory.food.label).first);
      await tester.pumpAndSettle();

      expect(find.text('French Fries'), findsWidgets,
          reason: 'food-category product must be visible');
      expect(find.text('Matcha Latte'), findsNothing,
          reason: 'non-food product must be filtered out');
    });

    testWidgets('deactivated products stay hidden under an active search',
        (tester) async {
      final pos = cashierProvider();
      final coffee = pos.products
          .firstWhere((p) => p.name == 'Kopi Susu Gula Aren');

      pos.toggleProductActive(coffee.id);
      await showGrid(tester, pos);

      await tester.enterText(find.byType(TextField).first, 'Kopi');
      await tester.pumpAndSettle();

      expect(find.text('Kopi Susu Gula Aren'), findsNothing,
          reason: 'a search match must not resurface a deactivated product');
    });

    testWidgets('active matches are still visible alongside deactivation',
        (tester) async {
      final pos = cashierProvider();
      final coffee = pos.products
          .firstWhere((p) => p.name == 'Kopi Susu Gula Aren');

      pos.toggleProductActive(coffee.id);
      await showGrid(tester, pos);

      await tester.enterText(find.byType(TextField).first, 'Matcha');
      await tester.pumpAndSettle();

      expect(find.text('Matcha Latte'), findsWidgets,
          reason: 'other active products must remain visible');
    });
  });
}