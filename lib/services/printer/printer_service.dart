import '../../models/receipt_data.dart';
import '../../models/business_config.dart';

enum PrinterConnectionState {
  ready('Siap digunakan'),
  printing('Sedang mencetak...'),
  disconnected('Printer tidak terhubung'),
  outOfPaper('Kertas habis'),
  error('Gagal / Error hardware');

  final String label;
  const PrinterConnectionState(this.label);

  bool get isReady => this == ready;
}

class PrinterResult {
  final bool success;
  final String message;
  final String? rawData;
  final PrinterConnectionState stateAfterPrint;
  final DateTime timestamp;

  const PrinterResult({
    required this.success,
    required this.message,
    this.rawData,
    this.stateAfterPrint = PrinterConnectionState.ready,
    required this.timestamp,
  });

  factory PrinterResult.success({
    required String message,
    String? rawData,
  }) {
    return PrinterResult(
      success: true,
      message: message,
      rawData: rawData,
      stateAfterPrint: PrinterConnectionState.ready,
      timestamp: DateTime.now(),
    );
  }

  factory PrinterResult.failure({
    required String message,
    PrinterConnectionState state = PrinterConnectionState.error,
  }) {
    return PrinterResult(
      success: false,
      message: message,
      stateAfterPrint: state,
      timestamp: DateTime.now(),
    );
  }
}

abstract class PrinterService {
  PrinterModeType get mode;
  PrinterConnectionState get connectionState;

  Future<PrinterResult> printReceipt(ReceiptData receipt);

  Future<PrinterResult> testPrint();

  Future<PrinterConnectionState> checkStatus();
}
