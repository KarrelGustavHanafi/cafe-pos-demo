import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/jakarta_time.dart';
import '../../widgets/receipt_widget.dart';

class OwnerOrdersScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerOrdersScreen({super.key, required this.pos});

  @override
  State<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends State<OwnerOrdersScreen> {
  String _search = '';
  PaymentMethod? _methodFilter;
  OrderStatus? _statusFilter;
  bool _filterTodayOnly = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showOrderDetail(Order order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Detail Transaksi Pesanan',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ReceiptWidget(order: order),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup Rincian'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The cafe's day, not the device's: a visitor in another timezone must see
    // the same "today" as the reporting screens.
    final today = jakartaDate(DateTime.now());

    final filteredOrders = widget.pos.orders.where((o) {
      if (_filterTodayOnly) {
        // Calendar-date comparison, matching PosProvider's period filtering.
        if (!jakartaDate(o.createdAt).isAtSameMomentAs(today)) return false;
      }
      if (_methodFilter != null && o.paymentMethod != _methodFilter) return false;
      if (_statusFilter != null && o.status != _statusFilter) return false;
      if (_search.isNotEmpty) {
        final matches = o.orderNumber.toLowerCase().contains(_search.toLowerCase()) ||
            o.tableNumber.toLowerCase().contains(_search.toLowerCase()) ||
            o.cashierName.toLowerCase().contains(_search.toLowerCase());
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Pesanan'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() => _search = v),
                              decoration: const InputDecoration(
                                hintText: 'Cari No. Order, Lokasi, atau Kasir...',
                                prefixIcon: Icon(Icons.search_rounded, size: 18),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Hari Ini', style: TextStyle(fontSize: 11)),
                            selected: _filterTodayOnly,
                            onSelected: (v) => setState(() => _filterTodayOnly = v),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Semua Pembayaran', style: TextStyle(fontSize: 11)),
                            selected: _methodFilter == null,
                            onSelected: (_) => setState(() => _methodFilter = null),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('QRIS', style: TextStyle(fontSize: 11)),
                            selected: _methodFilter == PaymentMethod.qris,
                            onSelected: (_) => setState(() => _methodFilter = PaymentMethod.qris),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Tunai', style: TextStyle(fontSize: 11)),
                            selected: _methodFilter == PaymentMethod.cash,
                            onSelected: (_) => setState(() => _methodFilter = PaymentMethod.cash),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Debit', style: TextStyle(fontSize: 11)),
                            selected: _methodFilter == PaymentMethod.debitCard,
                            onSelected: (_) => setState(() => _methodFilter = PaymentMethod.debitCard),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Orders List Card
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Daftar Transaksi (${filteredOrders.length})',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Klik baris pesanan untuk melihat detail struk',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  if (filteredOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Tidak ada transaksi pesanan yang sesuai filter.', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredOrders.length,
                      separatorBuilder: (_, index) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final itemsCount = order.items.fold<int>(0, (s, i) => s + i.quantity);

                        return InkWell(
                          onTap: () => _showOrderDetail(order),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: order.paymentMethod == PaymentMethod.qris
                                        ? AppColors.primarySoft
                                        : (order.paymentMethod == PaymentMethod.cash
                                            ? AppColors.accentCaramel.withValues(alpha: 0.12)
                                            : AppColors.surfaceSubtle),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    order.paymentMethod == PaymentMethod.qris
                                        ? Icons.qr_code_rounded
                                        : (order.paymentMethod == PaymentMethod.cash
                                            ? Icons.payments_rounded
                                            : Icons.credit_card_rounded),
                                    color: order.paymentMethod == PaymentMethod.qris
                                        ? AppColors.primary
                                        : (order.paymentMethod == PaymentMethod.cash
                                            ? AppColors.accentCaramel
                                            : AppColors.textSecondary),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.orderNumber,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${order.tableLabel} • Kasir: ${order.cashierName} • $itemsCount item',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      AppCurrency.format(order.grandTotal),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.successSoft,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        order.paymentMethod.label,
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.success),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
                              ],
                            ),
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
}
