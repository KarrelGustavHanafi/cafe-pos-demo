import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/stock_adjustment.dart';
import '../theme/app_theme.dart';

class StockUpdateDialog extends StatefulWidget {
  final Product product;
  final Function(AdjustmentType type, int quantity, String reason) onConfirm;

  const StockUpdateDialog({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  @override
  State<StockUpdateDialog> createState() => _StockUpdateDialogState();
}

class _StockUpdateDialogState extends State<StockUpdateDialog> {
  AdjustmentType _type = AdjustmentType.add;
  final _qtyController = TextEditingController(text: '10');
  final _reasonController = TextEditingController(text: 'Penerimaan supplier baru');

  final List<String> _commonReasons = [
    'Penerimaan supplier baru',
    'Koreksi stok fisik / opname',
    'Barang rusak atau expired',
    'Pemakaian internal / sampling',
    'Penyesuaian stok reguler',
  ];

  int get _parsedQty => int.tryParse(_qtyController.text.trim()) ?? 0;

  int get _calculatedNewStock {
    final qty = _parsedQty;
    switch (_type) {
      case AdjustmentType.add:
        return widget.product.stock + qty;
      case AdjustmentType.remove:
        return (widget.product.stock - qty).clamp(0, 9999);
      case AdjustmentType.set:
        return qty.clamp(0, 9999);
      case AdjustmentType.sale:
        return (widget.product.stock - qty).clamp(0, 9999);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStock = widget.product.stock;
    final newStock = _calculatedNewStock;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: const Icon(Icons.inventory_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Stok Produk',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          widget.product.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Current vs New Stock Visual Comparison Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Stok Saat Ini', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '$currentStock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 22),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Stok Setelah Update', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '$newStock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: newStock == 0
                                  ? AppColors.error
                                  : (newStock <= widget.product.lowStockThreshold
                                      ? AppColors.warning
                                      : AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Adjustment Type Segmented Selector
              const Text(
                'Tipe Penyesuaian',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              SegmentedButton<AdjustmentType>(
                segments: const [
                  ButtonSegment(
                    value: AdjustmentType.add,
                    label: Text('Tambah (+)'),
                    icon: Icon(Icons.add_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AdjustmentType.remove,
                    label: Text('Kurang (-)'),
                    icon: Icon(Icons.remove_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AdjustmentType.set,
                    label: Text('Setel (=)'),
                    icon: Icon(Icons.tune_rounded, size: 16),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (set) {
                  setState(() => _type = set.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primarySoft,
                  selectedForegroundColor: AppColors.primaryDark,
                ),
              ),

              const SizedBox(height: 16),

              // Quantity Input & Quick Chips
              const Text(
                'Jumlah Perubahan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              // The amount field and the quick chips are stacked on narrow
              // dialogs so neither is forced below its intrinsic width.
              LayoutBuilder(
                builder: (context, c) {
                  final field = TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Masukkan jumlah',
                      suffixText: 'unit',
                      prefixIcon: Icon(
                        _type == AdjustmentType.add
                            ? Icons.add_circle_outline
                            : (_type == AdjustmentType.remove
                                ? Icons.remove_circle_outline
                                : Icons.edit_note),
                        size: 18,
                      ),
                    ),
                  );
                  final chips = Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [5, 10, 20].map((qty) {
                      return ActionChip(
                        label: Text('+$qty', style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surface,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _qtyController.text = '$qty';
                          });
                        },
                      );
                    }).toList(),
                  );
                  if (c.maxWidth < 380) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [field, const SizedBox(height: 8), chips],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: field),
                      const SizedBox(width: 8),
                      chips,
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Reason
              const Text(
                'Alasan Penyesuaian',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _commonReasons.contains(_reasonController.text) ? _reasonController.text : null,
                // Without isExpanded the field sizes itself to its widest item
                // and overflows narrow dialogs.
                isExpanded: true,
                hint: const Text('Pilih atau ketik alasan...'),
                items: _commonReasons.map((r) {
                  return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _reasonController.text = val);
                  }
                },
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Keterangan tambahan (opsional)...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

              const SizedBox(height: 24),

              // Actions - Wrap so the buttons reflow instead of overflowing.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal', maxLines: 1),
                  ),
                  ElevatedButton.icon(
                    onPressed: _parsedQty <= 0
                        ? null
                        : () {
                            widget.onConfirm(
                              _type,
                              _parsedQty,
                              _reasonController.text.trim().isEmpty
                                  ? 'Penyesuaian stok reguler'
                                  : _reasonController.text.trim(),
                            );
                            Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Simpan Penyesuaian', maxLines: 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
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
