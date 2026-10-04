import 'package:flutter/material.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class OwnerReportsScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerReportsScreen({super.key, required this.pos});

  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Laporan Bisnis'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Performa Menu'),
            Tab(text: 'Metode Pembayaran'),
            Tab(text: 'Kinerja Kasir'),
            Tab(text: 'Perputaran Stok'),
            Tab(text: 'Rekap Shift'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductPerformanceTab(),
          _buildPaymentMixTab(),
          _buildCashierPerformanceTab(),
          _buildInventoryReportTab(),
          _buildShiftSummaryTab(),
        ],
      ),
    );
  }

  Widget _buildProductPerformanceTab() {
    final topList = widget.pos.topSellingProducts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Laporan Kontribusi Penjualan Menu',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topList.length,
                separatorBuilder: (_, index) => const Divider(height: 1, color: AppColors.borderLight),
                itemBuilder: (context, index) {
                  final item = topList[index];
                  final totalQty = widget.pos.todayTotalItemsSold;
                  final percentage = totalQty > 0 ? (item.value / totalQty * 100).toStringAsFixed(1) : '0';

                  final ratio = totalQty > 0 ? (item.value / totalQty).clamp(0.0, 1.0) : 0.0;
                  final barColor = index == 0
                      ? AppColors.primary
                      : index == 1
                          ? AppColors.primaryLight
                          : AppColors.primaryBorder;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primarySoft,
                              child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  Text('$percentage% dari seluruh pesanan', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Text(
                              '${item.value} terjual',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 5,
                            backgroundColor: AppColors.surfaceSubtle,
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMixTab() {
    final cash = widget.pos.todayCashSales;
    final qris = widget.pos.todayQrisSales;
    final debit = widget.pos.todayDebitSales;
    final total = widget.pos.todaySalesTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Komposisi Kanal Pembayaran',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              _buildPaymentChannelRow('QRIS (Statik & Dinamis)', qris, total, AppColors.primary, Icons.qr_code_rounded),
              const SizedBox(height: 14),
              _buildPaymentChannelRow('Tunai (Cash Register)', cash, total, AppColors.accentCaramel, Icons.payments_rounded),
              const SizedBox(height: 14),
              _buildPaymentChannelRow('Kartu Debit / EDC', debit, total, AppColors.textSecondary, Icons.credit_card_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChannelRow(String name, int amount, int total, Color color, IconData icon) {
    final pct = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0';
    final ratio = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
            Text(
              '${AppCurrency.format(amount)} ($pct%)',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: AppColors.surfaceSubtle,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildCashierPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistik Kasir Aktif',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.person_rounded, color: AppColors.primaryDark),
                ),
                title: const Text('Siti Rahma', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${widget.pos.todayTransactionsCount} transaksi hari ini • Rata-rata layan 1.8 menit'),
                trailing: Text(
                  AppCurrency.format(widget.pos.todaySalesTotal),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryReportTab() {
    final lowStockMenu = widget.pos.lowStockProducts;
    final lowStockMat = widget.pos.lowStockRawMaterials;
    final outOfStockMat = widget.pos.outOfStockRawMaterials;

    String formatNum(num val) =>
        val.truncateToDouble() == val ? val.toInt().toString() : val.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Metric Row for Inventory Health
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Menu Siap Jual', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('${widget.pos.products.length} Item', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Bahan Baku', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('${widget.pos.rawMaterials.length} Bahan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Peringatan Bahan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('${lowStockMat.length + outOfStockMat.length} Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: outOfStockMat.isNotEmpty ? AppColors.error : AppColors.warning)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Raw Material Health Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.egg_alt_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Laporan Stok Bahan Baku & Peringatan Reorder',
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.border),
                  if (outOfStockMat.isEmpty && lowStockMat.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Seluruh 10 bahan baku berada dalam batas aman stok.', style: TextStyle(color: AppColors.success, fontSize: 12)),
                    )
                  else ...[
                    if (outOfStockMat.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('BAHAN HABIS (OUT OF STOCK):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.error)),
                      ...outOfStockMat.map((m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            subtitle: Text('Stok: 0 ${m.unit.label} • Minimum diperlukan: ${formatNum(m.minimumStock)} ${m.unit.label}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: BorderRadius.circular(6)),
                              child: const Text('OUT OF STOCK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error)),
                            ),
                          )),
                    ],
                    if (lowStockMat.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('BAHAN MENIPIS (LOW STOCK):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.warning)),
                      ...lowStockMat.map((m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            subtitle: Text('Sisa: ${formatNum(m.stock)} ${m.unit.label} • Batas minimum: ${formatNum(m.minimumStock)} ${m.unit.label}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(6)),
                              child: const Text('LOW STOCK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.warning)),
                            ),
                          )),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Menu Product Health Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Laporan Stok Menu Produk Siap Jual',
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.border),
                  if (lowStockMenu.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Semua produk menu dalam batas aman stok.', style: TextStyle(color: AppColors.success, fontSize: 12)),
                    )
                  else
                    ...lowStockMenu.map((p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: Text('Sisa stok: ${p.stock} pcs • Batas minimum: ${p.lowStockThreshold} pcs'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.isOutOfStock ? AppColors.errorSoft : AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.stockStatus.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: p.isOutOfStock ? AppColors.error : AppColors.warning,
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSummaryTab() {
    final shifts = widget.pos.allShifts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rekapitulasi Shift Kasir',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              ...shifts.map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.isClosed ? Icons.lock_clock_rounded : Icons.lock_open_rounded,
                      color: s.isClosed ? AppColors.textSecondary : AppColors.success,
                    ),
                    title: Text(s.shiftName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text('Kasir: ${s.cashierName} • Kas Awal: ${AppCurrency.format(s.startingCash)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.isClosed ? AppColors.surfaceSubtle : AppColors.successSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.isClosed ? 'CLOSED' : 'OPEN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: s.isClosed ? AppColors.textSecondary : AppColors.success,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
