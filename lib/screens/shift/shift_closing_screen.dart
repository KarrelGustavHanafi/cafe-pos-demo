import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class ShiftClosingScreen extends StatefulWidget {
  final PosProvider pos;
  final VoidCallback onBackToDashboard;
  final VoidCallback? onLogout;

  const ShiftClosingScreen({
    super.key,
    required this.pos,
    required this.onBackToDashboard,
    this.onLogout,
  });

  @override
  State<ShiftClosingScreen> createState() => _ShiftClosingScreenState();
}

class _ShiftClosingScreenState extends State<ShiftClosingScreen> {
  final _actualCashController = TextEditingController();
  final _notesController = TextEditingController();
  int _actualCash = 0;

  @override
  void initState() {
    super.initState();
    final expected = widget.pos.currentShift.startingCash + widget.pos.todayCashSales;
    _actualCash = expected;
    _actualCashController.text = expected.toString();
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.pos.currentShift;
    final timeFormat = DateFormat('dd MMM yyyy, HH:mm');
    final startingCash = shift.startingCash;
    final cashSales = widget.pos.todayCashSales;
    final expectedEndingCash = startingCash + cashSales;
    final variance = _actualCash - expectedEndingCash;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Shift Kasir'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          splashRadius: 20,
          onPressed: widget.onBackToDashboard,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Shift Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: const Icon(Icons.lock_clock_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift.shiftName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kasir: ${shift.cashierName} • Dibuka: ${timeFormat.format(shift.startTime)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: shift.isClosed ? AppColors.dangerSoft : AppColors.successSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            shift.isClosed ? 'Ditutup' : 'Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: shift.isClosed ? AppColors.danger : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24, color: AppColors.border),

                    // Reconciliation Breakdown
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildLine('Modal Awal Kas di Laci', AppCurrency.format(startingCash)),
                          const SizedBox(height: 6),
                          _buildLine('Total Penjualan Tunai (Cash)', AppCurrency.format(cashSales)),
                          const SizedBox(height: 6),
                          _buildLine('Total Transaksi QRIS', AppCurrency.format(widget.pos.todayQrisSales)),
                          const SizedBox(height: 6),
                          _buildLine('Total Transaksi Kartu Debit', AppCurrency.format(widget.pos.todayDebitSales)),
                          const Divider(height: 16, color: AppColors.border),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Perkiraan Fisik Kas di Laci',
                                  maxLines: 2,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppCurrency.format(expectedEndingCash),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Actual Cash Input Field
                    const Text(
                      'Hitungan Fisik Uang Kas di Laci (Rp)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _actualCashController,
                      enabled: !shift.isClosed,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: 'Rp ',
                        hintText: '0',
                      ),
                      onChanged: (val) {
                        setState(() {
                          _actualCash = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Variance Alert
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: variance == 0
                            ? AppColors.successSoft
                            : (variance > 0 ? AppColors.infoSoft : AppColors.dangerSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  variance == 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                  color: variance == 0 ? AppColors.success : (variance > 0 ? AppColors.info : AppColors.danger),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    variance == 0
                                        ? 'Kas Seimbang (Klop / 0 Selisih)'
                                        : (variance > 0 ? 'Kelebihan Kas' : 'Kekurangan Kas'),
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: variance == 0 ? AppColors.success : (variance > 0 ? AppColors.info : AppColors.danger),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppCurrency.format(variance),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: variance == 0 ? AppColors.success : (variance > 0 ? AppColors.info : AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Closing Notes
                    const Text(
                      'Catatan Pergantian Shift (Opsional)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      enabled: !shift.isClosed,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Stok susu cukup, pecahan 2rb menipis...',
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Submit Action
                    if (!shift.isClosed)
                      SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            widget.pos.closeShift(
                              actualEndingCash: _actualCash,
                              notes: _notesController.text,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Shift berhasil ditutup dan laporan diserahkan.'),
                                backgroundColor: AppColors.primaryDark,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text(
                            'Konfirmasi Tutup Shift Sekarang',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              'Shift Berhasil Ditutup',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Shift kasir telah resmi diselesaikan.\nWaktu Penutupan: ${timeFormat.format(shift.closedAt ?? DateTime.now())}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            // Primary actions after shift closed: responsive layout
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final logoutButton = OutlinedButton.icon(
                                  onPressed: widget.onLogout,
                                  icon: const Icon(Icons.logout_rounded, size: 16),
                                  label: const Text('Logout Kasir', style: TextStyle(fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    foregroundColor: AppColors.danger,
                                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                                  ),
                                );

                                final newShiftButton = ElevatedButton.icon(
                                  onPressed: () {
                                    widget.pos.startNewShift(startingCash: 300000);
                                    widget.onBackToDashboard();
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('Buka Shift Baru', style: TextStyle(fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );

                                if (constraints.maxWidth >= 380) {
                                  return Row(
                                    children: [
                                      if (widget.onLogout != null)
                                        Expanded(child: logoutButton),
                                      if (widget.onLogout != null)
                                        const SizedBox(width: 10),
                                      Expanded(child: newShiftButton),
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    newShiftButton,
                                    if (widget.onLogout != null) ...[
                                      const SizedBox(height: 10),
                                      logoutButton,
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}
