import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/stock_adjustment.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/demo_guide_widget.dart';
import '../../widgets/sales_bar_chart.dart';
import '../../widgets/stat_card.dart';
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

  void _openStockAdjustmentDialog(BuildContext context, product) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Dashboard'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              onPressed: onViewSalesReport,
              icon: const Icon(Icons.bar_chart_rounded, size: 16),
              label: const Text('Laporan Rinci'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            const SizedBox(height: 4),

            // Live Shift Status Callout
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shift: ${currentShift.shiftName} • Kasir: ${currentShift.cashierName} • Meja Terisi: ${pos.occupiedTablesCount}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 14),

            // 1. TODAY'S PRIMARY METRICS GRID
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                // Cap columns by available width so each StatCard keeps enough
                // room for its icon + title + value without wrapping.
                final byWidth = (constraints.maxWidth / 180).floor().clamp(2, 4);
                final crossAxisCount = isWide ? byWidth : byWidth.clamp(2, 2);

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: (crossAxisCount == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth -
                              (crossAxisCount - 1) * 10) /
                              crossAxisCount) /
                      StatCard.minExtent,
                  children: [
                    StatCard(
                      title: 'Total Omzet Hari Ini',
                      value: AppCurrency.format(todaySales),
                      icon: Icons.payments_rounded,
                      color: AppColors.primaryDark,
                      subtitle: 'Pendapatan kotor',
                    ),
                    StatCard(
                      title: 'Total Transaksi',
                      value: '$txCount Transaksi',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.accentCaramel,
                      subtitle: 'Pesanan lunas',
                    ),
                    StatCard(
                      title: 'Rata-rata Order (AOV)',
                      value: AppCurrency.format(aov),
                      icon: Icons.trending_up_rounded,
                      color: AppColors.primary,
                      subtitle: 'Per transaksi',
                    ),
                    StatCard(
                      title: 'Total Menu Terjual',
                      value: '$itemsSold Pcs',
                      icon: Icons.coffee_rounded,
                      color: AppColors.accentAmber,
                      subtitle: 'Volume porsi/cup',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // 2. MIDDLE EDITORIAL SECTION: Trend & Payment Channels
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 840;

                final trendCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tren Penjualan Hari Ini (per Jam)',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    'Visualisasi transaksi berdasarkan jam operasional',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SalesBarChart(
                          height: 110,
                          data: _buildHourlyChartData(recentOrders),
                        ),
                      ],
                    ),
                  ),
                );

                final paymentCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Penerimaan Pembayaran Hari Ini',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            _buildPaymentTile(
                              'QRIS',
                              AppCurrency.format(qrisSales),
                              Icons.qr_code_rounded,
                              AppColors.primary,
                            ),
                            const SizedBox(height: 6),
                            _buildPaymentTile(
                              'Tunai',
                              AppCurrency.format(cashSales),
                              Icons.payments_rounded,
                              AppColors.accentCaramel,
                            ),
                            const SizedBox(height: 6),
                            _buildPaymentTile(
                              'Debit / EDC',
                              AppCurrency.format(debitSales),
                              Icons.credit_card_rounded,
                              AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
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

            const SizedBox(height: 14),

            // 3. BUSINESS INSIGHTS: TOP PRODUCTS, LOWEST, & LOW STOCK
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 768;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Selling
                      Expanded(
                        child: _buildTopSellingCard(topProducts),
                      ),
                      const SizedBox(width: 14),
                      // Low Stock / Lowest
                      Expanded(
                        child: _buildStockInsightsCard(context, lowStockItems, lowestProducts),
                      ),
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

            const SizedBox(height: 14),

            // 4. RECENT ORDERS & ACTIVE SHIFTS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Transaksi Pesanan Terbaru',
                            maxLines: 2,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                        if (onViewOrders != null)
                          TextButton(
                            onPressed: onViewOrders,
                            child: const Text('Lihat Semua Pesanan', maxLines: 1, style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.border),
                    if (recentOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('Belum ada pesanan.', style: TextStyle(color: AppColors.textSecondary)),
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
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: o.paymentMethod == PaymentMethod.qris
                                    ? AppColors.primarySoft
                                    : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                o.paymentMethod == PaymentMethod.qris
                                    ? Icons.qr_code_rounded
                                    : Icons.payments_rounded,
                                color: o.paymentMethod == PaymentMethod.qris
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 18,
                              ),
                            ),
                            title: Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text('Meja ${o.tableNumber} • ${o.paymentMethod.label} • Kasir: ${o.cashierName}'),
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
            ),
          ],
        ),
      ),
    );
  }

  /// Builds curated hourly chart data combining real orders + realistic demo baseline.
  List<SalesBarData> _buildHourlyChartData(List<Order> orders) {
    // Curated baseline representing a typical cafe day (8am-10pm)
    final baseline = {
      8: 45000, 9: 120000, 10: 185000, 11: 210000,
      12: 320000, 13: 275000, 14: 195000, 15: 160000,
      16: 140000, 17: 180000, 18: 250000, 19: 290000,
      20: 215000, 21: 130000,
    };

    // Overlay actual orders on top of baseline
    final actual = Map<int, int>.from(baseline);
    for (final o in orders) {
      final h = o.createdAt.hour;
      actual[h] = (actual[h] ?? 0) + o.grandTotal;
    }

    final now = DateTime.now().hour;
    final result = <SalesBarData>[];
    for (final entry in actual.entries) {
      final h = entry.key;
      if (h > now + 1) continue; // don't show future hours
      result.add(SalesBarData(
        label: h.toString().padLeft(2, '0'),
        value: entry.value,
        isHighlighted: h == now || h == now - 1,
      ));
    }
    // Sort by hour
    result.sort((a, b) => int.parse(a.label).compareTo(int.parse(b.label)));
    return result;
  }

  Widget _buildPaymentTile(String title, String amount, IconData icon, Color color) {
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
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingCard(List<MapEntry<String, int>> topProducts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department_rounded, color: AppColors.accentCaramel, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Produk Terlaris (Top Selling)',
                    maxLines: 2,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
              ...topProducts.take(4).map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInsightsCard(BuildContext context, List lowStockItems, List lowestProducts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Status Inventaris & Stok',
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewInventory != null)
                  InkWell(
                    onTap: onViewInventory,
                    child: const Text('Kelola', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
                    maxLines: 2,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
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
              ...pos.alertRawMaterials.take(4).map((mat) {
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
                          isOut ? 'OUT OF STOCK' : 'LOW STOCK',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isOut ? AppColors.error : AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mat.name,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          isOut ? '0 $unit' : '$stockStr $unit / min $minStr $unit',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isOut ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 10),

            // Finished Menu Stock Subsection
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'PRODUK MENU SIAP JUAL',
                    maxLines: 2,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
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
                              Text(p.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              Text('Tersisa: ${p.stock} pcs • Batas: ${p.lowStockThreshold}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _openStockAdjustmentDialog(context, p),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primarySoft,
                            foregroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
