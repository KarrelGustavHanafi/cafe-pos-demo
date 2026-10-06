import '../../models/business_config.dart';

class DailyReportData {
  final DateTime date;
  final int totalTransactions;
  final int totalSales;
  final int cashSales;
  final int qrisSales;
  final int debitSales;
  final List<MapEntry<String, int>> topProducts;
  final List<String> lowStockItems;
  final ShiftReportData? shiftReport;

  const DailyReportData({
    required this.date,
    required this.totalTransactions,
    required this.totalSales,
    required this.cashSales,
    required this.qrisSales,
    this.debitSales = 0,
    required this.topProducts,
    required this.lowStockItems,
    this.shiftReport,
  });
}

class ShiftReportData {
  final String shiftName;
  final String cashierName;
  final DateTime startTime;
  final DateTime? endTime;
  final int startingCash;
  final int expectedEndingCash;
  final int actualEndingCash;
  final int variance;
  final int cashSales;
  final int totalTransactions;
  final String? notes;

  const ShiftReportData({
    required this.shiftName,
    required this.cashierName,
    required this.startTime,
    this.endTime,
    required this.startingCash,
    required this.expectedEndingCash,
    required this.actualEndingCash,
    required this.variance,
    required this.cashSales,
    required this.totalTransactions,
    this.notes,
  });
}

class LowStockItemData {
  final String name;
  final num currentStock;
  final num minimumStock;
  final String unit;

  const LowStockItemData({
    required this.name,
    required this.currentStock,
    required this.minimumStock,
    required this.unit,
  });
}

class TelegramSendResult {
  final bool success;
  final String message;
  final int? messageId;
  final int statusCode;
  final dynamic rawResponse;

  const TelegramSendResult({
    required this.success,
    required this.message,
    this.messageId,
    this.statusCode = 200,
    this.rawResponse,
  });

  factory TelegramSendResult.success({
    required String message,
    int? messageId,
    dynamic rawResponse,
  }) {
    return TelegramSendResult(
      success: true,
      message: message,
      messageId: messageId,
      statusCode: 200,
      rawResponse: rawResponse,
    );
  }

  factory TelegramSendResult.failure({
    required String message,
    int statusCode = 500,
    dynamic rawResponse,
  }) {
    return TelegramSendResult(
      success: false,
      message: message,
      statusCode: statusCode,
      rawResponse: rawResponse,
    );
  }
}

abstract class TelegramService {
  bool get isEnabled;
  TelegramConfig get config;

  Future<TelegramSendResult> sendMessage(String text, {String? parseMode});

  Future<TelegramSendResult> sendDailyReport(DailyReportData report);

  Future<TelegramSendResult> sendShiftReport(ShiftReportData report);

  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items);

  Future<TelegramSendResult> testConnection();
}
