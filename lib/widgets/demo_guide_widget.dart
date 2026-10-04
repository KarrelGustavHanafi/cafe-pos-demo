import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// DemoGuideWidget: A responsive, non-intrusive guide banner for the CAFFE POS demo.
/// Adapts content density per breakpoint: compact on mobile, moderate on tablet, full on desktop.
/// Can be collapsed to a minimal chip and re-opened anytime.
class DemoGuideWidget extends StatefulWidget {
  final bool isCashierMode; // true = cashier guide, false = owner guide

  const DemoGuideWidget({
    super.key,
    required this.isCashierMode,
  });

  @override
  State<DemoGuideWidget> createState() => _DemoGuideWidgetState();
}

class _DemoGuideWidgetState extends State<DemoGuideWidget> {
  bool _isCollapsed = false;
  bool _showFullGuide = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    if (_isCollapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => setState(() => _isCollapsed = false),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.primaryDark),
                  const SizedBox(width: 5),
                  Text(
                    widget.isCashierMode ? '💡 Demo Kasir' : '💡 Demo Owner',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded, size: 14, color: AppColors.primaryDark),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 12,
        vertical: isMobile ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main row: icon + summary + close
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryText(isMobile: isMobile, isTablet: isTablet),
              ),
              const SizedBox(width: 6),
              // Show "full guide" toggle on mobile only
              if (isMobile && !_showFullGuide)
                InkWell(
                  onTap: () => setState(() => _showFullGuide = true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Selengkapnya',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() {
                  _isCollapsed = true;
                  _showFullGuide = false;
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),

          // Expanded guide for mobile (toggle) or always shown on desktop
          if (_showFullGuide && isMobile) ...[
            const SizedBox(height: 6),
            _buildFullGuideContent(),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => setState(() => _showFullGuide = false),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Tutup Panduan ▲',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryText({required bool isMobile, required bool isTablet}) {
    if (widget.isCashierMode) {
      if (isMobile) {
        return const Text(
          'Pilih menu → Cart → Checkout',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        );
      } else if (isTablet) {
        return const Text(
          'Demo: Pilih menu → Cart → Checkout → Payment → Receipt',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        );
      } else {
        // Desktop: full guide
        return const Text(
          '💡 Cara Demo: Pilih menu → Atur varian/cup size → Tambah ke cart → Checkout → Pilih pembayaran (Cash/QRIS) → Lihat struk',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        );
      }
    } else {
      // Owner mode
      if (isMobile) {
        return const Text(
          'Pantau omzet, stok & laporan',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        );
      } else if (isTablet) {
        return const Text(
          'Demo Owner: Pantau omzet live, stok resep otomatis, laporan shift',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        );
      } else {
        return const Text(
          '💡 Demo Owner: Pantau omzet live, pengurangan stok resep otomatis, kelola inventaris & bahan baku, dan laporan shift',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        );
      }
    }
  }

  Widget _buildFullGuideContent() {
    final steps = widget.isCashierMode
        ? [
            '1. Pilih kategori & menu produk',
            '2. Atur varian/cup size jika tersedia',
            '3. Tambah ke keranjang',
            '4. Klik Checkout / Bayar',
            '5. Pilih metode bayar: Cash atau QRIS',
            '6. Lihat struk & ringkasan transaksi',
          ]
        : [
            '1. Dashboard — Pantau omzet live & statistik hari ini',
            '2. Inventaris — Lihat stok bahan baku & menu',
            '3. Resep — Pemetaan bahan baku ke menu',
            '4. Laporan — Rincian penjualan per shift',
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: steps.map((step) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text(
            step,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.primaryDark),
          ),
        )).toList(),
      ),
    );
  }
}
