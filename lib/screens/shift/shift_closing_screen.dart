import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/business_config.dart';
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

  /// Parses and validates the opening float for a new shift.
  ///
  /// Returns `null` when [raw] is not a usable amount: empty, non-numeric, zero
  /// or negative. A drawer that starts at or below zero is not a real float, and
  /// silently coercing it to 0 would hide the mistake in the next
  /// reconciliation. Tolerates formatting separators ("300.000", "Rp 300000").
  ///
  /// A leading minus is rejected outright rather than stripped: discarding the
  /// sign would turn "-50000" into a positive float and quietly book money that
  /// was never counted.
  static int? parseOpeningCash(String raw) {
    return _parseRupiah(raw, allowZero: false);
  }

  /// Parses the physically counted cash in the drawer.
  ///
  /// Unlike the opening float, a zero count is legitimate (an empty drawer is a
  /// real, reportable outcome), so `allowZero` is true here.
  static int? parseActualCash(String raw) {
    return _parseRupiah(raw, allowZero: true);
  }

  /// Strict Rupiah integer parser shared by both cash fields.
  ///
  /// Accepts plain digits and the grouping separators this UI already renders
  /// ("300000", "300.000", "Rp 300000"). It deliberately does NOT strip stray
  /// characters and then coerce a parse failure to 0: doing so turned overflow,
  /// negatives and scientific-notation-like text ("1e5" -> 15) into a silent,
  /// plausible-looking zero and so into a false cash variance at closing time.
  ///
  /// Returns `null` for anything that is not a representable non-negative
  /// integer, letting the caller surface an error instead.
  static int? _parseRupiah(String raw, {required bool allowZero}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // A leading minus is a real negative count, not a formatting artifact.
    if (trimmed.startsWith('-')) return null;

    // Keep only digits and grouping separators, then verify the remainder is a
    // well-formed integer rather than silently discarding unknown characters.
    final stripped = trimmed.replaceFirst(RegExp(r'^[^\d]+'), '');
    if (!RegExp(r'^[\d.,\s]+$').hasMatch(stripped)) return null;

    final digits = stripped.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    // Reject absurd digit strings before parsing: `int.tryParse` returns null
    // on overflow, and that null must not degrade into 0.
    if (digits.length > 18) return null;

    final value = int.tryParse(digits);
    if (value == null) return null;
    if (value < 0) return null;
    if (!allowZero && value == 0) return null;
    return value;
  }

  @override
  State<ShiftClosingScreen> createState() => _ShiftClosingScreenState();
}

class _ShiftClosingScreenState extends State<ShiftClosingScreen> {
  final _actualCashController = TextEditingController();
  final _notesController = TextEditingController();
  int _actualCash = 0;

  /// Set when the counted-cash field holds text that is not a valid Rupiah
  /// amount. Surfaced inline, and the close action stays disabled while it is
  /// set, so an unparseable entry can never be booked as a zero count.
  String? _actualCashError;

  @override
  void initState() {
    super.initState();
    // Shift-scoped, not "today"-scoped: expected drawer cash must reflect only
    // the cash taken during THIS shift.
    final expected =
        widget.pos.expectedEndingCashForShift(widget.pos.currentShift);
    _actualCash = expected;
    _actualCashController.text = expected.toString();
  }

  Future<void> _promptForOpeningCash() async {
    final controller = TextEditingController();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modal Awal Shift Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan jumlah uang tunai yang ditaruh di laci kas '
                    'sebelum shift dibuka. Nilai ini menjadi Modal Awal pada '
                    'rekonsiliasi tutup shift.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Modal Awal (Rp)',
                      errorText: error,
                    ),
                    onChanged: (_) {
                      if (error != null) setState(() => error = null);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = ShiftClosingScreen.parseOpeningCash(controller.text);
                    if (parsed == null) {
                      setState(() =>
                          error = 'Masukkan nominal lebih dari 0.');
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Buka Shift'),
                ),
              ],
            );
          },
        );
      },
    );

    final openingCash = ShiftClosingScreen.parseOpeningCash(controller.text);
    controller.dispose();

    if (confirmed != true || openingCash == null) return;
    widget.pos.startNewShift(startingCash: openingCash);
    widget.onBackToDashboard();
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
    // Every figure below is scoped to this shift by Order.shiftId, so a second
    // shift on the same calendar day (or one crossing midnight) never leaks in.
    final cashSales = widget.pos.cashSalesForShift(shift.shiftId);
    final qrisSales = widget.pos.qrisSalesForShift(shift.shiftId);
    final debitSales = widget.pos.debitSalesForShift(shift.shiftId);
    final expectedEndingCash = startingCash + cashSales;
    final unattributed = widget.pos.unattributedCashTotal;
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
                          _buildLine('Total Transaksi QRIS', AppCurrency.format(qrisSales)),
                          const SizedBox(height: 6),
                          _buildLine('Total Transaksi Kartu Debit', AppCurrency.format(debitSales)),
                          const Divider(height: 16, color: AppColors.border),
                          // Reconciliation policy, stated openly: unknown-origin
                          // cash is never folded into this shift's drawer total.
                          // Showing it keeps the exclusion auditable instead of
                          // silently making the numbers look balanced.
                          if (unattributed > 0) ...[
                            _buildLine(
                              'Kas Tanpa Atribut Shift (di luar hitungan)',
                              AppCurrency.format(unattributed),
                            ),
                            const SizedBox(height: 6),
                          ],
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
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        hintText: '0',
                        errorText: _actualCashError,
                      ),
                      onChanged: (val) {
                        final parsed = ShiftClosingScreen.parseActualCash(val);
                        setState(() {
                          // Only a genuinely parsed amount updates the counted
                          // figure; an unparseable entry leaves the previous
                          // value untouched and raises an error instead of
                          // quietly becoming zero.
                          if (parsed != null) {
                            _actualCash = parsed;
                            _actualCashError = null;
                          } else {
                            _actualCashError = val.trim().isEmpty
                                ? null
                                : 'Masukkan nominal rupiah yang valid.';
                          }
                        });
                      },
                    ),
                    if (_actualCashError != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Periksa kembali hitungan kas sebelum menutup shift.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
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
                          // Blocked while the counted-cash field holds an
                          // amount that could not be parsed, so a malformed or
                          // overflowing entry is never silently closed as zero.
                          onPressed: _actualCashError != null
                              ? null
                              : () async {
                            final result = await widget.pos.closeShift(
                              actualEndingCash: _actualCash,
                              notes: _notesController.text,
                            );
                            if (!context.mounted) return;

                            final telegramConfig = widget.pos.businessConfig.telegramConfig;
                            final bool isSimulated = telegramConfig.integrationMode == TelegramIntegrationMode.mockSimulation ||
                                (widget.pos.businessConfig.isPublicDemo &&
                                    telegramConfig.integrationMode == TelegramIntegrationMode.directBotApi);

                            String feedbackText;
                            Color feedbackColor = AppColors.primaryDark;

                            if (!telegramConfig.enabled) {
                              feedbackText = 'Shift berhasil ditutup.';
                            } else if (result != null && result.success) {
                              if (isSimulated) {
                                feedbackText = 'Shift berhasil ditutup. Laporan shift disimulasikan (Mock Telegram).';
                              } else {
                                feedbackText = 'Shift berhasil ditutup. Laporan berhasil dikirim ke Telegram.';
                              }
                            } else if (result != null && !result.success) {
                              feedbackText = 'Shift berhasil ditutup, tetapi notifikasi Telegram gagal: ${result.message}';
                              feedbackColor = AppColors.warning;
                            } else {
                              feedbackText = 'Shift berhasil ditutup.';
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(feedbackText),
                                backgroundColor: feedbackColor,
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
                                  onPressed: () => _promptForOpeningCash(),
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
