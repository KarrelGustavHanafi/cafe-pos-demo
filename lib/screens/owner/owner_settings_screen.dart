import 'package:flutter/material.dart';
import '../../models/business_config.dart';
import '../../models/order.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

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
    _telegramIntegrationMode = t.integrationMode;

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
    final res = await widget.pos.testTelegramConnection();
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
    final testMsg = '📢 TEST MESSAGE — ${_nameController.text}\n'
        'Halo! Ini adalah pesan uji coba dari CAFFE POS Web.\n'
        'Waktu: ${DateTime.now()}\n'
        'Status: Integrasi Berfungsi Normal.';
    final res = await widget.pos.telegramService.sendMessage(testMsg);
    if (!mounted) return;
    setState(() => _isTestingTelegram = false);

    _showResultDialog(
      title: 'Kirim Pesan Uji Coba Telegram',
      success: res.success,
      message: res.message,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBusinessProfileTab(),
          _buildIntegrationsTab(),
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
                trailing: Switch(
                  value: _isTelegramEnabled,
                  activeTrackColor: const Color(0xFF0088CC),
                  onChanged: (v) => setState(() => _isTelegramEnabled = v),
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
                    items: TelegramIntegrationMode.values.map((mode) {
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
                        hintText: 'https://relay.yourdomain.com/sendTelegram',
                        prefixIcon: Icon(Icons.link_rounded, size: 18),
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
