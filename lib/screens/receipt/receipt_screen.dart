import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/receipt_widget.dart';

class ReceiptScreen extends StatefulWidget {
  final PosProvider pos;
  final Order? customOrder;
  final VoidCallback onBackToCashier;
  final VoidCallback? onGoToOwnerDashboard;

  const ReceiptScreen({
    super.key,
    required this.pos,
    this.customOrder,
    required this.onBackToCashier,
    this.onGoToOwnerDashboard,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  void _showPrintSimulationDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: const Icon(Icons.print_rounded, color: AppColors.primaryDark, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIMULASI CETAK STRUK',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                  Text(
                    'Thermal POS Printer (ESC/POS)',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildPrinterRow('Printer:', 'CAFFE POS Thermal 80mm', isBold: true),
                  const SizedBox(height: 6),
                  _buildPrinterStatusRow('Status:', 'Siap digunakan'),
                  const SizedBox(height: 6),
                  _buildPrinterRow('Ukuran:', '80 mm (Kertas Kasir)'),
                  const SizedBox(height: 6),
                  _buildPrinterRow('Jumlah:', '1 copy (Struk Pembeli)'),
                  const SizedBox(height: 6),
                  _buildPrinterRow('No. Pesanan:', order.orderNumber),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Catatan: Ini adalah demonstrasi alur pencetakan struk kasir Bluetooth/USB.',
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '✓ Simulasi cetak berhasil: Struk ${order.orderNumber} terkirim ke printer thermal 80mm.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.primaryDark,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Cetak Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppSimulationDialog(BuildContext context, Order order) {
    final phoneController = TextEditingController(text: '081234567890');
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.chat_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KIRIM STRUK DIGITAL',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                    Text(
                      'Kirim struk kasir via WhatsApp',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kirim salinan e-receipt pesanan ${order.orderNumber} langsung ke nomor WhatsApp pelanggan:',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nomor WhatsApp',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '08xxxxxxxxxx',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.textMuted, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Struk PDF dan ringkasan transaksi akan dikirimkan ke nomor tersebut.',
                style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final phone = phoneController.text.trim();
                if (phone.isEmpty || phone.length < 8) {
                  setDialogState(() {
                    errorText = 'Masukkan nomor WhatsApp yang valid';
                  });
                  return;
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✓ Simulasi struk berhasil dikirim ke WhatsApp $phone.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF0F766E),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Kirim Struk', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.customOrder ??
        widget.pos.currentOrder ??
        (widget.pos.orders.isNotEmpty ? widget.pos.orders.first : null);

    final isMobile = Breakpoints.isMobile(context);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Struk Pembayaran')),
        body: Center(
          child: ElevatedButton(
            onPressed: widget.onBackToCashier,
            child: const Text('Kembali ke Kasir'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Struk Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBackToCashier,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thermal Receipt Display
              ReceiptWidget(
                order: order,
                maxWidth: isMobile ? 340 : 360,
              ),

              const SizedBox(height: 18),

              // Action Buttons: Primary (Print), Secondary (WhatsApp), Tertiary (New Order / Return)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? 340 : 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Primary Action: Print
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPrintSimulationDialog(context, order),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text(
                          'Cetak Struk (Thermal 80mm)',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 2. Secondary Action: Send WhatsApp Receipt
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _showWhatsAppSimulationDialog(context, order),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primaryDark),
                        label: const Text(
                          'Kirim via WhatsApp',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.primaryBorder, width: 1.2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 3. Navigation: New Order / Back to POS
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: widget.onBackToCashier,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: AppColors.textSecondary),
                        label: const Text(
                          'Buat Pesanan Baru',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceSubtle,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),

                    if (widget.onGoToOwnerDashboard != null) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: widget.onGoToOwnerDashboard,
                        icon: const Icon(Icons.analytics_outlined, size: 15),
                        label: const Text('Lihat di Owner Dashboard', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
