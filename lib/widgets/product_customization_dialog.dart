import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/modifier.dart';
import '../theme/app_theme.dart';

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: ProductCustomizationDialog(
              product: product,
              initialCartItem: initialCartItem,
              onConfirm: onConfirm,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Harga Dasar: ${AppCurrency.format(widget.product.price)} • ${widget.product.category.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Scrollable Options Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
              const SizedBox(height: 12),
              const Text(
                'Catatan Pesanan (Opsional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Contoh: Sedikit es, saus dipisah, tanpa sedotan...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        const Divider(height: 1, color: AppColors.border),

        // Footer Actions with Quantity Stepper and Add Button
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          color: AppColors.surface,
          child: Row(
            children: [
              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

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
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            isEditing ? 'Simpan Perubahan' : 'Tambahkan ke Pesanan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppCurrency.format(_grandTotal),
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: group.isRequired ? AppColors.primarySoft : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  group.isRequired ? 'Wajib • Pilih 1' : 'Opsional',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: group.isRequired ? AppColors.primaryDark : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Options Grid/Wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options.map((option) {
              final isSelected = selectedSet.contains(option);

              return InkWell(
                onTap: () {
                  if (isSingle) {
                    _handleSingleSelect(group, option);
                  } else {
                    _handleMultiSelect(group, option);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySoft : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSingle
                            ? (isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded)
                            : (isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
                        size: 16,
                        color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                        ),
                      ),
                      if (option.priceAdjustment > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${AppCurrency.format(option.priceAdjustment)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: AppColors.primarySoft,
      child: const Center(
        child: Icon(Icons.coffee_rounded, color: AppColors.primary, size: 24),
      ),
    );
  }
}
