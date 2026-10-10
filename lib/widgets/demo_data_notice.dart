import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Compact, non-blocking disclosure that this build runs on demo data.
///
/// Operational data (transactions, stock and other POS records) is held in
/// memory and re-seeded from sample data on reload. Business configuration is
/// persisted separately, so the copy deliberately does not claim that every
/// setting resets.
class DemoDataNotice extends StatelessWidget {
  const DemoDataNotice({super.key, this.compact = false});

  /// Renders a denser variant for narrow viewports.
  final bool compact;

  static const String message =
      'Mode Demo: transaksi, stok, dan perubahan data operasional tidak '
      'tersimpan permanen. Setelah browser di-refresh, data dapat kembali ke '
      'data contoh. Pengaturan business tetap tersimpan.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        compact ? 8 : 16,
        compact ? 8 : 10,
        compact ? 8 : 16,
        0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: compact ? 15 : 17,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: compact ? 8 : 10),
          // Expanded keeps long text from overflowing on narrow screens.
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}