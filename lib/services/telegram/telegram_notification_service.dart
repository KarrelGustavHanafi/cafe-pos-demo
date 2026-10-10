import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/order.dart';
import '../../models/shift.dart';
import 'telegram_service.dart';

/// Central coordinator that receives POS Business Events and dispatches
/// corresponding notifications to [TelegramService] with duplicate prevention,
/// state tracking, and non-blocking failure resilience.
class TelegramNotificationService {
  TelegramService _telegramService;

  /// Tracks order numbers that have already been notified to avoid duplicates.
  final Set<String> _processedOrderNumbers = <String>{};

  /// Tracks ingredient / product IDs currently below threshold to prevent repeat alert spam.
  final Set<String> _lowStockAlertedIds = <String>{};

  /// Tracks shift IDs that have already been notified to avoid duplicate shift reports.
  final Set<String> _processedShiftIds = <String>{};

  TelegramNotificationService(this._telegramService);

  set telegramService(TelegramService service) {
    _telegramService = service;
  }

  bool get isEnabled => _telegramService.isEnabled;

  /// Check if an order has already been processed for notifications.
  bool isOrderProcessed(String orderNumber) => _processedOrderNumbers.contains(orderNumber);

  /// ─── 1. TRANSACTION COMPLETED (Payment Success) ───────────────────────────
  /// Triggered strictly AFTER payment is successfully completed.
  /// Also sends inventory update and low stock alert if applicable.
  Future<void> onTransactionCompleted(
    Order order, {
    List<({String name, double amount, String unit})>? deductions,
    List<LowStockItemData>? newlyLowStockItems,
  }) async {
    // Duplicate prevention: ensure an order is notified exactly once
    if (_processedOrderNumbers.contains(order.orderNumber)) {
      debugPrint('[TelegramNotification] Order ${order.orderNumber} already processed. Skipping duplicate.');
      return;
    }
    _processedOrderNumbers.add(order.orderNumber);

    if (!_telegramService.isEnabled) {
      debugPrint('[TelegramNotification] Telegram is disabled. Skipping transaction notification.');
      return;
    }

    // 1a. Send Successful Transaction Notification
    try {
      final notifData = TransactionNotifData(
        orderNumber: order.orderNumber,
        cashierName: order.cashierName,
        tableNumber: order.tableNumber,
        items: order.items.map((item) {
          final mod = item.hasModifiers ? item.modifierSummary : null;
          return (name: item.product.name, modifiers: mod, price: item.itemTotal);
        }).toList(),
        paymentMethod: order.paymentMethod.name.toUpperCase(),
        grandTotal: order.grandTotal,
        timestamp: order.createdAt,
      );

      final result = await _telegramService.sendTransactionNotification(notifData);
      if (!result.success) {
        debugPrint('[TelegramNotification] Transaction notification failed: ${result.message}');
      }
    } catch (e, stack) {
      // Telegram failure must NEVER break the POS transaction
      debugPrint('[TelegramNotification] Exception sending transaction notification: $e\n$stack');
    }

    // 1b. Send Inventory Deduction Notification (only if inventory actually changed)
    if (deductions != null && deductions.isNotEmpty) {
      try {
        final invData = InventoryUpdateData(
          orderNumber: order.orderNumber,
          deductions: deductions,
        );
        final result = await _telegramService.sendInventoryUpdate(invData);
        if (!result.success) {
          debugPrint('[TelegramNotification] Inventory deduction notification failed: ${result.message}');
        }
      } catch (e, stack) {
        debugPrint('[TelegramNotification] Exception sending inventory update: $e\n$stack');
      }
    }

    // 1c. Send Low Stock Alert (with duplicate spam suppression)
    if (newlyLowStockItems != null && newlyLowStockItems.isNotEmpty) {
      final itemsToAlert = <LowStockItemData>[];
      for (final item in newlyLowStockItems) {
        final key = item.id ?? item.name;
        if (!_lowStockAlertedIds.contains(key)) {
          _lowStockAlertedIds.add(key);
          itemsToAlert.add(item);
        }
      }

      if (itemsToAlert.isNotEmpty) {
        try {
          final result = await _telegramService.sendLowStockAlert(itemsToAlert);
          if (!result.success) {
            debugPrint('[TelegramNotification] Low stock alert failed: ${result.message}');
          }
        } catch (e, stack) {
          debugPrint('[TelegramNotification] Exception sending low stock alert: $e\n$stack');
        }
      }
    }
  }

  /// ─── 2. LOW STOCK ALERT TRACKING MANAGEMENT ──────────────────────────────
  /// Call when item stock goes above threshold (restocked), allowing future alerts.
  void resetLowStockAlert(String itemId) {
    _lowStockAlertedIds.remove(itemId);
  }

  /// Seed initial low stock items so they are not treated as freshly crossed.
  void seedAlreadyLowStockItems(Iterable<String> itemIds) {
    _lowStockAlertedIds.addAll(itemIds);
  }

  /// Clear all duplicate and alert tracking (useful for test resets).
  void resetTracking() {
    _processedOrderNumbers.clear();
    _lowStockAlertedIds.clear();
    _processedShiftIds.clear();
  }

  /// ─── 3. SHIFT OPEN ────────────────────────────────────────────────────────
  Future<void> onShiftOpened(ShiftInfo shift) async {
    if (!_telegramService.isEnabled) return;

    try {
      final data = ShiftOpenData(
        cashierName: shift.cashierName,
        openingCash: shift.startingCash,
        time: shift.startTime,
      );
      final result = await _telegramService.sendShiftOpen(data);
      if (!result.success) {
        debugPrint('[TelegramNotification] Shift open notification failed: ${result.message}');
      }
    } catch (e, stack) {
      debugPrint('[TelegramNotification] Exception sending shift open notification: $e\n$stack');
    }
  }

  /// ─── 4. SHIFT CLOSED ──────────────────────────────────────────────────────
  Future<TelegramSendResult?> onShiftClosed(
    ShiftInfo shift, {
    required int totalSales,
    required int cashSales,
    required int qrisSales,
    required int totalTransactions,
  }) async {
    // Duplicate prevention: ensure a shift is notified exactly once
    if (_processedShiftIds.contains(shift.shiftId)) {
      debugPrint('[TelegramNotification] Shift ${shift.shiftId} already processed. Skipping duplicate.');
      return null;
    }
    _processedShiftIds.add(shift.shiftId);

    if (!_telegramService.isEnabled) {
      debugPrint('[TelegramNotification] Telegram is disabled. Skipping shift closed notification.');
      return null;
    }

    try {
      final expectedCash = shift.startingCash + cashSales;
      final actualCash = shift.actualEndingCash ?? expectedCash;
      final variance = actualCash - expectedCash;

      final data = ShiftReportData(
        shiftName: shift.shiftName,
        cashierName: shift.cashierName,
        startTime: shift.startTime,
        endTime: shift.closedAt ?? DateTime.now(),
        startingCash: shift.startingCash,
        expectedEndingCash: expectedCash,
        actualEndingCash: actualCash,
        variance: variance,
        cashSales: cashSales,
        qrisSales: qrisSales,
        totalSales: totalSales,
        totalTransactions: totalTransactions,
        notes: shift.closingNotes,
      );

      final result = await _telegramService.sendShiftReport(data);
      if (!result.success) {
        debugPrint('[TelegramNotification] Shift closed notification failed: ${result.message}');
      }
      return result;
    } catch (e, stack) {
      debugPrint('[TelegramNotification] Exception sending shift closed notification: $e\n$stack');
      return TelegramSendResult.failure(
        message: 'Gagal mengirim laporan shift: $e',
        statusCode: 500,
      );
    }
  }

  /// ─── 5. DAILY OWNER REPORT ────────────────────────────────────────────────
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) async {
    if (!_telegramService.isEnabled) {
      return TelegramSendResult.failure(
        message: 'Integrasi Telegram sedang dinonaktifkan di pengaturan.',
        statusCode: 400,
      );
    }

    try {
      return await _telegramService.sendDailyReport(report);
    } catch (e, stack) {
      debugPrint('[TelegramNotification] Exception sending daily report: $e\n$stack');
      return TelegramSendResult.failure(
        message: 'Gagal mengirim laporan harian: $e',
        statusCode: 500,
      );
    }
  }
}
