// Web-specific implementation using dart:html
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unnecessary_null_comparison, dead_code
import 'dart:html' as html;

Future<void> triggerBrowserPrint({
  required String businessName,
  required String address,
  required String phone,
  required String orderNumber,
  required String dateTime,
  required String cashierName,
  required String tableNumber,
  required List<Map<String, dynamic>> items,
  required int subtotal,
  required double serviceChargeRate,
  required int serviceChargeAmount,
  required double taxRate,
  required int taxAmount,
  required int total,
  required String paymentMethod,
  required String paymentStatus,
  required int paidAmount,
  required int changeAmount,
  required String footer,
  required String widthType,
}) async {
  // Escape HTML to prevent XSS
  String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  // Format currency
  String formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  // Generate receipt HTML
  var receiptHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Receipt - $orderNumber</title>
  <style>
    @page {
      size: ${widthType == 'mm58' ? '58mm' : '80mm'} auto;
      margin: 0;
    }
    body {
      margin: 0;
      padding: 5mm;
      font-family: 'Courier New', monospace;
      font-size: 12px;
      line-height: 1.3;
      color: black;
      background: white;
    }
    .receipt {
      max-width: ${widthType == 'mm58' ? '58mm' : '80mm'};
      margin: 0 auto;
    }
    .center { text-align: center; }
    .bold { font-weight: bold; }
    .divider { border-top: 1px dashed black; margin: 8px 0; }
    .row { display: flex; justify-content: space-between; }
    .item-row { display: flex; justify-content: space-between; margin-bottom: 4px; }
    .item-name { 
      flex: 1; 
      overflow-wrap: break-word;
      word-break: break-word;
    }
    .item-qty { margin-left: 8px; }
    .item-price { margin-left: 8px; text-align: right; white-space: nowrap; }
    .modifier { 
      font-size: 10px; 
      color: #666; 
      margin-left: 8px;
      overflow-wrap: break-word;
      word-break: break-word;
    }
    .total-line { font-size: 14px; font-weight: bold; margin-top: 8px; }
    .footer { 
      font-size: 10px; 
      text-align: center; 
      margin-top: 16px; 
      font-style: italic;
      overflow-wrap: break-word;
      word-break: break-word;
    }
  </style>
</head>
<body>
  <div class="receipt">
    <div class="center bold" style="font-size: 16px; margin-bottom: 4px;">${escapeHtml(businessName)}</div>
    <div class="center" style="font-size: 10px; margin-bottom: 4px;">${escapeHtml(address)}</div>
    <div class="center" style="font-size: 10px; margin-bottom: 8px;">${escapeHtml(phone)}</div>
    
    <div class="divider"></div>
    
    <div class="row"><span>No:</span><span class="bold">${escapeHtml(orderNumber)}</span></div>
    <div class="row"><span>Waktu:</span><span>${escapeHtml(dateTime)}</span></div>
    <div class="row"><span>Kasir:</span><span>${escapeHtml(cashierName)}</span></div>
    <div class="row"><span>Meja:</span><span>${escapeHtml(tableNumber)}</span></div>
    
    <div class="divider"></div>
  ''';

  // Add items
  for (final item in items) {
    final name = escapeHtml(item['name'] as String);
    final qty = item['quantity'] as int;
    final modifiers = item['modifiers'] as List<String>;
    final totalPrice = item['totalPrice'] as int;

    receiptHtml += '''
    <div class="item-row">
      <span class="item-name">$name</span>
      <span class="item-qty">$qty</span>
      <span class="item-price">${formatCurrency(totalPrice)}</span>
    </div>
    ''';

    if (modifiers.isNotEmpty) {
      for (final mod in modifiers) {
        receiptHtml += '<div class="modifier">  ${escapeHtml(mod)}</div>';
      }
    }
  }

  // Add totals
  final serviceChargePercent = serviceChargeRate > 0 ? (serviceChargeRate * 100).toStringAsFixed(0) : '';
  final taxPercent = taxRate > 0 ? (taxRate * 100).toStringAsFixed(0) : '';

  receiptHtml += '''
    <div class="divider"></div>
    <div class="row"><span>Subtotal</span><span>${formatCurrency(subtotal)}</span></div>
    <div class="row"><span>Service${serviceChargePercent.isNotEmpty ? ' ($serviceChargePercent%)' : ''}</span><span>${formatCurrency(serviceChargeAmount)}</span></div>
    <div class="row"><span>Pajak${taxPercent.isNotEmpty ? ' ($taxPercent%)' : ''}</span><span>${formatCurrency(taxAmount)}</span></div>
    <div class="divider"></div>
    <div class="row total-line"><span>TOTAL</span><span>${formatCurrency(total)}</span></div>
    <div class="divider"></div>
    <div class="row"><span>Metode</span><span>${escapeHtml(paymentMethod)}</span></div>
  ''';

  if (paidAmount > 0) {
    receiptHtml += '''
    <div class="row"><span>Dibayar</span><span>${formatCurrency(paidAmount)}</span></div>
    <div class="row"><span>Kembalian</span><span>${formatCurrency(changeAmount)}</span></div>
    ''';
  }

  receiptHtml += '''
    <div class="divider"></div>
    <div class="footer">${escapeHtml(footer).replaceAll('\n', '<br>')}</div>
  </div>
</body>
</html>
  ''';

  // Create Blob from HTML
  final blob = html.Blob([receiptHtml], 'text/html');
  final url = html.Url.createObjectUrl(blob);

  // Open new window with receipt
  final newWindow = html.window.open(url, '_blank');

  // Handle popup blocker - if window failed to open, throw error
  // Note: dart:html window.open can return null when popup blocker is active
  if (newWindow == null) {
    html.Url.revokeObjectUrl(url);
    throw Exception('Popup blocker mencegah pembukaan tab baru. Izinkan popup untuk cetak struk.');
  }

  // Cleanup URL after extended delay (2 minutes to allow user time to print)
  // This ensures the Blob URL remains valid even with rapid repeated clicks
  Future.delayed(const Duration(minutes: 2), () {
    html.Url.revokeObjectUrl(url);
  });
}
