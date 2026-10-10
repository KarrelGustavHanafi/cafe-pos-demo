import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/order.dart';
import '../../models/shift.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shadcn_components.dart';
import '../../widgets/demo_data_notice.dart';
import '../order/order_screen.dart';
import '../checkout/payment_screen.dart';
import '../checkout/payment_success_screen.dart';
import '../receipt/receipt_screen.dart';
import '../shift/shift_closing_screen.dart';
import 'cashier_orders_screen.dart';
import '../../utils/shift_sale_guard.dart';

class CashierShell extends StatefulWidget {
  final PosProvider pos;
  final VoidCallback onLogout;

  const CashierShell({
    super.key,
    required this.pos,
    required this.onLogout,
  });

  @override
  State<CashierShell> createState() => _CashierShellState();
}

class _CashierShellState extends State<CashierShell> {
  int _currentTab = 0; // 0: POS / Pesanan, 1: Pesanan Selesai, 2: Shift Kasir
  bool _isInPayment = false;
  bool _isInPaymentSuccess = false;
  bool _isInReceipt = false;
  Order? _viewingOrder;

  /// Single place for blocked-shift feedback; the provider throws without
  /// showing any UI, so the cashier sees exactly one message.
  void _showBlockedSaleMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentTab = index;
      _isInPayment = false;
      _isInPaymentSuccess = false;
      _isInReceipt = false;
      _viewingOrder = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    // If in checkout / payment sub-flow
    if (_isInPayment) {
      return PaymentScreen(
        pos: widget.pos,
        onPaymentCompleted: () {
          setState(() {
            _isInPayment = false;
            _isInPaymentSuccess = true;
          });
        },
        onCancel: () {
          setState(() => _isInPayment = false);
        },
      );
    }

    if (_isInPaymentSuccess) {
      return PaymentSuccessScreen(
        pos: widget.pos,
        onViewReceipt: () {
          setState(() {
            _isInPaymentSuccess = false;
            _isInReceipt = true;
          });
        },
        onNewOrder: () {
          widget.pos.clearCart();
          setState(() {
            _isInPaymentSuccess = false;
            _currentTab = 0;
          });
        },
        onGoToCashier: () {
          setState(() {
            _isInPaymentSuccess = false;
            _currentTab = 0;
          });
        },
      );
    }

    if (_isInReceipt) {
      return ReceiptScreen(
        pos: widget.pos,
        customOrder: _viewingOrder,
        onBackToCashier: () {
          setState(() {
            _isInReceipt = false;
            _viewingOrder = null;
          });
        },
      );
    }

    return Scaffold(
      body: isMobile
          ? _buildTabContent()
          : Row(
              children: [
                _buildDesktopSidebar(),
                Expanded(child: _buildTabContent()),
              ],
            ),
      bottomNavigationBar: isMobile ? _buildMobileBottomBar() : null,
    );
  }

  Widget _buildDesktopSidebar() {
    final user = widget.pos.currentUser;
    final shift = widget.pos.currentShift;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        gradient: AppGradients.sidebarTint,
        border: const Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: AppShadows.sidebar,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            child: BrandHeader(subtitle: 'Kasir POS'),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Cashier Profile & Shift Status
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildProfileCard(user, shift),
          ),

          // Operational Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS / Pesanan',
                  badge: widget.pos.cartItemCount > 0
                      ? '${widget.pos.cartItemCount}'
                      : null,
                ),

                _buildNavItem(
                  index: 1,
                  icon: Icons.receipt_long_rounded,
                  label: 'Pesanan Selesai',
                  badge: '${widget.pos.todayTransactionsCount}',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.lock_clock_rounded,
                  label: 'Shift Kasir',
                ),
              ],
            ),
          ),

          // Logout
          // Owner access is deliberately NOT reachable from here: the owner
          // must sign in through the login screen like any other role.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Keluar Akun',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(User? user, ShiftInfo shift) {
    final isShiftActive = !shift.isClosed;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (user?.displayName ?? 'K').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Kasir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Role: Kasir',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: AppAnimations.fast,
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isShiftActive
                  ? AppColors.successSoft
                  : AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (isShiftActive
                        ? AppColors.success
                        : AppColors.danger)
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isShiftActive
                        ? AppColors.success
                        : AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  shift.isClosed ? 'Shift Ditutup' : 'Shift Aktif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isShiftActive
                        ? const Color(0xFF047857)
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    String? badge,
  }) {
    final isSelected = _currentTab == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _navigateToTab(index),
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.primarySoft.withValues(alpha: 0.6),
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            curve: AppAnimations.defaultCurve,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryBorder
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppAnimations.fast,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (badge != null)
                  AnimatedContainer(
                    duration: AppAnimations.fast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomBar() {
    return NavigationBar(
      selectedIndex: _currentTab,
      onDestinationSelected: _navigateToTab,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      elevation: 0,
      shadowColor: Colors.transparent,
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: widget.pos.cartItemCount > 0,
            label: Text('${widget.pos.cartItemCount}'),
            child: const Icon(Icons.point_of_sale_rounded),
          ),
          label: 'POS',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: widget.pos.todayTransactionsCount > 0,
            label: Text('${widget.pos.todayTransactionsCount}'),
            child: const Icon(Icons.receipt_long_rounded),
          ),
          label: 'Pesanan',
        ),
        const NavigationDestination(
          icon: Icon(Icons.lock_clock_rounded),
          label: 'Shift',
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    Widget content;
    switch (_currentTab) {
      case 0:
        content = OrderScreen(
          pos: widget.pos,
          onCheckout: () {
            try {
              widget.pos.prepareCheckoutOrder();
            } on PosSaleBlockedException catch (e) {
              _showBlockedSaleMessage(e.message);
              return;
            }
            setState(() => _isInPayment = true);
          },
        );
      case 1:
        content = CashierOrdersScreen(
          pos: widget.pos,
          onViewReceipt: (Order order) {
            setState(() {
              _viewingOrder = order;
              _isInReceipt = true;
            });
          },
        );
      case 2:
        content = ShiftClosingScreen(
          pos: widget.pos,
          onBackToDashboard: () => setState(() => _currentTab = 0),
          onLogout: widget.onLogout,
        );
      default:
        content = const SizedBox();
    }

    // Demo data disclosure sits above every cashier tab so the limitation is
    // visible during the core POS workflow without blocking it.
    return Column(
      children: [
        const DemoDataNotice(compact: true),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppAnimations.normal,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey<int>(_currentTab),
              child: content,
            ),
          ),
        ),
      ],
    );
  }
}
