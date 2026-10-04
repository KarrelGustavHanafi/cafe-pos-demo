import 'package:flutter/material.dart';
import '../../models/table.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class OwnerTablesScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerTablesScreen({super.key, required this.pos});

  @override
  State<OwnerTablesScreen> createState() => _OwnerTablesScreenState();
}

class _OwnerTablesScreenState extends State<OwnerTablesScreen> {
  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 10),
          // Expanded is required: a bare Column inside a Row is laid out with
          // unbounded width and overflows as soon as the card gets narrow.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openTableDialog({CafeTable? tableToEdit}) {
    final isEdit = tableToEdit != null;
    final numberController = TextEditingController(text: tableToEdit?.number ?? '');
    final capacityController = TextEditingController(text: tableToEdit != null ? '${tableToEdit.capacity}' : '4');
    TableStatus status = tableToEdit?.status ?? TableStatus.available;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isEdit ? 'Edit Data Meja' : 'Tambah Meja Baru', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Nomor / Nama Meja',
                  hintText: 'Contoh: A05, B04, VIP-2',
                  prefixIcon: Icon(Icons.tag_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kapasitas Kursi (Pax)',
                  hintText: 'Contoh: 4',
                  prefixIcon: Icon(Icons.people_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TableStatus>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Status Meja',
                  prefixIcon: Icon(Icons.info_outline_rounded, size: 18),
                ),
                items: TableStatus.values.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => status = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final num = numberController.text.trim();
                final cap = int.tryParse(capacityController.text.trim()) ?? 4;
                if (num.isNotEmpty) {
                  if (isEdit) {
                    widget.pos.updateTable(
                      tableToEdit.copyWith(number: num, capacity: cap, status: status),
                    );
                  } else {
                    final id = 'tbl-${DateTime.now().millisecondsSinceEpoch}';
                    widget.pos.addTable(
                      CafeTable(id: id, number: num, capacity: cap, status: status),
                    );
                  }
                  Navigator.of(context).pop();
                }
              },
              child: Text(isEdit ? 'Simpan' : 'Tambah Meja'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tables = widget.pos.tables;
    final availableCount = widget.pos.availableTablesCount;
    final occupiedCount = widget.pos.occupiedTablesCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Manajemen Meja'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _openTableDialog(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah Meja'),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status KPI Banner - wraps to a vertical stack on narrow screens
            // so the three cards never have to share a too-narrow row.
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final columns = w >= 760 ? 3 : (w >= 440 ? 2 : 1);
                final itemWidth = columns == 1 ? w : (w - (columns - 1) * 10) / columns;
                final cards = <Widget>[
                  _buildMetricCard(
                    icon: Icons.table_restaurant_rounded,
                    iconColor: AppColors.primary,
                    label: 'Total Meja Kafe',
                    value: '${tables.length} Unit',
                    valueColor: AppColors.textPrimary,
                  ),
                  _buildMetricCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.success,
                    label: 'Tersedia',
                    value: '$availableCount Meja',
                    valueColor: AppColors.success,
                  ),
                  _buildMetricCard(
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.warning,
                    label: 'Terisi Tamu',
                    value: '$occupiedCount Meja',
                    valueColor: AppColors.warning,
                  ),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in cards) SizedBox(width: itemWidth, child: c),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Table Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 720
                    ? 4
                    : (constraints.maxWidth >= 480 ? 3 : (constraints.maxWidth >= 300 ? 2 : 1));

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tables.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: 145,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final t = tables[index];
                    final isAvail = t.isAvailable;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAvail ? AppColors.successSoft : AppColors.warningSoft,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      isAvail ? 'Tersedia' : 'Terisi',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isAvail ? AppColors.success : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      color: AppColors.textSecondary,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      onPressed: () => _openTableDialog(tableToEdit: t),
                                    ),
                                    if (isAvail)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                        color: AppColors.error,
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        onPressed: () => widget.pos.deleteTable(t.id),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'Meja ${t.number}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kapasitas: ${t.capacity} Kursi (Pax)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            if (t.currentOrderId != null)
                              Text(
                                'Order: ${t.currentOrderId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, color: AppColors.primary, fontWeight: FontWeight.w600),
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
