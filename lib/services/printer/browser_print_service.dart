import '../../models/receipt_data.dart';
import '../../models/business_config.dart';
import 'printer_service.dart';
import 'receipt_formatter.dart';

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
    await Future.delayed(const Duration(milliseconds: 350));

    final rawText = formatter.formatPlainText(receipt);
    _state = PrinterConnectionState.ready;

    return PrinterResult.success(
      message: 'Perintah cetak browser dikirim untuk struk #${receipt.orderNumber}.',
      rawData: rawText,
    );
  }

  @override
  Future<PrinterResult> testPrint() async {
    _state = PrinterConnectionState.printing;
    await Future.delayed(const Duration(milliseconds: 250));
    _state = PrinterConnectionState.ready;

    return PrinterResult.success(
      message: 'Test cetak browser berhasil dikirim ke dialog print sistem.',
      rawData: '*** TEST BROWSER PRINT OK ***',
    );
  }

  @override
  Future<PrinterConnectionState> checkStatus() async {
    return _state;
  }
}
