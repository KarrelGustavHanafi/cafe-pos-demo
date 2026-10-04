import 'package:flutter/material.dart';
import '../state/pos_provider.dart';
import '../theme/app_theme.dart';
import 'product_customization_dialog.dart';

class CartView extends StatelessWidget {
  final PosProvider pos;
  final VoidCallback onCheckout;
  final VoidCallback? onChangeTable;

  const CartView({
    super.key,
    required this.pos,
    required this.onCheckout,
    this.onChangeTable,
  });

  @override
  Widget build(BuildContext context) {
    final cart = pos.cart;
    final tableName = pos.selectedTable?.number ?? 'Takeaway';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Table badge & location
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.table_restaurant_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lokasi Pesanan',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Meja $tableName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onChangeTable != null)
                  TextButton.icon(
                    onPressed: onChangeTable,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text('Ganti', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),

          // Cart Items List
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              size: 32,
                              color: AppColors.textMuted.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Keranjang Kosong',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pilih menu dari katalog untuk memulai pesanan pelanggan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: cart.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 10,
                      color: AppColors.borderLight,
                    ),
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final choices = item.selectedModifiers
                          .where((m) => m.priceAdjustment <= 0)
                          .map((m) => m.name)
                          .join(' • ');
                      final addons = item.selectedModifiers
                          .where((m) => m.priceAdjustment > 0)
                          .map((m) => m.name)
                          .join(' • ');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppCurrency.format(item.itemTotal),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (choices.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              choices,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (addons.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              addons,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                          if (item.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.notes.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${item.quantity} × ${AppCurrency.format(item.unitPrice)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (item.product.hasModifiers)
                                TextButton.icon(
                                  onPressed: () => _editCartItem(context, index),
                                  icon: const Icon(Icons.tune_rounded, size: 16),
                                  label: const Text('Ubah'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryDark,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: const Size(72, 40),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              _qtyButton(
                                icon: Icons.remove_rounded,
                                onTap: () => pos.updateCartQuantityAt(index, item.quantity - 1),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              _qtyButton(
                                icon: Icons.add_rounded,
                                onTap: () => pos.updateCartQuantityAt(index, item.quantity + 1),
                              ),
                              const SizedBox(width: 4),
                              _qtyButton(
                                icon: Icons.delete_outline_rounded,
                                color: AppColors.danger,
                                onTap: () => pos.removeCartItemAt(index),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Bill Summary Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', AppCurrency.format(pos.cartSubtotal)),
                const SizedBox(height: 3),
                _buildSummaryRow(
                  'Biaya Layanan (5%)',
                  AppCurrency.format(pos.cartServiceCharge),
                ),
                const SizedBox(height: 3),
                _buildSummaryRow('Pajak PB1 (10%)', AppCurrency.format(pos.cartTax)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Grand Total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppCurrency.format(pos.cartGrandTotal),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: cart.isEmpty ? null : onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Checkout (${pos.cartItemCount} item)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editCartItem(BuildContext context, int index) {
    final item = pos.cart[index];
    ProductCustomizationDialog.show(
      context,
      product: item.product,
      initialCartItem: item,
      onConfirm: (modifiers, quantity, notes) {
        pos.replaceCartItemAt(
          index,
          quantity: quantity,
          modifiers: modifiers,
          notes: notes,
        );
      },
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: color ?? AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
