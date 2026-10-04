import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onAdd;
  final int cartQuantity;
  final bool isOwnerMode;
  final VoidCallback? onEdit;
  final VoidCallback? onAdjustStock;
  final VoidCallback? onToggleActive;

  const ProductCard({
    super.key,
    required this.product,
    this.onAdd,
    this.cartQuantity = 0,
    this.isOwnerMode = false,
    this.onEdit,
    this.onAdjustStock,
    this.onToggleActive,
  });

  IconData _getIconForProduct(Product product) {
    switch (product.category) {
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
        return Icons.fastfood_rounded;
    }
  }

  Color _getCategoryColor(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.coffee:
        return AppColors.accentCaramel;
      case ProductCategory.nonCoffee:
        return AppColors.primary;
      case ProductCategory.food:
        return const Color(0xFFE11D48); // Rose
      case ProductCategory.snack:
        return const Color(0xFFEA580C); // Orange
      case ProductCategory.dessert:
        return const Color(0xFF9333EA); // Purple
      case ProductCategory.pastry:
        return const Color(0xFFD97706); // Amber
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildFoodImage(BuildContext context) {
    return Container(
      height: 96,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (product.imageUrl.isNotEmpty)
            Image.network(
              product.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackVisual(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            )
          else
            _buildFallbackVisual(),

          // Overlay gradient for subtle depth
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 28,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Stock Badge / Status Indicator
          Positioned(
            top: 7,
            right: 7,
            child: _buildStockBadge(),
          ),

          // Category Mini Pill on top-left
          Positioned(
            top: 7,
            left: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIconForProduct(product),
                    size: 11,
                    color: _getCategoryColor(product.category),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    product.category.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _getCategoryColor(product.category),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Out of stock overlay
          if (product.isOutOfStock)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'STOK HABIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            )
          else if (product.hasModifiers)
            Positioned(
              bottom: 6,
              left: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 9, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'Bisa Kustom',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackVisual() {
    final catColor = _getCategoryColor(product.category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            catColor.withValues(alpha: 0.15),
            catColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForProduct(product),
          color: catColor,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildStockBadge() {
    Color bg;
    Color fg;
    String label;

    if (product.isOutOfStock) {
      bg = AppColors.errorSoft;
      fg = AppColors.error;
      label = 'Habis';
    } else if (product.isLowStock) {
      bg = AppColors.warningSoft;
      fg = AppColors.warning;
      label = 'Sisa ${product.stock}';
    } else {
      bg = Colors.white.withValues(alpha: 0.92);
      fg = AppColors.textSecondary;
      label = '${product.stock} pcs';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInCart = cartQuantity > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isInCart ? AppColors.primary : AppColors.border,
          width: isInCart ? 1.8 : 1,
        ),
      ),
      elevation: isInCart ? 2 : 0,
      child: InkWell(
        onTap: isOwnerMode
            ? onEdit
            : (product.isOutOfStock ? null : onAdd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Realistic Food Photography Banner
            _buildFoodImage(context),

            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Title
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Product Description or SKU
                    if (isOwnerMode && product.sku.isNotEmpty)
                      Text(
                        'SKU: ${product.sku}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      Text(
                        product.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),

                    const Spacer(),

                    // Price & Actions Row
                    if (!isOwnerMode)
                      // CASHIER ACTION: Price + Quick Add to Cart
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppCurrency.format(product.price),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: SizedBox(
                              height: 28,
                              child: ElevatedButton(
                                onPressed: product.isOutOfStock ? null : onAdd,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isInCart
                                      ? AppColors.primaryDark
                                      : AppColors.primarySoft,
                                  foregroundColor: isInCart
                                      ? Colors.white
                                      : AppColors.primaryDark,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(0, 28),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
                                    side: BorderSide(
                                      color: isInCart
                                          ? AppColors.primaryDark
                                          : AppColors.primaryBorder,
                                    ),
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        product.hasModifiers
                                            ? Icons.tune_rounded
                                            : (isInCart
                                                ? Icons.check_rounded
                                                : Icons.add_rounded),
                                        size: 13,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        product.hasModifiers
                                            ? 'Varian'
                                            : (isInCart ? '$cartQuantity' : 'Tambah'),
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // OWNER ACTION: Price, HPP, Edit & Stock Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    AppCurrency.format(product.price),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (product.costPrice > 0)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'HPP: ${AppCurrency.format(product.costPrice)}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 2),
                          // Quick Stock Adjustment
                          IconButton(
                            onPressed: onAdjustStock,
                            icon: const Icon(Icons.add_box_outlined, size: 16),
                            color: AppColors.primary,
                            tooltip: 'Update Stok',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          ),
                          // Edit Product
                          IconButton(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            color: AppColors.textSecondary,
                            tooltip: 'Edit Produk',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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
