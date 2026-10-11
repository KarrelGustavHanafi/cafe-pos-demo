import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/business_config.dart';
import 'telegram_service.dart';
import 'telegram_formatter.dart';

/// Strips any known secret out of a message before it is returned or logged.
///
/// Upstream failures (and Dart exceptions) can echo the request URL, which for
/// Direct Bot API embeds the bot token, and for the relay embeds nothing but
/// can still surface the relay secret. Both are replaced with a marker so no
/// credential can reach the UI, the console, or a crash report.
String _redactSecrets(String message, List<String> secrets) {
  var result = message;
  for (final secret in secrets) {
    final value = secret.trim();
    if (value.isEmpty) continue;
    result = result.replaceAll(value, '[REDACTED]');
  }
  // Defence in depth: also mask anything that *looks* like a bot token, even if
  // it was not one of the supplied values.
  result = result.replaceAll(
    RegExp(r'\d{6,12}:[A-Za-z0-9_-]{30,}'),
    '[REDACTED]',
  );
  return result;
}

class TelegramBotService implements TelegramService {
  @override
  final TelegramConfig config;
  final TelegramFormatter formatter;
  final http.Client _httpClient;
  final bool isPublicDemo;

  TelegramBotService({
    required this.config,
    TelegramFormatter? formatter,
    http.Client? httpClient,
    this.isPublicDemo = true,
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

    // Safety check: prevent Direct Bot API in public demo mode
    if (isPublicDemo && config.integrationMode == TelegramIntegrationMode.directBotApi) {
      return TelegramSendResult.success(
        message: 'Pesan disimulasikan ke Telegram (Direct Bot API dinonaktifkan di mode demo publik).',
        messageId: DateTime.now().millisecondsSinceEpoch,
        rawResponse: {'ok': true, 'simulated': true, 'publicDemoMode': true},
      );
    }

    // 1. Mock simulation mode
    if (config.integrationMode == TelegramIntegrationMode.mockSimulation) {
      // No delay in test environments to avoid timer cleanup issues
      return TelegramSendResult.success(
        message: 'Pesan berhasil disimulasikan ke Telegram (Simulasi Client POS).',
        messageId: DateTime.now().millisecondsSinceEpoch,
        rawResponse: {'ok': true, 'simulated': true},
      );
    }

    // 2. Direct Bot API — NON-DURABLE SANDBOX ONLY.
    //
    // SECURITY: this path talks to Telegram straight from the browser, so the
    // bot token exists in client memory and in the request URL. It is therefore
    // NOT a production path:
    //   * `botToken` is never persisted (see TelegramConfig.toJson), so the mode
    //     stops working after a refresh and cannot be configured durably;
    //   * the token is never rendered into any message or exception;
    //   * public demo mode blocks it entirely (see the guard above).
    // Real deployments must use the relay Worker, where the token is a
    // Cloudflare secret that never reaches the browser.
    if (config.integrationMode == TelegramIntegrationMode.directBotApi) {
      final token = config.botToken?.trim() ?? '';
      if (token.isEmpty) {
        return TelegramSendResult.failure(
          message: 'Direct Bot API memerlukan bot token untuk sesi ini saja. '
              'Untuk penggunaan nyata, gunakan mode Relay Webhook.',
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
          // Never echo upstream text verbatim: it may embed the request URL,
          // which contains the bot token.
          return TelegramSendResult.failure(
            message: _redactSecrets(
              'Telegram API Error (${response.statusCode}): '
              '${data['description'] ?? 'Gagal mengirim pesan ke Telegram'}',
              [token],
            ),
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        return TelegramSendResult.failure(
          message: _redactSecrets(
            'Koneksi ke Telegram terputus atau timeout: $e',
            [token],
          ),
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

      final relaySecret = config.relaySecret?.trim() ?? '';
      if (relaySecret.isEmpty) {
        return TelegramSendResult.failure(
          message: 'Relay Webhook membutuhkan Relay Secret. '
              'Isi di Pengaturan > Integrasi Telegram (sama dengan secret Worker).',
          statusCode: 401,
        );
      }

      try {
        // Always use /telegram/send — the worker handles the bot token
        final sendUrl = endpoint.endsWith('/') ? '${endpoint}telegram/send' : '$endpoint/telegram/send';
        final uri = Uri.parse(sendUrl);
        final response = await _httpClient
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                // Server-to-server authentication for the relay.
                'X-Relay-Secret': relaySecret,
              },
              body: jsonEncode({
                'chatId': config.chatId.trim(),
                'message': text,
              }),
            )
            .timeout(const Duration(seconds: 10));

        final data = jsonDecode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300 && data['ok'] == true) {
          final msgId = data['messageId'] as int?;
          return TelegramSendResult.success(
            message: data['message']?.toString() ?? 'Laporan sukses diteruskan melalui Secure Relay ke Telegram.',
            messageId: msgId,
            rawResponse: data,
          );
        } else {
          final errMsg = data['error']?.toString() ?? 'Relay error';
          return TelegramSendResult.failure(
            message: _redactSecrets(
              'Relay Webhook (${response.statusCode}): $errMsg',
              [relaySecret],
            ),
            statusCode: response.statusCode,
            rawResponse: data,
          );
        }
      } catch (e) {
        return TelegramSendResult.failure(
          message: _redactSecrets(
            'Gagal menghubungi Secure Relay Webhook: $e',
            [relaySecret],
          ),
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
    // For relay mode, use the dedicated /telegram/test endpoint
    if (config.integrationMode == TelegramIntegrationMode.relayWebhook) {
      final endpoint = config.endpoint.trim();
      if (endpoint.isEmpty) {
        return TelegramSendResult.failure(
          message: 'Endpoint secure relay belum diatur.',
          statusCode: 400,
        );
      }

      if (config.chatId.trim().isEmpty) {
        return TelegramSendResult.failure(
          message: 'Chat ID Telegram belum diatur.',
          statusCode: 400,
        );
      }

      final relaySecret = config.relaySecret?.trim() ?? '';
      if (relaySecret.isEmpty) {
        return TelegramSendResult.failure(
          message: 'Relay Webhook membutuhkan Relay Secret. '
              'Isi di Pengaturan > Integrasi Telegram (sama dengan secret Worker).',
          statusCode: 401,
        );
      }

      try {
        final testUrl = endpoint.endsWith('/') ? '${endpoint}telegram/test' : '$endpoint/telegram/test';
        final uri = Uri.parse(testUrl);
        final response = await _httpClient
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'X-Relay-Secret': relaySecret,
              },
              body: jsonEncode({
                'chatId': config.chatId.trim(),
              }),
            )
            .timeout(const Duration(seconds: 10));

        final data = jsonDecode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300 && data['ok'] == true) {
          return TelegramSendResult.success(
            message: data['message']?.toString() ?? 'Koneksi Telegram via Secure Relay berhasil.',
            messageId: data['messageId'] as int?,
            rawResponse: data,
          );
        } else {
          final errMsg = data['error']?.toString() ?? 'Relay test error';
          return TelegramSendResult.failure(
            message: _redactSecrets(
              'Relay Test (${response.statusCode}): $errMsg',
              [relaySecret],
            ),
            statusCode: response.statusCode,
            rawResponse: data,
          );
        }
      } catch (e) {
        return TelegramSendResult.failure(
          message: _redactSecrets(
            'Gagal menghubungi Secure Relay untuk uji koneksi: $e',
            [relaySecret],
          ),
          statusCode: 502,
        );
      }
    }

    // For mock and direct modes, send a test message through sendMessage
    final now = DateTime.now();
    final testMsg = '🔔 Uji Coba Integrasi CAFFE POS\n'
        'Status: Terhubung OK\n'
        'Waktu: ${now.toIso8601String()}\n'
        'Sistem siap mengirim laporan transaksi & stok.';
    return sendMessage(testMsg);
  }
}
