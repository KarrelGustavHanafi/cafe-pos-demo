import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_bot_service.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

/// Regression tests for Phase 1 Telegram security hardening.
///
/// Covers the three guarantees this phase was meant to establish:
///   1. The bot token never reaches browser persistence.
///   2. Public demo mode never calls Telegram directly.
///   3. A Telegram failure never breaks an already-committed POS transaction.

/// Records every request so tests can assert on headers and bodies, and can be
/// told to fail so delivery-failure paths can be exercised.
class _RecordingHttpClient extends http.BaseClient {
  final List<http.Request> requests = [];
  bool shouldFail = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final streamed = request as http.Request;
    requests.add(streamed);

    if (shouldFail) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"ok":false,"description":"boom"}')),
        500,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"ok":true,"result":{"message_id":42}}')),
      200,
    );
  }
}

/// A Telegram service that always reports failure, used to prove the POS sale
/// still commits when notification cannot be delivered.
class _AlwaysFailingTelegramService implements TelegramService {
  int calls = 0;

  @override
  bool get isEnabled => true;

  @override
  TelegramConfig get config => const TelegramConfig();

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }

  @override
  Future<TelegramSendResult> sendTransactionNotification(TransactionNotifData data) async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }

  @override
  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data) async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }

  @override
  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data) async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }

  @override
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }

  @override
  Future<TelegramSendResult> sendShiftReport(ShiftReportData report) async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }

  @override
  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items) async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }

  @override
  Future<TelegramSendResult> testConnection() async {
    calls++;
    return TelegramSendResult.failure(message: 'simulated failure', statusCode: 500);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Placeholder only — never a real credential.
  const fakeToken = '000000:FAKE_TOKEN_PLACEHOLDER_NOT_REAL';
  const fakeRelaySecret = 'fake-relay-secret-not-real';

  group('1. bot token is never persisted to browser configuration', () {
    test('toJson() omits botToken for every integration mode', () {
      for (final mode in TelegramIntegrationMode.values) {
        final config = TelegramConfig(
          integrationMode: mode,
          botToken: fakeToken,
          relaySecret: fakeRelaySecret,
        );
        final json = config.toJson();
        expect(
          json.containsKey('botToken'),
          isFalse,
          reason: 'botToken must never be serialized (mode: $mode)',
        );
        expect(json.values, isNot(contains(fakeToken)));
      }
    });

    test('fromJson() ignores a legacy persisted botToken', () {
      // Simulates loading a config written by an older, insecure build.
      final restored = TelegramConfig.fromJson({
        'integrationMode': 'directBotApi',
        'botToken': fakeToken,
      });

      expect(
        restored.botToken,
        isNull,
        reason: 'a previously stored token must be discarded, not rehydrated',
      );
    });

    test('round-trip through JSON loses the token but keeps the relay secret', () {
      final original = TelegramConfig(
        integrationMode: TelegramIntegrationMode.relayWebhook,
        botToken: fakeToken,
        relaySecret: fakeRelaySecret,
      );
      final restored = TelegramConfig.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );

      expect(restored.botToken, isNull);
      expect(restored.relaySecret, fakeRelaySecret,
          reason: 'the relay secret is a client credential, not a bot secret');
    });
  });

  group('1b. relay secret can be set, retained, and explicitly cleared', () {
    const stored = 'previously-stored-relay-secret';

    test('setting a new secret replaces the previous one', () {
      const base = TelegramConfig(relaySecret: stored);

      final updated = base.copyWith(relaySecret: 'brand-new-secret');

      expect(updated.relaySecret, 'brand-new-secret');
    });

    test('retaining works when the value is supplied again', () {
      const base = TelegramConfig(relaySecret: stored);

      // Passing the same value through is the normal "saved unchanged" path.
      final updated = base.copyWith(relaySecret: stored);

      expect(updated.relaySecret, stored);
    });

    test('copyWith without touching relaySecret keeps the existing value', () {
      const base = TelegramConfig(relaySecret: stored);

      final updated = base.copyWith(chatId: '-1009999999999');

      expect(updated.relaySecret, stored,
          reason: 'unrelated edits must not drop the secret');
      expect(updated.chatId, '-1009999999999');
    });

    test('clearRelaySecret removes the value', () {
      const base = TelegramConfig(relaySecret: stored);

      final cleared = base.copyWith(clearRelaySecret: true);

      expect(cleared.relaySecret, isNull,
          reason: 'a compromised secret must be revocable from the UI');
    });

    test('clearRelaySecret wins over a supplied value', () {
      const base = TelegramConfig(relaySecret: stored);

      final cleared = base.copyWith(
        relaySecret: 'ignored',
        clearRelaySecret: true,
      );

      expect(cleared.relaySecret, isNull);
    });

    test('a cleared secret does not come back after a save/load round-trip', () {
      const base = TelegramConfig(
        integrationMode: TelegramIntegrationMode.relayWebhook,
        relaySecret: stored,
      );

      // Simulate the Settings save flow: an emptied field yields null PLUS the
      // explicit clear flag, and the result is then persisted and reloaded.
      final cleared = base.copyWith(clearRelaySecret: true);
      expect(cleared.relaySecret, isNull);

      final serialized = jsonEncode(cleared.toJson());
      expect(serialized, isNot(contains(stored)),
          reason: 'the old secret must not survive serialization');

      final reloaded = TelegramConfig.fromJson(jsonDecode(serialized));
      expect(reloaded.relaySecret, isNull);
    });

    test('clearing does not disturb the other Telegram fields', () {
      const base = TelegramConfig(
        relaySecret: stored,
        botUsername: '@KeepMe',
        chatId: '-1001234567890',
        integrationMode: TelegramIntegrationMode.relayWebhook,
      );

      final cleared = base.copyWith(clearRelaySecret: true);

      expect(cleared.botUsername, '@KeepMe');
      expect(cleared.chatId, '-1001234567890');
      expect(cleared.integrationMode, TelegramIntegrationMode.relayWebhook);
      expect(cleared.relaySecret, isNull);
    });
  });

  group('2. public demo mode never calls Telegram directly', () {
    test('directBotApi makes zero HTTP requests in public demo', () async {
      final client = _RecordingHttpClient();
      final service = TelegramBotService(
        config: const TelegramConfig(
          integrationMode: TelegramIntegrationMode.directBotApi,
          botToken: fakeToken,
          chatId: '-1001234567890',
        ),
        isPublicDemo: true,
        httpClient: client,
      );

      final result = await service.sendMessage('should not be delivered');

      expect(result.success, isTrue, reason: 'simulation still reports success');
      expect(result.rawResponse['simulated'], isTrue);
      expect(_requests(client), isEmpty,
          reason: 'no network call may happen in public demo mode');
    });

    test('relay requests carry the X-Relay-Secret header', () async {
      final client = _RecordingHttpClient();
      final service = TelegramBotService(
        config: TelegramConfig(
          integrationMode: TelegramIntegrationMode.relayWebhook,
          endpoint: 'https://relay.test',
          chatId: '-1001234567890',
          relaySecret: fakeRelaySecret,
        ),
        isPublicDemo: false,
        httpClient: client,
      );

      await service.sendMessage('report');

      final sent = _requests(client);
      expect(sent, hasLength(1));
      expect(sent.first.headers['X-Relay-Secret'], fakeRelaySecret,
          reason: 'relay calls must be authenticated server-to-server');
      expect(sent.first.url.path, '/telegram/send');
    });

    test('relay without a secret fails locally and makes no request', () async {
      final client = _RecordingHttpClient();
      final service = TelegramBotService(
        config: const TelegramConfig(
          integrationMode: TelegramIntegrationMode.relayWebhook,
          endpoint: 'https://relay.test',
          chatId: '-1001234567890',
        ),
        isPublicDemo: false,
        httpClient: client,
      );

      final result = await service.sendMessage('report');

      expect(result.success, isFalse);
      expect(result.statusCode, 401);
      expect(_requests(client), isEmpty);
    });

    test('token is redacted from surfaced error messages', () async {
      final client = _RecordingHttpClient()..shouldFail = true;
      final service = TelegramBotService(
        config: const TelegramConfig(
          integrationMode: TelegramIntegrationMode.directBotApi,
          botToken: fakeToken,
          chatId: '-1001234567890',
        ),
        isPublicDemo: false,
        httpClient: client,
      );

      final result = await service.sendMessage('report');

      expect(result.success, isFalse);
      expect(result.message, isNot(contains(fakeToken)),
          reason: 'the bot token must never reach the UI or a log line');
    });
  });

  group('3. Telegram failure never breaks a committed POS transaction', () {
    test('sale still completes and deducts stock when notify fails', () async {
      SharedPreferences.setMockInitialValues({});
      final pos = PosProvider();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      pos.login('cashier', 'cashier123');

      final failing = _AlwaysFailingTelegramService();
      pos.setTelegramService(failing);

      final product = pos.activeProducts.firstWhere((p) => p.stock > 0);
      final stockBefore = product.stock;
      final ordersBefore = pos.orders.length;

      pos.addToCart(product, qty: 1);
      final prepared = pos.prepareCheckoutOrder();
      final completed = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 100000000,
        changeAmount: 0,
      );

      // The transaction committed despite the notification failing.
      expect(completed.status, OrderStatus.paid);
      expect(pos.orders.length, ordersBefore + 1);
      expect(pos.orders.first.orderNumber, prepared.orderNumber);
      expect(product.stock, stockBefore - 1,
          reason: 'inventory deduction must still be applied');
      expect(pos.cart, isEmpty, reason: 'the cart must be cleared');

      // Give the fire-and-forget notification a chance to run and fail.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(failing.calls, greaterThan(0),
          reason: 'the notification really was attempted');
    });

    test('a failed notification stays eligible for a retry', () async {
      SharedPreferences.setMockInitialValues({});
      final pos = PosProvider();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      pos.login('cashier', 'cashier123');

      final failing = _AlwaysFailingTelegramService();
      pos.setTelegramService(failing);

      final product = pos.activeProducts.firstWhere((p) => p.stock > 0);
      pos.addToCart(product, qty: 1);
      pos.prepareCheckoutOrder();
      final order = pos.completePayment(
        method: PaymentMethod.cash,
        paidAmount: 100000000,
        changeAmount: 0,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final callsAfterFirstAttempt = failing.calls;

      // Retry the same order. Because the dedup key is only recorded on
      // success, a second attempt must actually be made.
      await pos.telegramNotificationService.onTransactionCompleted(order);
      expect(failing.calls, callsAfterFirstAttempt + 1,
          reason: 'a failed send must not burn the duplicate-suppression key');
    });
  });
}

/// Helper: pull the recorded requests out of the recording client.
List<http.Request> _requests(_RecordingHttpClient client) => client.requests;
