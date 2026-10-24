import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/screens/shift/shift_closing_screen.dart';
import 'package:cafe_pos_demo/services/telegram/telegram_service.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';

/// In-memory Telegram double. It never constructs an HTTP client, so no test in
/// this file can reach the real Telegram API.
class _FakeTelegram implements TelegramService {
  _FakeTelegram({
    required this.enabled,
    this.failResult = false,
  });

  bool enabled;
  bool failResult;
  int shiftReports = 0;

  @override
  bool get isEnabled => enabled;

  @override
  TelegramConfig get config => const TelegramConfig();

  TelegramSendResult _result() => failResult
      ? TelegramSendResult.failure(message: 'relay unreachable', statusCode: 500)
      : TelegramSendResult.success(message: 'ok');

  @override
  Future<TelegramSendResult> sendMessage(String text, {String? parseMode}) async =>
      _result();

  @override
  Future<TelegramSendResult> sendTransactionNotification(
          TransactionNotifData data) async =>
      _result();

  @override
  Future<TelegramSendResult> sendInventoryUpdate(InventoryUpdateData data) async =>
      _result();

  @override
  Future<TelegramSendResult> sendLowStockAlert(List<LowStockItemData> items) async =>
      _result();

  @override
  Future<TelegramSendResult> sendShiftOpen(ShiftOpenData data) async => _result();

  @override
  Future<TelegramSendResult> sendShiftReport(ShiftReportData report) async {
    shiftReports++;
    return _result();
  }

  @override
  Future<TelegramSendResult> sendDailyReport(DailyReportData report) async =>
      _result();

  @override
  Future<TelegramSendResult> testConnection() async => _result();
}

/// The close-shift status must always lead with the closed shift, and report the
/// Telegram outcome as a separate, truthful line:
///
///  * configured off  -> "Notifikasi Telegram (Demo)" + "belum diaktifkan"
///  * configured on but send failed -> "Shift berhasil ditutup" + explicit
///    failure note, never "not active"
///  * configured on but nothing dispatched -> "tidak terkirim", not "inactive"
///
/// A Telegram problem must never read as a failed shift close.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({PosProvider pos, _FakeTelegram telegram})> closeShiftScreen(
    WidgetTester tester, {
    required bool telegramConfigured,
    required bool serviceEnabled,
    bool failResult = false,
  }) async {
    await initializeDateFormatting('id_ID');
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final pos = PosProvider();
    // No `Future.delayed` wait here: inside `testWidgets` the clock is fake and
    // only advances on `pump`, so awaiting a delay before the first pump hangs.

    await pos.updateBusinessConfig(
      pos.businessConfig.copyWith(
        isPublicDemo: true,
        telegramConfig: pos.businessConfig.telegramConfig.copyWith(
          enabled: telegramConfigured,
        ),
      ),
    );

    // Installed after updateBusinessConfig, which rebuilds the real service.
    final telegram = _FakeTelegram(
      enabled: serviceEnabled,
      failResult: failResult,
    );
    pos.setTelegramService(telegram);

    await tester.pumpWidget(
      MaterialApp(
        home: ShiftClosingScreen(pos: pos, onBackToDashboard: () {}),
      ),
    );
    await tester.pump();

    final confirm = find.text('Konfirmasi Tutup Shift Sekarang');
    expect(confirm, findsOneWidget);
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    return (pos: pos, telegram: telegram);
  }

  group('close-shift Telegram wording', () {
    testWidgets('Telegram off: closed status plus the demo wording',
        (tester) async {
      final r = await closeShiftScreen(
        tester,
        telegramConfigured: false,
        serviceEnabled: false,
      );

      // Primary status: the shift really did close.
      expect(find.text('Shift berhasil ditutup'), findsOneWidget);
      // Separate, exact demo disclosure.
      expect(find.text('Notifikasi Telegram (Demo)'), findsOneWidget);
      expect(
        find.text('Pengiriman notifikasi Telegram belum diaktifkan pada demo ini.'),
        findsOneWidget,
      );
      // No failure language, and nothing was sent.
      expect(find.textContaining('gagal'), findsNothing);
      expect(r.telegram.shiftReports, 0);

      // The close itself is intact. `pastShifts` also holds the two seeded
      // historical shifts, so the newly closed one is at index 0.
      expect(r.pos.hasActiveShift, isFalse);
      expect(r.pos.pastShifts.first.shiftId, 'SHIFT-01');
    });

    testWidgets('send failure: close succeeds, failure reported separately',
        (tester) async {
      final r = await closeShiftScreen(
        tester,
        telegramConfigured: true,
        serviceEnabled: true,
        failResult: true,
      );

      expect(find.text('Shift berhasil ditutup'), findsOneWidget);
      expect(
        find.text('Notifikasi Telegram gagal dikirim. Penutupan shift tetap berhasil.'),
        findsOneWidget,
      );
      // A failed request is NOT a disabled integration, and no success is
      // claimed.
      expect(find.textContaining('belum diaktifkan'), findsNothing);
      expect(find.textContaining('berhasil dikirim ke Telegram'), findsNothing);
      expect(r.telegram.shiftReports, 1);

      // The business operation and its recap survive the reporting failure.
      expect(r.pos.hasActiveShift, isFalse);
      final archived = r.pos.pastShifts.first;
      expect(archived.summary, isNotNull);
      expect(archived.summary!.totalSales, r.pos.totalSalesForShift(archived.shiftId));
      expect(archived.summary!.cashSales, r.pos.cashSalesForShift(archived.shiftId));
      expect(archived.summary!.qrisSales, r.pos.qrisSalesForShift(archived.shiftId));
    });

    testWidgets('configured but nothing dispatched is not called inactive',
        (tester) async {
      final r = await closeShiftScreen(
        tester,
        telegramConfigured: true,
        serviceEnabled: false,
      );

      expect(find.text('Shift berhasil ditutup'), findsOneWidget);
      expect(
        find.text(
          'Notifikasi Telegram tidak terkirim untuk shift ini. Penutupan shift tetap berhasil.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('belum diaktifkan'), findsNothing);
      expect(r.telegram.shiftReports, 0);
      expect(r.pos.hasActiveShift, isFalse);
    });

    testWidgets('simulated delivery is disclosed as simulated', (tester) async {
      final r = await closeShiftScreen(
        tester,
        telegramConfigured: true,
        serviceEnabled: true,
      );

      expect(find.text('Shift berhasil ditutup'), findsOneWidget);
      expect(
        find.text('Laporan shift disimulasikan (Mock Telegram).'),
        findsOneWidget,
      );
      expect(find.textContaining('gagal'), findsNothing);
      expect(r.telegram.shiftReports, 1);
      expect(r.pos.hasActiveShift, isFalse);
    });
  });
}
