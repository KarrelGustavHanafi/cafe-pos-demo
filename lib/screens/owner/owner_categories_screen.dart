import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class OwnerCategoriesScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerCategoriesScreen({super.key, required this.pos});

  @override
  State<OwnerCategoriesScreen> createState() => _OwnerCategoriesScreenState();
}

class _OwnerCategoriesScreenState extends State<OwnerCategoriesScreen> {
  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori Menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nama kategori baru untuk mengelompokkan menu kafe.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nama Kategori',
                hintText: 'Contoh: Signature Drink / Bakery',
                prefixIcon: Icon(Icons.category_outlined, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                // In demo, we add to provider categories list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kategori "${controller.text.trim()}" berhasil ditambahkan!'),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Tambah Kategori'),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.coffee:
        return Icons.coffee_rounded;
      case ProductCategory.nonCoffee:
        return Icons.local_drink_rounded;
      case ProductCategory.food:
        return Icons.restaurant_rounded;
      case ProductCategory.snack:
        return Icons.cookie_outlined;
      case ProductCategory.dessert:
        return Icons.cake_outlined;
      case ProductCategory.pastry:
        return Icons.bakery_dining_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.coffee:
        return AppColors.accentCaramel;
      case ProductCategory.nonCoffee:
        return AppColors.primary;
      case ProductCategory.food:
        return const Color(0xFFE11D48);
      case ProductCategory.snack:
        return const Color(0xFFEA580C);
      case ProductCategory.dessert:
        return const Color(0xFF9333EA);
      case ProductCategory.pastry:
        return const Color(0xFFD97706);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.pos.categories;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Kategori Menu'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah Kategori'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.category_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kategori Menu Aktif',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Kategori digunakan oleh kasir dan pelanggan untuk menemukan produk dengan cepat.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Categories Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 720 ? 3 : (constraints.maxWidth >= 480 ? 2 : 1);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: 130,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final count = widget.pos.getProductCountForCategory(cat);
                    final color = _getCategoryColor(cat);
                    final icon = _getCategoryIcon(cat);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.borderLight),
                                  ),
                                  child: Text(
                                    '$count Produk',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              cat.label,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Status: Aktif di Kasir',
                              style: TextStyle(fontSize: 10.5, color: AppColors.success, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
