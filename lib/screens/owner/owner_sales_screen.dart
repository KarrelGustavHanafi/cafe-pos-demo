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
  // 0: Hari Ini, 1: 7 Hari Terakhir, 2: 30 Hari Terakhir.
  // The tabs are rolling calendar-date windows, not calendar week/month.
  int _selectedPeriod = 0;

  ReportPeriod get _period => switch (_selectedPeriod) {
        0 => ReportPeriod.today,
        1 => ReportPeriod.last7Days,
        _ => ReportPeriod.last30Days,
      };

  @override
  Widget build(BuildContext context) {
    // Every figure below is derived from the orders that actually exist in the
    // selected period. Nothing is scaled or estimated, so two periods that
    // report the same numbers simply mean no orders were recorded between them.
    final period = _period;
    final paidOrders = widget.pos.getPaidOrdersForPeriod(period);

    final totalSales = widget.pos.getSalesTotalForPeriod(period);
    final grossSales = paidOrders.fold<int>(0, (sum, o) => sum + o.subtotal);
    final taxTotal = paidOrders.fold<int>(0, (sum, o) => sum + o.tax);
    final serviceTotal = paidOrders.fold<int>(0, (sum, o) => sum + o.serviceCharge);
    final netSales = grossSales;
    final txCount = widget.pos.getTransactionsCountForPeriod(period);
    final aov = widget.pos.getAverageTransactionForPeriod(period);
    final totalItems = widget.pos.getTotalItemsSoldForPeriod(period);

    final qrisSales = widget.pos.getQrisSalesForPeriod(period);
    final cashSales = widget.pos.getCashSalesForPeriod(period);
    final debitSales = widget.pos.getDebitSalesForPeriod(period);
    final topProducts = widget.pos.getTopSellingProductsForPeriod(period);

    final periodLabel = _selectedPeriod == 0
        ? 'Hari Ini'
        : (_selectedPeriod == 1 ? '7 Hari Terakhir' : '30 Hari Terakhir');

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
                        ButtonSegment(value: 0, label: Text('Hari Ini')),
                        ButtonSegment(value: 1, label: Text('7 Hari')),
                        ButtonSegment(value: 2, label: Text('30 Hari')),
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

            // Demo Limitation Disclosure
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Riwayat transaksi pada mode demo tersimpan di memori saja dan hilang saat aplikasi dimuat ulang. Jika periode 7 atau 30 hari menampilkan angka yang sama dengan hari ini, itu karena belum ada transaksi pada periode sebelumnya.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
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
                    _buildBreakdownRow('QRIS (BCA, GoPay, OVO, Dana)', AppCurrency.format(qrisSales), false),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Tunai / Cash', AppCurrency.format(cashSales), false),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Debit Card / EDC', AppCurrency.format(debitSales), false),
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
                    ...topProducts.take(5).map((entry) {
                      final soldCount = entry.value;
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
                                '$soldCount terjual',
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
