// Responsive layout regression guard.
//
// Renders every screen, dialog and shared widget at each supported viewport and
// fails if any RenderFlex / RenderBox reports an overflow. This locks in the
// responsive behaviour so a future layout change cannot silently reintroduce
// "A RenderFlex overflowed by N pixels on the right".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';

import 'package:cafe_pos_demo/screens/login_screen.dart';
import 'package:cafe_pos_demo/screens/order/order_screen.dart';
import 'package:cafe_pos_demo/screens/order/table_selection_screen.dart';
import 'package:cafe_pos_demo/screens/checkout/payment_screen.dart';
import 'package:cafe_pos_demo/screens/checkout/payment_success_screen.dart';
import 'package:cafe_pos_demo/screens/receipt/receipt_screen.dart';
import 'package:cafe_pos_demo/screens/shift/shift_closing_screen.dart';
import 'package:cafe_pos_demo/screens/cashier/cashier_orders_screen.dart';
import 'package:cafe_pos_demo/screens/cashier/cashier_shell.dart';
import 'package:cafe_pos_demo/screens/owner/owner_shell.dart';
import 'package:cafe_pos_demo/screens/owner/owner_dashboard.dart';
import 'package:cafe_pos_demo/screens/owner/owner_pos_overview_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_orders_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_sales_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_products_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_categories_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_inventory_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_tables_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_reports_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_shifts_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_settings_screen.dart';
import 'package:cafe_pos_demo/widgets/cart_view.dart';
import 'package:cafe_pos_demo/widgets/product_card.dart';
import 'package:cafe_pos_demo/widgets/product_customization_dialog.dart';
import 'package:cafe_pos_demo/widgets/product_form_dialog.dart';
import 'package:cafe_pos_demo/widgets/receipt_widget.dart';
import 'package:cafe_pos_demo/widgets/recipe_editor_dialog.dart';
import 'package:cafe_pos_demo/widgets/stock_update_dialog.dart';
import 'package:cafe_pos_demo/widgets/raw_material_form_dialog.dart';
import 'package:cafe_pos_demo/widgets/raw_material_stock_dialog.dart';
import 'package:cafe_pos_demo/widgets/stat_card.dart';

/// Breakpoints under test: mobile, tablet and desktop widths.
const List<Size> viewports = [
  Size(360, 800),
  Size(390, 844),
  Size(412, 915),
  Size(768, 1024),
  Size(1024, 768),
  Size(1280, 800),
  Size(1440, 900),
];

/// Pumps [build] at [size] and returns every overflow reported during layout.
Future<List<String>> collectOverflows(
  WidgetTester tester,
  Size size,
  Widget Function(PosProvider pos) build,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final found = <String>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed')) {
      found.add(details.exceptionAsString());
    }
  };



  final pos = PosProvider()..login('owner', 'owner123');
  pos.loadDemoQuickOrder();

  try {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: build(pos)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  } finally {
    FlutterError.onError = previousOnError;
  }
  return found;
}

void main() {
  final screens = <String, Widget Function(PosProvider)>{
    'LoginScreen': (p) => LoginScreen(pos: p, onLoginSuccess: () {}),
    'CashierShell': (p) => CashierShell(pos: p, onLogout: () {}),
    'OwnerShell': (p) => OwnerShell(pos: p, onLogout: () {}),
    'OrderScreen': (p) =>
        OrderScreen(pos: p, onCheckout: () {}, onChangeTable: () {}),
    'TableSelectionScreen': (p) =>
        TableSelectionScreen(pos: p, onTableSelected: () {}),
    'CashierOrdersScreen': (p) =>
        CashierOrdersScreen(pos: p, onViewReceipt: (_) {}),
    'ShiftClosingScreen': (p) =>
        ShiftClosingScreen(pos: p, onBackToDashboard: () {}),
    'PaymentScreen': (p) =>
        PaymentScreen(pos: p, onPaymentCompleted: () {}, onCancel: () {}),
    'PaymentSuccessScreen': (p) => PaymentSuccessScreen(
          pos: p,
          onViewReceipt: () {},
          onNewOrder: () {},
          onGoToCashier: () {},
        ),
    'ReceiptScreen': (p) =>
        ReceiptScreen(pos: p, onBackToCashier: () {}),
    'OwnerDashboard': (p) => OwnerDashboard(
          pos: p,
          onViewSalesReport: () {},
          onViewProducts: () {},
          onViewOrders: () {},
          onViewInventory: () {},
          onViewShifts: () {},
          onViewTables: () {},
        ),
    'OwnerPosOverviewScreen': (p) => OwnerPosOverviewScreen(pos: p),
    'OwnerOrdersScreen': (p) => OwnerOrdersScreen(pos: p),
    'OwnerSalesScreen': (p) => OwnerSalesScreen(pos: p),
    'OwnerProductsScreen': (p) => OwnerProductsScreen(pos: p),
    'OwnerCategoriesScreen': (p) => OwnerCategoriesScreen(pos: p),
    'OwnerInventoryScreen': (p) => OwnerInventoryScreen(pos: p),
    'OwnerTablesScreen': (p) => OwnerTablesScreen(pos: p),
    'OwnerReportsScreen': (p) => OwnerReportsScreen(pos: p),
    'OwnerShiftsScreen': (p) => OwnerShiftsScreen(pos: p),
    'OwnerSettingsScreen': (p) => OwnerSettingsScreen(pos: p),
  };

  final dialogs = <String, Widget Function(PosProvider)>{
    'ProductCustomizationDialog': (p) => ProductCustomizationDialog(
          product: p.products.first,
          onConfirm: (_, _, _) {},
        ),
    'ProductFormDialog': (p) => ProductFormDialog(onSave: (_) {}),
    'StockUpdateDialog': (p) => StockUpdateDialog(
          product: p.products.first,
          onConfirm: (_, _, _) {},
        ),
    'RecipeEditorDialog': (p) => RecipeEditorDialog(
          product: p.products.first,
          initialRecipe: p.getRecipeForProduct(p.products.first.id),
          availableMaterials: p.activeRawMaterials,
          onSave: (_) {},
        ),
    'RawMaterialFormDialog': (p) => RawMaterialFormDialog(onSave: (_) {}),
    'RawMaterialStockDialog': (p) => RawMaterialStockDialog(
          material: p.rawMaterials.first,
          onConfirm: (_, _, _) {},
        ),
  };

  final widgets = <String, Widget Function(PosProvider)>{
    'ReceiptWidget': (p) => Scaffold(
          body: SingleChildScrollView(
            child: ReceiptWidget(order: p.orders.first, maxWidth: 360),
          ),
        ),
    'CartView': (p) => Scaffold(
          body: SizedBox(width: 360, child: CartView(pos: p, onCheckout: () {})),
        ),
    'ProductCard (cashier)': (p) => Scaffold(
          body: SizedBox(
            width: 200,
            child: GridView.count(
              crossAxisCount: 1,
              childAspectRatio: 0.85,
              children: [ProductCard(product: p.products.first, onAdd: () {})],
            ),
          ),
        ),
    'ProductCard (owner)': (p) => Scaffold(
          body: SizedBox(
            width: 200,
            child: GridView.count(
              crossAxisCount: 1,
              childAspectRatio: 0.85,
              children: [
                ProductCard(
                    product: p.products.first, isOwnerMode: true, onEdit: () {}),
              ],
            ),
          ),
        ),
    'StatCard': (p) => const Scaffold(
          body: SizedBox(
            width: 160,
            child: StatCard(
              title: 'Total Omzet Hari Ini',
              value: 'Rp1.592.000',
              subtitle: '+12% dari kemarin',
              icon: Icons.attach_money,
            ),
          ),
        ),
  };

  final groups = <String, Map<String, Widget Function(PosProvider)>>{
    'screen': screens,
    'dialog': dialogs,
    'widget': widgets,
  };

  for (final size in viewports) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    groups.forEach((groupName, entries) {
      testWidgets('$groupName layouts do not overflow at $tag', (tester) async {
        final failures = <String>[];
        for (final entry in entries.entries) {
          final overflows = await collectOverflows(tester, size, entry.value);
          for (final o in overflows) {
            failures.add('${entry.key}: $o');
          }
        }
        expect(failures, isEmpty, reason: 'Overflow in $groupName at $tag');
      });
    });
  }
}
