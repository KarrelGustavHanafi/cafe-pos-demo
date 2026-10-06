import 'dart:convert';
import 'package:intl/intl.dart';
import '../../models/receipt_data.dart';
import '../../models/business_config.dart';

class ReceiptFormatter {
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'id_ID');

  String formatCurrency(num amount) {
    return 'Rp${_currencyFormat.format(amount)}';
  }

  /// Formats receipt data into fixed-width monospace text (80mm = 48 cols, 58mm = 32 cols)
  String formatPlainText(ReceiptData receipt) {
    final int width = receipt.widthType == PrinterWidthType.mm58 ? 32 : 48;
    final divider = '-' * width;
    final buffer = StringBuffer();

    // 1. Header (Centered)
    buffer.writeln(_center(receipt.businessName, width));
    if (receipt.address.isNotEmpty) {
      final addressLines = _wrap(receipt.address, width);
      for (final line in addressLines) {
        buffer.writeln(_center(line, width));
      }
    }
    if (receipt.phone.isNotEmpty) {
      buffer.writeln(_center('Telp: ${receipt.phone}', width));
    }
    buffer.writeln(divider);

    // 2. Order Metadata
    buffer.writeln(_twoColumn('Order', ': ${receipt.orderNumber}', width));
    buffer.writeln(_twoColumn('Cashier', ': ${receipt.cashierName}', width));
    buffer.writeln(_twoColumn('Date', ': ${receipt.formattedDateTime}', width));
    if (receipt.tableNumber.isNotEmpty && receipt.tableNumber.toLowerCase() != 'takeaway') {
      buffer.writeln(_twoColumn('Table', ': Meja ${receipt.tableNumber}', width));
    } else {
      buffer.writeln(_twoColumn('Type', ': Takeaway', width));
    }
    buffer.writeln(divider);

    // 3. Items
    for (int i = 0; i < receipt.items.length; i++) {
      final item = receipt.items[i];
      buffer.writeln(item.name);

      // Modifiers listed under item
      for (final mod in item.modifiers) {
        buffer.writeln('  + $mod');
      }

      final qtyPriceStr = '${item.quantity} x ${formatCurrency(item.unitPrice)}';
      final totalStr = formatCurrency(item.totalPrice);
      buffer.writeln(_twoColumn(qtyPriceStr, totalStr, width));

      if (i < receipt.items.length - 1) {
        buffer.writeln();
      }
    }
    buffer.writeln(divider);

    // 4. Totals & Tax Breakdown
    buffer.writeln(_twoColumn('Subtotal', formatCurrency(receipt.subtotal), width));
    if (receipt.serviceChargeAmount > 0) {
      final sPercent = (receipt.serviceChargeRate * 100).toStringAsFixed(0);
      buffer.writeln(_twoColumn('Service $sPercent%', formatCurrency(receipt.serviceChargeAmount), width));
    }
    if (receipt.taxAmount > 0) {
      final tPercent = (receipt.taxRate * 100).toStringAsFixed(0);
      buffer.writeln(_twoColumn('Tax $tPercent%', formatCurrency(receipt.taxAmount), width));
    }
    buffer.writeln(_twoColumn('TOTAL', formatCurrency(receipt.total), width));
    buffer.writeln(divider);

    // 5. Payment details
    buffer.writeln(_twoColumn('Payment', receipt.paymentMethod, width));
    buffer.writeln(_twoColumn('Status', receipt.paymentStatus, width));
    if (receipt.paidAmount > 0) {
      buffer.writeln(_twoColumn('Tendered', formatCurrency(receipt.paidAmount), width));
      buffer.writeln(_twoColumn('Change', formatCurrency(receipt.changeAmount), width));
    }
    buffer.writeln(divider);

    // 6. Footer (Centered)
    if (receipt.footer.isNotEmpty) {
      final footerLines = receipt.footer.split('\n');
      for (final fLine in footerLines) {
        final wrapped = _wrap(fLine.trim(), width);
        for (final line in wrapped) {
          buffer.writeln(_center(line, width));
        }
      }
    } else {
      buffer.writeln(_center('Terima kasih atas kunjungan Anda.', width));
    }

    return buffer.toString();
  }

  /// Converts text receipt into standard ESC/POS byte sequence
  List<int> toEscPosBytes(ReceiptData receipt) {
    final text = formatPlainText(receipt);
    final List<int> bytes = [];

    // ESC @ (Initialize printer)
    bytes.addAll([0x1B, 0x40]);
    // Page code standard ASCII / Latin
    bytes.addAll([0x1B, 0x74, 0x00]);

    // Encode text to latin-1/utf-8 bytes
    bytes.addAll(utf8.encode(text));

    // Feed lines & Cut Paper (GS V 65 0)
    bytes.addAll([0x0A, 0x0A, 0x0A]);
    bytes.addAll([0x1D, 0x56, 0x41, 0x10]);

    return bytes;
  }

  String _center(String text, int width) {
    if (text.length >= width) return text;
    final int leftPadding = ((width - text.length) / 2).floor();
    return ' ' * leftPadding + text;
  }

  String _twoColumn(String left, String right, int width) {
    final available = width - right.length;
    if (left.length > available - 1) {
      left = '${left.substring(0, available - 2)}.';
    }
    final int spaces = width - left.length - right.length;
    return left + (' ' * (spaces > 0 ? spaces : 1)) + right;
  }

  List<String> _wrap(String text, int width) {
    final List<String> result = [];
    final words = text.split(' ');
    String current = '';

    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= width) {
        current += ' $word';
      } else {
        result.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) {
      result.add(current);
    }
    return result.isEmpty ? [''] : result;
  }
}
