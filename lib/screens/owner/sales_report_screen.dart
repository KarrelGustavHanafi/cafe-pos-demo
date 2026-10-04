import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class SalesReportScreen extends StatelessWidget {
  final PosProvider pos;
  final VoidCallback onBackToOwner;

  const SalesReportScreen({
    super.key,
    required this.pos,
    required this.onBackToOwner,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');
    final paidOrders = pos.orders.where((o) => o.status == OrderStatus.paid).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Rinci Penjualan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBackToOwner,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Laporan berhasil diekspor ke Excel / PDF (Simulasi)'),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Ekspor Laporan'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            // Revenue Breakdown Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isNarrow = width < 650;

                if (isNarrow) {
                  return Column(
                    children: [
                      _buildBreakdownCard('Total Tunai (Cash)', AppCurrency.format(pos.todayCashSales), Icons.payments_rounded, AppColors.primary),
                      const SizedBox(height: 10),
                      _buildBreakdownCard('Total QRIS Digital', AppCurrency.format(pos.todayQrisSales), Icons.qr_code_2_rounded, const Color(0xFF0284C7)),
                      const SizedBox(height: 10),
                      _buildBreakdownCard('Total Kartu Debit / EDC', AppCurrency.format(pos.todayDebitSales), Icons.credit_card_rounded, AppColors.accentCaramel),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownCard(
                        'Total Tunai (Cash)',
                        AppCurrency.format(pos.todayCashSales),
                        Icons.payments_rounded,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBreakdownCard(
                        'Total QRIS Digital',
                        AppCurrency.format(pos.todayQrisSales),
                        Icons.qr_code_2_rounded,
                        const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBreakdownCard(
                        'Total Kartu Debit / EDC',
                        AppCurrency.format(pos.todayDebitSales),
                        Icons.credit_card_rounded,
                        AppColors.accentCaramel,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            // Transactions History Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Riwayat Transaksi Masuk Hari Ini',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${paidOrders.length} Selesai',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.border),

                    if (paidOrders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('Belum ada transaksi hari ini', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paidOrders.length,
                        separatorBuilder: (_, _) => const Divider(height: 14, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final order = paidOrders[index];
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dateFormat.format(order.createdAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          order.orderNumber,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Meja ${order.tableNumber}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getPaymentMethodColor(order.paymentMethod).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  order.paymentMethod.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _getPaymentMethodColor(order.paymentMethod),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 14),

                              Text(
                                AppCurrency.format(order.grandTotal),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
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

  Color _getPaymentMethodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return AppColors.primary;
      case PaymentMethod.qris:
        return const Color(0xFF0284C7);
      case PaymentMethod.debitCard:
        return AppColors.accentCaramel;
    }
  }

  Widget _buildBreakdownCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
