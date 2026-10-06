import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/recipe.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import 'shadcn_components.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? productToEdit;
  final VoidCallback? onDelete;
  final Function(Product product) onSave;
  final VoidCallback? onManageRecipe;
  final ProductRecipe? currentRecipe;

  const ProductFormDialog({
    super.key,
    this.productToEdit,
    this.onDelete,
    required this.onSave,
    this.onManageRecipe,
    this.currentRecipe,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  late TextEditingController _skuController;
  late TextEditingController _imageUrlController;
  late ProductCategory _category;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p != null ? '${p.price}' : '22000');
    _costPriceController = TextEditingController(text: p != null ? '${p.costPrice}' : '9500');
    _stockController = TextEditingController(text: p != null ? '${p.stock}' : '20');
    _thresholdController = TextEditingController(text: p != null ? '${p.lowStockThreshold}' : '15');
    _skuController = TextEditingController(text: p?.sku ?? 'NC-STM-08');
    _imageUrlController = TextEditingController(
      text: p?.imageUrl ??
          (MockData.presetPhotography['Strawberry Matcha'] ??
              'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=600&q=80'),
    );
    _category = p?.category ?? ProductCategory.nonCoffee;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _skuController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.productToEdit?.id ??
        'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final costPrice = int.tryParse(_costPriceController.text.trim()) ?? 0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final threshold = int.tryParse(_thresholdController.text.trim()) ?? 15;

    final product = Product(
      id: id,
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      price: price,
      costPrice: costPrice,
      category: _category,
      stock: stock,
      lowStockThreshold: threshold,
      imageUrl: _imageUrlController.text.trim(),
      sku: _skuController.text.trim(),
      isActive: _isActive,
      iconName: _category == ProductCategory.coffee
          ? 'coffee'
          : (_category == ProductCategory.food ? 'rice' : 'matcha'),
    );

    widget.onSave(product);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productToEdit != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 640;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Produk' : 'Tambah Produk',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isEdit
                              ? 'Ubah informasi harga, kategori, dan stok'
                              : 'Masukkan data produk baru',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isEdit && widget.onManageRecipe != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ShadcnButton(
                        variant: ShadButtonVariant.outline,
                        height: 32,
                        icon: const Icon(Icons.restaurant_menu_rounded, size: 14),
                        text: 'Resep',
                        onPressed: widget.onManageRecipe,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Image & Visual Presentation
                      const Text(
                        'Foto Produk',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Live Image Preview
                          Container(
                            width: 90,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _imageUrlController.text.isNotEmpty
                                ? Image.network(
                                    _imageUrlController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_outlined, color: AppColors.textMuted),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          // Image URL input & quick presets
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _imageUrlController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'URL Foto',
                                    hintText: 'https://images.unsplash.com/...',
                                    prefixIcon: Icon(Icons.link_rounded, size: 18),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Pilihan Foto Cepat:',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: MockData.presetPhotography.entries.map((entry) {
                                      final isSelected = _imageUrlController.text == entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text(entry.key, style: const TextStyle(fontSize: 10.5)),
                                          selected: isSelected,
                                          selectedColor: AppColors.primarySoft,
                                          onSelected: (_) {
                                            setState(() {
                                              _imageUrlController.text = entry.value;
                                              if (_nameController.text.isEmpty) {
                                                _nameController.text = entry.key;
                                              }
                                            });
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 12),

                      // Section 2: General Info
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nameController,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Nama produk wajib diisi' : null,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Produk *',
                                  hintText: 'Contoh: Strawberry Matcha',
                                  prefixIcon: Icon(Icons.fastfood_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<ProductCategory>(
                                initialValue: _category,
                                decoration: const InputDecoration(
                                  labelText: 'Kategori *',
                                  prefixIcon: Icon(Icons.category_outlined, size: 18),
                                ),
                                items: ProductCategory.values
                                    .where((c) => c != ProductCategory.all)
                                    .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c.label, style: const TextStyle(fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _category = val);
                                },
                              ),
                            ),
                          ],
                        )
                      else ...[
                        TextFormField(
                          controller: _nameController,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nama produk wajib diisi' : null,
                          decoration: const InputDecoration(
                            labelText: 'Nama Produk *',
                            hintText: 'Contoh: Strawberry Matcha',
                            prefixIcon: Icon(Icons.fastfood_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<ProductCategory>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Kategori *',
                            prefixIcon: Icon(Icons.category_outlined, size: 18),
                          ),
                          items: ProductCategory.values
                              .where((c) => c != ProductCategory.all)
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.label, style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _category = val);
                          },
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Description
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi',
                          hintText: 'Perpaduan puree stroberi segar dengan ceremonial matcha dan susu dingin',
                          prefixIcon: Icon(Icons.description_outlined, size: 18),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 12),

                      // Section 3: Pricing & Cost
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Harga jual wajib diisi' : null,
                                decoration: const InputDecoration(
                                  labelText: 'Harga Jual (Rp) *',
                                  prefixText: 'Rp ',
                                  prefixIcon: Icon(Icons.payments_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _costPriceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'HPP (Rp)',
                                  prefixText: 'Rp ',
                                  prefixIcon: Icon(Icons.receipt_long_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _skuController,
                                decoration: const InputDecoration(
                                  labelText: 'SKU',
                                  hintText: 'Contoh: NC-STM-08',
                                  prefixIcon: Icon(Icons.qr_code_2_rounded, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Harga jual wajib diisi' : null,
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual (Rp) *',
                            prefixText: 'Rp ',
                            prefixIcon: Icon(Icons.payments_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _costPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HPP (Rp)',
                            prefixText: 'Rp ',
                            prefixIcon: Icon(Icons.receipt_long_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(
                            labelText: 'SKU',
                            hintText: 'Contoh: NC-STM-08',
                            prefixIcon: Icon(Icons.qr_code_2_rounded, size: 18),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 12),

                      // Section 4: Stock & Threshold & Status
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Stok wajib diisi' : null,
                                decoration: const InputDecoration(
                                  labelText: 'Stok *',
                                  suffixText: 'unit',
                                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _thresholdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Batas Rendah',
                                  suffixText: 'unit',
                                  prefixIcon: Icon(Icons.warning_amber_rounded, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Status:',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: _isActive,
                                      activeTrackColor: AppColors.primary,
                                      onChanged: (val) => setState(() => _isActive = val),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Stok wajib diisi' : null,
                          decoration: const InputDecoration(
                            labelText: 'Stok *',
                            suffixText: 'unit',
                            prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _thresholdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Batas Rendah',
                            suffixText: 'unit',
                            prefixIcon: Icon(Icons.warning_amber_rounded, size: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _isActive ? 'Status: Aktif' : 'Status: Nonaktif',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: _isActive,
                                activeTrackColor: AppColors.primary,
                                onChanged: (val) => setState(() => _isActive = val),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Section 5: Resep & Komposisi Bahan Baku (Priority 1 UX Discovery)
                      if (isEdit && widget.onManageRecipe != null) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: AppColors.borderLight),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Resep & Komposisi Bahan Baku',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (widget.currentRecipe != null &&
                                widget.currentRecipe!.items.isNotEmpty)
                              ShadcnBadge(
                                label: '${widget.currentRecipe!.items.length} Bahan',
                                variant: ShadBadgeVariant.success,
                                showDot: true,
                              )
                            else
                              const ShadcnBadge(
                                label: 'Belum Ada Resep',
                                variant: ShadBadgeVariant.secondary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ShadcnCard(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: AppColors.surfaceSubtle,
                          borderColor: AppColors.border,
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primaryBorder),
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Hubungkan Takaran Bahan Baku',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.currentRecipe != null &&
                                              widget.currentRecipe!.items.isNotEmpty
                                          ? widget.currentRecipe!.items
                                              .map((i) =>
                                                  '${i.materialName} (${i.quantity.toStringAsFixed(i.quantity.truncateToDouble() == i.quantity ? 0 : 1)} ${i.unit})')
                                              .join(', ')
                                          : 'Atur resep agar bahan baku otomatis terpotong dari stok.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ShadcnButton(
                                variant: ShadButtonVariant.primary,
                                height: 34,
                                icon: const Icon(Icons.tune_rounded, size: 14),
                                text: 'Kelola',
                                onPressed: widget.onManageRecipe,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isEdit && widget.onDelete != null)
                    TextButton.icon(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                      label: const Text('Hapus', maxLines: 1, style: TextStyle(color: AppColors.error)),
                    ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal', maxLines: 1),
                  ),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: Text(isEdit ? 'Simpan' : 'Tambah', maxLines: 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
