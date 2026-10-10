import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/stock_adjustment.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/demo_guide_widget.dart';
import '../../widgets/sales_bar_chart.dart';
import '../../widgets/shadcn_components.dart';
import '../../widgets/stock_update_dialog.dart';

class OwnerDashboard extends StatelessWidget {
  final PosProvider pos;
  final VoidCallback onViewSalesReport;
  final VoidCallback onViewProducts;
  final VoidCallback? onViewOrders;
  final VoidCallback? onViewInventory;
  final VoidCallback? onViewShifts;
  final VoidCallback? onViewTables;

  const OwnerDashboard({
    super.key,
    required this.pos,
    required this.onViewSalesReport,
    required this.onViewProducts,
    this.onViewOrders,
    this.onViewInventory,
    this.onViewShifts,
    this.onViewTables,
  });

  void _openStockAdjustmentDialog(BuildContext context, dynamic product) {
    showDialog(
      context: context,
      builder: (context) => StockUpdateDialog(
        product: product,
        onConfirm: (type, quantity, reason) {
          pos.adjustStock(
            productId: product.id,
            type: type,
            quantity: quantity,
            reason: reason,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Stok ${product.name} berhasil diperbarui: '
                '${type == AdjustmentType.add ? "+$quantity" : (type == AdjustmentType.remove ? "-$quantity" : "=$quantity")} unit',
              ),
              backgroundColor: AppColors.primaryDark,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todaySales = pos.todaySalesTotal;
    final txCount = pos.todayTransactionsCount;
    final aov = pos.todayAverageTransactionValue;
    final itemsSold = pos.todayTotalItemsSold;
    final cashSales = pos.todayCashSales;
    final qrisSales = pos.todayQrisSales;
    final debitSales = pos.todayDebitSales;

    final topProducts = pos.topSellingProducts;
    final lowStockItems = pos.lowStockProducts;
    final lowestProducts = pos.lowestSellingProducts;
    final currentShift = pos.currentShift;
    final recentOrders = pos.orders.take(5).toList();

      // The hourly chart must reflect every paid sale made today, not just the
      // five most recent orders shown in the activity list.
      final todayPaidOrders = pos.getPaidOrdersForPeriod(ReportPeriod.today);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Dashboard Bisnis'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              onPressed: onViewSalesReport,
              icon: const Icon(Icons.bar_chart_rounded, size: 16),
              label: const Text('Laporan Rinci'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo Guide for Owner — shown once per session
            const DemoGuideWidget(isCashierMode: false),
            const SizedBox(height: 6),

            // Live Shift & Operational Callout
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: const Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ringkasan Operasional Hari Ini',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shift: ${currentShift.shiftName} • Kasir: ${currentShift.cashierName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Combined Inventory Alert Banner (Menu & Raw Materials)
            if (lowStockItems.isNotEmpty || pos.alertRawMaterials.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: pos.outOfStockRawMaterials.isNotEmpty ? AppColors.errorSoft : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (pos.outOfStockRawMaterials.isNotEmpty ? AppColors.error : AppColors.warning).withValues(alpha: 0.3),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, bannerConstraints) {
                    final isNarrow = bannerConstraints.maxWidth < 480;
                    final content = Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pos.outOfStockRawMaterials.isNotEmpty
                                ? 'Peringatan: ${pos.alertRawMaterials.length} Bahan, ${lowStockItems.length} Menu Perlu Perhatian'
                                : 'Peringatan: ${pos.lowStockRawMaterials.length} Bahan, ${lowStockItems.length} Menu Stok Menipis',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: pos.outOfStockRawMaterials.isNotEmpty ? AppColors.error : AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (pos.outOfStockRawMaterials.isNotEmpty)
                                'HABIS: ${pos.outOfStockRawMaterials.map((m) => m.name).join(", ")}',
                              if (pos.lowStockRawMaterials.isNotEmpty)
                                'MENIPIS: ${pos.lowStockRawMaterials.map((m) => "${m.name} (${m.stock.truncateToDouble() == m.stock ? m.stock.toInt() : m.stock} ${m.unit.label})").join(", ")}',
                              if (lowStockItems.isNotEmpty)
                                'MENU: ${lowStockItems.map((p) => "${p.name} (${p.stock} pcs)").join(", ")}',
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                pos.outOfStockRawMaterials.isNotEmpty ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                                color: pos.outOfStockRawMaterials.isNotEmpty ? AppColors.error : AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              content,
                            ],
                          ),
                          if (onViewInventory != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: onViewInventory,
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Kelola Inventaris', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                            ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Icon(
                          pos.outOfStockRawMaterials.isNotEmpty ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                          color: pos.outOfStockRawMaterials.isNotEmpty ? AppColors.error : AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        content,
                        if (onViewInventory != null)
                          TextButton(
                            onPressed: onViewInventory,
                            child: const Text('Kelola Inventaris', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                          ),
                      ],
                    );
                  },
                ),
              ),

            // 1. TODAY'S PRIMARY METRICS GRID (Using KpiCard)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final byWidth = (constraints.maxWidth / 180).floor().clamp(2, 4);
                final crossAxisCount = isWide ? byWidth : 2;

                final spacing = 10.0;
                final totalSpacing = (crossAxisCount - 1) * spacing;
                final cardWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
                final aspectRatio = (cardWidth / 155).clamp(0.8, 2.5);

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: aspectRatio,
                  children: [
                    KpiCard(
                      title: 'Total Omzet Hari Ini',
                      value: AppCurrency.format(todaySales),
                      icon: Icons.payments_rounded,
                      accentColor: AppColors.primary,
                      subtitle: 'Pendapatan kotor',
                      onTap: onViewSalesReport,
                    ),
                    KpiCard(
                      title: 'Total Transaksi',
                      value: '$txCount Transaksi',
                      icon: Icons.receipt_long_rounded,
                      accentColor: AppColors.accentCaramel,
                      subtitle: 'Pesanan lunas',
                      onTap: onViewOrders,
                    ),
                    KpiCard(
                      title: 'Rata-rata Order (AOV)',
                      value: AppCurrency.format(aov),
                      icon: Icons.trending_up_rounded,
                      accentColor: AppColors.primaryDark,
                      subtitle: 'Per transaksi',
                    ),
                    KpiCard(
                      title: 'Total Menu Terjual',
                      value: '$itemsSold Pcs',
                      icon: Icons.coffee_rounded,
                      accentColor: AppColors.accentAmber,
                      subtitle: 'Volume porsi/cup',
                      onTap: onViewProducts,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // 2. MIDDLE SECTION: Sales Trend & Payment Breakdown
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 840;

                final trendCard = Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.sm,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tren Penjualan Hari Ini (per Jam)',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'Transaksi lunas hari ini dikelompokkan berdasarkan jam',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SalesBarChart(
                        height: 120,
                        data: buildHourlyChartData(todayPaidOrders),
                      ),
                    ],
                  ),
                );

                final paymentCard = Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.sm,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accentCaramel.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accentCaramel, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Penerimaan Pembayaran',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Column(
                        children: [
                          _buildPaymentTile(
                            'QRIS (Digital)',
                            AppCurrency.format(qrisSales),
                            Icons.qr_code_rounded,
                            AppColors.primary,
                            todaySales > 0 ? (qrisSales / todaySales) : 0.0,
                          ),
                          const SizedBox(height: 8),
                          _buildPaymentTile(
                            'Tunai (Cash)',
                            AppCurrency.format(cashSales),
                            Icons.payments_rounded,
                            AppColors.accentCaramel,
                            todaySales > 0 ? (cashSales / todaySales) : 0.0,
                          ),
                          const SizedBox(height: 8),
                          _buildPaymentTile(
                            'Debit / EDC',
                            AppCurrency.format(debitSales),
                            Icons.credit_card_rounded,
                            AppColors.textSecondary,
                            todaySales > 0 ? (debitSales / todaySales) : 0.0,
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: trendCard),
                      const SizedBox(width: 14),
                      Expanded(flex: 5, child: paymentCard),
                    ],
                  );
                }

                return Column(
                  children: [
                    trendCard,
                    const SizedBox(height: 14),
                    paymentCard,
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // 3. BUSINESS INSIGHTS: TOP PRODUCTS & STOCK INSIGHTS
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 768;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTopSellingCard(topProducts)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildStockInsightsCard(context, lowStockItems, lowestProducts)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildTopSellingCard(topProducts),
                      const SizedBox(height: 14),
                      _buildStockInsightsCard(context, lowStockItems, lowestProducts),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // 4. RECENT ORDERS
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Transaksi Pesanan Terbaru',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      if (onViewOrders != null)
                        TextButton(
                          onPressed: onViewOrders,
                          child: const Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.border),
                  if (recentOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Belum ada pesanan hari ini.', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentOrders.length,
                      separatorBuilder: (_, index) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final o = recentOrders[index];
                        final isQris = o.paymentMethod == PaymentMethod.qris;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isQris ? AppColors.primarySoft : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isQris ? AppColors.primaryBorder : AppColors.borderLight,
                              ),
                            ),
                            child: Icon(
                              isQris ? Icons.qr_code_rounded : Icons.payments_rounded,
                              color: isQris ? AppColors.primary : AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                          title: Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                          subtitle: Text('${o.tableLabel} • ${o.paymentMethod.label} • Kasir: ${o.cashierName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            AppCurrency.format(o.grandTotal),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Buckets paid sales by the hour they actually occurred in.
  ///
  /// Only real, paid orders contribute, using their own `createdAt` and
  /// `grandTotal`. No baseline or estimated revenue is mixed in: hours without
  /// a qualifying sale are simply absent, and an empty input yields an empty
  /// chart so the widget can show its empty state. Exposed as a static helper so
  /// the aggregation can be asserted directly in tests.
  static List<SalesBarData> buildHourlyChartData(List<Order> orders) {
    final byHour = <int, int>{};
    for (final o in orders) {
      if (o.status != OrderStatus.paid) continue;
      final h = o.createdAt.hour;
      byHour[h] = (byHour[h] ?? 0) + o.grandTotal;
    }

    final hours = byHour.keys.toList()..sort();
    final nowHour = DateTime.now().hour;
    return [
      for (final h in hours)
        SalesBarData(
          label: h.toString().padLeft(2, '0'),
          value: byHour[h]!,
          isHighlighted: h == nowHour,
        ),
    ];
  }

  Widget _buildPaymentTile(String title, String amount, IconData icon, Color color, double percentage) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                amount,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingCard(List<MapEntry<String, int>> topProducts) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: AppColors.accentCaramel, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Produk Terlaris (Top Selling)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          if (topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('Belum ada data penjualan.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...topProducts.take(4).toList().asMap().entries.map((indexed) {
              final idx = indexed.key;
              final entry = indexed.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: idx == 0
                            ? AppColors.primarySoft
                            : AppColors.surfaceSubtle,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: idx == 0 ? AppColors.primaryBorder : AppColors.borderLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: idx == 0 ? AppColors.primaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${entry.value} terjual',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStockInsightsCard(BuildContext context, List lowStockItems, List lowestProducts) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Status Inventaris & Stok',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              if (onViewInventory != null)
                TextButton(
                  onPressed: onViewInventory,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Kelola', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Raw Materials Status Subsection
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BAHAN BAKU (RAW MATERIALS)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${pos.rawMaterials.length} total bahan',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (pos.alertRawMaterials.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Semua bahan baku dalam kondisi stok aman.', style: TextStyle(color: AppColors.success, fontSize: 11.5)),
            )
          else
            ...pos.alertRawMaterials.take(3).map((mat) {
              final isOut = mat.isOutOfStock;
              final unit = mat.unit.label;
              final stockStr = mat.stock.truncateToDouble() == mat.stock ? mat.stock.toInt().toString() : mat.stock.toStringAsFixed(1);
              final minStr = mat.minimumStock.truncateToDouble() == mat.minimumStock ? mat.minimumStock.toInt().toString() : mat.minimumStock.toStringAsFixed(1);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOut ? AppColors.errorSoft : AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOut ? 'HABIS' : 'MENIPIS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isOut ? AppColors.danger : AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mat.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        isOut ? '0 $unit' : '$stockStr / min $minStr $unit',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOut ? AppColors.danger : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 8),

          // Finished Menu Stock Subsection
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PRODUK MENU SIAP JUAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${pos.products.length} total menu',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (lowStockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Semua produk menu dalam batas aman stok.', style: TextStyle(color: AppColors.success, fontSize: 11.5)),
            )
          else
            ...lowStockItems.take(3).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            Text('Tersisa: ${p.stock} pcs • Min: ${p.lowStockThreshold}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _openStockAdjustmentDialog(context, p),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.primaryBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
