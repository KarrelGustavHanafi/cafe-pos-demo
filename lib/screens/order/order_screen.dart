import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_view.dart';
import '../../widgets/demo_guide_widget.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_customization_dialog.dart';
import '../../widgets/shadcn_components.dart';

class OrderScreen extends StatefulWidget {
  final PosProvider pos;
  final VoidCallback onCheckout;
  final VoidCallback onChangeTable;

  const OrderScreen({
    super.key,
    required this.pos,
    required this.onCheckout,
    required this.onChangeTable,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  ProductCategory _selectedCategory = ProductCategory.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleProductTap(Product product) {
    if (product.hasModifiers) {
      ProductCustomizationDialog.show(
        context,
        product: product,
        onConfirm: (selectedModifiers, quantity, notes) {
          widget.pos.addToCart(
            product,
            qty: quantity,
            notes: notes,
            modifiers: selectedModifiers,
          );
        },
      );
    } else {
      widget.pos.addToCart(product);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} ditambahkan ke pesanan'),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final isTablet = Breakpoints.isTablet(context);

    final filteredProducts = widget.pos.products.where((product) {
      final matchesCategory =
          _selectedCategory == ProductCategory.all || product.category == _selectedCategory;
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    if (isDesktop) {
      // 3-COLUMN DESKTOP WORKSPACE: Left Categories, Center Catalog, Right Cart
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column 1: Vertical Categories Navigation (~160px)
            _buildDesktopCategorySidebar(),

            // Column 2: Product Grid & Search (Flex)
            Expanded(
              child: Column(
                children: [
                  const DemoGuideWidget(isCashierMode: true),
                  Expanded(child: _buildCatalogMainArea(filteredProducts)),
                ],
              ),
            ),

            // Column 3: Persistent Right Cart Panel (360px)
            SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: CartView(
                  pos: widget.pos,
                  onCheckout: widget.onCheckout,
                  onChangeTable: widget.onChangeTable,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (isTablet) {
      // TABLET ADAPTIVE LAYOUT: Catalog with compact side cart or 2-column split
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  const DemoGuideWidget(isCashierMode: true),
                  Expanded(child: _buildCatalogMainArea(filteredProducts, showTopCategoryChips: true)),
                ],
              ),
            ),
            SizedBox(
              width: 320,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CartView(
                  pos: widget.pos,
                  onCheckout: widget.onCheckout,
                  onChangeTable: widget.onChangeTable,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // MOBILE LAYOUT: Full-width catalog with bottom cart bar
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const DemoGuideWidget(isCashierMode: true),
            Expanded(
              child: Stack(
                children: [
                  _buildCatalogMainArea(filteredProducts, showTopCategoryChips: true, bottomPadding: 80),
                  if (widget.pos.cart.isNotEmpty)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: _buildMobileFloatingCartBar(),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDesktopCategorySidebar() {
    return Container(
      width: 150,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              'KATEGORI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: ProductCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primarySoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryBorder : Colors.transparent,
                          width: isSelected ? 1.2 : 0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(cat),
                            size: 15,
                            color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogMainArea(
    List<Product> products, {
    bool showTopCategoryChips = false,
    double bottomPadding = 16,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Quick Preset Demo Row
          Semantics(
            header: true,
            headingLevel: 1,
            label: 'POS',
            child: LayoutBuilder(
              builder: (context, c) {
                final search = SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari menu...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                );
                final preset = ShadcnButton(
                  onPressed: () {
                    widget.pos.loadDemoQuickOrder();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Menu Demo Dimuat: 2x Kopi Susu Aren + 1x French Fries'),
                        duration: Duration(seconds: 2),
                        backgroundColor: AppColors.primaryDark,
                      ),
                    );
                  },
                  variant: ShadButtonVariant.outline,
                  icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.accentAmber),
                  text: 'Demo',
                  height: 42,
                );
              // Stack the preset button under the search field when the two
              // cannot share the available width.
              if (c.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [search, const SizedBox(height: 8), preset],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  preset,
                ],
              );
            },
          ),
        ),

          if (showTopCategoryChips) ...[
            const SizedBox(height: 12),
            ShadcnTabs<ProductCategory>(
              items: ProductCategory.values,
              selectedItem: _selectedCategory,
              onSelected: (cat) => setState(() => _selectedCategory = cat),
              labelBuilder: (cat) => cat.label,
              iconBuilder: (cat) => Icon(_getCategoryIcon(cat)),
            ),
          ],

          const SizedBox(height: 14),


          // Product Grid
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada menu yang sesuai',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      // Responsive columns driven by a minimum card width:
                      // 2 on phones, growing up to 6 on wide desktops.
                      const minCardWidth = 165.0;
                      final crossAxisCount =
                          (width / minCardWidth).floor().clamp(2, 6);

                      return GridView.builder(
                        itemCount: products.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: 215,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final cartQuantity = widget.pos.cart
                              .where((item) => item.product.id == product.id)
                              .fold<int>(0, (sum, item) => sum + item.quantity);

                          return ProductCard(
                            product: product,
                            cartQuantity: cartQuantity,
                            onAdd: () => _handleProductTap(product),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFloatingCartBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openMobileCartBottomSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.pos.cartItemCount} Menu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppCurrency.format(widget.pos.cartGrandTotal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  void _openMobileCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(14),
          child: CartView(
            pos: widget.pos,
            onCheckout: () {
              Navigator.pop(ctx);
              widget.onCheckout();
            },
            onChangeTable: () {
              Navigator.pop(ctx);
              widget.onChangeTable();
            },
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.all:
        return Icons.grid_view_rounded;
      case ProductCategory.coffee:
        return Icons.coffee_rounded;
      case ProductCategory.nonCoffee:
        return Icons.local_drink_rounded;
      case ProductCategory.food:
        return Icons.restaurant_rounded;
      case ProductCategory.snack:
        return Icons.fastfood_rounded;
      case ProductCategory.dessert:
        return Icons.icecream_rounded;
      case ProductCategory.pastry:
        return Icons.bakery_dining_rounded;
    }
  }
}
