import 'package:flutter/material.dart';
import '../../models/shift.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class OwnerShiftsScreen extends StatelessWidget {
  final PosProvider pos;

  const OwnerShiftsScreen({super.key, required this.pos});

  @override
  Widget build(BuildContext context) {
    final shifts = pos.allShifts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Monitoring Shift'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Management Warning / Role Separation Callout
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panel Pengawasan Pemilik (Owner Mode)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Monitoring pembukaan kasir, verifikasi selisih fisik kas, serta data yang tersimpan saat shift ditutup, tanpa mencampuri proses operasional POS.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Shifts List Cards
            ...shifts.map((s) => _buildShiftCard(context, s)),
          ],
        ),
      ),
    );
  }

  /// Placeholder for figures the current data model cannot support.
  ///
  /// Closed shifts store no sales of their own and orders carry no shift
  /// reference, so per-shift sales and the cash variance derived from them
  /// cannot be calculated honestly. Showing a number here would be invented.
  static const String _unavailable = 'Tidak tersedia';

  Widget _buildShiftCard(BuildContext context, ShiftInfo shift) {
    final isOpen = !shift.isClosed;

    // An open shift is the live one, so today's running figures apply to it.
    // A closed shift has no order linkage, so only the values recorded at
    // closing time itself are real.
    final totalShiftSales = isOpen ? pos.todaySalesTotal : null;
    final cashSales = isOpen ? pos.todayCashSales : null;
    final qrisSales = isOpen ? pos.todayQrisSales : null;
    final expectedCash = isOpen ? shift.startingCash + pos.todayCashSales : null;
    final actualCash =
        isOpen ? expectedCash : (shift.actualEndingCash ?? expectedCash);
    final variance = (expectedCash != null && actualCash != null)
        ? actualCash - expectedCash
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Shift Name & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isOpen ? AppColors.successSoft : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOpen ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
                          color: isOpen ? AppColors.success : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shift.shiftName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Kasir Bertugas: ${shift.cashierName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.successSoft : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isOpen ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
                    ),
                    child: Text(
                      isOpen ? 'STATUS: OPEN' : 'STATUS: CLOSED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOpen ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),

            // Metrics Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final crossAxisCount = isWide ? 4 : 2;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: isWide ? 2.2 : 2.0,
                  children: [
                    _buildSubMetric('Modal Kas Awal', AppCurrency.format(shift.startingCash)),
                    _buildSubMetric(
                      'Total Penjualan Shift',
                      totalShiftSales != null
                          ? AppCurrency.format(totalShiftSales)
                          : _unavailable,
                    ),
                    _buildSubMetric(
                      'Penjualan Tunai',
                      cashSales != null
                          ? AppCurrency.format(cashSales)
                          : _unavailable,
                    ),
                    _buildSubMetric(
                      'Penjualan QRIS',
                      qrisSales != null
                          ? AppCurrency.format(qrisSales)
                          : _unavailable,
                    ),
                    _buildSubMetric(
                      'Kas Diharapkan',
                      expectedCash != null
                          ? AppCurrency.format(expectedCash)
                          : _unavailable,
                    ),
                    _buildSubMetric(
                      'Kas Aktual Fisik',
                      actualCash != null
                          ? AppCurrency.format(actualCash)
                          : _unavailable,
                    ),
                    _buildSubMetric(
                      'Selisih Kas',
                      variance == null
                          ? _unavailable
                          : (variance == 0
                              ? 'Cocok (Rp0)'
                              : AppCurrency.format(variance)),
                      color: variance == null
                          ? AppColors.textSecondary
                          : (variance == 0
                              ? AppColors.success
                              : AppColors.warning),
                    ),
                    _buildSubMetric(
                      'Waktu Buka',
                      '${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}',
                    ),
                    _buildSubMetric(
                      'Waktu Tutup',
                      // An open shift has no closing time yet. Say so plainly
                      // instead of showing an "unavailable" placeholder that
                      // reads like missing data. Never infer a time from the
                      // current clock.
                      shift.closedAt != null
                          ? '${shift.closedAt!.hour.toString().padLeft(2, '0')}:${shift.closedAt!.minute.toString().padLeft(2, '0')}'
                          : (isOpen ? 'Belum ditutup' : _unavailable),
                    ),
                  ],
                );
              },
            ),

            if (shift.closingNotes != null && shift.closingNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Catatan Kasir: "${shift.closingNotes}"',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubMetric(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
