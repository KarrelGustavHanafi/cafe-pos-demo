import 'dart:async';
import '../../models/order.dart';
import '../../models/business_config.dart';
import '../../models/receipt_data.dart';
import '../printer/printer_service.dart';
import '../printer/receipt_formatter.dart';
import '../printer/preview_printer_service.dart';
import '../printer/browser_print_service.dart';
import '../printer/esc_pos_printer_service.dart';

class ReceiptService {
  final ReceiptFormatter formatter;
  PrinterService _printerService;
  ReceiptData? _lastReceipt;
  final List<ReceiptData> _receiptHistory = [];

  ReceiptService({
    ReceiptFormatter? formatter,
    PrinterService? printerService,
  })  : formatter = formatter ?? ReceiptFormatter(),
        _printerService = printerService ?? PreviewPrinterService();

  PrinterService get printerService => _printerService;
  ReceiptData? get lastReceipt => _lastReceipt;
  List<ReceiptData> get receiptHistory => List.unmodifiable(_receiptHistory);

  void updatePrinterMode(PrinterModeType mode, {String? host, int? port}) {
    switch (mode) {
      case PrinterModeType.preview:
        _printerService = PreviewPrinterService(formatter: formatter);
        break;
      case PrinterModeType.browserPrint:
        _printerService = BrowserPrintService(formatter: formatter);
        break;
      case PrinterModeType.escPos:
        _printerService = EscPosPrinterService(
          formatter: formatter,
          printerHost: host ?? '192.168.1.200',
          printerPort: port ?? 9100,
        );
        break;
    }
  }

  void setCustomPrinter(PrinterService customPrinter) {
    _printerService = customPrinter;
  }

  /// Drops the receipts printed during the current session.
  ///
  /// Used by the demo reset. [ReceiptService] keeps nothing on disk, so this
  /// cannot touch persisted data or business configuration — it only empties
  /// [lastReceipt] and [receiptHistory]. Afterwards the service behaves exactly
  /// as it does before any receipt has ever been printed: [reprintLastReceipt]
  /// reports that there is nothing to reprint, and [reprintReceipt] falls back
  /// to its "not found" error instead of resolving to a stale sale's receipt.
  void clearSessionReceipts() {
    _lastReceipt = null;
    _receiptHistory.clear();
  }

  ReceiptData buildReceiptData(Order order, BusinessConfig config) {
    return ReceiptData.fromOrder(order, config);
  }

  Future<PrinterResult> printOrderReceipt(Order order, BusinessConfig config) async {
    final receiptData = buildReceiptData(order, config);
    return printReceipt(receiptData);
  }

  Future<PrinterResult> printReceipt(ReceiptData receipt) async {
    _lastReceipt = receipt;
    _receiptHistory.insert(0, receipt);
    if (_receiptHistory.length > 50) {
      _receiptHistory.removeLast();
    }
    return _printerService.printReceipt(receipt);
  }

  /// Reprints a previously printed receipt, located by [orderId].
  ///
  /// Takes the stable `Order.id`, NOT the display order number: two distinct
  /// sales can share an `orderNumber` (a rejected stale-shift order is
  /// re-prepared without advancing the sequence), and matching on it would
  /// return whichever of them happened to be printed first — silently reprinting
  /// the wrong customer's receipt.
  ///
  /// Fallback to the most recent receipt is preserved for the case where the
  /// requested receipt is not in the retained history window.
  ///
  /// NOTE: this feature is not currently reachable from the UI. The contract is
  /// fixed here anyway so that wiring it up later cannot reintroduce a
  /// display-number lookup.
  Future<PrinterResult> reprintReceipt(String orderId) async {
    final found = _receiptHistory.firstWhere(
      (r) => r.orderId == orderId,
      orElse: () => _lastReceipt ?? (throw StateError('Struk tidak ditemukan untuk dicetak ulang.')),
    );
    return _printerService.printReceipt(found);
  }

  Future<PrinterResult> reprintLastReceipt() async {
    if (_lastReceipt == null) {
      return PrinterResult.failure(
        message: 'Belum ada transaksi struk yang dapat dicetak ulang.',
        state: PrinterConnectionState.error,
      );
    }
    return _printerService.printReceipt(_lastReceipt!);
  }

  String formatReceiptPlainText(ReceiptData receipt) {
    return formatter.formatPlainText(receipt);
  }
}
