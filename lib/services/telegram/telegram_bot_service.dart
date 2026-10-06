import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/business_config.dart';
import 'telegram_service.dart';
import 'telegram_formatter.dart';

class TelegramBotService implements TelegramService {
  @override
  final TelegramConfig config;
  final TelegramFormatter formatter;
  final http.Client _httpClient;

  TelegramBotService({
    required this.config,
    TelegramFormatter? formatter,
    http.Client? httpClient,
  })  : formatter = formatter ?? TelegramFormatter(),
        _httpClient = httpClient ?? http.Client();

  @override
  bool get isEnabled => config.enabled;

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async {
    if (!config.enabled) {
      return TelegramSendResult.failure(
        message: 'Integrasi Telegram dinonaktifkan di pengaturan.',
        statusCode: 400,
      );
    }

    if (config.chatId.trim().isEmpty) {
      return TelegramSendResult.failure(
        message: 'Chat ID Telegram belum diatur. Silakan periksa Pengaturan > Integrasi.',
        statusCode: 400,
      );
    }

    // 1. Mock simulation mode
    if (config.integrationMode == TelegramIntegrationMode.mockSimulation) {
      await Future.delayed(const Duration(milliseconds: 300));
      return TelegramSendResult.success(
        message: 'Pesan berhasil disimulasikan ke Telegram (Simulasi Client POS).',
        messageId: DateTime.now().millisecondsSinceEpoch,
        rawResponse: {'ok': true, 'simulated': true},
      );
    }

    // 2. Direct Bot API (Sandbox / test mode with user-provided token from settings)
    if (config.integrationMode == TelegramIntegrationMode.directBotApi) {
      final token = config.botToken?.trim() ?? '';
      if (token.isEmpty) {
        return TelegramSendResult.failure(
          message: 'Bot token belum diisi untuk pengujian Direct Bot API. Gunakan mode Mock atau isi token uji coba.',
          statusCode: 401,
        );
      }

      try {
        final uri = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
        final response = await _httpClient
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'chat_id': config.chatId.trim(),
                'text': text,
                'parse_mode': parseMode,
              }..removeWhere((k, v) => v == null)),
            )
            .timeout(const Duration(seconds: 8));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['ok'] == true) {
          final msgId = data['result']?['message_id'] as int?;
          return TelegramSendResult.success(
            message: 'Pesan Telegram berhasil terkirim ke chat ${config.chatId}.',
            messageId: msgId,
            rawResponse: data,
          );
        } else {
          final description = data['description'] ?? 'Gagal mengirim pesan ke Telegram';
          return TelegramSendResult.failure(
            message: 'Telegram API Error (${response.statusCode}): $description',
            statusCode: response.statusCode,
            rawResponse: data,
          );
        }
      } catch (e) {
        return TelegramSendResult.failure(
          message: 'Koneksi ke Telegram terputus atau timeout: $e',
          statusCode: 504,
        );
      }
    }

    // 3. Secure Relay Webhook (Cloudflare Worker / edge backend relay)
    if (config.integrationMode == TelegramIntegrationMode.relayWebhook) {
      final endpoint = config.endpoint.trim();
      if (endpoint.isEmpty) {
        return TelegramSendResult.failure(
          message: 'Endpoint secure relay belum diatur.',
          statusCode: 400,
        );
      }

      try {
        final uri = Uri.parse(endpoint);
        final response = await _httpClient
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'chatId': config.chatId.trim(),
                'message': text,
                'botUsername': config.botUsername,
                'source': 'caffe_pos_web',
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return TelegramSendResult.success(
            message: 'Laporan sukses diteruskan melalui Secure Relay ke Telegram.',
          );
        } else {
          return TelegramSendResult.failure(
            message: 'Relay Webhook mengembalikan kode ${response.statusCode}: ${response.body}',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        return TelegramSendResult.failure(
          message: 'Gagal menghubungi Secure Relay Webhook: $e',
          statusCode: 502,
        );
      }
    }

    return TelegramSendResult.failure(
      message: 'Mode integrasi Telegram tidak dikenali.',
      statusCode: 400,
    );
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
    final now = DateTime.now();
    final testMsg = '🔔 Uji Coba Integrasi CAFFE POS\n'
        'Status: Terhubung OK\n'
        'Waktu: ${now.toIso8601String()}\n'
        'Sistem siap mengirim laporan transaksi & stok.';
    return sendMessage(testMsg);
  }
}
