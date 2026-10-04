import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../order/order_screen.dart';
import '../order/table_selection_screen.dart';
import '../checkout/payment_screen.dart';
import '../checkout/payment_success_screen.dart';
import '../receipt/receipt_screen.dart';
import '../shift/shift_closing_screen.dart';
import 'cashier_orders_screen.dart';

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
  int _currentTab = 0; // 0: POS, 1: Meja, 2: Pesanan, 3: Shift
  bool _isInPayment = false;
  bool _isInPaymentSuccess = false;
  bool _isInReceipt = false;
  Order? _viewingOrder;

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
            _currentTab = 0; // Back to POS
          });
        },
        onGoToOwnerDashboard: () {
          setState(() {
            _isInPaymentSuccess = false;
          });
          widget.pos.switchUserRole(UserRole.owner);
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
        onGoToOwnerDashboard: () {
          setState(() {
            _isInReceipt = false;
            _viewingOrder = null;
          });
          widget.pos.switchUserRole(UserRole.owner);
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: const Icon(Icons.coffee_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CAFFE',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Kasir POS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Cashier Profile & Shift Chip
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user?.displayName.substring(0, 1) ?? 'K',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
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
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const Text(
                              'Role: Kasir',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: shift.isClosed ? AppColors.dangerSoft : AppColors.successSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shift.isClosed ? 'Shift Ditutup' : 'Shift Aktif (Shift 1)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: shift.isClosed ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Operational Navigation Tabs
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS / Pesanan',
                  badge: widget.pos.cartItemCount > 0 ? '${widget.pos.cartItemCount}' : null,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.table_restaurant_rounded,
                  label: 'Denah Meja',
                  badge: '${widget.pos.availableTablesCount} Meja',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.receipt_long_rounded,
                  label: 'Pesanan Selesai',
                  badge: '${widget.pos.todayTransactionsCount}',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.lock_clock_rounded,
                  label: 'Shift Kasir',
                ),
              ],
            ),
          ),

          // Presenter Demo Switch & Logout Action
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.pos.switchUserRole(UserRole.owner),
                  icon: const Icon(Icons.insights_rounded, size: 15, color: AppColors.primary),
                  label: const Text(
                    'Beralih ke Owner (Demo)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppColors.primaryBorder),
                    backgroundColor: AppColors.primarySoft,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textSecondary),
                  label: const Text(
                    'Keluar Akun',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
      child: InkWell(
        onTap: () => _navigateToTab(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryBorder : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
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
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: widget.pos.cartItemCount > 0,
            label: Text('${widget.pos.cartItemCount}'),
            child: const Icon(Icons.point_of_sale_rounded),
          ),
          label: 'POS',
        ),
        const NavigationDestination(
          icon: Icon(Icons.table_restaurant_rounded),
          label: 'Meja',
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
          onChangeTable: () => setState(() => _currentTab = 1),
          onCheckout: () {
            widget.pos.prepareCheckoutOrder();
            setState(() => _isInPayment = true);
          },
        );
      case 1:
        content = TableSelectionScreen(
          pos: widget.pos,
          onTableSelected: () {
            setState(() => _currentTab = 0); // Directly proceed to POS
          },
        );
      case 2:
        content = CashierOrdersScreen(
          pos: widget.pos,
          onViewReceipt: (Order order) {
            setState(() {
              _viewingOrder = order;
              _isInReceipt = true;
            });
          },
        );
      case 3:
        content = ShiftClosingScreen(
          pos: widget.pos,
          onBackToDashboard: () => setState(() => _currentTab = 0),
          onLogout: widget.onLogout,
        );
      default:
        content = const SizedBox();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: KeyedSubtree(
        key: ValueKey<int>(_currentTab),
        child: content,
      ),
    );
  }
}
