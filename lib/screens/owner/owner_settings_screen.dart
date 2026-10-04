import 'package:flutter/material.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class OwnerSettingsScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerSettingsScreen({super.key, required this.pos});

  @override
  State<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends State<OwnerSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _instagramController;
  late TextEditingController _receiptFooterController;
  late TextEditingController _orderPrefixController;
  late TextEditingController _thresholdController;

  late bool _isTaxEnabled;
  late bool _isServiceEnabled;

  @override
  void initState() {
    super.initState();
    final s = widget.pos.settings;
    _nameController = TextEditingController(text: s.cafeName);
    _addressController = TextEditingController(text: s.address);
    _phoneController = TextEditingController(text: s.phone);
    _instagramController = TextEditingController(text: s.instagram);
    _receiptFooterController = TextEditingController(text: s.receiptFooter);
    _orderPrefixController = TextEditingController(text: s.orderNumberPrefix);
    _thresholdController = TextEditingController(text: '${s.defaultLowStockThreshold}');
    _isTaxEnabled = s.isTaxEnabled;
    _isServiceEnabled = s.isServiceEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _receiptFooterController.dispose();
    _orderPrefixController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final updated = widget.pos.settings.copyWith(
      cafeName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      instagram: _instagramController.text.trim(),
      receiptFooter: _receiptFooterController.text.trim(),
      orderNumberPrefix: _orderPrefixController.text.trim(),
      defaultLowStockThreshold: int.tryParse(_thresholdController.text.trim()) ?? 15,
      isTaxEnabled: _isTaxEnabled,
      isServiceEnabled: _isServiceEnabled,
    );

    widget.pos.updateSettings(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan kafe berhasil disimpan!'),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Kafe'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Simpan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Demo disclaimer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Data demo bersifat sementara dan akan kembali ke nilai awal saat refresh halaman.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.info, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Informasi Kafe',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kafe',
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
                              labelText: 'Nomor Telepon Kafe',
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
              ),
            ),

            const SizedBox(height: 16),

            // Section 2: Transaction & Tax Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pengaturan Transaksi & Struk',
                            maxLines: 2,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktifkan Pajak Restoran (PB1 10%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Otomatis ditambahkan pada rincian pembayaran kasir'),
                      value: _isTaxEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => setState(() => _isTaxEnabled = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktifkan Service Charge (5%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Biaya pelayanan dine-in kafe'),
                      value: _isServiceEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => setState(() => _isServiceEnabled = v),
                    ),

                    const SizedBox(height: 8),
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
              ),
            ),

            const SizedBox(height: 16),

            // Section 3: Business & Inventory Defaults
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pengaturan Sistem & Inventaris',
                            maxLines: 2,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 12),
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
                              labelText: 'Default Batas Stok Rendah',
                              suffixText: 'unit',
                              prefixIcon: Icon(Icons.warning_amber_rounded, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
