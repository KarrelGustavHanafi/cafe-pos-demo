import 'package:flutter/material.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class TableSelectionScreen extends StatefulWidget {
  final PosProvider pos;
  final VoidCallback onTableSelected;

  const TableSelectionScreen({
    super.key,
    required this.pos,
    required this.onTableSelected,
  });

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  String _selectedZone = 'ALL'; // ALL, A, B

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    final tables = widget.pos.tables.where((t) {
      if (_selectedZone == 'A') return t.number.startsWith('A');
      if (_selectedZone == 'B') return t.number.startsWith('B');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Denah Meja', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: OutlinedButton.icon(
              onPressed: () {
                widget.pos.clearSelectedTable();
                widget.onTableSelected();
              },
              icon: const Icon(Icons.takeout_dining_rounded, size: 16),
              // Short label on narrow phones so the title and the action
              // never compete for the same AppBar row.
              label: Text(
                MediaQuery.of(context).size.width < 420
                    ? 'Takeaway'
                    : 'Bawa Pulang (Takeaway)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            // Controls: Zone filter chips & status legends
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Zone filter chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildFilterChip('Semua', 'ALL'),
                    _buildFilterChip('Indoor (Zona A)', 'A'),
                    _buildFilterChip('Outdoor (Zona B)', 'B'),
                  ],
                ),

                // Status Legends
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildLegendItem(AppColors.success, 'Tersedia (${widget.pos.availableTablesCount})'),
                    _buildLegendItem(AppColors.danger, 'Terisi (${widget.pos.occupiedTablesCount})'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Floor Plan Interactive Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossCount = 2;
                if (width >= 900) {
                  crossCount = 4;
                } else if (width >= 600) {
                  crossCount = 3;
                } else if (width < 480) {
                  // Below this the 2-column cells get too narrow for the
                  // name + status pills, so give each card a full-width row.
                  crossCount = 1;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tables.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisExtent: isMobile ? 150 : 160,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final table = tables[index];
                    final isAvailable = table.isAvailable;
                    final isSelected = widget.pos.selectedTable?.id == table.id;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : (isAvailable
                                  ? AppColors.success.withValues(alpha: 0.4)
                                  : AppColors.danger.withValues(alpha: 0.4)),
                          width: isSelected ? 2 : 1.2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          widget.pos.selectTable(table);
                          widget.onTableSelected();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Table Header: Name & Status Pill
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        'Meja ${table.number}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isAvailable ? AppColors.successSoft : AppColors.dangerSoft,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: isAvailable ? AppColors.success : AppColors.danger,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              table.status.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isAvailable ? AppColors.success : AppColors.danger,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Table Capacity
                              Row(
                                children: [
                                  const Icon(Icons.people_alt_outlined, size: 15, color: AppColors.textSecondary),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '${table.capacity} Kursi Tamu',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (table.currentOrderId != null) ...[
                                Text(
                                  'Aktif: ${table.currentOrderId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],

                              // Bottom action
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      isAvailable ? 'Buka Pesanan' : 'Meja Terisi',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isAvailable ? AppColors.primaryDark : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (!isAvailable)
                                    TextButton(
                                      onPressed: () => widget.pos.freeTable(table.number),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        minimumSize: const Size(40, 20),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: AppColors.danger,
                                      ),
                                      child: const Text('Kosongkan', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11)),
                                    )
                                  else
                                    const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.primary),
                                ],
                              ),
                            ],
                          ),
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

  Widget _buildFilterChip(String label, String zone) {
    final isSelected = _selectedZone == zone;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (_) => setState(() => _selectedZone = zone),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
