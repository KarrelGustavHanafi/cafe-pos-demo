import 'package:intl/intl.dart';
import 'telegram_service.dart';

class TelegramFormatter {
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'id_ID');

  String formatCurrency(num amount) {
    final prefix = amount < 0 ? '-Rp' : 'Rp';
    return '$prefix${_currencyFormat.format(amount.abs())}';
  }

  String formatDailyReport(DailyReportData report, {String cafeName = 'CAFFE'}) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final dateStr = dateFormat.format(report.date);

    final buffer = StringBuffer();
    buffer.writeln('$cafeName POS');
    buffer.writeln('LAPORAN PENJUALAN');
    buffer.writeln();
    buffer.writeln('Tanggal: $dateStr');
    buffer.writeln();
    buffer.writeln('Total Transaksi');
    buffer.writeln('${report.totalTransactions}');
    buffer.writeln();
    buffer.writeln('Total Penjualan');
    buffer.writeln(formatCurrency(report.totalSales));
    buffer.writeln();
    buffer.writeln('Pembayaran:');
    buffer.writeln('Cash   ${formatCurrency(report.cashSales)}');
    buffer.writeln('QRIS   ${formatCurrency(report.qrisSales)}');
    if (report.debitSales > 0) {
      buffer.writeln('Debit  ${formatCurrency(report.debitSales)}');
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
        buffer.writeln('- $item');
      }
      buffer.writeln();
    }

    if (report.shiftReport != null) {
      final s = report.shiftReport!;
      buffer.writeln('Shift Kasir:');
      buffer.writeln('Opening Cash : ${formatCurrency(s.startingCash)}');
      buffer.writeln('Actual Cash  : ${formatCurrency(s.actualEndingCash)}');
      buffer.writeln('Variance     : ${formatCurrency(s.variance)}');
    }

    return buffer.toString().trim();
  }

  String formatShiftReport(ShiftReportData shift, {String cafeName = 'CAFFE'}) {
    final timeFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final buffer = StringBuffer();

    buffer.writeln('$cafeName POS');
    buffer.writeln('LAPORAN PENUTUPAN SHIFT');
    buffer.writeln('--------------------------------');
    buffer.writeln('Nama Shift  : ${shift.shiftName}');
    buffer.writeln('Kasir       : ${shift.cashierName}');
    buffer.writeln('Mulai       : ${timeFormat.format(shift.startTime)}');
    if (shift.endTime != null) {
      buffer.writeln('Selesai     : ${timeFormat.format(shift.endTime!)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Total Transaksi : ${shift.totalTransactions}');
    buffer.writeln('Penjualan Tunai : ${formatCurrency(shift.cashSales)}');
    buffer.writeln('--------------------------------');
    buffer.writeln('Opening Cash       : ${formatCurrency(shift.startingCash)}');
    buffer.writeln('Expected Cash      : ${formatCurrency(shift.expectedEndingCash)}');
    buffer.writeln('Actual Cash Fisik  : ${formatCurrency(shift.actualEndingCash)}');
    buffer.writeln('Selisih (Variance) : ${formatCurrency(shift.variance)}');

    if (shift.notes != null && shift.notes!.trim().isNotEmpty) {
      buffer.writeln('Catatan: ${shift.notes!.trim()}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Status Shift : CLOSED & VERIFIED');

    return buffer.toString().trim();
  }

  String formatLowStockAlert(List<LowStockItemData> items, {String cafeName = 'CAFFE'}) {
    final buffer = StringBuffer();
    buffer.writeln('⚠️ PERINGATAN STOK MENIPIS');
    buffer.writeln('$cafeName POS - Inventaris');
    buffer.writeln('--------------------------------');
    buffer.writeln('Terdapat ${items.length} bahan/produk di bawah batas minimum:');
    buffer.writeln();

    for (final item in items) {
      buffer.writeln('• ${item.name}');
      buffer.writeln('  Stok saat ini: ${item.currentStock} ${item.unit}');
      buffer.writeln('  Batas minimum: ${item.minimumStock} ${item.unit}');
    }

    buffer.writeln();
    buffer.writeln('Segera lakukan purchase order / restock.');
    return buffer.toString().trim();
  }
}
