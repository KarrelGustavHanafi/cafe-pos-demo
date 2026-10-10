import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class CashierOrdersScreen extends StatelessWidget {
  final PosProvider pos;
  final ValueChanged<Order> onViewReceipt;

  const CashierOrdersScreen({
    super.key,
    required this.pos,
    required this.onViewReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');
    final paidOrders = pos.orders.where((o) => o.status == OrderStatus.paid).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: Text(
            paidOrders.isEmpty
                ? 'Pesanan Selesai'
                : 'Pesanan Selesai (${paidOrders.length})',
          ),
        ),
      ),
      body: paidOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum Ada Transaksi Hari Ini',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Transaksi yang telah selesai akan muncul di sini.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Coba lakukan transaksi dari tab POS.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: paidOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = paidOrders[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final timeChip = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: Text(
                            dateFormat.format(order.createdAt),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        );
                        final amount = Text(
                          AppCurrency.format(order.grandTotal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        );
                        final viewReceipt = InkWell(
                          onTap: () => onViewReceipt(order),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_rounded, size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Lihat Struk',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        final tableChip = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.tableLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        );
                        final itemsLine = Text(
                          order.items.map((i) {
                            final mods = i.hasModifiers ? ' (${i.modifierSummary})' : '';
                            return '${i.quantity}x ${i.product.name}$mods';
                          }).join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        );
                        final orderNumber = Text(
                          order.orderNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        );

                        // Wide: original single-row card.
                        if (c.maxWidth >= 430) {
                          return Row(
                            children: [
                              timeChip,
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(child: orderNumber),
                                        const SizedBox(width: 8),
                                        tableChip,
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    itemsLine,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  amount,
                                  const SizedBox(height: 4),
                                  viewReceipt,
                                ],
                              ),
                            ],
                          );
                        }

                        // Narrow: stacked card so nothing is squeezed out.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                timeChip,
                                const SizedBox(width: 10),
                                Expanded(child: orderNumber),
                              ],
                            ),
                            const SizedBox(height: 6),
                            itemsLine,
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                tableChip,
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: amount,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                viewReceipt,
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
