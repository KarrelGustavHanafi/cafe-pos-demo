import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_pos_demo/screens/cashier/cashier_shell.dart';
import 'package:cafe_pos_demo/screens/owner/owner_dashboard.dart';
import 'package:cafe_pos_demo/screens/owner/owner_orders_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_products_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_reports_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_settings_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_shell.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';

/// Pins the Owner session against any route — gesture or button — into the
/// Cashier experience.
///
/// Audit history: the Owner shell never had a `PageView`, `PageController` or
/// horizontal-drag handler. The real Owner→Cashier route was an explicit
/// "Buka Kasir POS (Demo)" button in the desktop sidebar and the mobile drawer,
/// which called `switchUserRole`. Both are gone, and `switchUserRole` itself was
/// removed with them, so reaching the Cashier now requires logging out and
/// logging in as Cashier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Desktop viewport, so the Owner shell renders its sidebar rather than a
  /// drawer. Keeps the gesture assertions about the shell itself.
  Future<void> useDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<PosProvider> pumpOwner(WidgetTester tester) async {
    await useDesktop(tester);
    final pos = PosProvider()..login('owner', 'owner123');
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: OwnerShell(pos: pos, onLogout: () {})),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return pos;
  }

  group('The Owner → Cashier switch is gone from both layouts', () {
    testWidgets('desktop sidebar renders no cashier-switch button',
        (tester) async {
      final pos = await pumpOwner(tester);

      expect(find.text('Buka Kasir POS (Demo)'), findsNothing);
      expect(find.byIcon(Icons.point_of_sale_rounded), findsNothing);

      // The affordance is gone entirely, by label and by icon, and the sidebar
      // still offers the normal logout action in its place.
      expect(find.text('Keluar Akun Owner'), findsOneWidget);
      expect(pos.currentUser?.isOwner, isTrue);
    });

    testWidgets('mobile drawer renders no cashier-switch button', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final pos = PosProvider()..login('owner', 'owner123');
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: OwnerShell(pos: pos, onLogout: () {})),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Open the drawer, which is where the second button used to live.
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Buka Kasir POS (Demo)'), findsNothing);
      expect(find.text('Keluar Akun Owner'), findsOneWidget);
    });

    testWidgets('no control anywhere in the owner shell can change the role',
        (tester) async {
      final pos = await pumpOwner(tester);

      // Tap every rendered button; none may escalate or de-escalate the role.
      final buttons = find.byType(OutlinedButton);
      for (var i = 0; i < buttons.evaluate().length; i++) {
        await tester.tap(buttons.at(i), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        if (pos.currentUser?.isOwner != true) break;
      }

      expect(pos.currentUser?.isOwner, isTrue);
      expect(find.byType(CashierShell), findsNothing);
    });
  });

  group('Owner shell exposes no swipe route to Cashier', () {
    testWidgets('contains no paged or horizontal-drag gesture surface',
        (tester) async {
      await pumpOwner(tester);

      // A PageView would be the obvious way to swipe between Owner and Cashier.
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(PageController), findsNothing);

      // No horizontal-drag recognizer is registered anywhere in the Owner shell,
      // so no horizontal gesture has a swipe handler to reach. (The Drawer's own
      // open-drag is absent here because the desktop layout has no drawer.)
      expect(find.byType(HorizontalDragGestureRecognizer), findsNothing);
      expect(find.byType(VerticalDragGestureRecognizer), findsNothing);
    });

    testWidgets('swiping left and right keeps the Owner session and page',
        (tester) async {
      final pos = await pumpOwner(tester);

      for (final offset in const [Offset(-500, 0), Offset(500, 0)]) {
        await tester.drag(find.byType(OwnerShell), offset);
        await tester.pump(const Duration(milliseconds: 300));

        expect(pos.currentUser?.isOwner, isTrue,
            reason: 'a swipe must never change the role');
        expect(pos.currentUser?.role.name, 'owner');
        expect(find.byType(CashierShell), findsNothing,
            reason: 'a swipe must never reveal the cashier experience');
        expect(find.byType(OwnerShell), findsOneWidget,
            reason: 'the owner shell must stay mounted');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('swiping after navigating tabs does not leave the Owner page',
        (tester) async {
      final pos = await pumpOwner(tester);

      await tester.tap(find.text('Katalog Menu (Produk)'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OwnerProductsScreen), findsOneWidget);

      await tester.drag(find.byType(OwnerShell), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 300));

      // Still the same Owner tab, still Owner.
      expect(find.byType(OwnerProductsScreen), findsOneWidget);
      expect(find.byType(CashierShell), findsNothing);
      expect(pos.currentUser?.isOwner, isTrue);
    });

    testWidgets('logout is still reachable, so the session can be ended normally',
        (tester) async {
      var loggedOut = false;
      await useDesktop(tester);
      final pos = PosProvider()..login('owner', 'owner123');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerShell(pos: pos, onLogout: () => loggedOut = true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Keluar Akun Owner'));
      await tester.pump();

      expect(loggedOut, isTrue);
    });
  });

  group('Owner navigation still works normally', () {
    testWidgets('sidebar items still switch between owner tabs', (tester) async {
      // Tall viewport: the sidebar is a ListView, so items below the fold are
      // not laid out and could not be tapped.
      tester.view.physicalSize = const Size(1440, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final pos = PosProvider()..login('owner', 'owner123');
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: OwnerShell(pos: pos, onLogout: () {})),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Katalog Menu (Produk)'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OwnerProductsScreen), findsOneWidget);

      await tester.tap(find.text('Pesanan (Orders)'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OwnerOrdersScreen), findsOneWidget);

      await tester.tap(find.text('Laporan Bisnis'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OwnerReportsScreen), findsOneWidget);

      await tester.tap(find.text('Dashboard Bisnis'));
      await tester.pump(const Duration(milliseconds: 400));
      // Assert the destination positively: AnimatedSwitcher keeps the outgoing
      // child alive during its fade, so a "old screen is gone" check would be
      // timing-dependent and flaky.
      expect(find.byType(OwnerDashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('owner can still open settings, including the demo reset',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final pos = PosProvider()..login('owner', 'owner123');
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: OwnerShell(pos: pos, onLogout: () {})),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Pengaturan Kafe'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OwnerSettingsScreen), findsOneWidget);
      // The Reset Data Demo control must be untouched by this change.
      expect(find.widgetWithText(OutlinedButton, 'Reset Data Demo'),
          findsOneWidget);
      expect(pos.canResetDemoData, isTrue);
    });
  });

  group('Reaching the cashier now requires logging out', () {
    testWidgets('owner logout still works, then cashier login succeeds',
        (tester) async {
      await useDesktop(tester);
      final pos = PosProvider()..login('owner', 'owner123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OwnerShell(pos: pos, onLogout: () => pos.logout()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Keluar Akun Owner'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(pos.isAuthenticated, isFalse);

      expect(pos.login('cashier', 'cashier123'), isTrue);
      expect(pos.currentUser?.isOwner, isFalse);

      // And the cashier shell is what now renders for that session.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CashierShell(pos: pos, onLogout: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CashierShell), findsOneWidget);
      expect(find.byType(OwnerShell), findsNothing);
    });
  });

  group('Cashier navigation is untouched', () {
    testWidgets('cashier shell keeps its own navigation after a horizontal drag',
        (tester) async {
      await useDesktop(tester);
      final pos = PosProvider()..login('cashier', 'cashier123');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CashierShell(pos: pos, onLogout: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(CashierShell), const Offset(-400, 0));
      await tester.pump(const Duration(milliseconds: 300));

      // The Cashier session is unchanged by a gesture, and still renders.
      expect(pos.currentUser?.isOwner, isFalse);
      expect(find.byType(CashierShell), findsOneWidget);
      expect(find.byType(OwnerShell), findsNothing);
      expect(find.text('Keluar Akun'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}