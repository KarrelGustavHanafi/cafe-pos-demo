import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import 'owner_dashboard.dart';
import 'owner_pos_overview_screen.dart';
import 'owner_orders_screen.dart';
import 'owner_sales_screen.dart';
import 'owner_products_screen.dart';
import 'owner_categories_screen.dart';
import 'owner_inventory_screen.dart';
import 'owner_tables_screen.dart';
import 'owner_customers_screen.dart';
import 'owner_reports_screen.dart';
import 'owner_shifts_screen.dart';
import 'owner_settings_screen.dart';

class OwnerShell extends StatefulWidget {
  final PosProvider pos;
  final VoidCallback onLogout;

  const OwnerShell({
    super.key,
    required this.pos,
    required this.onLogout,
  });

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _currentTab = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateToTab(int index) {
    setState(() => _currentTab = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final isMobile = Breakpoints.isMobile(context);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      );
    } else {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_getTabTitle(_currentTab)),
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20),
              tooltip: 'Keluar',
              onPressed: widget.onLogout,
            ),
          ],
        ),
        drawer: _buildMobileDrawer(),
        body: _buildTabContent(),
        bottomNavigationBar: isMobile ? _buildMobileBottomBar() : null,
      );
    }
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard Bisnis';
      case 1:
        return 'Monitor Kasir (Live)';
      case 2:
        return 'Pesanan';
      case 3:
        return 'Penjualan';
      case 4:
        return 'Katalog Menu';
      case 5:
        return 'Kategori Menu';
      case 6:
        return 'Inventaris & Stok';
      case 7:
        return 'Manajemen Meja';
      case 8:
        return 'Pelanggan';
      case 9:
        return 'Laporan Bisnis';
      case 10:
        return 'Monitoring Shift';
      case 11:
        return 'Pengaturan Kafe';
      default:
        return 'Owner Portal';
    }
  }

  Widget _buildDesktopSidebar() {
    final user = widget.pos.currentUser;

    return Container(
      width: 240,
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
                  child: const Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.pos.settings.cafeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Owner Portal',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
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

          // Owner Profile Card
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primaryDark,
                    child: Text(
                      user?.displayName.substring(0, 1) ?? 'O',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Pemilik',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const Text(
                          'Role: OWNER (Bisnis)',
                          style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 12 Navigation Items Organized by Clean Business Sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: [
                _buildSectionHeader('RINGKASAN'),
                _buildNavItem(0, Icons.dashboard_customize_rounded, 'Dashboard Bisnis'),
                _buildNavItem(1, Icons.visibility_rounded, 'Monitor Kasir (Live)'),

                const SizedBox(height: 6),
                _buildSectionHeader('MENU & INVENTARIS'),
                _buildNavItem(4, Icons.fastfood_rounded, 'Katalog Menu (Produk)', badge: '${widget.pos.products.length}'),
                _buildNavItem(5, Icons.category_rounded, 'Kategori Menu'),
                _buildNavItem(
                  6,
                  Icons.inventory_2_outlined,
                  'Inventaris & Stok',
                  badge: widget.pos.lowStockProducts.isNotEmpty ? '${widget.pos.lowStockProducts.length}' : null,
                  badgeColor: AppColors.warning,
                ),

                const SizedBox(height: 6),
                _buildSectionHeader('OPERASIONAL'),
                _buildNavItem(2, Icons.receipt_long_rounded, 'Pesanan (Orders)', badge: '${widget.pos.todayTransactionsCount}'),
                _buildNavItem(7, Icons.table_restaurant_rounded, 'Denah & Meja'),
                _buildNavItem(10, Icons.lock_clock_rounded, 'Monitoring Shift'),

                const SizedBox(height: 6),
                _buildSectionHeader('ANALISIS'),
                _buildNavItem(3, Icons.bar_chart_rounded, 'Penjualan (Sales)'),
                _buildNavItem(9, Icons.assessment_outlined, 'Laporan Bisnis'),

                const SizedBox(height: 6),
                _buildSectionHeader('LAINNYA'),
                _buildNavItem(8, Icons.people_alt_outlined, 'Pelanggan'),
                _buildNavItem(11, Icons.settings_outlined, 'Pengaturan Kafe'),
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
                  onPressed: () => widget.pos.switchUserRole(UserRole.cashier),
                  icon: const Icon(Icons.point_of_sale_rounded, size: 15, color: AppColors.primary),
                  label: const Text(
                    'Buka Kasir POS (Demo)',
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
                    'Keluar Akun Owner',
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = _currentTab == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => _navigateToTab(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                    color: badgeColor ?? (isSelected ? AppColors.primary : AppColors.surfaceSubtle),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected || badgeColor != null ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.pos.settings.cafeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const Text('Owner Portal Menu', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                children: [
                  _buildSectionHeader('RINGKASAN'),
                  _buildNavItem(0, Icons.dashboard_customize_rounded, 'Dashboard Bisnis'),
                  _buildNavItem(1, Icons.visibility_rounded, 'Monitor Kasir (Live)'),

                  const SizedBox(height: 6),
                  _buildSectionHeader('MENU & INVENTARIS'),
                  _buildNavItem(4, Icons.fastfood_rounded, 'Katalog Menu (Produk)'),
                  _buildNavItem(5, Icons.category_rounded, 'Kategori Menu'),
                  _buildNavItem(6, Icons.inventory_2_outlined, 'Inventaris & Stok'),

                  const SizedBox(height: 6),
                  _buildSectionHeader('OPERASIONAL'),
                  _buildNavItem(2, Icons.receipt_long_rounded, 'Pesanan (Orders)'),
                  _buildNavItem(7, Icons.table_restaurant_rounded, 'Manajemen Meja'),
                  _buildNavItem(10, Icons.lock_clock_rounded, 'Monitoring Shift'),

                  const SizedBox(height: 6),
                  _buildSectionHeader('ANALISIS'),
                  _buildNavItem(3, Icons.bar_chart_rounded, 'Penjualan (Sales)'),
                  _buildNavItem(9, Icons.assessment_outlined, 'Laporan Bisnis'),

                  const SizedBox(height: 6),
                  _buildSectionHeader('LAINNYA'),
                  _buildNavItem(8, Icons.people_alt_outlined, 'Pelanggan'),
                  _buildNavItem(11, Icons.settings_outlined, 'Pengaturan Kafe'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Keluar Akun'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomBar() {
    // Quick mobile tabs: Dashboard, Pesanan, Menu, Stok
    int selectedIndex;
    if (_currentTab == 0) {
      selectedIndex = 0;
    } else if (_currentTab == 2) {
      selectedIndex = 1;
    } else if (_currentTab == 4) {
      selectedIndex = 2;
    } else if (_currentTab == 6) {
      selectedIndex = 3;
    } else {
      selectedIndex = 0;
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (idx) {
        if (idx == 0) _navigateToTab(0);
        if (idx == 1) _navigateToTab(2);
        if (idx == 2) _navigateToTab(4);
        if (idx == 3) _navigateToTab(6);
      },
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_customize_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_rounded),
          label: 'Pesanan',
        ),
        NavigationDestination(
          icon: Icon(Icons.fastfood_rounded),
          label: 'Produk',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Stok',
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    Widget content;
    switch (_currentTab) {
      case 0:
        content = OwnerDashboard(
          pos: widget.pos,
          onViewSalesReport: () => setState(() => _currentTab = 3),
          onViewProducts: () => setState(() => _currentTab = 4),
          onViewOrders: () => setState(() => _currentTab = 2),
          onViewInventory: () => setState(() => _currentTab = 6),
          onViewShifts: () => setState(() => _currentTab = 10),
          onViewTables: () => setState(() => _currentTab = 7),
        );
      case 1:
        content = OwnerPosOverviewScreen(pos: widget.pos);
      case 2:
        content = OwnerOrdersScreen(pos: widget.pos);
      case 3:
        content = OwnerSalesScreen(pos: widget.pos);
      case 4:
        content = OwnerProductsScreen(pos: widget.pos);
      case 5:
        content = OwnerCategoriesScreen(pos: widget.pos);
      case 6:
        content = OwnerInventoryScreen(pos: widget.pos);
      case 7:
        content = OwnerTablesScreen(pos: widget.pos);
      case 8:
        content = OwnerCustomersScreen(pos: widget.pos);
      case 9:
        content = OwnerReportsScreen(pos: widget.pos);
      case 10:
        content = OwnerShiftsScreen(pos: widget.pos);
      case 11:
        content = OwnerSettingsScreen(pos: widget.pos);
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
