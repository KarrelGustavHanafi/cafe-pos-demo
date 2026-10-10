import 'package:intl/intl.dart';
import 'telegram_service.dart';

class TelegramFormatter {
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'id_ID');

  String formatCurrency(num amount) {
    final prefix = amount < 0 ? '-Rp' : 'Rp';
    return '$prefix${_currencyFormat.format(amount.abs())}';
  }

  String _formatQuantity(num amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(1);
  }

  String _formatPaymentMethod(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('qris')) {
      return '💳 QRIS';
    } else if (lower.contains('debit') || lower.contains('card')) {
      return '💳 Kartu Debit';
    } else {
      return '💵 Tunai';
    }
  }

  /// 1. Transaksi Sukses / Selesai
  String formatTransactionNotification(TransactionNotifData data) {
    final buffer = StringBuffer();
    buffer.writeln('🧾 TRANSAKSI BARU');
    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('Order: ${data.orderNumber}');
    buffer.writeln('Kasir: ${data.cashierName}');
    if (data.tableNumber != null &&
        data.tableNumber!.trim().isNotEmpty &&
        data.tableNumber != 'Takeaway') {
      buffer.writeln('Meja: ${data.tableNumber}');
    }
    buffer.writeln();

    for (final item in data.items) {
      buffer.writeln('☕ ${item.name}');
      if (item.modifiers != null && item.modifiers!.trim().isNotEmpty) {
        buffer.writeln(item.modifiers!.trim());
      }
      buffer.writeln(formatCurrency(item.price));
      buffer.writeln();
    }

    final methodStr = _formatPaymentMethod(data.paymentMethod);
    buffer.writeln(methodStr);
    buffer.writeln('✅ LUNAS');
    buffer.writeln();
    buffer.writeln('💰 Total: ${formatCurrency(data.grandTotal)}');
    buffer.writeln('━━━━━━━━━━━━━━━━');
    return buffer.toString().trim();
  }

  /// 2. Pengurangan Stok Bahan / Produk
  String formatInventoryUpdate(InventoryUpdateData data) {
    final buffer = StringBuffer();
    buffer.writeln('📦 STOCK UPDATE');
    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('Order: ${data.orderNumber}');
    buffer.writeln();

    for (final d in data.deductions) {
      final amtStr = _formatQuantity(d.amount);
      final padName = d.name.padRight(14);
      buffer.writeln('$padName -$amtStr${d.unit}');
    }

    buffer.writeln();
    buffer.writeln('Stock updated automatically.');
    return buffer.toString().trim();
  }

  /// 3. Peringatan Stok Menipis (Threshold Alert)
  String formatLowStockAlert(List<LowStockItemData> items, {String cafeName = 'CAFFE'}) {
    if (items.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('⚠️ LOW STOCK ALERT');
    buffer.writeln('━━━━━━━━━━━━━━━━');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln(item.name);
      buffer.writeln('Current: ${_formatQuantity(item.currentStock)}${item.unit}');
      buffer.writeln('Minimum: ${_formatQuantity(item.minimumStock)}${item.unit}');
      if (i < items.length - 1) {
        buffer.writeln('----------------');
      }
    }

    buffer.writeln();
    buffer.writeln('Please restock.');
    return buffer.toString().trim();
  }

  /// 4. Pembukaan Shift Kasir
  String formatShiftOpen(ShiftOpenData data) {
    final timeFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final buffer = StringBuffer();
    buffer.writeln('🟢 SHIFT OPENED');
    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('Cashier: ${data.cashierName}');
    buffer.writeln('Opening Cash: ${formatCurrency(data.openingCash)}');
    buffer.writeln('Time: ${timeFormat.format(data.time)}');
    return buffer.toString().trim();
  }

  /// 5. Penutupan Shift Kasir
  String formatShiftReport(ShiftReportData shift, {String cafeName = 'CAFFE'}) {
    final timeFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final buffer = StringBuffer();
    buffer.writeln('🔴 SHIFT CLOSED');
    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('Cashier: ${shift.cashierName}');
    buffer.writeln();

    final totalSales = shift.totalSales > 0 ? shift.totalSales : (shift.cashSales + shift.qrisSales);
    buffer.writeln('Sales: ${formatCurrency(totalSales)}');
    buffer.writeln('Cash: ${formatCurrency(shift.cashSales)}');
    buffer.writeln('QRIS: ${formatCurrency(shift.qrisSales)}');
    buffer.writeln('Expected Cash: ${formatCurrency(shift.expectedEndingCash)}');
    buffer.writeln('Actual Cash: ${formatCurrency(shift.actualEndingCash)}');
    buffer.writeln('Variance: ${formatCurrency(shift.variance)}');
    buffer.writeln();
    buffer.writeln('Time: ${timeFormat.format(shift.endTime ?? DateTime.now())}');
    return buffer.toString().trim();
  }

  /// 6. Laporan Harian Owner
  String formatDailyReport(DailyReportData report, {String cafeName = 'CAFFE'}) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final dateStr = dateFormat.format(report.date);

    final buffer = StringBuffer();
    buffer.writeln('📊 LAPORAN HARIAN $cafeName');
    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('Tanggal: $dateStr');
    buffer.writeln();
    buffer.writeln('Ringkasan Bisnis:');
    buffer.writeln('• Total Penjualan  : ${formatCurrency(report.totalSales)}');
    buffer.writeln('• Total Transaksi  : ${report.totalTransactions} pesanan');
    if (report.totalItemsSold > 0) {
      buffer.writeln('• Produk Terjual   : ${report.totalItemsSold} item');
    }
    if (report.averageOrderValue > 0) {
      buffer.writeln('• Rata-rata Order  : ${formatCurrency(report.averageOrderValue)}');
    }
    buffer.writeln();
    buffer.writeln('Pembayaran:');
    buffer.writeln('• Cash   : ${formatCurrency(report.cashSales)}');
    buffer.writeln('• QRIS   : ${formatCurrency(report.qrisSales)}');
    if (report.debitSales > 0) {
      buffer.writeln('• Debit  : ${formatCurrency(report.debitSales)}');
    }
    buffer.writeln();

    if (report.topProducts.isNotEmpty) {
      buffer.writeln('Produk Terlaris:');
      for (int i = 0; i < report.topProducts.length && i < 5; i++) {
        final p = report.topProducts[i];
        buffer.writeln('${i + 1}. ${p.key} (${p.value} terjual)');
      }
      buffer.writeln();
    }

    if (report.lowStockItems.isNotEmpty) {
      buffer.writeln('Stok Menipis:');
      for (final item in report.lowStockItems) {
        buffer.writeln('• $item');
      }
      buffer.writeln();
    }

    if (report.shiftReport != null) {
      final s = report.shiftReport!;
      buffer.writeln('Shift Terakhir:');
      buffer.writeln('• Kasir        : ${s.cashierName}');
      buffer.writeln('• Opening Cash : ${formatCurrency(s.startingCash)}');
      buffer.writeln('• Actual Cash  : ${formatCurrency(s.actualEndingCash)}');
      buffer.writeln('• Variance     : ${formatCurrency(s.variance)}');
      buffer.writeln();
    }

    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('$cafeName POS • Laporan Otomatis');
    return buffer.toString().trim();
  }
}
