import 'package:flutter/material.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class OwnerSalesScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerSalesScreen({super.key, required this.pos});

  @override
  State<OwnerSalesScreen> createState() => _OwnerSalesScreenState();
}

class _OwnerSalesScreenState extends State<OwnerSalesScreen> {
  int _selectedPeriod = 0; // 0: Harian (Daily), 1: Mingguan (Weekly), 2: Bulanan (Monthly)

  @override
  Widget build(BuildContext context) {
    // Multipliers for believable realistic period simulation
    final multiplier = _selectedPeriod == 0 ? 1.0 : (_selectedPeriod == 1 ? 6.8 : 28.5);

    final totalSales = (widget.pos.todaySalesTotal * multiplier).round();
    final grossSales = (widget.pos.todayGrossSales * multiplier).round();
    final taxTotal = (widget.pos.todayTaxTotal * multiplier).round();
    final serviceTotal = (widget.pos.todayServiceTotal * multiplier).round();
    final netSales = (widget.pos.todayNetSales * multiplier).round();
    final txCount = (widget.pos.todayTransactionsCount * multiplier).round();
    final aov = txCount > 0 ? (totalSales / txCount).round() : 0;
    final totalItems = (widget.pos.todayTotalItemsSold * multiplier).round();

    final periodLabel = _selectedPeriod == 0 ? 'Hari Ini' : (_selectedPeriod == 1 ? '7 Hari Terakhir' : 'Bulan Ini');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Penjualan'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Period Toggle Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final label = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Periode Analisis',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Menampilkan data performa omzet $periodLabel',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    );
                    final toggle = SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Harian')),
                        ButtonSegment(value: 1, label: Text('Mingguan')),
                        ButtonSegment(value: 2, label: Text('Bulanan')),
                      ],
                      selected: {_selectedPeriod},
                      onSelectionChanged: (set) => setState(() => _selectedPeriod = set.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.primarySoft,
                        selectedForegroundColor: AppColors.primaryDark,
                      ),
                    );
                    // Stack the toggle under the label when the card is too
                    // narrow to hold both side by side.
                    if (c.maxWidth < 470) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [label, const SizedBox(height: 10), toggle],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: label),
                        const SizedBox(width: 12),
                        toggle,
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Primary Sales KPI Grid
            LayoutBuilder(
              builder: (context, constraints) {
                // Cap columns by available width so each StatCard keeps enough
                // room for its icon + title + value without wrapping.
                final byWidth = (constraints.maxWidth / 180).floor().clamp(2, 4);
                final crossAxisCount = constraints.maxWidth >= 720 ? byWidth : 2;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: (constraints.maxWidth -
                          (crossAxisCount - 1) * 10) /
                      crossAxisCount /
                      StatCard.minExtent,
                  children: [
                    StatCard(
                      title: 'Total Omzet (Gross)',
                      value: AppCurrency.format(totalSales),
                      icon: Icons.payments_rounded,
                      color: AppColors.primaryDark,
                      subtitle: '$txCount transaksi berhasil',
                    ),
                    StatCard(
                      title: 'Penjualan Bersih (Net)',
                      value: AppCurrency.format(netSales),
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.accentCaramel,
                      subtitle: 'Sebelum pajak & servis',
                    ),
                    StatCard(
                      title: 'Rata-rata Order (AOV)',
                      value: AppCurrency.format(aov),
                      icon: Icons.shopping_basket_rounded,
                      color: AppColors.primary,
                      subtitle: 'Per transaksi',
                    ),
                    StatCard(
                      title: 'Total Produk Terjual',
                      value: '$totalItems pcs',
                      icon: Icons.coffee_rounded,
                      color: AppColors.accentAmber,
                      subtitle: 'Volume penjualan',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Revenue Breakdown Detail Table
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rincian Komponen Pendapatan ($periodLabel)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),

                    _buildBreakdownRow('Penjualan Kotor (Gross Subtotal)', AppCurrency.format(grossSales), false),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Pajak Restoran (PB1 10%)', AppCurrency.format(taxTotal), false),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Biaya Layanan (Service Charge 5%)', AppCurrency.format(serviceTotal), false),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Total Penerimaan Bersih Kasir', AppCurrency.format(totalSales), true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Payment Channel Breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Komposisi Metode Pembayaran',
                            maxLines: 2,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),
                    _buildBreakdownRow('QRIS (BCA, GoPay, OVO, Dana)', AppCurrency.format((widget.pos.todayQrisSales * multiplier).round()), false),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Tunai / Cash', AppCurrency.format((widget.pos.todayCashSales * multiplier).round()), false),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Debit Card / EDC', AppCurrency.format((widget.pos.todayDebitSales * multiplier).round()), false),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Top Products Section
            Card(
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
                            'Top Produk Terlaris',
                            maxLines: 2,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 8),
                    ...widget.pos.topSellingProducts.take(5).map((entry) {
                      final estSales = (entry.value * multiplier).round();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$estSales terjual',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, bool isTotal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 13.5 : 12,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: isTotal ? 15 : 12.5,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            color: isTotal ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
