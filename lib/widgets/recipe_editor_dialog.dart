import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/raw_material.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

class RecipeEditorDialog extends StatefulWidget {
  final Product product;
  final ProductRecipe? initialRecipe;
  final List<RawMaterial> availableMaterials;
  final Function(ProductRecipe) onSave;

  const RecipeEditorDialog({
    super.key,
    required this.product,
    this.initialRecipe,
    required this.availableMaterials,
    required this.onSave,
  });

  @override
  State<RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends State<RecipeEditorDialog> {
  late List<RecipeItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.initialRecipe != null
        ? widget.initialRecipe!.items.map((i) => i.copyWith()).toList()
        : [];
  }

  void _openAddOrEditIngredientDialog({RecipeItem? existingItem, int? index}) {
    RawMaterial? selectedMaterial;
    if (existingItem != null) {
      selectedMaterial = widget.availableMaterials.firstWhere(
        (m) => m.id == existingItem.materialId,
        orElse: () => widget.availableMaterials.first,
      );
    } else {
      // Find first material not already in recipe, or default to first
      final existingIds = _items.map((i) => i.materialId).toSet();
      selectedMaterial = widget.availableMaterials.firstWhere(
        (m) => !existingIds.contains(m.id),
        orElse: () => widget.availableMaterials.first,
      );
    }

    final qtyController = TextEditingController(
      text: existingItem != null
          ? (existingItem.quantity.truncateToDouble() == existingItem.quantity
              ? existingItem.quantity.toInt().toString()
              : existingItem.quantity.toString())
          : '10',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                existingItem != null ? 'Edit Jumlah Takaran' : 'Tambah Bahan ke Resep',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pilih Bahan Baku:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMaterial?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: widget.availableMaterials.map((mat) {
                      return DropdownMenuItem(
                        value: mat.id,
                        child: Text('${mat.name} (${mat.unit.label})', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedMaterial = widget.availableMaterials.firstWhere((m) => m.id == val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Satuan Terkunci: ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          selectedMaterial?.unit.label ?? 'gram',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Jumlah Takaran per 1 Porsi:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Contoh: 18',
                      suffixText: selectedMaterial?.unit.label ?? '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = num.tryParse(qtyController.text.trim());
                    if (qty == null || qty <= 0 || selectedMaterial == null) {
                      return;
                    }

                    setState(() {
                      if (index != null && index >= 0) {
                        _items[index] = RecipeItem(
                          materialId: selectedMaterial!.id,
                          materialName: selectedMaterial!.name,
                          quantity: qty.toDouble(),
                          unit: selectedMaterial!.unit,
                        );
                      } else {
                        // Check if already in recipe
                        final existingIdx = _items.indexWhere((i) => i.materialId == selectedMaterial!.id);
                        if (existingIdx >= 0) {
                          _items[existingIdx] = _items[existingIdx].copyWith(quantity: qty.toDouble());
                        } else {
                          _items.add(
                            RecipeItem(
                              materialId: selectedMaterial!.id,
                              materialName: selectedMaterial!.name,
                              quantity: qty.toDouble(),
                              unit: selectedMaterial!.unit,
                            ),
                          );
                        }
                      }
                    });

                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _save() {
    final recipe = ProductRecipe(
      productId: widget.product.id,
      items: _items,
    );
    widget.onSave(recipe);
    Navigator.of(context).pop();
  }

  String _formatQty(num val) {
    return val.truncateToDouble() == val ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.product.imageUrl.isNotEmpty
                        ? Image.network(
                            widget.product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
                          )
                        : const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resep: ${widget.product.name}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Komposisi bahan baku per 1 porsi saji • ${widget.product.category.label}',
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

              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),

              // Sub-bar with Add Button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daftar Bahan (${_items.length} bahan)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openAddOrEditIngredientDialog(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Tambah Bahan', maxLines: 1),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Ingredient List
              Expanded(
                child: _items.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.kitchen_outlined, size: 40, color: AppColors.textMuted),
                              SizedBox(height: 10),
                              Text(
                                'Belum ada bahan yang diatur untuk produk ini.',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Klik "+ Tambah Bahan" untuk menambahkan takaran bahan baku.',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _items.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: LayoutBuilder(
                                builder: (context, c) {
                                  final indexBadge = Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                                      ),
                                    ),
                                  );
                                  final nameBlock = Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.materialName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      Text(
                                        'Kebutuhan per porsi: ${_formatQty(item.quantity)} ${item.unit.label}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  );
                                  final qtyPill = Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      '${_formatQty(item.quantity)} ${item.unit.label}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                                    ),
                                  );
                                  final editBtn = IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                    tooltip: 'Edit Takaran',
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _openAddOrEditIngredientDialog(existingItem: item, index: index),
                                  );
                                  final deleteBtn = IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                    tooltip: 'Hapus Bahan',
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      setState(() {
                                        _items.removeAt(index);
                                      });
                                    },
                                  );

                                  // Narrow: two lines so the name, quantity and
                                  // both actions all stay reachable.
                                  if (c.maxWidth < 360) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            indexBadge,
                                            const SizedBox(width: 12),
                                            Expanded(child: nameBlock),
                                            const SizedBox(width: 8),
                                            qtyPill,
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [editBtn, deleteBtn],
                                        ),
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      indexBadge,
                                      const SizedBox(width: 12),
                                      Expanded(child: nameBlock),
                                      const SizedBox(width: 8),
                                      qtyPill,
                                      const SizedBox(width: 4),
                                      editBtn,
                                      deleteBtn,
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 18),

              // Bottom Actions
              // Bottom Actions - Wrap so the buttons reflow when narrow.
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
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Simpan Resep', maxLines: 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
