import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/modifier.dart';
import '../theme/app_theme.dart';
import 'shadcn_components.dart';

class ProductCustomizationDialog extends StatefulWidget {
  final Product product;
  final CartItem? initialCartItem;
  final Function(List<ModifierOption> selectedModifiers, int quantity, String notes) onConfirm;

  const ProductCustomizationDialog({
    super.key,
    required this.product,
    this.initialCartItem,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required Product product,
    CartItem? initialCartItem,
    required Function(List<ModifierOption> selectedModifiers, int quantity, String notes) onConfirm,
  }) {
    final isMobile = Breakpoints.isMobile(context);

    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ProductCustomizationDialog(
            product: product,
            initialCartItem: initialCartItem,
            onConfirm: onConfirm,
          ),
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 660),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.roundedLg,
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ProductCustomizationDialog(
                  product: product,
                  initialCartItem: initialCartItem,
                  onConfirm: onConfirm,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  State<ProductCustomizationDialog> createState() => _ProductCustomizationDialogState();
}

class _ProductCustomizationDialogState extends State<ProductCustomizationDialog> {
  late final Map<String, Set<ModifierOption>> _selections = {};
  late final TextEditingController _notesController;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialCartItem?.quantity ?? 1;
    _notesController = TextEditingController(text: widget.initialCartItem?.notes ?? '');

    final activeGroups = widget.product.activeModifierGroups;

    if (widget.initialCartItem != null) {
      // Pre-fill selections from existing cart item
      for (final group in activeGroups) {
        final selectedInGroup = <ModifierOption>{};
        for (final opt in group.options) {
          if (widget.initialCartItem!.selectedModifiers.any((m) => m.id == opt.id)) {
            selectedInGroup.add(opt);
          }
        }
        _selections[group.id] = selectedInGroup;
      }
    } else {
      // Initialize defaults for new customization
      for (final group in activeGroups) {
        final selected = <ModifierOption>{};
        final defaultOpt = group.defaultOption;
        if (defaultOpt != null) {
          selected.add(defaultOpt);
        }
        _selections[group.id] = selected;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<ModifierOption> get _flattenedSelectedModifiers {
    final list = <ModifierOption>[];
    for (final group in widget.product.activeModifierGroups) {
      final opts = _selections[group.id];
      if (opts != null) {
        list.addAll(opts);
      }
    }
    return list;
  }

  int get _unitPrice {
    final modifierTotal = _flattenedSelectedModifiers.fold<int>(
      0,
      (sum, opt) => sum + opt.priceAdjustment,
    );
    return widget.product.price + modifierTotal;
  }

  int get _grandTotal => _unitPrice * _quantity;

  bool get _isValid {
    for (final group in widget.product.activeModifierGroups) {
      if (group.isRequired) {
        final count = _selections[group.id]?.length ?? 0;
        if (count < 1) return false;
      }
    }
    return true;
  }

  void _handleSingleSelect(ModifierGroup group, ModifierOption option) {
    setState(() {
      _selections[group.id] = {option};
    });
  }

  void _handleMultiSelect(ModifierGroup group, ModifierOption option) {
    setState(() {
      final current = _selections[group.id] ?? <ModifierOption>{};
      if (current.contains(option)) {
        current.remove(option);
      } else {
        if (current.length < group.maxSelection) {
          current.add(option);
        }
      }
      _selections[group.id] = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialCartItem != null;
    final activeGroups = widget.product.activeModifierGroups;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.roundedMd,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: widget.product.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildFallbackIcon(),
                        )
                      : _buildFallbackIcon(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: AppTypography.sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Harga Dasar: ${AppCurrency.format(widget.product.price)} • ${widget.product.category.label}',
                      style: AppTypography.supporting,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                splashRadius: 18,
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),

        // Scrollable Options Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              if (activeGroups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Menu ini tidak memiliki varian khusus.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),

              // Build each modifier group
              ...activeGroups.map((group) {
                return _buildModifierGroupSection(group);
              }),

              // Notes Input Field
              const SizedBox(height: 6),
              ShadcnInput(
                controller: _notesController,
                label: 'Catatan Pesanan (Opsional)',
                hintText: 'Contoh: Sedikit es, saus dipisah, tanpa sedotan...',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1, color: AppColors.border),

        // Footer Actions with Quantity Stepper and Add Button
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          color: AppColors.surface,
          child: Row(
            children: [
              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppRadius.roundedMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Confirm Button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isValid
                        ? () {
                            widget.onConfirm(
                              _flattenedSelectedModifiers,
                              _quantity,
                              _notesController.text.trim(),
                            );
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            isEditing ? 'Simpan' : 'Tambahkan ke Pesanan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppCurrency.format(_grandTotal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModifierGroupSection(ModifierGroup group) {
    final isSingle = group.selectionType == ModifierSelectionType.single;
    final selectedSet = _selections[group.id] ?? <ModifierOption>{};

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ShadcnBadge(
                label: group.isRequired ? 'Wajib • Pilih 1' : 'Opsional',
                variant: group.isRequired ? ShadBadgeVariant.primary : ShadBadgeVariant.secondary,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Options Tiles
          ...group.options.map((option) {
            final isSelected = selectedSet.contains(option);
            final priceExtra = option.priceAdjustment > 0
                ? '+${AppCurrency.format(option.priceAdjustment)}'
                : null;

            if (isSingle) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: ShadcnSelectionTile(
                  title: option.name,
                  priceExtra: priceExtra,
                  isSelected: isSelected,
                  onTap: () => _handleSingleSelect(group, option),
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: ShadcnCheckboxTile(
                  title: option.name,
                  priceExtra: priceExtra,
                  isChecked: isSelected,
                  onChanged: (_) => _handleMultiSelect(group, option),
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: AppColors.primarySoft,
      child: const Center(
        child: Icon(Icons.coffee, color: AppColors.primary, size: 24),
      ),
    );
  }
}
