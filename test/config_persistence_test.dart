import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/services/storage/local_app_storage.dart';
import 'package:cafe_pos_demo/services/config/business_config_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Local Config Persistence Tests', () {
    test('1. Save config: saves business config into local storage', () async {
      final storage = LocalAppStorage();
      await storage.init();
      final configService = LocalBusinessConfigService(storage);
      await configService.init();

      final newConfig = BusinessConfig(
        businessName: 'TEST CAFFE',
        address: 'Jl. Testing No. 123',
        phone: '+62 899-9999-8888',
        taxPercent: 11.0,
        serviceChargePercent: 6.0,
        receiptFooter: 'Terima kasih atas kunjungan di TEST CAFFE!',
        printerWidth: PrinterWidthType.mm80,
        printerMode: PrinterModeType.escPos,
        telegramConfig: const TelegramConfig(
          enabled: true,
          botUsername: '@TestBot',
          chatId: '-10099999999',
          endpoint: 'https://api.telegram.org',
          integrationMode: TelegramIntegrationMode.relayWebhook,
          testMode: false,
        ),
        qrisConfig: const QrisConfig(
          enabled: true,
          merchantName: 'TEST CAFFE QRIS',
          merchantId: 'NMID: ID999888777',
          paymentMode: QrisPaymentMode.staticQris,
          providerName: 'BCA QRIS',
        ),
      );

      await configService.saveConfig(newConfig);

      final rawStored = await storage.getJson('caffe_business_config');
      expect(rawStored, isNotNull);
      expect(rawStored!['businessName'], 'TEST CAFFE');
      expect(rawStored['taxPercent'], 11.0);
      expect(rawStored['serviceChargePercent'], 6.0);
    });

    test('2. Load config: retrieves and parses saved config from local storage', () async {
      final storage = LocalAppStorage();
      await storage.init();

      final initialConfig = BusinessConfig(
        businessName: 'SAVED CAFFE',
        address: 'Jl. Melawai No. 10',
        phone: '+62 811-2233-4455',
        taxPercent: 12.0,
        serviceChargePercent: 7.0,
        receiptFooter: 'Custom Footer',
      );
      await storage.setJson('caffe_business_config', initialConfig.toJson());

      final configService = LocalBusinessConfigService(storage);
      await configService.init();

      expect(configService.config.businessName, 'SAVED CAFFE');
      expect(configService.config.address, 'Jl. Melawai No. 10');
      expect(configService.config.phone, '+62 811-2233-4455');
      expect(configService.config.taxPercent, 12.0);
      expect(configService.config.serviceChargePercent, 7.0);
      expect(configService.config.receiptFooter, 'Custom Footer');
    });

    test('3. Persistence after service reinitialization (simulating browser reload)', () async {
      // Step A: Save config via PosProvider
      final storage1 = LocalAppStorage();
      final pos1 = PosProvider(storage: storage1);
      await pos1.loadPersistedConfig();

      final updatedConfig = pos1.businessConfig.copyWith(
        businessName: 'TEST CAFFE RELOADED',
        taxPercent: 11.0,
        serviceChargePercent: 6.0,
        printerWidth: PrinterWidthType.mm80,
        printerMode: PrinterModeType.browserPrint,
      );
      await pos1.updateBusinessConfig(updatedConfig);

      // Step B: Reinitialize fresh storage & PosProvider (same backing SharedPreferences)
      final storage2 = LocalAppStorage();
      final pos2 = PosProvider(storage: storage2);
      await pos2.loadPersistedConfig();

      expect(pos2.businessConfig.businessName, 'TEST CAFFE RELOADED');
      expect(pos2.businessConfig.taxPercent, 11.0);
      expect(pos2.businessConfig.serviceChargePercent, 6.0);
      expect(pos2.businessConfig.printerWidth, PrinterWidthType.mm80);
      expect(pos2.businessConfig.printerMode, PrinterModeType.browserPrint);
      expect(pos2.settings.cafeName, 'TEST CAFFE RELOADED');
      expect(pos2.settings.taxRate, 0.11);
      expect(pos2.settings.serviceChargeRate, 0.06);
    });

    test('4. Default config when no saved data exists', () async {
      final storage = LocalAppStorage();
      await storage.init();
      final configService = LocalBusinessConfigService(storage);
      await configService.init();

      final def = BusinessConfig.defaultCaffeDemo();
      expect(configService.config.businessName, def.businessName);
      expect(configService.config.taxPercent, def.taxPercent);
      expect(configService.config.serviceChargePercent, def.serviceChargePercent);
      expect(configService.config.address, def.address);
      expect(configService.config.phone, def.phone);
    });

    test('5. Malformed stored data fallback: safely reverts to default config without crash', () async {
      final storage = LocalAppStorage();
      await storage.init();

      // Put malformed JSON string into storage
      await storage.setString('caffe_business_config', '{ corrupted_json: true, invalid... ');

      final configService = LocalBusinessConfigService(storage);
      // init should NOT throw
      await configService.init();

      final def = BusinessConfig.defaultCaffeDemo();
      expect(configService.config.businessName, def.businessName);
      expect(configService.config.taxPercent, def.taxPercent);

      // Also test corrupted field types in JSON map
      await storage.setString(
        'caffe_business_config',
        jsonEncode({
          'businessName': 12345, // int instead of String
          'taxPercent': 'not-a-number', // invalid string
          'serviceChargePercent': null,
          'printerWidth': 'unknown_printer_size',
          'qrisConfig': 'not-a-map',
          'telegramConfig': ['not-a-map'],
        }),
      );

      final configService2 = LocalBusinessConfigService(storage);
      await configService2.init();

      // Should safely parse with fallbacks and not throw
      expect(configService2.config.businessName, '12345');
      expect(configService2.config.taxPercent, 10.0);
      expect(configService2.config.serviceChargePercent, 5.0);
      expect(configService2.config.printerWidth, PrinterWidthType.mm80);
      expect(configService2.config.qrisConfig.enabled, isTrue);
      expect(configService2.config.telegramConfig.enabled, isTrue);
    });

    test('6. Business config values persist across save and load', () async {
      final storage = LocalAppStorage();
      final pos = PosProvider(storage: storage);
      await pos.loadPersistedConfig();

      final customBusiness = pos.businessConfig.copyWith(
        businessName: 'KOPI NUSANTARA',
        address: 'Jl. Sudirman No. 88, Jakarta Pusat',
        phone: '+62 813-8888-7777',
        taxPercent: 11.0,
        serviceChargePercent: 6.0,
        receiptFooter: 'Terima kasih telah singgah di Kopi Nusantara!',
      );

      await pos.updateBusinessConfig(customBusiness);

      // Verify POS calculation reflects updated tax and service charge
      pos.loadDemoQuickOrder(); // 53,000 subtotal
      expect(pos.cartSubtotal, 53000);
      expect(pos.cartTax, (53000 * 0.11).round()); // 5830
      expect(pos.cartServiceCharge, (53000 * 0.06).round()); // 3180

      // Re-read from storage
      final reloadedPos = PosProvider(storage: storage);
      await reloadedPos.loadPersistedConfig();

      expect(reloadedPos.businessConfig.businessName, 'KOPI NUSANTARA');
      expect(reloadedPos.businessConfig.address, 'Jl. Sudirman No. 88, Jakarta Pusat');
      expect(reloadedPos.businessConfig.phone, '+62 813-8888-7777');
      expect(reloadedPos.businessConfig.taxPercent, 11.0);
      expect(reloadedPos.businessConfig.serviceChargePercent, 6.0);
      expect(reloadedPos.businessConfig.receiptFooter, 'Terima kasih telah singgah di Kopi Nusantara!');
    });

    test('7. Telegram config persists across save and load', () async {
      final storage = LocalAppStorage();
      final pos = PosProvider(storage: storage);
      await pos.loadPersistedConfig();

      final customTelegram = const TelegramConfig(
        enabled: true,
        botUsername: '@PersistedBot',
        chatId: '-1008877665544',
        endpoint: 'https://relay.caffe.id/webhook',
        integrationMode: TelegramIntegrationMode.relayWebhook,
        testMode: false,
        botToken: 'demo_token_only',
      );

      await pos.updateBusinessConfig(pos.businessConfig.copyWith(telegramConfig: customTelegram));

      final reloadedPos = PosProvider(storage: storage);
      await reloadedPos.loadPersistedConfig();

      final t = reloadedPos.businessConfig.telegramConfig;
      expect(t.enabled, isTrue);
      expect(t.botUsername, '@PersistedBot');
      expect(t.chatId, '-1008877665544');
      expect(t.endpoint, 'https://relay.caffe.id/webhook');
      expect(t.integrationMode, TelegramIntegrationMode.relayWebhook);
      expect(t.testMode, isFalse);
      expect(t.botToken, 'demo_token_only');
    });

    test('8. QRIS config persists across save and load', () async {
      final storage = LocalAppStorage();
      final pos = PosProvider(storage: storage);
      await pos.loadPersistedConfig();

      final customQris = const QrisConfig(
        enabled: true,
        merchantName: 'WARUNG KOPI PERSISTED',
        merchantId: 'NMID: ID10987654321',
        qrImagePath: 'assets/images/qris_warung.png',
        paymentMode: QrisPaymentMode.staticQris,
        providerName: 'QRIS Bank Mandiri',
      );

      await pos.updateBusinessConfig(pos.businessConfig.copyWith(qrisConfig: customQris));

      final reloadedPos = PosProvider(storage: storage);
      await reloadedPos.loadPersistedConfig();

      final q = reloadedPos.businessConfig.qrisConfig;
      expect(q.enabled, isTrue);
      expect(q.merchantName, 'WARUNG KOPI PERSISTED');
      expect(q.merchantId, 'NMID: ID10987654321');
      expect(q.qrImagePath, 'assets/images/qris_warung.png');
      expect(q.paymentMode, QrisPaymentMode.staticQris);
      expect(q.providerName, 'QRIS Bank Mandiri');
    });

    test('9. Printer config persists across save and load', () async {
      final storage = LocalAppStorage();
      final pos = PosProvider(storage: storage);
      await pos.loadPersistedConfig();

      await pos.updateBusinessConfig(pos.businessConfig.copyWith(
        printerWidth: PrinterWidthType.mm80,
        printerMode: PrinterModeType.escPos,
      ));

      final reloadedPos = PosProvider(storage: storage);
      await reloadedPos.loadPersistedConfig();

      expect(reloadedPos.businessConfig.printerWidth, PrinterWidthType.mm80);
      expect(reloadedPos.businessConfig.printerMode, PrinterModeType.escPos);
      expect(reloadedPos.receiptService.printerService.mode, PrinterModeType.escPos);
    });
  });
}
