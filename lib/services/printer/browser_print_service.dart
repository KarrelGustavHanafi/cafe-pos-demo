import '../../models/receipt_data.dart';
import '../../models/business_config.dart';
import 'printer_service.dart';
import 'receipt_formatter.dart';
import 'browser_print_stub.dart'
    if (dart.library.html) 'browser_print_web.dart';

class BrowserPrintService implements PrinterService {
  final ReceiptFormatter formatter;
  PrinterConnectionState _state = PrinterConnectionState.ready;

  BrowserPrintService({ReceiptFormatter? formatter})
      : formatter = formatter ?? ReceiptFormatter();

  @override
  PrinterModeType get mode => PrinterModeType.browserPrint;

  @override
  PrinterConnectionState get connectionState => _state;

  @override
  Future<PrinterResult> printReceipt(ReceiptData receipt) async {
    _state = PrinterConnectionState.printing;

    try {
      // Convert items to JSON-serializable format
      final itemsJson = receipt.items.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'modifiers': item.modifiers,
        'totalPrice': item.totalPrice,
      }).toList();

      await triggerBrowserPrint(
        businessName: receipt.businessName,
        address: receipt.address,
        phone: receipt.phone,
        orderNumber: receipt.orderNumber,
        dateTime: receipt.formattedDateTime,
        cashierName: receipt.cashierName,
        tableNumber: receipt.tableNumber,
        items: itemsJson,
        subtotal: receipt.subtotal,
        serviceChargeRate: receipt.serviceChargeRate,
        serviceChargeAmount: receipt.serviceChargeAmount,
        taxRate: receipt.taxRate,
        taxAmount: receipt.taxAmount,
        total: receipt.total,
        paymentMethod: receipt.paymentMethod,
        paymentStatus: receipt.paymentStatus,
        paidAmount: receipt.paidAmount,
        changeAmount: receipt.changeAmount,
        footer: receipt.footer,
        widthType: receipt.widthType.name,
      );

      _state = PrinterConnectionState.ready;

      return PrinterResult.success(
        message: 'Tab cetak struk dibuka untuk #${receipt.orderNumber}. Silakan pilih printer thermal dan klik Print.',
        rawData: formatter.formatPlainText(receipt),
      );
    } catch (e) {
      _state = PrinterConnectionState.error;
      return PrinterResult.failure(
        message: 'Gagal membuka tab cetak: $e',
      );
    }
  }

  @override
  Future<PrinterResult> testPrint() async {
    _state = PrinterConnectionState.printing;

    try {
      // Use test data for print test
      await triggerBrowserPrint(
        businessName: 'CAFFE TEST',
        address: 'Jl. Test No. 123',
        phone: '081234567890',
        orderNumber: 'TEST-001',
        dateTime: '01/01/2024 12:00',
        cashierName: 'Test Kasir',
        tableNumber: 'Meja 1',
        items: [
          {
            'name': 'Kopi Susu',
            'quantity': 2,
            'unitPrice': 25000,
            'modifiers': ['Gula Aren'],
            'totalPrice': 50000,
          },
        ],
        subtotal: 50000,
        serviceChargeRate: 0.05,
        serviceChargeAmount: 2500,
        taxRate: 0.10,
        taxAmount: 5000,
        total: 57500,
        paymentMethod: 'CASH',
        paymentStatus: 'PAID',
        paidAmount: 60000,
        changeAmount: 2500,
        footer: '*** TEST PRINT ***',
        widthType: 'mm80',
      );

      _state = PrinterConnectionState.ready;

      return PrinterResult.success(
        message: 'Dialog cetak browser berhasil dibuka untuk test print.',
        rawData: '*** TEST BROWSER PRINT OK ***',
      );
    } catch (e) {
      _state = PrinterConnectionState.error;
      return PrinterResult.failure(
        message: 'Gagal membuka dialog cetak browser: $e',
      );
    }
  }

  @override
  Future<PrinterConnectionState> checkStatus() async {
    return _state;
  }
}
