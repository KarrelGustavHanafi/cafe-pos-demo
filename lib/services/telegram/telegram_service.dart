import '../../models/business_config.dart';

// ─── Transaction notification (sent after successful payment) ─────────────────
class TransactionNotifData {
  final String orderNumber;
  final String cashierName;
  final String? tableNumber;
  final List<({String name, String? modifiers, int price})> items;
  final String paymentMethod;
  final int grandTotal;
  final DateTime timestamp;

  const TransactionNotifData({
    required this.orderNumber,
    required this.cashierName,
    this.tableNumber,
    required this.items,
    required this.paymentMethod,
    required this.grandTotal,
    required this.timestamp,
  });
}

// ─── Inventory update notification (sent after stock deduction) ───────────────
class InventoryUpdateData {
  final String orderNumber;
  final List<({String name, double amount, String unit})> deductions;

  const InventoryUpdateData({
    required this.orderNumber,
    required this.deductions,
  });
}

// ─── Shift open notification ──────────────────────────────────────────────────
class ShiftOpenData {
  final String cashierName;
  final int openingCash;
  final DateTime time;

  const ShiftOpenData({
    required this.cashierName,
    required this.openingCash,
    required this.time,
  });
}

class DailyReportData {
  final DateTime date;
  final int totalTransactions;
  final int totalSales;
  final int cashSales;
  final int qrisSales;
  final int debitSales;
  final int totalItemsSold;
  final int averageOrderValue;
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
    this.totalItemsSold = 0,
    this.averageOrderValue = 0,
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
  final int qrisSales;
  final int totalSales;
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
    this.qrisSales = 0,
    this.totalSales = 0,
    required this.totalTransactions,
    this.notes,
  });
}

class LowStockItemData {
  final String? id;
  final String name;
  final num currentStock;
  final num minimumStock;
  final String unit;

  const LowStockItemData({
    this.id,
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

  Future<TelegramSendResult> sendTransactionNotification(TransactionNotifData data);

  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data);

  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items);

  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data);

  Future<TelegramSendResult> sendShiftReport(ShiftReportData report);

  Future<TelegramSendResult> sendDailyReport(DailyReportData report);

  Future<TelegramSendResult> testConnection();
}
