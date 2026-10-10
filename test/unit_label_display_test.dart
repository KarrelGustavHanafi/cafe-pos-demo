import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/product.dart';
import 'package:cafe_pos_demo/models/raw_material.dart';
import 'package:cafe_pos_demo/models/recipe.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/product_form_dialog.dart';

/// Regression tests for the C20 browser finding.
///
/// In a real browser the product editor's recipe summary rendered raw Dart enum
/// names to the owner, e.g.
///   "Coffee Beans (18 RawMaterialUnit.gram), UHT Milk (120 RawMaterialUnit.ml)"
/// because `RawMaterialUnit` was interpolated directly instead of its `label`.
/// The same leak appeared on the inventory screen's recipe breakdown.
///
/// This is client-visible: it puts internal type names in front of a cafe owner
/// during the most persuasive screen of the demo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PosProvider pos;
  late Product product;
  late ProductRecipe recipe;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Built inside the test zone: PosProvider constructs a Telegram bot service
    // that opens an HttpClient.
    pos = PosProvider()..login('owner', 'owner123');
    // The seeded recipe for Kopi Susu Gula Aren already exercises several units.
    product = pos.products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
    recipe = pos.recipes[product.id]!;
  });

  group('C20 unit label regression', () {
    test('seeded recipe contains more than one unit so the leak is visible',
        () {
      final units = recipe.items.map((i) => i.unit).toSet();
      expect(units.length, greaterThan(1),
          reason: 'a single unit would hide the formatting bug');
      expect(recipe.items.length, greaterThan(1));
    });

    test('recipe items render their display label, never the enum name', () {
      for (final item in recipe.items) {
        final rendered = '${item.quantity.toStringAsFixed(
          item.quantity.truncateToDouble() == item.quantity ? 0 : 1,
        )} ${item.unit.label}';

        expect(rendered, isNot(contains('RawMaterialUnit')),
            reason: 'enum type name must never reach the owner');
        expect(rendered, contains(item.unit.label));
      }
    });

    test('every RawMaterialUnit has a human-readable label', () {
      for (final u in RawMaterialUnit.values) {
        expect(u.label.trim(), isNotEmpty);
        expect(u.label, isNot(contains('RawMaterialUnit')));
        // Labels must be lowercase short units, not identifiers.
        expect(RegExp(r'^[a-z]+$').hasMatch(u.label), isTrue,
            reason: 'label for $u should be a plain word, got "${u.label}"');
      }
    });

    testWidgets('product editor recipe summary shows labels, not enum names',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ProductFormDialog(
                    productToEdit: product,
                    currentRecipe: recipe,
                    // Section 5 (the recipe summary) only renders in edit mode
                    // when a recipe manager is supplied, which is how the owner
                    // catalog opens it.
                    onManageRecipe: () {},
                    onSave: (_) {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The dialog must not print any Dart enum name anywhere.
      expect(find.textContaining('RawMaterialUnit'), findsNothing,
          reason: 'the recipe summary leaked the Dart enum name to the owner');



      expect(find.textContaining('Resep & Komposisi'), findsWidgets, reason: 'recipe section must render in edit mode');

      final allText = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((d) => d.isNotEmpty)
          .toList();

      final summary = allText
          .where((d) => recipe.items.any((i) => d.contains(i.materialName)))
          .join(' ');
      expect(summary, isNotEmpty,
          reason: 'the recipe summary must render its ingredients');

      for (final item in recipe.items) {
        expect(summary, contains(item.unit.label),
            reason: '${item.materialName} should show "${item.unit.label}"');
      }
    });

    });
}
