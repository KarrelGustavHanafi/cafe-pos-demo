import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_bot_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/screens/shift/shift_closing_screen.dart';

/// Mock HTTP client that tracks request count without making real network calls
class MockHttpClient extends http.BaseClient {
  int requestCount = 0;
  List<http.Request> capturedRequests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requestCount++;
    capturedRequests.add(request as http.Request);
    
    // Return a mock success response
    return Future.value(http.StreamedResponse(
      Stream.fromIterable([utf8.encode('{"ok":true,"result":{"message_id":123}}')]),
      200,
      request: request,
    ));
  }
}

void main() {
  group('Public Demo Telegram Security Tests', () {
    test('Direct Bot API is hidden from UI in public demo mode', () {
      // Create a public demo config
      final publicConfig = BusinessConfig.defaultCaffeDemo();
      
      // Verify isPublicDemo defaults to true
      expect(publicConfig.isPublicDemo, true);
      
      // Verify getSafeMode replaces Direct Bot API with Mock Simulation in public demo
      final directApiConfig = publicConfig.telegramConfig.copyWith(
        integrationMode: TelegramIntegrationMode.directBotApi,
      );
      final safeMode = directApiConfig.getSafeMode(publicConfig.isPublicDemo);
      
      expect(safeMode, TelegramIntegrationMode.mockSimulation);
      expect(safeMode, isNot(TelegramIntegrationMode.directBotApi));
    });

    test('Direct Bot API is preserved in non-public mode', () {
      // Create a non-public config for local testing
      final localConfig = BusinessConfig.defaultCaffeDemo().copyWith(
        isPublicDemo: false,
      );
      
      // Verify isPublicDemo is false
      expect(localConfig.isPublicDemo, false);
      
      // Verify getSafeMode preserves Direct Bot API in non-public mode
      final directApiConfig = localConfig.telegramConfig.copyWith(
        integrationMode: TelegramIntegrationMode.directBotApi,
      );
      final safeMode = directApiConfig.getSafeMode(localConfig.isPublicDemo);
      
      expect(safeMode, TelegramIntegrationMode.directBotApi);
    });

    test('Mock Simulation is always available regardless of demo mode', () {
      final publicConfig = BusinessConfig.defaultCaffeDemo();
      final localConfig = BusinessConfig.defaultCaffeDemo().copyWith(
        isPublicDemo: false,
      );
      
      final mockConfig = publicConfig.telegramConfig.copyWith(
        integrationMode: TelegramIntegrationMode.mockSimulation,
      );
      
      expect(mockConfig.getSafeMode(publicConfig.isPublicDemo), TelegramIntegrationMode.mockSimulation);
      expect(mockConfig.getSafeMode(localConfig.isPublicDemo), TelegramIntegrationMode.mockSimulation);
    });

    test('Relay Webhook is always available regardless of demo mode', () {
      final publicConfig = BusinessConfig.defaultCaffeDemo();
      final localConfig = BusinessConfig.defaultCaffeDemo().copyWith(
        isPublicDemo: false,
      );
      
      final relayConfig = publicConfig.telegramConfig.copyWith(
        integrationMode: TelegramIntegrationMode.relayWebhook,
      );
      
      expect(relayConfig.getSafeMode(publicConfig.isPublicDemo), TelegramIntegrationMode.relayWebhook);
      expect(relayConfig.getSafeMode(localConfig.isPublicDemo), TelegramIntegrationMode.relayWebhook);
    });

    test('isPublicDemo flag is persisted and loaded correctly', () {
      final config = BusinessConfig.defaultCaffeDemo().copyWith(
        isPublicDemo: true,
      );
      
      final json = config.toJson();
      expect(json['isPublicDemo'], true);
      
      final loaded = BusinessConfig.fromJson(json);
      expect(loaded.isPublicDemo, true);
    });

    test('Old saved Direct Bot API config falls back to Mock Simulation in public demo', () {
      // Simulate old saved config with Direct Bot API mode
      final oldJson = {
        'businessName': 'CAFFE',
        'telegramConfig': {
          'enabled': true,
          'botUsername': '@CaffePosBot',
          'chatId': '-1002938472910',
          'endpoint': 'https://api.telegram.org',
          'integrationMode': 'directBotApi',
          'testMode': true,
          'botToken': 'dummy-token-for-test',
        },
        'isPublicDemo': true,
      };
      
      final loaded = BusinessConfig.fromJson(oldJson);
      
      // Verify the loaded mode is converted to safe mode
      final safeMode = loaded.telegramConfig.getSafeMode(loaded.isPublicDemo);
      expect(safeMode, TelegramIntegrationMode.mockSimulation);
      
      // Verify botToken is still present in loaded config (not deleted)
      expect(loaded.telegramConfig.botToken, 'dummy-token-for-test');
    });

    test('Direct Bot API HTTP request is blocked in public demo mode', () async {
      // Create a mock HTTP client to track requests (configured to not throw)
      final mockClient = MockHttpClient();
      
      // Configure TelegramBotService with Direct Bot API mode in public demo
      final config = const TelegramConfig(
        enabled: true,
        botUsername: '@TestBot',
        chatId: '-1001234567890',
        endpoint: 'https://api.telegram.org',
        integrationMode: TelegramIntegrationMode.directBotApi,
        testMode: true,
        botToken: 'FAKE_TEST_TOKEN_123456789', // Clearly fake test token
      );
      
      final service = TelegramBotService(
        config: config,
        isPublicDemo: true, // Critical: public demo mode enabled
        httpClient: mockClient,
      );
      
      // Attempt to send a message
      final result = await service.sendMessage('Test message for HTTP blocking verification');
      
      // Verify the result is marked as simulated (not a real delivery)
      expect(result.success, isTrue, reason: 'Should return success even when blocked');
      expect(result.message, contains('disimulasikan'), reason: 'Message should indicate simulation');
      expect(result.message, contains('Direct Bot API dinonaktifkan'), reason: 'Should mention Direct Bot API is disabled');
      expect(result.rawResponse['simulated'], isTrue, reason: 'rawResponse should have simulated flag');
      expect(result.rawResponse['publicDemoMode'], isTrue, reason: 'rawResponse should have publicDemoMode flag');
      
      // Verify NO HTTP request was made (the critical security check)
      expect(mockClient.requestCount, 0, reason: 'No HTTP requests should be made in public demo mode');
      expect(mockClient.capturedRequests, isEmpty, reason: 'No requests should be captured');
    });

    test('Direct Bot API HTTP request is allowed in non-public mode', () async {
      // Create a mock HTTP client that returns a success response
      final mockClient = MockHttpClient();
      
      // Configure TelegramBotService with Direct Bot API mode in NON-public mode
      final config = const TelegramConfig(
        enabled: true,
        botUsername: '@TestBot',
        chatId: '-1001234567890',
        endpoint: 'https://api.telegram.org',
        integrationMode: TelegramIntegrationMode.directBotApi,
        testMode: true,
        botToken: 'FAKE_TEST_TOKEN_123456789',
      );
      
      final service = TelegramBotService(
        config: config,
        isPublicDemo: false, // Critical: NOT public demo mode
        httpClient: mockClient,
      );
      
      // Attempt to send a message - this should make an HTTP request
      final result = await service.sendMessage('Test message');
      
      // Verify the result was successful (mock returned success)
      expect(result.success, isTrue, reason: 'Should succeed with mock response');
      
      // Verify an HTTP request WAS attempted (this is the key difference from public demo mode)
      expect(mockClient.requestCount, 1, reason: 'HTTP request should be attempted in non-public mode');
      expect(mockClient.capturedRequests.length, 1, reason: 'One request should be captured');
      
      // Verify the request was to Telegram API
      final capturedRequest = mockClient.capturedRequests.first;
      expect(capturedRequest.url.toString(), contains('api.telegram.org'), reason: 'Should request Telegram API');
      expect(capturedRequest.url.toString(), contains('FAKE_TEST_TOKEN_123456789'), reason: 'Should include bot token in URL');
    });

    testWidgets('Shift closing displays simulated feedback when in mock/public demo mode', (WidgetTester tester) async {
      // Initialize locale for date formatting
      await initializeDateFormatting('id_ID');

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pos = PosProvider();
      // Start a shift to have something to close
      pos.startNewShift(startingCash: 300000);

      await tester.pumpWidget(
        MaterialApp(
          home: ShiftClosingScreen(
            pos: pos,
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pump();

      final confirmBtn = find.text('Konfirmasi Tutup Shift Sekarang');
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Should indicate simulation truthfully in the SnackBar
      expect(find.textContaining('disimulasikan'), findsOneWidget);
      expect(find.textContaining('Mock Telegram'), findsOneWidget);
    });
  });
}
