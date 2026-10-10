import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../models/stock_adjustment.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/raw_material_form_dialog.dart';
import '../../widgets/raw_material_stock_dialog.dart';
import '../../widgets/recipe_editor_dialog.dart';
import '../../widgets/shadcn_components.dart';
import '../../widgets/stock_update_dialog.dart';

class OwnerInventoryScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerInventoryScreen({super.key, required this.pos});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: Menu Stock state
  String _menuSearchQuery = '';
  ProductCategory _menuCategoryFilter = ProductCategory.all;
  StockStatus? _menuStatusFilter;
  final _menuSearchController = TextEditingController();

  // Tab 2: Raw Material state
  String _matSearchQuery = '';
  RawMaterialCategory? _matCategoryFilter;
  StockStatus? _matStatusFilter;
  final _matSearchController = TextEditingController();

  // Tab 3: Recipes state
  String _recipeSearchQuery = '';
  final _recipeSearchController = TextEditingController();

  // Tab 4: History state
  String _historyFilter = 'all'; // 'all', 'materials', 'products'
  bool _isSendingTelegramAlert = false;

  void _sendTelegramStockAlert() async {
    setState(() => _isSendingTelegramAlert = true);
    final res = await widget.pos.sendTelegramLowStockAlert();
    if (!mounted) return;
    setState(() => _isSendingTelegramAlert = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              res.success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(res.message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: res.success ? AppColors.primaryDark : AppColors.danger,
        duration: const Duration(seconds: 4),
        action: res.success
            ? null
            : SnackBarAction(
                label: 'Coba Lagi',
                textColor: Colors.white,
                onPressed: _sendTelegramStockAlert,
              ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _menuSearchController.dispose();
    _matSearchController.dispose();
    _recipeSearchController.dispose();
    super.dispose();
  }

  String _formatNum(num val) {
    return val.truncateToDouble() == val ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  // Finished Product Stock Adjustment
  void _openProductStockAdjustmentDialog(Product product) {
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
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stok ${product.name} berhasil diperbarui: '
                      '${type == AdjustmentType.add ? "+$quantity" : (type == AdjustmentType.remove ? "-$quantity" : "=$quantity")} unit',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primaryDark,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  // Raw Material Stock Adjustment
  void _openRawMaterialStockDialog(RawMaterial material) {
    showDialog(
      context: context,
      builder: (context) => RawMaterialStockDialog(
        material: material,
        onConfirm: (type, quantity, reason) {
          widget.pos.adjustRawMaterialStock(
            materialId: material.id,
            type: type,
            quantity: quantity,
            reason: reason,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stok ${material.name} berhasil diperbarui: '
                      '${type == AdjustmentType.add ? "+$quantity" : (type == AdjustmentType.remove ? "-$quantity" : "=$quantity")} ${material.unit.label}',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primaryDark,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  // Raw Material Form (Add / Edit)
  void _openRawMaterialForm({RawMaterial? material}) {
    showDialog(
      context: context,
      builder: (context) => RawMaterialFormDialog(
        material: material,
        onSave: (saved) {
          if (material != null) {
            widget.pos.updateRawMaterial(saved);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bahan baku "${saved.name}" berhasil diperbarui.'),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          } else {
            widget.pos.addRawMaterial(saved);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bahan baku "${saved.name}" berhasil didaftarkan.'),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          }
        },
      ),
    );
  }

  // Recipe Editor Dialog
  void _openRecipeEditor(Product product) {
    final existingRecipe = widget.pos.getRecipeForProduct(product.id);
    showDialog(
      context: context,
      builder: (context) => RecipeEditorDialog(
        product: product,
        initialRecipe: existingRecipe,
        availableMaterials: widget.pos.activeRawMaterials,
        onSave: (recipe) {
          widget.pos.saveRecipe(recipe);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resep untuk "${product.name}" berhasil disimpan.'),
              backgroundColor: AppColors.primaryDark,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Inventaris'),
        ),
        actions: [
          if (isMobile)
            IconButton(
              onPressed: _isSendingTelegramAlert ? null : _sendTelegramStockAlert,
              tooltip: _isSendingTelegramAlert ? 'Mengirim...' : 'Kirim Alert Stok ke Telegram',
              icon: _isSendingTelegramAlert
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0088CC)),
                    )
                  : const Icon(Icons.notifications_active_rounded, color: Color(0xFF0088CC)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _isSendingTelegramAlert ? null : _sendTelegramStockAlert,
                icon: _isSendingTelegramAlert
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.notifications_active_rounded, size: 14),
                label: Text(
                  _isSendingTelegramAlert ? 'Mengirim...' : 'Kirim Alert ke Telegram',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMobile)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Pantau stok menu dan bahan baku cafe.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    text: isMobile ? 'Menu (${widget.pos.products.length})' : 'Stok Menu (${widget.pos.products.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.egg_alt_outlined, size: 18),
                    text: isMobile ? 'Bahan (${widget.pos.rawMaterials.length})' : 'Bahan Baku (${widget.pos.rawMaterials.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    text: isMobile ? 'Resep (${widget.pos.recipes.length})' : 'Resep Menu (${widget.pos.recipes.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.history_rounded, size: 18),
                    text: isMobile ? 'Riwayat (${widget.pos.stockAdjustments.length})' : 'Riwayat Stok (${widget.pos.stockAdjustments.length})',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMenuStockTab(),
          _buildRawMaterialsTab(),
          _buildRecipesTab(),
          _buildStockHistoryTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: MENU STOCK (Finished Products)
  // ==========================================
  Widget _buildMenuStockTab() {
    final filteredProducts = widget.pos.products.where((p) {
      final matchesCategory =
          _menuCategoryFilter == ProductCategory.all || p.category == _menuCategoryFilter;
      final matchesStatus = _menuStatusFilter == null || p.stockStatus == _menuStatusFilter;
      final matchesSearch = p.name.toLowerCase().contains(_menuSearchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_menuSearchQuery.toLowerCase());
      return matchesCategory && matchesStatus && matchesSearch;
    }).toList();

    final lowStockCount = widget.pos.lowStockProducts.length;
    final outOfStockCount = widget.pos.outOfStockProducts.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 500) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Total Menu',
                        value: '${widget.pos.products.length}',
                        icon: Icons.all_inbox_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Stok Menipis',
                        value: '$lowStockCount',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Stok Habis',
                        value: '$outOfStockCount',
                        icon: Icons.error_outline_rounded,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                );
              }
              // Compact 2+1 layout for narrow screens
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Total Menu',
                          value: '${widget.pos.products.length}',
                          icon: Icons.all_inbox_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Menipis',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMetricTile(
                    label: 'Stok Habis',
                    value: '$outOfStockCount',
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Search & Filter Panel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _menuSearchController,
                    onChanged: (v) => setState(() => _menuSearchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Cari menu...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Semua Status', style: TextStyle(fontSize: 11)),
                        selected: _menuStatusFilter == null,
                        onSelected: (_) => setState(() => _menuStatusFilter = null),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('IN STOCK', style: TextStyle(fontSize: 11)),
                        selected: _menuStatusFilter == StockStatus.inStock,
                        selectedColor: AppColors.successSoft,
                        onSelected: (_) => setState(() => _menuStatusFilter = StockStatus.inStock),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('LOW STOCK', style: TextStyle(fontSize: 11)),
                        selected: _menuStatusFilter == StockStatus.lowStock,
                        selectedColor: AppColors.warningSoft,
                        onSelected: (_) => setState(() => _menuStatusFilter = StockStatus.lowStock),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('OUT OF STOCK', style: TextStyle(fontSize: 11)),
                        selected: _menuStatusFilter == StockStatus.outOfStock,
                        selectedColor: AppColors.errorSoft,
                        onSelected: (_) => setState(() => _menuStatusFilter = StockStatus.outOfStock),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ProductCategory.values.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat.label, style: const TextStyle(fontSize: 11)),
                          selected: _menuCategoryFilter == cat,
                          onSelected: (_) => setState(() => _menuCategoryFilter = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Menu List Card
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daftar Stok Menu Siap Jual (${filteredProducts.length} item)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Kelola stok jadi & tautan resep',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (filteredProducts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Tidak Ada Menu Ditemukan',
                      description: 'Tidak ada produk menu yang sesuai dengan filter pencarian.',
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProducts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductRow(product);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product product) {
    StockStatusLevel statusLevel;
    switch (product.stockStatus) {
      case StockStatus.outOfStock:
        statusLevel = StockStatusLevel.outOfStock;
        break;
      case StockStatus.lowStock:
        statusLevel = StockStatusLevel.low;
        break;
      case StockStatus.inStock:
        statusLevel = StockStatusLevel.healthy;
        break;
    }

    final recipe = widget.pos.getRecipeForProduct(product.id);

    final photo = Container(
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
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.coffee_rounded, size: 20, color: AppColors.primary),
            )
          : const Icon(Icons.coffee_rounded, size: 20, color: AppColors.primary),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                product.name,
                maxLines: 1,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (recipe != null && recipe.items.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                fit: FlexFit.loose,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${recipe.items.length} bahan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${product.category.label} • SKU: ${product.sku.isNotEmpty ? product.sku : "-"} • Batas Min: ${product.lowStockThreshold} unit',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        ),
      ],
    );

    final statusBadge = StockStatusBadge(
      label: product.stockStatus.label,
      level: statusLevel,
    );

    final stockCounter = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${product.stock}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: product.isOutOfStock
                ? AppColors.error
                : (product.isLowStock ? AppColors.warning : AppColors.textPrimary),
          ),
        ),
        const Text('unit', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
      ],
    );

    final recipeButton = IconButton(
      onPressed: () => _openRecipeEditor(product),
      icon: const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primaryDark),
      tooltip: 'Atur Resep',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );

    final updateButton = ElevatedButton.icon(
      onPressed: () => _openProductStockAdjustmentDialog(product),
      icon: const Icon(Icons.tune_rounded, size: 13),
      label: const Text('UPDATE', maxLines: 1),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.primaryBorder),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The single-row layout needs ~410px of fixed chrome. Below that the
          // row is split into two lines instead of being squeezed.
          if (constraints.maxWidth >= 430) {
            return Row(
              children: [
                photo,
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 10),
                statusBadge,
                const SizedBox(width: 14),
                SizedBox(width: 65, child: stockCounter),
                const SizedBox(width: 10),
                recipeButton,
                updateButton,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  photo,
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  statusBadge,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  stockCounter,
                  const Spacer(),
                  recipeButton,
                  const SizedBox(width: 4),
                  updateButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 2: RAW MATERIALS (Bahan Baku)
  // ==========================================
  Widget _buildRawMaterialsTab() {
    final filteredMaterials = widget.pos.rawMaterials.where((m) {
      final matchesCat = _matCategoryFilter == null || m.category == _matCategoryFilter;
      final matchesStatus = _matStatusFilter == null || m.status == _matStatusFilter;
      final matchesSearch = m.name.toLowerCase().contains(_matSearchQuery.toLowerCase());
      return matchesCat && matchesStatus && matchesSearch;
    }).toList();

    final lowStockCount = widget.pos.lowStockRawMaterials.length;
    final outOfStockCount = widget.pos.outOfStockRawMaterials.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 500) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Total Bahan Baku',
                        value: '${widget.pos.rawMaterials.length}',
                        icon: Icons.kitchen_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Bahan Menipis',
                        value: '$lowStockCount',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Bahan Habis',
                        value: '$outOfStockCount',
                        icon: Icons.error_outline_rounded,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Total Bahan',
                          value: '${widget.pos.rawMaterials.length}',
                          icon: Icons.kitchen_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Menipis',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMetricTile(
                    label: 'Bahan Habis',
                    value: '$outOfStockCount',
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Search, Filter & Action Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _matSearchController,
                          onChanged: (v) => setState(() => _matSearchQuery = v),
                          decoration: const InputDecoration(
                            hintText: 'Cari bahan...',
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openRawMaterialForm(),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Tambah Bahan'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Semua Status', style: TextStyle(fontSize: 11)),
                        selected: _matStatusFilter == null,
                        onSelected: (_) => setState(() => _matStatusFilter = null),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('IN STOCK', style: TextStyle(fontSize: 11)),
                        selected: _matStatusFilter == StockStatus.inStock,
                        selectedColor: AppColors.successSoft,
                        onSelected: (_) => setState(() => _matStatusFilter = StockStatus.inStock),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('LOW STOCK', style: TextStyle(fontSize: 11)),
                        selected: _matStatusFilter == StockStatus.lowStock,
                        selectedColor: AppColors.warningSoft,
                        onSelected: (_) => setState(() => _matStatusFilter = StockStatus.lowStock),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('OUT OF STOCK', style: TextStyle(fontSize: 11)),
                        selected: _matStatusFilter == StockStatus.outOfStock,
                        selectedColor: AppColors.errorSoft,
                        onSelected: (_) => setState(() => _matStatusFilter = StockStatus.outOfStock),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Semua Kategori', style: TextStyle(fontSize: 11)),
                        selected: _matCategoryFilter == null,
                        onSelected: (_) => setState(() => _matCategoryFilter = null),
                      ),
                      ...RawMaterialCategory.values.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: FilterChip(
                            label: Text(cat.label, style: const TextStyle(fontSize: 11)),
                            selected: _matCategoryFilter == cat,
                            onSelected: (_) => setState(() => _matCategoryFilter = cat),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Raw Material Table / Cards
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventaris Bahan Baku & Komposisi (${filteredMaterials.length} bahan)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Stok otomatis terpotong saat transaksi kasir berhasil',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (filteredMaterials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Tidak Ada Bahan Baku',
                      description: 'Tidak ada data bahan baku yang cocok dengan filter pencarian.',
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredMaterials.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (context, index) {
                      final mat = filteredMaterials[index];
                      return _buildRawMaterialRow(mat);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawMaterialRow(RawMaterial material) {
    StockStatusLevel statusLevel;
    switch (material.status) {
      case StockStatus.outOfStock:
        statusLevel = StockStatusLevel.outOfStock;
        break;
      case StockStatus.lowStock:
        statusLevel = StockStatusLevel.low;
        break;
      case StockStatus.inStock:
        statusLevel = StockStatusLevel.healthy;
        break;
    }

    final unitLabel = material.unit.label;

    final iconBox = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.egg_alt_outlined, color: AppColors.primaryDark, size: 22),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                material.name,
                maxLines: 1,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!material.isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('Nonaktif', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${material.category.label} • Batas Minimum: ${_formatNum(material.minimumStock)} $unitLabel',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        ),
      ],
    );

    final statusBadge = StockStatusBadge(
      label: material.status.label,
      level: statusLevel,
    );

    final stockCounter = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatNum(material.stock),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: material.isOutOfStock
                ? AppColors.error
                : (material.isLowStock ? AppColors.warning : AppColors.textPrimary),
          ),
        ),
        Text(unitLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );

    final editButton = IconButton(
      onPressed: () => _openRawMaterialForm(material: material),
      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
      tooltip: 'Edit Data Bahan',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );

    final updateButton = ElevatedButton.icon(
      onPressed: () => _openRawMaterialStockDialog(material),
      icon: const Icon(Icons.tune_rounded, size: 13),
      label: const Text('UPDATE STOK', maxLines: 1),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.primaryBorder),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 450) {
            return Row(
              children: [
                iconBox,
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 10),
                statusBadge,
                const SizedBox(width: 14),
                SizedBox(width: 90, child: stockCounter),
                const SizedBox(width: 8),
                editButton,
                updateButton,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconBox,
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  statusBadge,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  stockCounter,
                  const Spacer(),
                  editButton,
                  const SizedBox(width: 4),
                  updateButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 3: RECIPES (Resep Menu)
  // ==========================================
  Widget _buildRecipesTab() {
    final products = widget.pos.products.where((p) {
      return p.name.toLowerCase().contains(_recipeSearchQuery.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pemetaan Bahan Baku ke Menu Produk (BOM / Recipe)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Setiap menu dapat memiliki satu atau lebih takaran bahan baku. Saat kasir menyelesaikan pembayaran pesanan, stok bahan baku akan otomatis terpotong proporsional.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          SizedBox(
            height: 42,
            child: TextField(
              controller: _recipeSearchController,
              onChanged: (v) => setState(() => _recipeSearchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Cari menu untuk melihat/mengatur resep...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Recipes Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              final recipe = widget.pos.getRecipeForProduct(product.id);
              final availability = widget.pos.checkRecipeAvailability(product.id);

              Color badgeBg = AppColors.successSoft;
              Color badgeFg = AppColors.success;
              if (availability.status == 'UNAVAILABLE') {
                badgeBg = AppColors.errorSoft;
                badgeFg = AppColors.error;
              } else if (availability.status == 'LOW INGREDIENT') {
                badgeBg = AppColors.warningSoft;
                badgeFg = AppColors.warning;
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row / Responsive Layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final photo = Container(
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
                                        const Icon(Icons.restaurant_menu_rounded, size: 20, color: AppColors.primary),
                                  )
                                : const Icon(Icons.restaurant_menu_rounded, size: 20, color: AppColors.primary),
                          );

                          final info = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              Text(
                                '${product.category.label} • Harga: ${AppCurrency.format(product.price)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          );

                          final badge = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              availability.status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeFg),
                            ),
                          );

                          final actionBtn = ElevatedButton.icon(
                            onPressed: () => _openRecipeEditor(product),
                            icon: const Icon(Icons.tune_rounded, size: 14),
                            label: Text(recipe != null && recipe.items.isNotEmpty ? 'Edit Resep' : 'Buat Resep'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          );

                          if (constraints.maxWidth >= 520) {
                            return Row(
                              children: [
                                photo,
                                const SizedBox(width: 12),
                                Expanded(child: info),
                                const SizedBox(width: 8),
                                badge,
                                const SizedBox(width: 8),
                                actionBtn,
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  photo,
                                  const SizedBox(width: 10),
                                  Expanded(child: info),
                                  const SizedBox(width: 6),
                                  badge,
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: actionBtn,
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 10),

                      // Recipe Items Chips
                      if (recipe == null || recipe.items.isEmpty)
                        const Text(
                          'Belum ada resep yang dipetakan untuk menu ini. Klik "Buat Resep" untuk memetakan bahan baku.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        )
                      else ...[
                        const Text(
                          'Komposisi Takaran per 1 Porsi Saji:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: recipe.items.map((ing) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, size: 6, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    ing.materialName,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_formatNum(ing.quantity)} ${ing.unit}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Issues if unavailable
                      if (availability.issues.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_rounded, size: 14, color: AppColors.error),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Kekurangan: ${availability.issues.join(", ")}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: STOCK HISTORY (Riwayat Stok)
  // ==========================================
  Widget _buildStockHistoryTab() {
    final allAdjustments = widget.pos.stockAdjustments;
    final filtered = allAdjustments.where((adj) {
      if (_historyFilter == 'materials') return adj.isRawMaterial;
      if (_historyFilter == 'products') return !adj.isRawMaterial;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Row — stacked vertically to prevent overflow on mobile
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log Audit Penyesuaian & Pengurangan Stok',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Semua', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'materials', label: Text('Bahan Baku', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'products', label: Text('Menu Jadi', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_historyFilter},
                  onSelectionChanged: (set) => setState(() => _historyFilter = set.first),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Card(
            clipBehavior: Clip.antiAlias,
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: AppEmptyState(
                      icon: Icons.history_rounded,
                      title: 'Belum Ada Riwayat Stok',
                      description: 'Belum ada log mutasi atau penyesuaian stok yang tercatat.',
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (context, index) {
                      final adj = filtered[index];
                      final isAdd = adj.type == AdjustmentType.add;
                      final isRemove = adj.type == AdjustmentType.remove;
                      final isSale = adj.type == AdjustmentType.sale;

                      Color iconBg = AppColors.primarySoft;
                      Color iconFg = AppColors.primaryDark;
                      IconData iconData = Icons.tune_rounded;
                      String typeBadge = 'SET STOCK';

                      if (isAdd) {
                        iconBg = AppColors.successSoft;
                        iconFg = AppColors.success;
                        iconData = Icons.add_rounded;
                        typeBadge = 'ADD STOCK';
                      } else if (isRemove) {
                        iconBg = AppColors.errorSoft;
                        iconFg = AppColors.error;
                        iconData = Icons.remove_rounded;
                        typeBadge = 'REMOVE';
                      } else if (isSale) {
                        iconBg = AppColors.warningSoft;
                        iconFg = AppColors.warning;
                        iconData = Icons.shopping_bag_outlined;
                        typeBadge = 'AUTO SALE';
                      }

                      final sign = isAdd ? '+' : (isRemove || isSale ? '-' : '=');

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final iconWidget = Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(iconData, color: iconFg, size: 20),
                            );

                            final titleAndReason = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        adj.productName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: adj.isRawMaterial ? AppColors.secondarySoft : AppColors.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        adj.isRawMaterial ? 'Bahan Baku' : 'Menu Jadi',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: adj.isRawMaterial ? AppColors.secondary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${adj.reason} • Oleh: ${adj.adjustedBy}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            );

                            final rightDetails = Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: iconBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$typeBadge $sign${_formatNum(adj.quantity)} ${adj.unit}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: iconFg),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_formatNum(adj.previousStock)} → ${_formatNum(adj.newStock)} ${adj.unit}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${adj.timestamp.day}/${adj.timestamp.month} ${adj.timestamp.hour.toString().padLeft(2, '0')}:${adj.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            );

                            if (constraints.maxWidth >= 500) {
                              return Row(
                                children: [
                                  iconWidget,
                                  const SizedBox(width: 12),
                                  Expanded(child: titleAndReason),
                                  const SizedBox(width: 10),
                                  rightDetails,
                                ],
                              );
                            }

                            // Mobile 2-tier layout
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    iconWidget,
                                    const SizedBox(width: 10),
                                    Expanded(child: titleAndReason),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: iconBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$typeBadge $sign${_formatNum(adj.quantity)} ${adj.unit}',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: iconFg),
                                      ),
                                    ),
                                    Text(
                                      '${_formatNum(adj.previousStock)} → ${_formatNum(adj.newStock)} ${adj.unit} • ${adj.timestamp.day}/${adj.timestamp.month} ${adj.timestamp.hour.toString().padLeft(2, '0')}:${adj.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
