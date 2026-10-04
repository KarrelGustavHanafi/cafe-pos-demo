import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/stock_adjustment.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_form_dialog.dart';
import '../../widgets/stock_update_dialog.dart';

class OwnerProductsScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerProductsScreen({super.key, required this.pos});

  @override
  State<OwnerProductsScreen> createState() => _OwnerProductsScreenState();
}

class _OwnerProductsScreenState extends State<OwnerProductsScreen> {
  ProductCategory _category = ProductCategory.all;
  String _search = '';
  bool _isGridView = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProductForm([Product? productToEdit]) {
    showDialog(
      context: context,
      builder: (context) => ProductFormDialog(
        productToEdit: productToEdit,
        onDelete: productToEdit != null ? () => _confirmDeleteProduct(productToEdit) : null,
        onSave: (product) {
          if (productToEdit != null) {
            widget.pos.updateProduct(product);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Menu "${product.name}" berhasil diperbarui!'),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          } else {
            widget.pos.addProduct(product);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Menu baru "${product.name}" berhasil ditambahkan & tersedia di Kasir!'),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Menu'),
        content: Text('Apakah Anda yakin ingin menghapus "${product.name}" dari katalog menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              widget.pos.deleteProduct(product.id);
              Navigator.pop(ctx);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Menu "${product.name}" berhasil dihapus.'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _openStockAdjustment(Product product) {
    showDialog(
      context: context,
      builder: (context) => StockUpdateDialog(
        product: product,
        onConfirm: (type, quantity, reason) {
          widget.pos.adjustStock(
            productId: product.id,
            type: type,
            quantity: quantity,
            reason: reason,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Stok ${product.name} berhasil diperbarui: '
                '${type == AdjustmentType.add ? "+$quantity" : (type == AdjustmentType.remove ? "-$quantity" : "=$quantity")} unit',
              ),
              backgroundColor: AppColors.primaryDark,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.pos.products.where((p) {
      final matchesCategory = _category == ProductCategory.all || p.category == _category;
      final matchesSearch = p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.description.toLowerCase().contains(_search.toLowerCase()) ||
          p.sku.toLowerCase().contains(_search.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Katalog Menu & Manajemen Produk'),
        actions: [
          // View Mode Switcher
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Tampilan Tabel' : 'Tampilan Grid Foto',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _openProductForm(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah Produk'),
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
            // Search Bar & Filter Chips
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _search = val),
                              decoration: const InputDecoration(
                                hintText: 'Cari menu berdasarkan nama, deskripsi, atau SKU...',
                                prefixIcon: Icon(Icons.search_rounded, size: 18),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ProductCategory.values.map((cat) {
                          final isSelected = _category == cat;
                          final count = widget.pos.getProductCountForCategory(cat);

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('${cat.label} ($count)', style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: AppColors.primarySoft,
                              backgroundColor: AppColors.surface,
                              onSelected: (_) => setState(() => _category = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text('Tidak ada menu yang sesuai kriteria.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else if (_isGridView)
              // GRID VIEW: Realistic Food Photography Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = (width / 220).floor().clamp(2, 6);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: 225,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        isOwnerMode: true,
                        onEdit: () => _openProductForm(product),
                        onAdjustStock: () => _openStockAdjustment(product),
                      );
                    },
                  );
                },
              )
            else
              // TABLE VIEW: Dense Management List
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, index) => const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (context, index) {
                    final product = products[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.surfaceSubtle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(
                                    product.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.coffee_rounded, color: AppColors.primary),
                                  )
                                : const Icon(Icons.coffee_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text(
                                  '${product.category.label} • SKU: ${product.sku.isNotEmpty ? product.sku : "-"}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(AppCurrency.format(product.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              Text('Stok: ${product.stock} pcs', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            color: AppColors.primary,
                            tooltip: 'Update Stok',
                            onPressed: () => _openStockAdjustment(product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.textSecondary,
                            tooltip: 'Edit Produk',
                            onPressed: () => _openProductForm(product),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
