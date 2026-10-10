import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/data/mock_data.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/product_form_dialog.dart';

/// Regression tests for C11-06: editing a product must preserve its
/// `modifierGroups`.
///
/// `ProductFormDialog._submit()` builds a brand-new `Product` instead of
/// mutating the original, so any field it does not pass falls back to the
/// constructor default. `modifierGroups` defaulted to `const []`, so a routine
/// rename or price change silently erased a product's size / temperature /
/// sugar / add-on configuration.
///
/// Consequences of that loss:
///   * `OrderScreen` stops opening `ProductCustomizationDialog`, because
///     `Product.hasModifiers` becomes false,
///   * per-option `priceAdjustment` values disappear, changing line pricing,
///   * `RecipeCalculator` no longer sees `selectedModifiers`, so raw-material
///     deductions change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// A seeded product that genuinely carries multiple modifier groups.
  Product productWithModifiers() {
    final product =
        MockData.getInitialProducts().firstWhere((p) => p.modifierGroups.length > 1);
    expect(product.modifierGroups.length, greaterThan(1),
        reason: 'fixture must have multiple groups for this test to mean anything');
    return product;
  }

  /// Opens the dialog on [product], applies [mutate] to the form, saves, and
  /// returns the Product handed to `onSave`.
  ///
  /// Fields are located by their label text rather than index, because the
  /// dialog builds a different field set in its wide and narrow layouts.
  Future<Product> editProduct(
    WidgetTester tester,
    Product product,
    Future<void> Function(WidgetTester tester) mutate,
  ) async {
    Product? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ProductFormDialog(
            productToEdit: product,
            onSave: (p) => saved = p,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await mutate(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull, reason: 'save callback must have fired');
    return saved!;
  }

  /// Finds the text field carrying [label].
  ///
  /// The dialog renders a wide and a narrow variant of the same field, and
  /// labels carry a required-field asterisk, so match exactly and take the
  /// single field that is actually laid out.
  Finder fieldWithLabel(String label) => find
      .widgetWithText(TextFormField, label)
      .hitTestable()
      .first;

  group('editing preserves modifier groups', () {
    testWidgets('changing only the name keeps groups, options and prices',
        (tester) async {
      final original = productWithModifiers();

      final saved = await editProduct(tester, original, (t) async {
        await t.enterText(fieldWithLabel('Nama Produk *'), 'Kopi Susu Baru');
      });

      // The edit itself applied...
      expect(saved.name, 'Kopi Susu Baru');
      expect(saved.id, original.id, reason: 'editing must not change the id');

      // ...and every modifier group, option and price adjustment survived.
      expect(saved.modifierGroups.length, original.modifierGroups.length);

      for (var i = 0; i < original.modifierGroups.length; i++) {
        final before = original.modifierGroups[i];
        final after = saved.modifierGroups[i];
        expect(after.id, before.id, reason: 'group id must survive at index $i');
        expect(after.options.length, before.options.length);
        for (var j = 0; j < before.options.length; j++) {
          expect(after.options[j].id, before.options[j].id);
          expect(after.options[j].name, before.options[j].name);
          expect(
            after.options[j].priceAdjustment,
            before.options[j].priceAdjustment,
            reason: 'price adjustment must survive for ${before.options[j].name}',
          );
        }
      }
    });

    testWidgets('changing the price keeps modifier configuration intact',
        (tester) async {
      final original = productWithModifiers();
      final originalAdjustments = original.modifierGroups
          .expand((g) => g.options.map((o) => o.priceAdjustment))
          .toList();

      final saved = await editProduct(tester, original, (t) async {
        await t.enterText(fieldWithLabel('Harga Jual (Rp) *'), '27500');
      });

      expect(saved.price, 27500, reason: 'the edited price must be saved');
      expect(saved.modifierGroups.length, original.modifierGroups.length);

      final afterAdjustments = saved.modifierGroups
          .expand((g) => g.options.map((o) => o.priceAdjustment))
          .toList();
      expect(afterAdjustments, originalAdjustments);

      // The cashier-facing consequence: customization stays available.
      expect(saved.hasModifiers, isTrue,
          reason: 'cashier customization must remain available after an edit');
    });

    testWidgets('a product with no modifiers still saves cleanly',
        (tester) async {
      final plain = MockData.getInitialProducts()
          .firstWhere((p) => p.modifierGroups.isEmpty);

      final saved = await editProduct(tester, plain, (t) async {
        await t.enterText(fieldWithLabel('Harga Jual (Rp) *'), '19000');
      });

      expect(saved.price, 19000);
      expect(saved.modifierGroups, isEmpty);
      expect(saved.hasModifiers, isFalse);
    });

    testWidgets('existing save and validation behaviour is unchanged',
        (tester) async {
      final original = productWithModifiers();
      var saveCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ProductFormDialog(
              productToEdit: original,
              onSave: (_) => saveCalls++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clearing the required name must block the save, as before the fix.
      await tester.enterText(fieldWithLabel('Nama Produk *'), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(saveCalls, 0, reason: 'empty name must still block saving');
      expect(find.text('Nama produk wajib diisi'), findsOneWidget);
    });
  });

  group('model-level guarantee', () {
    test('copyWith already preserves modifier groups (project convention)', () {
      final original = productWithModifiers();
      final renamed = original.copyWith(name: 'Renamed');

      expect(renamed.modifierGroups.length, original.modifierGroups.length);
      expect(renamed.modifierGroups.first.id, original.modifierGroups.first.id);
    });

    test('a replacement Product without the argument loses them', () {
      // Documents the regression precisely: this is what the dialog used to do.
      final original = productWithModifiers();
      final lossy = Product(
        id: original.id,
        name: original.name,
        price: original.price,
        category: original.category,
      );

      expect(original.modifierGroups, isNotEmpty);
      expect(lossy.modifierGroups, isEmpty);
    });
  });
}