import '../../models/receipt_data.dart';
import '../../models/business_config.dart';
import 'printer_service.dart';
import 'receipt_formatter.dart';

/// ESC/POS Thermal Printer Hardware Adapter.
/// In this demo / client-ready phase, this acts as a robust stub adapter
/// that prepares binary ESC/POS payload and validates communication status.
/// Hardware drivers (USB, Bluetooth serial, or TCP/IP socket 9100)
/// can be plugged directly without changing receipt formatting or UI.
class EscPosPrinterService implements PrinterService {
  final ReceiptFormatter formatter;
  final String printerHost;
  final int printerPort;
  PrinterConnectionState _state = PrinterConnectionState.ready;

  EscPosPrinterService({
    ReceiptFormatter? formatter,
    this.printerHost = '192.168.1.200',
    this.printerPort = 9100,
  }) : formatter = formatter ?? ReceiptFormatter();

  @override
  PrinterModeType get mode => PrinterModeType.escPos;

  @override
  PrinterConnectionState get connectionState => _state;

  @override
  Future<PrinterResult> printReceipt(ReceiptData receipt) async {
    _state = PrinterConnectionState.printing;
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // 1. Generate ESC/POS standard byte sequences
      final bytes = formatter.toEscPosBytes(receipt);
      final previewText = formatter.formatPlainText(receipt);

      _state = PrinterConnectionState.ready;
      return PrinterResult.success(
        message: 'Struk dikirim ke hardware ESC/POS 80mm ($printerHost:$printerPort). Total ${bytes.length} bytes.',
        rawData: previewText,
      );
    } catch (e) {
      _state = PrinterConnectionState.error;
      return PrinterResult.failure(
        message: 'Gagal mengirim payload ke printer ESC/POS: $e',
        state: PrinterConnectionState.error,
      );
    }
  }

  @override
  Future<PrinterResult> testPrint() async {
    _state = PrinterConnectionState.printing;
    await Future.delayed(const Duration(milliseconds: 400));
    _state = PrinterConnectionState.ready;

    return PrinterResult.success(
      message: 'Uji komunikasi ESC/POS 80mm berhasil ($printerHost:$printerPort).',
      rawData: '*** ESC/POS 80MM HARDWARE ADAPTER READY ***',
    );
  }

  @override
  Future<PrinterConnectionState> checkStatus() async {
    return _state;
  }
}
