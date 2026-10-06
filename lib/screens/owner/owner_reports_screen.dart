import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class OwnerReportsScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerReportsScreen({super.key, required this.pos});

  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;
  bool _isSendingTelegram = false;

  void _sendTelegramReport() async {
    setState(() => _isSendingTelegram = true);
    final result = await widget.pos.sendTelegramDailyReport();
    if (!mounted) return;
    setState(() => _isSendingTelegram = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(result.message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: result.success ? AppColors.primaryDark : AppColors.danger,
        duration: const Duration(seconds: 4),
        action: result.success
            ? null
            : SnackBarAction(
                label: 'Coba Lagi',
                textColor: Colors.white,
                onPressed: _sendTelegramReport,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Reports'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _isSendingTelegram ? null : _sendTelegramReport,
              icon: _isSendingTelegram
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 14),
              label: Text(
                _isSendingTelegram ? 'Mengirim...' : (isMobile ? 'Telegram' : 'Kirim ke Telegram'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMobile)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Analisis penjualan dan transaksi CAFFE.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildPeriodFilter(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPrimaryMetrics(),
            const SizedBox(height: 10),
            _buildSalesTrend(),
            const SizedBox(height: 10),
            _buildPaymentBreakdown(),
            const SizedBox(height: 10),
            _buildTopSellingProducts(),
            const SizedBox(height: 10),
            _buildTransactionSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        return SegmentedButton<ReportPeriod>(
          segments: [
            ButtonSegment(
              value: ReportPeriod.today,
              icon: const Icon(Icons.today, size: 16),
              label: Text(isNarrow ? '' : 'Hari Ini', style: TextStyle(fontSize: isNarrow ? 0 : 11, fontWeight: FontWeight.w700)),
            ),
            ButtonSegment(
              value: ReportPeriod.last7Days,
              icon: const Icon(Icons.date_range, size: 16),
              label: Text(isNarrow ? '' : '7 Hari', style: TextStyle(fontSize: isNarrow ? 0 : 11, fontWeight: FontWeight.w700)),
            ),
            ButtonSegment(
              value: ReportPeriod.last30Days,
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(isNarrow ? '' : '30 Hari', style: TextStyle(fontSize: isNarrow ? 0 : 11, fontWeight: FontWeight.w700)),
            ),
          ],
          selected: {_selectedPeriod},
          onSelectionChanged: (set) => setState(() => _selectedPeriod = set.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.primarySoft,
            selectedForegroundColor: AppColors.primaryDark,
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 12, vertical: isNarrow ? 8 : 12),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryMetrics() {
    final totalSales = widget.pos.getSalesTotalForPeriod(_selectedPeriod);
    final totalTx = widget.pos.getTransactionsCountForPeriod(_selectedPeriod);
    final avgTx = widget.pos.getAverageTransactionForPeriod(_selectedPeriod);
    final totalItems = widget.pos.getTotalItemsSoldForPeriod(_selectedPeriod);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 650) {
          return Row(
            children: [
              Expanded(child: _buildMetricCard('Total Penjualan', AppCurrency.format(totalSales), Icons.trending_up_rounded, AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Total Transaksi', '$totalTx', Icons.receipt_long_rounded, AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Rata-rata', AppCurrency.format(avgTx), Icons.analytics_rounded, AppColors.accentCaramel)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Item Terjual', '$totalItems', Icons.inventory_2_outlined, AppColors.textSecondary)),
            ],
          );
        }
        if (constraints.maxWidth >= 450) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Penjualan', AppCurrency.format(totalSales), Icons.trending_up_rounded, AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildMetricCard('Total Transaksi', '$totalTx', Icons.receipt_long_rounded, AppColors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Rata-rata', AppCurrency.format(avgTx), Icons.analytics_rounded, AppColors.accentCaramel)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildMetricCard('Item Terjual', '$totalItems', Icons.inventory_2_outlined, AppColors.textSecondary)),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildMetricCard('Total Penjualan', AppCurrency.format(totalSales), Icons.trending_up_rounded, AppColors.primary),
            const SizedBox(height: 10),
            _buildMetricCard('Total Transaksi', '$totalTx', Icons.receipt_long_rounded, AppColors.primary),
            const SizedBox(height: 10),
            _buildMetricCard('Rata-rata', AppCurrency.format(avgTx), Icons.analytics_rounded, AppColors.accentCaramel),
            const SizedBox(height: 10),
            _buildMetricCard('Item Terjual', '$totalItems', Icons.inventory_2_outlined, AppColors.textSecondary),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        return Container(
          padding: EdgeInsets.all(isNarrow ? 10 : 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: isNarrow ? 32 : 36,
                height: isNarrow ? 32 : 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isNarrow ? 18 : 20),
              ),
              SizedBox(width: isNarrow ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isNarrow ? 10 : 11, color: AppColors.textSecondary)),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: isNarrow ? 16 : 18, fontWeight: FontWeight.w900, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesTrend() {
    final orders = widget.pos.getPaidOrdersForPeriod(_selectedPeriod);
    final totalSales = widget.pos.getSalesTotalForPeriod(_selectedPeriod);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tren Penjualan',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '${orders.length} tx',
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Penjualan:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                  const SizedBox(height: 2),
                  Text(
                    AppCurrency.format(totalSales),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (orders.isEmpty)
              const Text('Belum ada data penjualan.', style: TextStyle(fontSize: 9, color: AppColors.textSecondary))
            else
              Text(
                'Rata-rata ${AppCurrency.format(widget.pos.getAverageTransactionForPeriod(_selectedPeriod))}/tx',
                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    final cash = widget.pos.getCashSalesForPeriod(_selectedPeriod);
    final qris = widget.pos.getQrisSalesForPeriod(_selectedPeriod);
    final debit = widget.pos.getDebitSalesForPeriod(_selectedPeriod);
    final total = widget.pos.getSalesTotalForPeriod(_selectedPeriod);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metode Pembayaran',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            _buildPaymentRow('QRIS', qris, total, AppColors.primary, Icons.qr_code_rounded),
            const SizedBox(height: 6),
            _buildPaymentRow('Tunai', cash, total, AppColors.accentCaramel, Icons.payments_rounded),
            const SizedBox(height: 6),
            _buildPaymentRow('Debit', debit, total, AppColors.textSecondary, Icons.credit_card_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String name, int amount, int total, Color color, IconData icon) {
    final pct = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0';
    final ratio = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 10),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$pct%',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    AppCurrency.format(amount),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 2,
                  backgroundColor: AppColors.surfaceSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  AppCurrency.format(amount),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: AppColors.surfaceSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopSellingProducts() {
    final topList = widget.pos.getTopSellingProductsForPeriod(_selectedPeriod);
    final totalItems = widget.pos.getTotalItemsSoldForPeriod(_selectedPeriod);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produk Terlaris',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            if (topList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Belum ada data penjualan produk.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topList.take(10).length,
                separatorBuilder: (_, _) => const Divider(height: 8, color: AppColors.borderLight),
                itemBuilder: (context, index) {
                  final item = topList[index];
                  final percentage = totalItems > 0 ? (item.value / totalItems * 100).toStringAsFixed(1) : '0';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 350;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(item.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$percentage%', style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                                  Text(
                                    '${item.value}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  Text('$percentage% dari total', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Text(
                              '${item.value}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSummary() {
    final orders = widget.pos.getPaidOrdersForPeriod(_selectedPeriod);
    final dateFormat = DateFormat('dd/MM HH:mm');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 380;
        if (isVeryNarrow) {
          return const SizedBox.shrink();
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat Transaksi',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${orders.length} tx',
                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Belum ada transaksi.', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) => const Divider(height: 6, color: AppColors.borderLight),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  dateFormat.format(order.createdAt),
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(order.orderNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(order.cashierName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _getPaymentColor(order.paymentMethod).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  order.paymentMethod.label,
                                  style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: _getPaymentColor(order.paymentMethod)),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                AppCurrency.format(order.grandTotal),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getPaymentColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return AppColors.primary;
      case PaymentMethod.qris:
        return const Color(0xFF0284C7);
      case PaymentMethod.debitCard:
        return AppColors.accentCaramel;
    }
  }
}
