import 'package:flutter/material.dart';
import '../models/raw_material.dart';
import '../models/stock_adjustment.dart';
import '../theme/app_theme.dart';

class RawMaterialStockDialog extends StatefulWidget {
  final RawMaterial material;
  final Function(AdjustmentType type, num quantity, String reason) onConfirm;

  const RawMaterialStockDialog({
    super.key,
    required this.material,
    required this.onConfirm,
  });

  @override
  State<RawMaterialStockDialog> createState() => _RawMaterialStockDialogState();
}

class _RawMaterialStockDialogState extends State<RawMaterialStockDialog> {
  AdjustmentType _selectedType = AdjustmentType.add;
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _quickReasons = [
    'Pengiriman supplier / restok',
    'Hasil opname berkala',
    'Tumpah / rusak saat operasional',
    'Bahan kedaluwarsa',
    'Koreksi input stok',
    'Penerimaan bonus vendor',
  ];

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  num get _calculatedNewStock {
    final qty = num.tryParse(_qtyController.text.trim()) ?? 0;
    final current = widget.material.stock;

    switch (_selectedType) {
      case AdjustmentType.add:
        return current + qty;
      case AdjustmentType.remove:
        return (current - qty).clamp(0.0, 999999.0);
      case AdjustmentType.set:
        return qty.clamp(0.0, 999999.0);
      case AdjustmentType.sale:
        return (current - qty).clamp(0.0, 999999.0);
    }
  }

  String _formatNum(num val) {
    return val.truncateToDouble() == val ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final qty = num.tryParse(_qtyController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim().isEmpty
        ? 'Penyesuaian stok manual'
        : _reasonController.text.trim();

    widget.onConfirm(_selectedType, qty, reason);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = widget.material.unit.label;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.primaryDark, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Penyesuaian Stok Bahan Baku',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            Text(
                              '${widget.material.name} • ${widget.material.category.label}',
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
                  const SizedBox(height: 18),

                  // Current Stock Card Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Stok Saat Ini', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '${_formatNum(widget.material.stock)} $unitLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Batas Minimum', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '${_formatNum(widget.material.minimumStock)} $unitLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warning),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Selector (ADD STOCK, REMOVE STOCK, SET STOCK)
                  const Text('Pilih Jenis Aksi *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  SegmentedButton<AdjustmentType>(
                    segments: const [
                      ButtonSegment(
                        value: AdjustmentType.add,
                        label: Text('ADD STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        icon: Icon(Icons.add_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: AdjustmentType.remove,
                        label: Text('REMOVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        icon: Icon(Icons.remove_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: AdjustmentType.set,
                        label: Text('SET STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        icon: Icon(Icons.edit_note_rounded, size: 16),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (set) {
                      setState(() {
                        _selectedType = set.first;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Quantity Field
                  Text(
                    _selectedType == AdjustmentType.set
                        ? 'Jumlah Stok Baru ($unitLabel) *'
                        : 'Jumlah Penyesuaian ($unitLabel) *',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Contoh: 1000',
                      suffixText: unitLabel,
                      prefixIcon: const Icon(Icons.scale_rounded, size: 18),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Jumlah wajib diisi';
                      final parsed = num.tryParse(val.trim());
                      if (parsed == null || parsed <= 0) return 'Masukkan angka lebih dari 0';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Reason Field with Quick Suggestions
                  const Text('Alasan Penyesuaian *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      hintText: 'Tulis atau pilih alasan di bawah...',
                      prefixIcon: Icon(Icons.notes_rounded, size: 18),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Alasan wajib diisi';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quickReasons.map((r) {
                      return ActionChip(
                        label: Text(r, style: const TextStyle(fontSize: 10.5)),
                        backgroundColor: AppColors.surfaceSubtle,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        onPressed: () {
                          setState(() {
                            _reasonController.text = r;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // Stock Preview Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Kalkulasi Stok Baru:',
                            maxLines: 2,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${_formatNum(widget.material.stock)} → ${_formatNum(_calculatedNewStock)} $unitLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Dialog Action Buttons - Wrap so they reflow when narrow.
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
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Konfirmasi & Simpan', maxLines: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
