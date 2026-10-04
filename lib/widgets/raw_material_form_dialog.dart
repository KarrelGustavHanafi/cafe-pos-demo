import 'package:flutter/material.dart';
import '../models/raw_material.dart';
import '../theme/app_theme.dart';

class RawMaterialFormDialog extends StatefulWidget {
  final RawMaterial? material;
  final Function(RawMaterial) onSave;

  const RawMaterialFormDialog({
    super.key,
    this.material,
    required this.onSave,
  });

  @override
  State<RawMaterialFormDialog> createState() => _RawMaterialFormDialogState();
}

class _RawMaterialFormDialogState extends State<RawMaterialFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;

  late RawMaterialCategory _selectedCategory;
  late RawMaterialUnit _selectedUnit;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    _nameController = TextEditingController(text: m?.name ?? '');
    _stockController = TextEditingController(
      text: m != null
          ? (m.stock.truncateToDouble() == m.stock ? m.stock.toInt().toString() : m.stock.toString())
          : '',
    );
    _minStockController = TextEditingController(
      text: m != null
          ? (m.minimumStock.truncateToDouble() == m.minimumStock
              ? m.minimumStock.toInt().toString()
              : m.minimumStock.toString())
          : '',
    );
    _selectedCategory = m?.category ?? RawMaterialCategory.coffee;
    _selectedUnit = m?.unit ?? RawMaterialUnit.gram;
    _isActive = m?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final stock = num.tryParse(_stockController.text.trim()) ?? 0;
    final minStock = num.tryParse(_minStockController.text.trim()) ?? 0;

    final updated = RawMaterial(
      id: widget.material?.id ?? 'MAT-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: _selectedCategory,
      unit: _selectedUnit,
      stock: stock.toDouble(),
      minimumStock: minStock.toDouble(),
      isActive: _isActive,
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.material != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.egg_alt_outlined, color: AppColors.primaryDark, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Bahan Baku' : 'Tambah Bahan Baku Baru',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            Text(
                              isEditing
                                  ? 'Perbarui detail informasi bahan baku cafe'
                                  : 'Daftarkan bahan baku baru ke dalam inventaris',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 20),

                  // Material Name
                  const Text('Nama Bahan Baku *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Vanilla Syrup, Biji Kopi Robusta',
                      prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama bahan baku wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category & Unit Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kategori *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<RawMaterialCategory>(
                              initialValue: _selectedCategory,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.category_outlined, size: 18),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: RawMaterialCategory.values.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat.label, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Unit
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Satuan Unit *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<RawMaterialUnit>(
                              initialValue: _selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.straighten_rounded, size: 18),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: RawMaterialUnit.values.map((u) {
                                return DropdownMenuItem(
                                  value: u,
                                  child: Text(u.label, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedUnit = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stock & Min Stock Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Stock
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stok Saat Ini *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _stockController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '0',
                                suffixText: _selectedUnit.label,
                                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Stok wajib diisi';
                                }
                                if (num.tryParse(value.trim()) == null) {
                                  return 'Harus angka';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Min Stock Threshold
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Batas Minimum *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _minStockController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '0',
                                suffixText: _selectedUnit.label,
                                prefixIcon: const Icon(Icons.warning_amber_rounded, size: 18),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Batas wajib diisi';
                                }
                                if (num.tryParse(value.trim()) == null) {
                                  return 'Harus angka';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Active Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Status Aktif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              Text(
                                _isActive ? 'Bahan baku dapat dipakai dalam resep' : 'Bahan baku dinonaktifkan sementara',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isActive,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions - Wrap so the buttons reflow instead of
                  // overflowing when the dialog is narrow.
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal', maxLines: 1),
                      ),
                      ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(isEditing ? 'Simpan Perubahan' : 'Tambah Bahan', maxLines: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
