import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';

class OwnerCustomersScreen extends StatefulWidget {
  final PosProvider pos;

  const OwnerCustomersScreen({super.key, required this.pos});

  @override
  State<OwnerCustomersScreen> createState() => _OwnerCustomersScreenState();
}

class _OwnerCustomersScreenState extends State<OwnerCustomersScreen> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Data Pelanggan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap Pelanggan',
                hintText: 'Contoh: Rian Pratama',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / HP',
                hintText: 'Contoh: 0812-8899-1122',
                prefixIcon: Icon(Icons.phone_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Preferensi Menu',
                hintText: 'Contoh: Suka Kopi Susu less sugar',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                widget.pos.addCustomer(
                  Customer(
                    id: 'CUST-${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    totalOrders: 1,
                    totalSpend: 35000,
                    lastTransaction: DateTime.now(),
                    notes: notesController.text.trim(),
                  ),
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pelanggan berhasil ditambahkan!'),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = widget.pos.customers.where((c) {
      return c.name.toLowerCase().contains(_search.toLowerCase()) ||
          c.phone.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Data Pelanggan Kafe'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddCustomerDialog,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Tambah Pelanggan'),
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
            // Search Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama atau nomor HP pelanggan...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Customers Table Card
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Text(
                      'Daftar Pelanggan Setia (${customers.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customers.length,
                    separatorBuilder: (_, index) => const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (context, index) {
                      final c = customers[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primarySoft,
                              child: Text(
                                c.name.substring(0, 1),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c.phone} • ${c.notes.isNotEmpty ? c.notes : "Pelanggan umum"}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppCurrency.format(c.totalSpend),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${c.totalOrders} kali order',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
