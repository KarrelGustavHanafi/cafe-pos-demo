import 'package:flutter/material.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final PosProvider pos;
  final VoidCallback onViewReceipt;
  final VoidCallback onNewOrder;
  final VoidCallback? onGoToOwnerDashboard;
  final VoidCallback onGoToCashier;

  const PaymentSuccessScreen({
    super.key,
    required this.pos,
    required this.onViewReceipt,
    required this.onNewOrder,
    this.onGoToOwnerDashboard,
    required this.onGoToCashier,
  });

  @override
  Widget build(BuildContext context) {
    final order = pos.currentOrder ?? (pos.orders.isNotEmpty ? pos.orders.first : null);

    if (order == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: onGoToCashier,
            child: const Text('Kembali ke Kasir'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Icon
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: AppColors.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 14),

                    Semantics(
                      header: true,
                      headingLevel: 1,
                      child: const Text(
                        'Pembayaran Berhasil!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pesanan telah terdaftar dan transaksi telah selesai dicatat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Order Summary Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Nomor Pesanan', order.orderNumber, isBold: true),
                          const SizedBox(height: 6),
                          _buildDetailRow('Meja / Lokasi', 'Meja ${order.tableNumber}'),
                          const SizedBox(height: 6),
                          _buildDetailRow('Metode Pembayaran', order.paymentMethod.label),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            'Total Pembayaran',
                            AppCurrency.format(order.grandTotal),
                            valueColor: AppColors.primaryDark,
                            isBold: true,
                          ),
                          if (order.changeAmount > 0) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow('Kembalian', AppCurrency.format(order.changeAmount)),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Inventory & System Update Notification
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: AppColors.primaryDark, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pembaruan Stok & Bahan Baku Otomatis',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Stok produk jadi dan takaran bahan baku resep (${order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', ')}) telah otomatis dikurangi dari inventaris kafe.',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Primary Action: View Receipt
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: onViewReceipt,
                        icon: const Icon(Icons.receipt_rounded, size: 18),
                        label: const Text(
                          'Lihat Struk Pesanan (Receipt)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Secondary Action: Start New Order
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: onNewOrder,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                        label: const Text('Buat Pesanan Baru'),
                      ),
                    ),

                    if (onGoToOwnerDashboard != null) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: onGoToOwnerDashboard,
                        icon: const Icon(Icons.insights_rounded, size: 16),
                        label: const Text('Buka Dashboard Owner'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: isBold ? 12 : 11,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
