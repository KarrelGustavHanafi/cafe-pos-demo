import 'telegram_service.dart';
import 'telegram_formatter.dart';
import '../../models/business_config.dart';

class MockTelegramService implements TelegramService {
  final TelegramConfig _config;
  final TelegramFormatter formatter;
  final List<String> sentMessages = [];
  bool shouldSimulateFailure = false;

  MockTelegramService({
    TelegramConfig? config,
    TelegramFormatter? formatter,
  })  : _config = config ?? const TelegramConfig(),
        formatter = formatter ?? TelegramFormatter();

  @override
  bool get isEnabled => _config.enabled;

  @override
  TelegramConfig get config => _config;

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async {
    if (!_config.enabled) {
      return TelegramSendResult.failure(
        message: 'Integrasi Telegram sedang dinonaktifkan di pengaturan.',
        statusCode: 400,
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (shouldSimulateFailure) {
      return TelegramSendResult.failure(
        message: 'Simulasi gagal: Server Telegram tidak dapat dijangkau (Simulated Timeout).',
        statusCode: 504,
      );
    }

    sentMessages.add(text);
    return TelegramSendResult.success(
      message: 'Pesan berhasil disimulasikan terkirim ke chat ${_config.chatId}',
      messageId: DateTime.now().millisecondsSinceEpoch,
      rawResponse: {'ok': true, 'simulated': true},
    );
  }

  @override
  Future<TelegramSendResult> sendTransactionNotification(TransactionNotifData data) async {
    final text = formatter.formatTransactionNotification(data);
    return sendMessage(text);
  }

  @override
  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data) async {
    final text = formatter.formatInventoryUpdate(data);
    return sendMessage(text);
  }

  @override
  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data) async {
    final text = formatter.formatShiftOpen(data);
    return sendMessage(text);
  }

  @override
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) async {
    final text = formatter.formatDailyReport(report);
    return sendMessage(text);
  }

  @override
  Future<TelegramSendResult> sendShiftReport(ShiftReportData report) async {
    final text = formatter.formatShiftReport(report);
    return sendMessage(text);
  }

  @override
  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items) async {
    final text = formatter.formatLowStockAlert(items);
    return sendMessage(text);
  }

  @override
  Future<TelegramSendResult> testConnection() async {
    if (!_config.enabled) {
      return TelegramSendResult.failure(
        message: 'Integrasi Telegram belum diaktifkan.',
        statusCode: 400,
      );
    }

    await Future.delayed(const Duration(milliseconds: 250));
    return TelegramSendResult.success(
      message: 'Koneksi Telegram bot ${_config.botUsername} berhasil diverifikasi (Mode Demo).',
    );
  }
}
