import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/business_config.dart';
import '../theme/app_theme.dart';

class ReceiptWidget extends StatelessWidget {
  final Order order;
  final double? maxWidth;
  final BusinessConfig? businessConfig;

  const ReceiptWidget({
    super.key,
    required this.order,
    this.maxWidth = 360,
    this.businessConfig,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      key: const Key('thermal-receipt'),
      constraints: BoxConstraints(maxWidth: maxWidth ?? 360),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Cafe Name
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: const Icon(
                Icons.coffee_rounded,
                color: AppColors.primaryDark,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            businessConfig?.businessName ?? 'CAFFE',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            businessConfig != null
                ? '${businessConfig!.address}${businessConfig!.phone.isNotEmpty ? '\nTelp: ${businessConfig!.phone}' : ''}'
                : 'Jl. Senopati No. 45, Kebayoran Baru\nJakarta Selatan • Telp: (021) 7890-1234',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          _buildDashedDivider(),
          const SizedBox(height: 10),

          // Order Meta
          _buildMetaRow('No. Pesanan', order.orderNumber),
          const SizedBox(height: 3),
          _buildMetaRow('Waktu', dateFormat.format(order.createdAt)),
          const SizedBox(height: 3),
          _buildMetaRow('Kasir', order.cashierName),
          const SizedBox(height: 3),
          // Seating is free-choice: a takeaway order was never assigned a table, so
// printing "Meja Takeaway" would be meaningless to the customer. Mirrors the
// guard already used by receipt_formatter.dart.
            if (order.tableNumber.toLowerCase() != 'takeaway')
              _buildMetaRow('Meja', 'Meja ${order.tableNumber}'),
          const SizedBox(height: 3),
          _buildMetaRow('Status', order.status.label),

          const SizedBox(height: 10),
          _buildDashedDivider(),
          const SizedBox(height: 10),

          // Items Table
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppCurrency.format(item.itemTotal),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  for (final modifier in item.selectedModifiers)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        modifier.name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ),
                  if (item.notes.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        item.notes.trim(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${item.quantity} × ${AppCurrency.format(item.unitPrice)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),
          _buildDashedDivider(),
          const SizedBox(height: 10),

          // Financial Summary
          _buildSummaryLine('Subtotal', AppCurrency.format(order.subtotal)),
          const SizedBox(height: 3),
          _buildSummaryLine(
            'Biaya Layanan${order.subtotal > 0 && order.serviceCharge > 0 ? ' (${((order.serviceCharge / order.subtotal) * 100).toStringAsFixed(0)}%)' : ''}',
            AppCurrency.format(order.serviceCharge),
          ),
          const SizedBox(height: 3),
          _buildSummaryLine(
            'Pajak PB1${order.subtotal > 0 && order.tax > 0 ? ' (${((order.tax / order.subtotal) * 100).toStringAsFixed(0)}%)' : ''}',
            AppCurrency.format(order.tax),
          ),
          const SizedBox(height: 6),
          const Divider(thickness: 1.2, color: AppColors.textPrimary),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                AppCurrency.format(order.grandTotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDashedDivider(),
          const SizedBox(height: 8),

          // Payment details
          _buildSummaryLine('Metode Pembayaran', order.paymentMethod.label),
          if (order.paidAmount > 0) ...[
            const SizedBox(height: 3),
            _buildSummaryLine('Tunai Diterima', AppCurrency.format(order.paidAmount)),
            const SizedBox(height: 3),
            _buildSummaryLine('Kembalian', AppCurrency.format(order.changeAmount)),
          ],

          const SizedBox(height: 16),
          // Footer
          Text(
            businessConfig?.receiptFooter.isNotEmpty == true
                ? businessConfig!.receiptFooter
                : '*** TERIMA KASIH ***\nNikmati Harimu Bersama Caffe\nWiFi ID: Caffe_Guest • Pass: caffekopi',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        const pitch = dashWidth + dashSpace;
        // Never emit more dash width than the row actually has, otherwise the
        // spaceBetween Flex overflows by up to (pitch - dashWidth) pixels.
        final dashCount =
            boxWidth <= dashWidth ? 0 : ((boxWidth + dashSpace) / pitch).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.border),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
