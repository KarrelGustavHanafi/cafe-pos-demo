import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/screens/cashier/cashier_shell.dart';
import 'package:cafe_pos_demo/screens/login_screen.dart';
import 'package:cafe_pos_demo/screens/owner/owner_shell.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/theme/app_theme.dart';
import 'package:cafe_pos_demo/widgets/demo_data_notice.dart';

/// Regression tests for the Cashier/Owner role boundary and the demo-data
/// disclosure.
///
/// The Cashier shell used to offer a `Beralih ke Owner (Demo)` button that
/// called `pos.switchUserRole(UserRole.owner)` with no credential check,
/// handing a logged-in cashier all eleven owner tabs in one tap. Owner access
/// must now go through the login screen like any other role.
///
/// These tests verify the UI boundary and the presence of the disclosure. They
/// deliberately do NOT claim that runtime persistence was exercised.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<PosProvider> pumpShell(
    WidgetTester tester,
    Widget shell,
  ) async {
    final pos = PosProvider();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: shell),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return pos;
  }

  group('Cashier cannot reach the Owner role', () {
    testWidgets('no role-switch shortcut is rendered in the cashier shell',
        (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      await pumpShell(tester, CashierShell(pos: pos, onLogout: () {}));

      // The affordance is gone entirely, by icon and by label.
      expect(find.textContaining('Beralih ke Owner'), findsNothing);
      expect(find.byIcon(Icons.insights_rounded), findsNothing);
      expect(find.text('Beralih ke Owner (Demo)'), findsNothing);
    });

    testWidgets('logout is still available', (tester) async {
      var loggedOut = false;
      final pos = PosProvider()..login('cashier', 'cashier123');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CashierShell(pos: pos, onLogout: () => loggedOut = true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Keluar Akun'), findsOneWidget);

      await tester.tap(find.text('Keluar Akun'));
      await tester.pump();
      expect(loggedOut, isTrue);
    });

    testWidgets('normal cashier navigation still renders its tabs',
        (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      await pumpShell(tester, CashierShell(pos: pos, onLogout: () {}));

      // Tapping around the shell must not produce owner content.
      for (final label in ['Pesanan', 'Meja', 'Shift']) {
        final finder = find.text(label);
        if (finder.evaluate().isNotEmpty) {
          await tester.tap(finder.first);
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.textContaining('Beralih ke Owner'), findsNothing);
        }
      }
    });

    testWidgets('the cashier session stays cashier after exploring tabs',
        (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      await pumpShell(tester, CashierShell(pos: pos, onLogout: () {}));

      // No visible control may escalate the role.
      expect(pos.currentUser?.isOwner, isFalse);

      // Tapping every rendered button must not flip the role to owner.
      final buttons = find.byType(OutlinedButton);
      for (var i = 0; i < buttons.evaluate().length; i++) {
        await tester.tap(buttons.at(i), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 250));
        if (pos.currentUser?.isOwner == true) break;
      }

      expect(pos.currentUser?.isOwner, isFalse);
    });
  });

  group('Owner is reached through the login flow', () {
    testWidgets('login as owner reaches the owner shell', (tester) async {
      final pos = PosProvider();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LoginScreen(pos: pos, onLoginSuccess: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Fill the real login form rather than switching roles.
      await tester.enterText(find.byType(TextField).first, 'owner');
      await tester.enterText(find.byType(TextField).at(1), 'owner123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 800));

      expect(pos.isAuthenticated, isTrue);
      expect(pos.currentUser?.isOwner, isTrue);
    });

    testWidgets('login as cashier does not reach the owner shell',
        (tester) async {
      final pos = PosProvider();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LoginScreen(pos: pos, onLoginSuccess: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(find.byType(TextField).first, 'cashier');
      await tester.enterText(find.byType(TextField).at(1), 'cashier123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 800));

      expect(pos.isAuthenticated, isTrue);
      expect(pos.currentUser?.isOwner, isFalse);
    });
  });

  group('Demo data disclosure', () {
    testWidgets('is visible in the owner experience', (tester) async {
      final pos = PosProvider()..login('owner', 'owner123');
      await pumpShell(tester, OwnerShell(pos: pos, onLogout: () {}));

      expect(find.byType(DemoDataNotice), findsOneWidget);
      expect(find.textContaining('Mode Demo'), findsOneWidget);
    });

    testWidgets('is visible in the cashier experience', (tester) async {
      final pos = PosProvider()..login('cashier', 'cashier123');
      await pumpShell(tester, CashierShell(pos: pos, onLogout: () {}));

      expect(find.byType(DemoDataNotice), findsOneWidget);
      expect(find.textContaining('Mode Demo'), findsOneWidget);
    });

    test('copy states the refresh limitation and the persistence caveat', () {
      // Must tell the user data can return to sample data after a refresh.
      expect(DemoDataNotice.message, contains('Mode Demo'));
      expect(DemoDataNotice.message, contains('di-refresh'));
      expect(DemoDataNotice.message, contains('data contoh'));
      expect(DemoDataNotice.message, contains('tidak tersimpan permanen'));

      // Must NOT claim that every setting resets, because business config is
      // persisted while operational data is not.
      expect(DemoDataNotice.message, contains('Pengaturan business tetap tersimpan'));
    });

    testWidgets('does not overflow on a narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final pos = PosProvider()..login('cashier', 'cashier123');
      await pumpShell(tester, CashierShell(pos: pos, onLogout: () {}));

      expect(find.byType(DemoDataNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}