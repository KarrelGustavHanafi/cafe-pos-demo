import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/data/mock_data.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/screens/order/order_screen.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/product_form_dialog.dart';

/// Regression tests for C16B: product numeric validation and inactive-product
/// gating.
///
/// Before this stage the form validated only for emptiness, so
/// `int.tryParse(text) ?? 0` in `_submit()` silently stored 0 for "abc", "" or a
/// negative value (documented defect D-7). Separately, the cashier grid listed
/// every product, so an item the owner had deactivated could still be sold.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ==========================================
  // A. Pure validator rules
  // ==========================================
  group('validateNumericField', () {
    test('required field rejects blank', () {
      expect(validateNumericField('', label: 'Harga jual'), isNotNull);
      expect(validateNumericField('   ', label: 'Harga jual'), isNotNull);
      expect(validateNumericField(null, label: 'Harga jual'), isNotNull);
    });

    test('optional field accepts blank', () {
      expect(validateNumericField('', label: 'HPP', allowBlank: true), isNull);
      expect(validateNumericField(null, label: 'HPP', allowBlank: true), isNull);
    });

    test('rejects non-numeric input', () {
      expect(validateNumericField('abc', label: 'Harga jual'), isNotNull);
      expect(validateNumericField('12abc', label: 'Stok'), isNotNull);
      expect(validateNumericField('1.5', label: 'Stok'), isNotNull,
          reason: 'rupiah/stock are whole numbers');
    });

    test('minExclusive rejects zero and negatives, accepts positives', () {
      expect(validateNumericField('0', label: 'Harga jual', minExclusive: true),
          isNotNull);
      expect(
          validateNumericField('-1', label: 'Harga jual', minExclusive: true),
          isNotNull);
      expect(
          validateNumericField('1', label: 'Harga jual', minExclusive: true),
          isNull);
    });

    test('zero allowed when not minExclusive', () {
      expect(validateNumericField('0', label: 'Stok'), isNull);
      expect(validateNumericField('0', label: 'HPP', allowBlank: true), isNull);
    });

    test('negatives rejected when not minExclusive', () {
      expect(validateNumericField('-5', label: 'Stok'), isNotNull);
      expect(validateNumericField('-5', label: 'HPP', allowBlank: true), isNotNull);
      expect(validateNumericField('-5', label: 'Batas rendah stok', allowBlank: true),
          isNotNull);
    });

    test('rejects values beyond the JS safe integer range', () {
      expect(validateNumericField('99999999999999999999', label: 'Harga jual'),
          isNotNull);
      expect(validateNumericField('99999999999999999999', label: 'Stok'),
          isNotNull);
    });

    test('accepts a large but representable value', () {
      expect(validateNumericField('9000000000000', label: 'Harga jual',
          minExclusive: true), isNull);
    });

    test('surrounding whitespace is tolerated', () {
      expect(validateNumericField('  22000  ', label: 'Harga jual',
          minExclusive: true), isNull);
    });
  });

  // ==========================================
  // B. Real dialog save path
  // ==========================================
  group('product form save path', () {
    /// Opens the dialog on [product], applies [mutate], taps Simpan, and
    /// returns the Product handed to onSave (null when the save was blocked).
    Future<Product?> submit(
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

      return saved;
    }

    /// Locates a form field by its label and scrolls it into view.
    ///
    /// The dialog body is a SingleChildScrollView, so lower fields are built
    /// but off-screen; entering text requires them to be hit-testable first.
    Finder field(String label) =>
        find.widgetWithText(TextFormField, label).first;

    Future<void> setField(
      WidgetTester tester,
      String label,
      String value,
    ) async {
      final finder = field(label);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.enterText(finder, value);
      await tester.pumpAndSettle();
    }

    Product seededProduct() => MockData.getInitialProducts().first;

    testWidgets('zero selling price is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Harga Jual (Rp) *', '0');
      });

      expect(saved, isNull, reason: 'zero price must not save');
      expect(find.textContaining('lebih besar dari 0'), findsOneWidget);
    });

    testWidgets('negative selling price is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Harga Jual (Rp) *', '-5000');
      });

      expect(saved, isNull);
      expect(find.textContaining('lebih besar dari 0'), findsOneWidget);
    });

    testWidgets('nonnumeric selling price is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Harga Jual (Rp) *', 'abc');
      });

      expect(saved, isNull);
      expect(find.textContaining('harus berupa angka'), findsOneWidget);
    });

    testWidgets('empty selling price is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Harga Jual (Rp) *', '');
      });

      expect(saved, isNull);
      expect(find.textContaining('wajib diisi'), findsOneWidget);
    });

    testWidgets('oversized selling price is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Harga Jual (Rp) *', '99999999999999999999');
      });

      expect(saved, isNull,
          reason: 'an unrepresentable price must never save as 0');
      // A 20-digit literal fails int.tryParse entirely, so it is reported as
      // non-numeric; anything that parses but exceeds 2^53 is reported as
      // "terlalu besar" (covered by the pure-validator tests above).
      expect(find.textContaining('harus berupa angka'), findsOneWidget);
    });

    testWidgets('zero cost price is accepted', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'HPP (Rp)', '0');
      });

      expect(saved, isNotNull, reason: 'zero HPP is a legitimate value');
      expect(saved!.costPrice, 0);
    });

    testWidgets('blank optional HPP keeps its existing default',
        (tester) async {
      final original = seededProduct();
      final saved = await submit(tester, original, (t) async {
        await setField(t, 'HPP (Rp)', '');
      });

      expect(saved, isNotNull, reason: 'blank optional field must still save');
      expect(saved!.costPrice, 0, reason: 'blank parses to the 0 default');
    });

    testWidgets('nonnumeric cost price is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'HPP (Rp)', 'abc');
      });

      expect(saved, isNull);
      expect(find.textContaining('harus berupa angka'), findsOneWidget);
    });

    testWidgets('negative cost price is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'HPP (Rp)', '-100');
      });

      expect(saved, isNull);
      expect(find.textContaining('tidak boleh negatif'), findsOneWidget);
    });

    testWidgets('zero stock is accepted', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Stok *', '0');
      });

      expect(saved, isNotNull,
          reason: 'zero stock is allowed; checkout enforces sufficiency');
      expect(saved!.stock, 0);
    });

    testWidgets('nonnumeric stock is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Stok *', 'abc');
      });

      expect(saved, isNull);
      expect(find.textContaining('harus berupa angka'), findsOneWidget);
    });

    testWidgets('negative stock is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Stok *', '-3');
      });

      expect(saved, isNull);
      expect(find.textContaining('tidak boleh negatif'), findsOneWidget);
    });

    testWidgets('zero low-stock threshold is accepted', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Batas Rendah', '0');
      });

      expect(saved, isNotNull);
      expect(saved!.lowStockThreshold, 0);
    });

    testWidgets('nonnumeric low-stock threshold is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Batas Rendah', 'abc');
      });

      expect(saved, isNull);
      expect(find.textContaining('harus berupa angka'), findsOneWidget);
    });

    testWidgets('negative low-stock threshold is rejected', (tester) async {
      final saved = await submit(tester, seededProduct(), (t) async {
        await setField(t, 'Batas Rendah', '-2');
      });

      expect(saved, isNull);
      expect(find.textContaining('tidak boleh negatif'), findsOneWidget);
    });

    testWidgets('a valid edit saves and keeps modifier groups',
        (tester) async {
      final original = MockData.getInitialProducts()
          .firstWhere((p) => p.modifierGroups.isNotEmpty);

      final saved = await submit(tester, original, (t) async {
        await setField(t, 'Harga Jual (Rp) *', '27500');
      });

      expect(saved, isNotNull);
      expect(saved!.price, 27500);
      // C14B guarantee must survive the validation work.
      expect(saved.modifierGroups.length, original.modifierGroups.length);
    });
  });

  // ==========================================
  // C. Cashier grid hides inactive products
  // ==========================================
  group('cashier product grid', () {
    test('activeProducts excludes deactivated items', () {
      final pos = PosProvider();
      final target = pos.products.first;

      expect(pos.activeProducts.any((p) => p.id == target.id), isTrue);

      pos.toggleProductActive(target.id);

      expect(pos.activeProducts.any((p) => p.id == target.id), isFalse,
          reason: 'a deactivated product must leave the active list');
      expect(pos.products.any((p) => p.id == target.id), isTrue,
          reason: 'it must remain in the full catalog for owner management');
    });

    testWidgets('inactive product is not rendered in the cashier grid',
        (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      final target = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');

      Future<void> showGrid() async {
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

      // Visible while active.
      await showGrid();
      expect(find.text(target.name), findsWidgets);

      // Hidden once deactivated. OrderScreen registers no provider listener
      // (it relies on the parent shell rebuilding), so the grid is re-shown.
      pos.toggleProductActive(target.id);
      await showGrid();

      expect(find.text(target.name), findsNothing,
          reason: 'deactivated products must not appear for the cashier');
    });

    testWidgets('other active products remain visible', (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      final target = pos.products.first;
      final other = pos.products[1];

      pos.toggleProductActive(target.id);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: OrderScreen(pos: pos, onCheckout: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text(other.name), findsWidgets,
          reason: 'only the deactivated item should disappear');
    });

    testWidgets('deactivated product still completes checkout from the cart',
        (tester) async {
      // No new checkout-time active-status rejection is introduced.
      final pos = PosProvider()..login('cashier', 'cashier123');
      final target = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');

      pos.addToCart(target);
      pos.toggleProductActive(target.id);

      // The line survives and the sale still settles.
      expect(pos.cartItemCount, 1);
      pos.prepareCheckoutOrder();
      final order = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: pos.currentOrder!.grandTotal,
        changeAmount: 0,
      );

      expect(order.status, OrderStatus.paid);
    });
  });
}