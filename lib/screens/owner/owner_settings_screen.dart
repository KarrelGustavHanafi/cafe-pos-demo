import 'package:flutter/material.dart';
import '../../models/business_config.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/telegram/telegram_bot_service.dart';

class OwnerSettingsScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerSettingsScreen({super.key, required this.pos});

  @override
  State<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends State<OwnerSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Business Profile Controllers
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _instagramController;
  late TextEditingController _receiptFooterController;
  late TextEditingController _orderPrefixController;
  late TextEditingController _thresholdController;
  late TextEditingController _taxPercentController;
  late TextEditingController _serviceChargePercentController;

  late bool _isTaxEnabled;
  late bool _isServiceEnabled;

  // Printer Integration State
  late PrinterWidthType _printerWidth;
  late PrinterModeType _printerMode;

  // Telegram Integration State
  late bool _isTelegramEnabled;
  late TextEditingController _telegramBotUsernameController;
  late TextEditingController _telegramChatIdController;
  late TextEditingController _telegramEndpointController;
  late TextEditingController _telegramBotTokenController;
  late TextEditingController _telegramRelaySecretController;
  late TelegramIntegrationMode _telegramIntegrationMode;

  // QRIS Integration State
  late bool _isQrisEnabled;
  late TextEditingController _qrisMerchantNameController;
  late TextEditingController _qrisMerchantIdController;
  late QrisPaymentMode _qrisPaymentMode;

  // Action status states
  bool _isTestingTelegram = false;
  bool _isTestingPrinter = false;
  bool _isTestingQris = false;
  bool _isResettingDemoData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFromConfig(widget.pos.businessConfig);
  }

  void _loadFromConfig(BusinessConfig b) {
    _nameController = TextEditingController(text: b.businessName);
    _addressController = TextEditingController(text: b.address);
    _phoneController = TextEditingController(text: b.phone);
    _instagramController = TextEditingController(text: b.instagram);
    _receiptFooterController = TextEditingController(text: b.receiptFooter);
    _orderPrefixController = TextEditingController(text: b.orderNumberPrefix);
    _thresholdController = TextEditingController(text: '${b.defaultLowStockThreshold}');
    _taxPercentController = TextEditingController(text: '${b.taxPercent}');
    _serviceChargePercentController = TextEditingController(text: '${b.serviceChargePercent}');

    _isTaxEnabled = b.isTaxEnabled;
    _isServiceEnabled = b.isServiceEnabled;

    _printerWidth = b.printerWidth;
    _printerMode = b.printerMode;

    final t = b.telegramConfig;
    _isTelegramEnabled = t.enabled;
    _telegramBotUsernameController = TextEditingController(text: t.botUsername);
    _telegramChatIdController = TextEditingController(text: t.chatId);
    _telegramEndpointController = TextEditingController(text: t.endpoint);
    _telegramBotTokenController = TextEditingController(text: t.botToken ?? '');
    _telegramRelaySecretController = TextEditingController(text: t.relaySecret ?? '');
    // Use safe mode: in public demo, Direct Bot API is replaced with Mock Simulation
    _telegramIntegrationMode = t.getSafeMode(b.isPublicDemo);

    final q = b.qrisConfig;
    _isQrisEnabled = q.enabled;
    _qrisMerchantNameController = TextEditingController(text: q.merchantName);
    _qrisMerchantIdController = TextEditingController(text: q.merchantId);
    _qrisPaymentMode = q.paymentMode;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _receiptFooterController.dispose();
    _orderPrefixController.dispose();
    _thresholdController.dispose();
    _taxPercentController.dispose();
    _serviceChargePercentController.dispose();
    _telegramBotUsernameController.dispose();
    _telegramChatIdController.dispose();
    _telegramEndpointController.dispose();
    _telegramBotTokenController.dispose();
    _telegramRelaySecretController.dispose();
    _qrisMerchantNameController.dispose();
    _qrisMerchantIdController.dispose();
    super.dispose();
  }

  void _saveAllSettings() async {
    final updatedTelegram = widget.pos.businessConfig.telegramConfig.copyWith(
      enabled: _isTelegramEnabled,
      botUsername: _telegramBotUsernameController.text.trim(),
      chatId: _telegramChatIdController.text.trim(),
      endpoint: _telegramEndpointController.text.trim(),
      integrationMode: _telegramIntegrationMode,
      botToken: _telegramBotTokenController.text.trim().isEmpty ? null : _telegramBotTokenController.text.trim(),
      relaySecret: _telegramRelaySecretController.text.trim().isEmpty
          ? null
          : _telegramRelaySecretController.text.trim(),
      // An emptied field must REMOVE the stored secret, not keep the old one.
      clearRelaySecret: _telegramRelaySecretController.text.trim().isEmpty,
    );

    final updatedQris = widget.pos.businessConfig.qrisConfig.copyWith(
      enabled: _isQrisEnabled,
      merchantName: _qrisMerchantNameController.text.trim(),
      merchantId: _qrisMerchantIdController.text.trim(),
      paymentMode: _qrisPaymentMode,
    );

    final updatedBusiness = widget.pos.businessConfig.copyWith(
      businessName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      instagram: _instagramController.text.trim(),
      taxPercent: double.tryParse(_taxPercentController.text.trim()) ?? 10.0,
      serviceChargePercent: double.tryParse(_serviceChargePercentController.text.trim()) ?? 5.0,
      isTaxEnabled: _isTaxEnabled,
      isServiceEnabled: _isServiceEnabled,
      receiptFooter: _receiptFooterController.text.trim(),
      orderNumberPrefix: _orderPrefixController.text.trim(),
      defaultLowStockThreshold: int.tryParse(_thresholdController.text.trim()) ?? 15,
      printerWidth: _printerWidth,
      printerMode: _printerMode,
      telegramConfig: updatedTelegram,
      qrisConfig: updatedQris,
    );

    await widget.pos.updateBusinessConfig(updatedBusiness);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Pengaturan & Integrasi berhasil disimpan!', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _testTelegramConnection() async {
    setState(() => _isTestingTelegram = true);
    final tempConfig = TelegramConfig(
      enabled: _isTelegramEnabled,
      botUsername: _telegramBotUsernameController.text.trim(),
      chatId: _telegramChatIdController.text.trim(),
      endpoint: _telegramEndpointController.text.trim(),
      integrationMode: _telegramIntegrationMode,
      botToken: _telegramBotTokenController.text.trim().isEmpty ? null : _telegramBotTokenController.text.trim(),
      relaySecret: _telegramRelaySecretController.text.trim().isEmpty
          ? null
          : _telegramRelaySecretController.text.trim(),
    );
    final tempService = TelegramBotService(
      config: tempConfig,
      isPublicDemo: widget.pos.businessConfig.isPublicDemo,
    );
    final res = await tempService.testConnection();
    if (!mounted) return;
    setState(() => _isTestingTelegram = false);

    _showResultDialog(
      title: 'Uji Koneksi Telegram',
      success: res.success,
      message: res.message,
    );
  }

  Future<void> _sendTestTelegramMessage() async {
    setState(() => _isTestingTelegram = true);
    final tempConfig = TelegramConfig(
      enabled: _isTelegramEnabled,
      botUsername: _telegramBotUsernameController.text.trim(),
      chatId: _telegramChatIdController.text.trim(),
      endpoint: _telegramEndpointController.text.trim(),
      integrationMode: _telegramIntegrationMode,
      botToken: _telegramBotTokenController.text.trim().isEmpty ? null : _telegramBotTokenController.text.trim(),
      relaySecret: _telegramRelaySecretController.text.trim().isEmpty
          ? null
          : _telegramRelaySecretController.text.trim(),
    );
    final tempService = TelegramBotService(
      config: tempConfig,
      isPublicDemo: widget.pos.businessConfig.isPublicDemo,
    );
    final testMsg = '📢 TEST MESSAGE — ${_nameController.text}\n'
        'Halo! Ini adalah pesan uji coba dari CAFFE POS Web.\n'
        'Waktu: ${DateTime.now()}\n'
        'Status: Integrasi Berfungsi Normal.';
    final res = await tempService.sendMessage(testMsg);
    if (!mounted) return;
    setState(() => _isTestingTelegram = false);

    _showResultDialog(
      title: 'Kirim Pesan Uji Coba Telegram',
      success: res.success,
      message: res.message,
    );
  }

  Widget _buildTelegramStatusBadge() {
    String text;
    Color bg;
    Color fg;
    IconData icon;

    if (!_isTelegramEnabled) {
      text = 'DISCONNECTED';
      bg = AppColors.dangerSoft;
      fg = AppColors.danger;
      icon = Icons.cancel_outlined;
    } else if (_telegramIntegrationMode == TelegramIntegrationMode.mockSimulation) {
      text = 'SIMULATION';
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
      icon = Icons.smart_toy_rounded;
    } else {
      final hasToken = _telegramIntegrationMode != TelegramIntegrationMode.directBotApi ||
          _telegramBotTokenController.text.trim().isNotEmpty;
      if (!hasToken || _telegramChatIdController.text.trim().isEmpty) {
        text = 'DISCONNECTED';
        bg = AppColors.dangerSoft;
        fg = AppColors.danger;
        icon = Icons.warning_amber_rounded;
      } else {
        text = 'CONNECTED';
        bg = AppColors.successSoft;
        fg = AppColors.success;
        icon = Icons.check_circle_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Future<void> _testPrinter() async {
    setState(() => _isTestingPrinter = true);
    final res = await widget.pos.testPrinter();
    if (!mounted) return;
    setState(() => _isTestingPrinter = false);

    _showResultDialog(
      title: 'Uji Cetak Printer (${_printerWidth.label})',
      success: res.success,
      message: '${res.message}\n\n[Raw Output]:\n${res.rawData ?? "OK"}',
    );
  }

  Future<void> _testQrisPayment() async {
    setState(() => _isTestingQris = true);
    final service = widget.pos.createPaymentServiceForMethod(PaymentMethod.qris);
    final res = await service.createPayment(
      orderNumber: 'TEST-QRIS-${DateTime.now().millisecondsSinceEpoch}',
      amount: 25000,
      method: PaymentMethod.qris,
    );
    if (!mounted) return;
    setState(() => _isTestingQris = false);

    _showResultDialog(
      title: 'Uji Pembayaran QRIS (${_qrisPaymentMode.label})',
      success: res.success,
      message: '${res.message}\nPayload: ${res.qrPayload ?? "-"}',
    );
  }

  // ==========================================
  // OWNER-ONLY DEMO RESET
  // ==========================================

  /// Opens the confirmation dialog, then runs the reset only on confirmation.
  ///
  /// Access is re-checked twice on purpose: once when the action is requested,
  /// and again inside [_runResetDemoData] immediately before the state is
  /// cleared. Rendering the button is never treated as authorisation, so a
  /// stale screen cannot perform a reset after the role or demo mode changed.
  Future<void> _openResetDemoDataDialog() async {
    if (!widget.pos.canResetDemoData) {
      _showResultDialog(
        title: 'Reset Data Demo',
        success: false,
        message: 'Aksi ini hanya tersedia untuk Owner pada mode demo publik. '
            'Tidak ada data yang diubah.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reset Data Demo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tindakan ini membersihkan data operasional SESI DEMO:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Seluruh transaksi dan omzet demo\n'
                '• Pesanan aktif dan keranjang kasir\n'
                '• Riwayat shift sesi ini\n'
                '• Riwayat penyesuaian stok\n'
                '• Riwayat struk sesi ini',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, color: AppColors.success, size: 15),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'TIDAK AKAN dihapus:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Stok produk dan bahan baku (dipertahankan persis)\n'
                      '• Menu, kategori, dan resep\n'
                      '• Akun Owner & Kasir\n'
                      '• Konfigurasi bisnis dan pengaturan aplikasi',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Gunakan hanya untuk sesi demonstrasi, bukan untuk data operasional nyata.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    // Cancelling changes nothing: the reset is only reached from `true`.
    if (confirmed != true || !mounted) return;
    await _runResetDemoData();
  }

  Future<void> _runResetDemoData() async {
    if (_isResettingDemoData) return;
    setState(() => _isResettingDemoData = true);

    late final bool ok;
    late final String message;
    try {
      // Final authorisation check at the moment of execution.
      if (!widget.pos.canResetDemoData) {
        throw StateError('Aksi reset tidak diizinkan.');
      }
      widget.pos.resetDemoData();
      ok = true;
      message = 'Data operasional demo berhasil dikosongkan. '
          'Omzet kini nol, stok produk dan bahan baku tetap dipertahankan, '
          'dan satu shift demo terbuka untuk penjualan berikutnya.';
    } catch (_) {
      ok = false;
      // The underlying error is deliberately not surfaced: it could carry
      // configuration detail. The reset validates before it mutates, so a
      // failure here means nothing was cleared.
      message = 'Reset data demo gagal dan dibatalkan. Tidak ada data yang diubah.';
    }

    if (!mounted) return;
    setState(() => _isResettingDemoData = false);
    _showResultDialog(title: 'Reset Data Demo', success: ok, message: message);
  }

  Widget _buildDemoResetCard() {
    return _buildSectionCard(
      title: 'Reset Data Demo',
      icon: Icons.restart_alt_rounded,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_outlined, color: AppColors.info, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Khusus mode demo publik. Mengosongkan transaksi, omzet, keranjang, riwayat shift, penyesuaian stok, dan struk sesi. Stok, menu, resep, akun, dan konfigurasi bisnis tetap utuh.',
                  style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _isResettingDemoData ? null : _openResetDemoDataDialog,
            icon: _isResettingDemoData
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.restart_alt_rounded, size: 16),
            label: Text(
              _isResettingDemoData ? 'Mengosongkan Data...' : 'Reset Data Demo',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
      ],
    );
  }

  void _showResultDialog({required String title, required bool success, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppColors.success : AppColors.danger,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          ],
        ),
        content: SelectableText(
          message,
          style: const TextStyle(fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Pengaturan'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _saveAllSettings,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Simpan Perubahan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Profil & Bisnis'),
            Tab(icon: Icon(Icons.hub_rounded, size: 18), text: 'Integrasi (Telegram, Printer, QRIS)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Demo Mode Disclosure Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              border: Border(
                bottom: BorderSide(color: AppColors.info.withValues(alpha: 0.3), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.info,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DEMO ONLY · Data dapat tersimpan di browser. Jangan masukkan token rahasia atau kredensial produksi.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBusinessProfileTab(),
                _buildIntegrationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: BUSINESS PROFILE & FINANCIALS
  // ==========================================
  Widget _buildBusinessProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionCard(
                title: 'Informasi Kafe & Brand',
                icon: Icons.storefront_rounded,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Bisnis / Brand',
                      hintText: 'CAFFE',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Lengkap',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Telepon',
                            prefixIcon: Icon(Icons.phone_outlined, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _instagramController,
                          decoration: const InputDecoration(
                            labelText: 'Instagram',
                            prefixIcon: Icon(Icons.camera_alt_outlined, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Pengaturan Pajak, Biaya Layanan & Struk',
                icon: Icons.receipt_long_rounded,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktifkan Pajak Restoran (PB1)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Otomatis ditambahkan pada pesanan kasir'),
                    value: _isTaxEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isTaxEnabled = v),
                  ),
                  if (_isTaxEnabled) ...[
                    TextField(
                      controller: _taxPercentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Persentase Pajak (%)',
                        suffixText: '%',
                        prefixIcon: Icon(Icons.percent_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktifkan Biaya Layanan (Service Charge)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Biaya pelayanan dine-in kafe'),
                    value: _isServiceEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isServiceEnabled = v),
                  ),
                  if (_isServiceEnabled) ...[
                    TextField(
                      controller: _serviceChargePercentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Persentase Service Charge (%)',
                        suffixText: '%',
                        prefixIcon: Icon(Icons.room_service_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _receiptFooterController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Pesan Footer Struk Pembayaran',
                      prefixIcon: Icon(Icons.format_quote_rounded, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Pengaturan Sistem & Inventaris',
                icon: Icons.tune_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _orderPrefixController,
                          decoration: const InputDecoration(
                            labelText: 'Prefix Nomor Order',
                            hintText: 'ORD',
                            prefixIcon: Icon(Icons.tag_rounded, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _thresholdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Batas Stok Rendah Default',
                            suffixText: 'unit',
                            prefixIcon: Icon(Icons.warning_amber_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Owner-only, public-demo-only control. Hidden outright rather than
              // shown disabled, so the action is unreachable in any other mode.
              if (widget.pos.canResetDemoData) ...[
                const SizedBox(height: 16),
                _buildDemoResetCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: INTEGRATIONS (Telegram, Printer, QRIS)
  // ==========================================
  Widget _buildIntegrationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TELEGRAM INTEGRATION CARD
              _buildSectionCard(
                title: 'Integrasi Telegram',
                icon: Icons.send_rounded,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTelegramStatusBadge(),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isTelegramEnabled,
                      activeTrackColor: const Color(0xFF0088CC),
                      onChanged: (v) => setState(() => _isTelegramEnabled = v),
                    ),
                  ],
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.security_rounded, color: AppColors.info, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Keamanan: Bot Token tidak di-hardcode di browser. Untuk mode produksi, sistem siap diteruskan via Secure Relay Webhook (Cloudflare Worker).',
                            style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _telegramBotUsernameController,
                          decoration: const InputDecoration(
                            labelText: 'Bot Username',
                            hintText: '@CaffePosBot',
                            prefixIcon: Icon(Icons.smart_toy_outlined, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _telegramChatIdController,
                          decoration: const InputDecoration(
                            labelText: 'Target Chat ID / Group ID',
                            hintText: '-1002938472910',
                            prefixIcon: Icon(Icons.forum_outlined, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TelegramIntegrationMode>(
                    initialValue: _telegramIntegrationMode,
                    decoration: const InputDecoration(
                      labelText: 'Mode Integrasi Telegram',
                      prefixIcon: Icon(Icons.alt_route_rounded, size: 18),
                    ),
                    items: TelegramIntegrationMode.values
                        .where((mode) => !widget.pos.businessConfig.isPublicDemo || mode != TelegramIntegrationMode.directBotApi)
                        .map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode.label));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _telegramIntegrationMode = v);
                    },
                  ),
                  if (_telegramIntegrationMode == TelegramIntegrationMode.directBotApi) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telegramBotTokenController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Bot Token (Hanya Uji Coba Sandbox)',
                        hintText: '123456789:ABCdefGHIjklMNOpqrsTUVwxyz',
                        prefixIcon: Icon(Icons.key_rounded, size: 18),
                      ),
                    ),
                  ],
                  if (_telegramIntegrationMode == TelegramIntegrationMode.relayWebhook) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telegramEndpointController,
                      decoration: const InputDecoration(
                        labelText: 'Endpoint Relay Webhook URL',
                        hintText: 'https://telegram-relay.yourdomain.com',
                        prefixIcon: Icon(Icons.link_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telegramRelaySecretController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Relay Secret (sama dengan TELEGRAM_RELAY_SECRET di Worker)',
                        helperText: 'Disimpan di browser agar tidak perlu mengetik ulang. '
                            'Bot token TIDAK pernah disimpan di sini.',
                        helperMaxLines: 3,
                        prefixIcon: Icon(Icons.vpn_key_rounded, size: 18),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isTestingTelegram ? null : _testTelegramConnection,
                        icon: _isTestingTelegram
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering_rounded, size: 16),
                        label: const Text('Uji Koneksi Telegram', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isTestingTelegram ? null : _sendTestTelegramMessage,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Kirim Pesan Uji Coba', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0088CC),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. PRINTER THERMAL 80MM CARD
              _buildSectionCard(
                title: 'Integrasi Thermal Printer 80mm',
                icon: Icons.print_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<PrinterWidthType>(
                          initialValue: _printerWidth,
                          decoration: const InputDecoration(
                            labelText: 'Lebar Kertas Printer',
                            prefixIcon: Icon(Icons.format_size_rounded, size: 18),
                          ),
                          items: PrinterWidthType.values.map((w) {
                            return DropdownMenuItem(value: w, child: Text(w.label));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _printerWidth = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<PrinterModeType>(
                          initialValue: _printerMode,
                          decoration: const InputDecoration(
                            labelText: 'Mode Printer Adapter',
                            prefixIcon: Icon(Icons.settings_input_composite_rounded, size: 18),
                          ),
                          items: PrinterModeType.values.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m.label));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _printerMode = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _printerMode == PrinterModeType.preview
                          ? 'Mode Pratinjau Virtual: Memformat struk 80mm ke monospace text & preview widget tanpa memerlukan hardware fisik.'
                          : (_printerMode == PrinterModeType.browserPrint
                              ? 'Mode Browser Print: Mengirimkan struk ke dialog cetak sistem operasi browser.'
                              : 'Mode ESC/POS Hardware: Driver adapter binary ESC/POS siap dihubungkan ke printer Bluetooth/USB/Network.'),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isTestingPrinter ? null : _testPrinter,
                      icon: _isTestingPrinter
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.receipt_rounded, size: 16),
                      label: Text('Test Print (${_printerWidth.label})', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. QRIS INTEGRATION CARD
              _buildSectionCard(
                title: 'Integrasi Pembayaran QRIS',
                icon: Icons.qr_code_2_rounded,
                trailing: Switch(
                  value: _isQrisEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isQrisEnabled = v),
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qrisMerchantNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Merchant QRIS',
                            hintText: 'CAFFE OFFICIAL',
                            prefixIcon: Icon(Icons.store_rounded, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _qrisMerchantIdController,
                          decoration: const InputDecoration(
                            labelText: 'NMID Merchant QRIS',
                            hintText: 'NMID: ID1020039281729',
                            prefixIcon: Icon(Icons.pin_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<QrisPaymentMode>(
                    initialValue: _qrisPaymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Mode Alur QRIS POS',
                      prefixIcon: Icon(Icons.payment_rounded, size: 18),
                    ),
                    items: QrisPaymentMode.values.map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode.label));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _qrisPaymentMode = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _qrisPaymentMode == QrisPaymentMode.simulation
                          ? 'Mode Simulasi: Alur interaktif pelanggan scan -> deteksi -> sukses otomatis untuk demo kasir.'
                          : (_qrisPaymentMode == QrisPaymentMode.staticQris
                              ? 'Mode Static QRIS: Menampilkan QR & NMID merchant statis dengan konfirmasi verifikasi kasir.'
                              : 'Mode Real Gateway: Arsitektur STUB siap integrasi backend webhook (Midtrans/Xendit/Bank).'),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isTestingQris ? null : _testQrisPayment,
                      icon: _isTestingQris
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_circle_outline_rounded, size: 16),
                      label: const Text('Test Pembayaran QRIS', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
