enum PrinterWidthType {
  mm80('80mm', 48),
  mm58('58mm', 32);

  final String label;
  final int maxColumns;
  const PrinterWidthType(this.label, this.maxColumns);
}

enum PrinterModeType {
  preview('Preview'),
  browserPrint('Browser Print'),
  escPos('ESC/POS Thermal');

  final String label;
  const PrinterModeType(this.label);
}

enum QrisPaymentMode {
  simulation('Simulasi QRIS'),
  staticQris('Static QRIS Display'),
  realGateway('Real Gateway (Backend)');

  final String label;
  const QrisPaymentMode(this.label);
}

enum TelegramIntegrationMode {
  mockSimulation('Simulasi Mock'),
  relayWebhook('Secure Relay Webhook'),
  directBotApi('Direct Bot API (Test Only)');

  final String label;
  const TelegramIntegrationMode(this.label);
}

class QrisConfig {
  final bool enabled;
  final String merchantName;
  final String merchantId;
  final String qrImagePath;
  final QrisPaymentMode paymentMode;
  final String providerName;

  const QrisConfig({
    this.enabled = true,
    this.merchantName = 'CAFFE OFFICIAL',
    this.merchantId = 'NMID: ID1020039281729',
    this.qrImagePath = '',
    this.paymentMode = QrisPaymentMode.simulation,
    this.providerName = 'Bank Indonesia / ASPI QRIS',
  });

  QrisConfig copyWith({
    bool? enabled,
    String? merchantName,
    String? merchantId,
    String? qrImagePath,
    QrisPaymentMode? paymentMode,
    String? providerName,
  }) {
    return QrisConfig(
      enabled: enabled ?? this.enabled,
      merchantName: merchantName ?? this.merchantName,
      merchantId: merchantId ?? this.merchantId,
      qrImagePath: qrImagePath ?? this.qrImagePath,
      paymentMode: paymentMode ?? this.paymentMode,
      providerName: providerName ?? this.providerName,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'merchantName': merchantName,
        'merchantId': merchantId,
        'qrImagePath': qrImagePath,
        'paymentMode': paymentMode.name,
        'providerName': providerName,
      };

  factory QrisConfig.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val, bool fallback) {
      if (val is bool) return val;
      if (val is String) {
        final lower = val.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
      return fallback;
    }

    return QrisConfig(
      enabled: parseBool(json['enabled'], true),
      merchantName: json['merchantName']?.toString() ?? 'CAFFE OFFICIAL',
      merchantId: json['merchantId']?.toString() ?? 'NMID: ID1020039281729',
      qrImagePath: json['qrImagePath']?.toString() ?? '',
      paymentMode: QrisPaymentMode.values.firstWhere(
        (m) => m.name == json['paymentMode'],
        orElse: () => QrisPaymentMode.simulation,
      ),
      providerName: json['providerName']?.toString() ?? 'Bank Indonesia / ASPI QRIS',
    );
  }
}

class TelegramConfig {
  final bool enabled;
  final String botUsername;
  final String chatId;
  final String endpoint;
  final TelegramIntegrationMode integrationMode;
  final bool testMode;
  // NOTE: SANDBOX ONLY — in-memory token for local Direct Bot API testing.
  //
  // This value is deliberately NEVER serialized to browser storage (see
  // [toJson]) and is NEVER rehydrated from storage (see [fromJson]). Any token
  // left in `localStorage` by an older build is ignored on load and discarded.
  //
  // The bot token for real deployments lives ONLY in the Cloudflare Worker's
  // `TELEGRAM_BOT_TOKEN` secret and never reaches browser code. Use
  // [TelegramIntegrationMode.relayWebhook] for anything beyond a local sandbox.
  final String? botToken;

  /// Shared secret used to authenticate this client against the relay Worker.
  ///
  /// Unlike [botToken] this is intentionally persisted so the owner does not
  /// retype it after every refresh. It authenticates the *application*, not a
  // user, and it does not grant access to the Telegram bot itself — the bot
  /// token stays server-side in the Worker.
  final String? relaySecret;

  const TelegramConfig({
    this.enabled = true,
    this.botUsername = '@CaffePosBot',
    this.chatId = '-1002938472910',
    this.endpoint = 'https://api.telegram.org',
    this.integrationMode = TelegramIntegrationMode.mockSimulation,
    this.testMode = true,
    this.botToken,
    this.relaySecret,
  });

  TelegramConfig copyWith({
    bool? enabled,
    String? botUsername,
    String? chatId,
    String? endpoint,
    TelegramIntegrationMode? integrationMode,
    bool? testMode,
    String? botToken,
    String? relaySecret,
    bool clearRelaySecret = false,
  }) {
    return TelegramConfig(
      enabled: enabled ?? this.enabled,
      botUsername: botUsername ?? this.botUsername,
      chatId: chatId ?? this.chatId,
      endpoint: endpoint ?? this.endpoint,
      integrationMode: integrationMode ?? this.integrationMode,
      testMode: testMode ?? this.testMode,
      botToken: botToken ?? this.botToken,
      // `clearRelaySecret` exists because a plain `relaySecret: null` is
      // indistinguishable from "not supplied" in a `??` chain, so clearing the
      // field in the UI would silently keep the previous secret — leaving no way
      // to revoke a compromised secret from the app. An explicit flag keeps the
      // clearing intent type-safe without a sentinel object.
      relaySecret: clearRelaySecret ? null : (relaySecret ?? this.relaySecret),
    );
  }

  /// Returns the safe integration mode for public demo.
  /// In public demo mode, Direct Bot API is automatically replaced with Mock Simulation.
  TelegramIntegrationMode getSafeMode(bool isPublicDemo) {
    if (isPublicDemo && integrationMode == TelegramIntegrationMode.directBotApi) {
      return TelegramIntegrationMode.mockSimulation;
    }
    return integrationMode;
  }

  Map<String, dynamic> toJson() {
    // SECURITY: `botToken` is NEVER written to browser storage.
    //
    // The Telegram bot token belongs only in the relay Worker's
    // `TELEGRAM_BOT_TOKEN` secret. Persisting it here would expose it to any
    // script on the origin (XSS), browser extensions, and shared-device forensics.
    // Direct Bot API is therefore a non-durable sandbox mode only: a token entered
    // there is used for the current session and discarded on reload.
    //
    // `relaySecret` is different: a client-to-worker shared secret that
    // authenticates this application to the relay. It is persisted on purpose so
    // the owner is not forced to retype it, and it grants no access to the bot.
    return <String, dynamic>{
      'enabled': enabled,
      'botUsername': botUsername,
      'chatId': chatId,
      'endpoint': endpoint,
      'integrationMode': integrationMode.name,
      'testMode': testMode,
      'relaySecret': relaySecret,
    };
  }

  factory TelegramConfig.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val, bool fallback) {
      if (val is bool) return val;
      if (val is String) {
        final lower = val.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
      return fallback;
    }

    // SECURITY: `botToken` is deliberately NOT read here.
    //
    // Older builds persisted the token into browser storage. Refusing to
    // rehydrate it means any previously stored credential is ignored and
    // effectively dead, so it cannot be used from the client even once.
    return TelegramConfig(
      enabled: parseBool(json['enabled'], true),
      botUsername: json['botUsername']?.toString() ?? '@CaffePosBot',
      chatId: json['chatId']?.toString() ?? '-1002938472910',
      endpoint: json['endpoint']?.toString() ?? 'https://api.telegram.org',
      integrationMode: TelegramIntegrationMode.values.firstWhere(
        (m) => m.name == json['integrationMode'],
        orElse: () => TelegramIntegrationMode.mockSimulation,
      ),
      testMode: parseBool(json['testMode'], true),
      relaySecret: json['relaySecret']?.toString(),
    );
  }
}

class BusinessConfig {
  final String businessName;
  final String logoUrl;
  final String address;
  final String phone;
  final String instagram;
  final String currency;
  final double taxPercent; // e.g. 10.0 (10%)
  final double serviceChargePercent; // e.g. 5.0 (5%)
  final bool isTaxEnabled;
  final bool isServiceEnabled;
  final String receiptFooter;
  final PrinterWidthType printerWidth;
  final PrinterModeType printerMode;
  final QrisConfig qrisConfig;
  final TelegramConfig telegramConfig;
  final String orderNumberPrefix;
  final int defaultLowStockThreshold;
  final bool isPublicDemo;

  const BusinessConfig({
    this.businessName = 'CAFFE',
    this.logoUrl = '',
    this.address = 'Jl. Senopati No. 45, Kebayoran Baru, Jakarta Selatan',
    this.phone = '+62 812-3456-7890',
    this.instagram = '@caffe.id',
    this.currency = 'Rp',
    this.taxPercent = 10.0,
    this.serviceChargePercent = 5.0,
    this.isTaxEnabled = true,
    this.isServiceEnabled = true,
    this.receiptFooter = 'Terima kasih atas kunjungan Anda di CAFFE!\nSemoga hari Anda menyenangkan.',
    this.printerWidth = PrinterWidthType.mm80,
    this.printerMode = PrinterModeType.preview,
    this.qrisConfig = const QrisConfig(),
    this.telegramConfig = const TelegramConfig(),
    this.orderNumberPrefix = 'ORD',
    this.defaultLowStockThreshold = 15,
    this.isPublicDemo = true,
  });

  double get taxRate => taxPercent / 100.0;
  double get serviceChargeRate => serviceChargePercent / 100.0;

  BusinessConfig copyWith({
    String? businessName,
    String? logoUrl,
    String? address,
    String? phone,
    String? instagram,
    String? currency,
    double? taxPercent,
    double? serviceChargePercent,
    bool? isTaxEnabled,
    bool? isServiceEnabled,
    String? receiptFooter,
    PrinterWidthType? printerWidth,
    PrinterModeType? printerMode,
    QrisConfig? qrisConfig,
    TelegramConfig? telegramConfig,
    String? orderNumberPrefix,
    int? defaultLowStockThreshold,
    bool? isPublicDemo,
  }) {
    return BusinessConfig(
      businessName: businessName ?? this.businessName,
      logoUrl: logoUrl ?? this.logoUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      instagram: instagram ?? this.instagram,
      currency: currency ?? this.currency,
      taxPercent: taxPercent ?? this.taxPercent,
      serviceChargePercent: serviceChargePercent ?? this.serviceChargePercent,
      isTaxEnabled: isTaxEnabled ?? this.isTaxEnabled,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      printerWidth: printerWidth ?? this.printerWidth,
      printerMode: printerMode ?? this.printerMode,
      qrisConfig: qrisConfig ?? this.qrisConfig,
      telegramConfig: telegramConfig ?? this.telegramConfig,
      orderNumberPrefix: orderNumberPrefix ?? this.orderNumberPrefix,
      defaultLowStockThreshold: defaultLowStockThreshold ?? this.defaultLowStockThreshold,
      isPublicDemo: isPublicDemo ?? this.isPublicDemo,
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'logoUrl': logoUrl,
        'address': address,
        'phone': phone,
        'instagram': instagram,
        'currency': currency,
        'taxPercent': taxPercent,
        'serviceChargePercent': serviceChargePercent,
        'isTaxEnabled': isTaxEnabled,
        'isServiceEnabled': isServiceEnabled,
        'receiptFooter': receiptFooter,
        'printerWidth': printerWidth.name,
        'printerMode': printerMode.name,
        'qrisConfig': qrisConfig.toJson(),
        'telegramConfig': telegramConfig.toJson(),
        'orderNumberPrefix': orderNumberPrefix,
        'defaultLowStockThreshold': defaultLowStockThreshold,
        'isPublicDemo': isPublicDemo,
      };

  factory BusinessConfig.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? fallback;
      return fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic val, bool fallback) {
      if (val is bool) return val;
      if (val is String) {
        final lower = val.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
      return fallback;
    }

    Map<String, dynamic>? safeMap(dynamic val) {
      if (val is Map<String, dynamic>) return val;
      if (val is Map) return Map<String, dynamic>.from(val);
      return null;
    }

    final rawQris = safeMap(json['qrisConfig']);
    final rawTelegram = safeMap(json['telegramConfig']);

    return BusinessConfig(
      businessName: json['businessName']?.toString() ?? 'CAFFE',
      logoUrl: json['logoUrl']?.toString() ?? '',
      address: json['address']?.toString() ?? 'Jl. Senopati No. 45, Kebayoran Baru, Jakarta Selatan',
      phone: json['phone']?.toString() ?? '+62 812-3456-7890',
      instagram: json['instagram']?.toString() ?? '@caffe.id',
      currency: json['currency']?.toString() ?? 'Rp',
      taxPercent: parseDouble(json['taxPercent'], 10.0),
      serviceChargePercent: parseDouble(json['serviceChargePercent'], 5.0),
      isTaxEnabled: parseBool(json['isTaxEnabled'], true),
      isServiceEnabled: parseBool(json['isServiceEnabled'], true),
      receiptFooter: json['receiptFooter']?.toString() ?? 'Terima kasih atas kunjungan Anda di CAFFE!\nSemoga hari Anda menyenangkan.',
      printerWidth: PrinterWidthType.values.firstWhere(
        (w) => w.name == json['printerWidth'],
        orElse: () => PrinterWidthType.mm80,
      ),
      printerMode: PrinterModeType.values.firstWhere(
        (m) => m.name == json['printerMode'],
        orElse: () => PrinterModeType.preview,
      ),
      qrisConfig: rawQris != null ? QrisConfig.fromJson(rawQris) : const QrisConfig(),
      telegramConfig: rawTelegram != null ? TelegramConfig.fromJson(rawTelegram) : const TelegramConfig(),
      orderNumberPrefix: json['orderNumberPrefix']?.toString() ?? 'ORD',
      defaultLowStockThreshold: parseInt(json['defaultLowStockThreshold'], 15),
      isPublicDemo: parseBool(json['isPublicDemo'], true),
    );
  }

  factory BusinessConfig.defaultCaffeDemo() => const BusinessConfig();
}
