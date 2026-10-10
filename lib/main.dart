import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'state/pos_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/cashier/cashier_shell.dart';
import 'screens/owner/owner_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosApp());
}

class PosApp extends StatefulWidget {
  const PosApp({super.key});

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  // PosProvider's constructor kicks off the persisted-config load, so it must not
  // be triggered again here or the config would be read twice.
  final PosProvider _posProvider = PosProvider();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _posProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'CAFFE POS Demo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            return shad.Theme(
              data: AppTheme.shadcnTheme,
              child: child!,
            );
          },
          home: _buildRootScreen(),
        );
      },
    );
  }

  Widget _buildRootScreen() {
    if (!_posProvider.isAuthenticated) {
      return LoginScreen(
        pos: _posProvider,
        onLoginSuccess: () {
          // The ListenableBuilder triggers automatically and rebuilds with the respective shell!
        },
      );
    }

    final user = _posProvider.currentUser;

    if (user != null && user.isOwner) {
      // DEDICATED OWNER APPLICATION SHELL
      return OwnerShell(
        pos: _posProvider,
        onLogout: () => _posProvider.logout(),
      );
    } else {
      // DEDICATED CASHIER APPLICATION SHELL
      return CashierShell(
        pos: _posProvider,
        onLogout: () => _posProvider.logout(),
      );
    }
  }
}
