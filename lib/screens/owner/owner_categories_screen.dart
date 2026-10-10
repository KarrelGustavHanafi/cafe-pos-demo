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
  /// Product categories are a fixed enum (see `ProductCategory`), so a
  /// user-typed name cannot become a real category. Rather than pretend the
  /// addition worked, this explains the limitation instead of adding anything.
  void _showCategoryLimitationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Dinamis Tidak Tersedia',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text(
          'Kategori menu pada mode demo bersifat tetap dan sudah ditentukan di dalam aplikasi, sehingga kategori baru tidak dapat dibuat dari layar ini. '
          'Kategori yang tersedia saat ini tetap bisa digunakan mengelompokkan produk seperti biasa.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti')),
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
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Kategori Menu'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            // This is an informational action, not an add action: it opens an
            // explanation. The icon, label, styling and semantics all say so,
            // and it is fully enabled because it does exactly what it promises.
            child: Semantics(
              button: true,
              label:
                  'Informasi kategori. Menambah kategori baru tidak tersedia.',
              child: OutlinedButton.icon(
                onPressed: _showCategoryLimitationDialog,
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text('Info Kategori'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryBorder),
                ),
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
                          'Kategori digunakan oleh kasir untuk menemukan produk dengan cepat.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Fixed-Category Limitation Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.textSecondary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kategori bersifat tetap pada mode demo. Menambah kategori baru tidak tersedia, dan aplikasi tidak akan menampilkan pesan berhasil untuk tindakan yang tidak dijalankan.',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
