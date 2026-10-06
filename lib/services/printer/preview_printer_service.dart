import '../../models/receipt_data.dart';
import '../../models/business_config.dart';
import 'printer_service.dart';
import 'receipt_formatter.dart';

class PreviewPrinterService implements PrinterService {
  final ReceiptFormatter formatter;
  PrinterConnectionState _state = PrinterConnectionState.ready;
  ReceiptData? _lastReceipt;

  PreviewPrinterService({ReceiptFormatter? formatter})
      : formatter = formatter ?? ReceiptFormatter();

  @override
  PrinterModeType get mode => PrinterModeType.preview;

  @override
  PrinterConnectionState get connectionState => _state;

  ReceiptData? get lastReceipt => _lastReceipt;

  @override
  Future<PrinterResult> printReceipt(ReceiptData receipt) async {
    _state = PrinterConnectionState.printing;
    await Future.delayed(const Duration(milliseconds: 300));

    _lastReceipt = receipt;
    final formattedText = formatter.formatPlainText(receipt);
    _state = PrinterConnectionState.ready;

    return PrinterResult.success(
      message: 'Pratinjau struk berhasil digenerate (${receipt.widthType.label}).',
      rawData: formattedText,
    );
  }

  @override
  Future<PrinterResult> testPrint() async {
    _state = PrinterConnectionState.printing;
    await Future.delayed(const Duration(milliseconds: 300));
    _state = PrinterConnectionState.ready;

    return PrinterResult.success(
      message: 'Test pratinjau printer berhasil (80mm Virtual Printer)',
      rawData: '*** TEST PRINT 80MM OK ***\nCAFFE POS Ready\nDateTime: ${DateTime.now()}',
    );
  }

  @override
  Future<PrinterConnectionState> checkStatus() async {
    return _state;
  }
}
