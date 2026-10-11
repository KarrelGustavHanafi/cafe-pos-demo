// Locks transaction identity on the receipt reprint path (Phase 2C.2).
//
// The defect: `ReceiptService.reprintReceipt` located a stored receipt by
// `orderNumber`. That is a *display* label which can legitimately repeat — a
// rejected stale-shift order is re-prepared without advancing the sequence — so
// matching on it would return whichever receipt happened to be printed first,
// silently reprinting the wrong customer's receipt.
//
// Lookup now keys on `Order.id`, carried through `ReceiptData.orderId`.
//
// No test prints anything: a recording `PrinterService` double is injected, so
// no printer, browser, socket or external service is contacted.

import 'package:cafe_pos_demo/models/business_config.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/models/receipt_data.dart';
import 'package:cafe_pos_demo/services/printer/printer_service.dart';
import 'package:cafe_pos_demo/services/receipt/receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what would have been printed. Never touches hardware or a browser.
class _RecordingPrinter implements PrinterService {
  final List<ReceiptData> printed = [];

  @override
  PrinterModeType get mode => PrinterModeType.preview;

  @override
  PrinterConnectionState get connectionState => PrinterConnectionState.ready;

  @override
  Future<PrinterResult> printReceipt(ReceiptData receipt) async {
    printed.add(receipt);
    return PrinterResult.success(message: 'recorded');
  }

  @override
  Future<PrinterResult> testPrint() async =>
      PrinterResult.success(message: 'recorded');

  @override
  Future<PrinterConnectionState> checkStatus() async =>
      PrinterConnectionState.ready;
}

/// Two DIFFERENT orders that deliberately share one display order number.
///
/// This is the real hazard: a stale-shift order is rejected and re-prepared, so
/// the sequence does not advance and both carry the same `orderNumber`.
({Order first, Order second}) collidingOrders() {
  const displayNumber = 'ORD-20260315-0007';
  final created = DateTime(2026, 3, 15, 10, 30);
  return (
    first: Order.create(
      orderNumber: displayNumber,
      tableNumber: 'Takeaway',
      items: const [],
      cashierName: 'Siti Rahma (Kasir)',
      createdAt: created,
      shiftId: 'SHIFT-A',
    ),
    second: Order.create(
      orderNumber: displayNumber,
      tableNumber: 'Takeaway',
      items: const [],
      cashierName: 'Siti Rahma (Kasir)',
      createdAt: created.add(const Duration(hours: 2)),
      shiftId: 'SHIFT-B',
    ),
  );
}

void main() {
  const config = BusinessConfig();

  group('ReceiptData carries stable identity', () {
    test('fromOrder copies Order.id into orderId', () {
      final pair = collidingOrders();
      final data = ReceiptData.fromOrder(pair.first, config);

      expect(data.orderId, pair.first.id);
      expect(data.orderId, isNot(pair.second.id));
      expect(data.orderNumber, pair.first.orderNumber);
    });

    test('orderNumber stays the display label', () {
      final pair = collidingOrders();
      final data = ReceiptData.fromOrder(pair.first, config);

      // Unchanged receipt contract: the printed number is still the display one.
      expect(data.orderNumber, 'ORD-20260315-0007');
    });
  });

  group('reprint selects by identity, not by display number', () {
    test('two orders sharing a display number do not collide', () async {
      final printer = _RecordingPrinter();
      final service = ReceiptService(printerService: printer);
      final pair = collidingOrders();

      // Sanity: the fixture really is a collision.
      expect(pair.first.orderNumber, pair.second.orderNumber);
      expect(pair.first.id, isNot(pair.second.id));

      // Print the FIRST order, then the second (history is newest-first).
      await service.printOrderReceipt(pair.first, config);
      await service.printOrderReceipt(pair.second, config);
      expect(printer.printed.length, 2);

      printer.printed.clear();

      // Reprint the FIRST (older) order by its stable id.
      await service.reprintReceipt(pair.first.id);

      expect(printer.printed.length, 1);
      expect(
        printer.printed.single.orderId,
        pair.first.id,
        reason: 'must reprint the requested transaction, not the newest',
      );
      expect(
        printer.printed.single.dateTime,
        pair.first.createdAt,
        reason: 'the correct receipt body was selected',
      );
      // Both receipts display the same number; identity is what disambiguated.
      expect(printer.printed.single.orderNumber, pair.second.orderNumber);
    });

    test('reprinting the second order selects the second order', () async {
      final printer = _RecordingPrinter();
      final service = ReceiptService(printerService: printer);
      final pair = collidingOrders();

      await service.printOrderReceipt(pair.first, config);
      await service.printOrderReceipt(pair.second, config);
      printer.printed.clear();

      await service.reprintReceipt(pair.second.id);

      expect(printer.printed.single.orderId, pair.second.id);
      expect(printer.printed.single.dateTime, pair.second.createdAt);
    });

    test('the old display-number lookup would have chosen wrongly', () async {
      // Documents WHY the key changed: with newest-first history, matching on
      // the shared display number returns the *second* order for both requests.
      final printer = _RecordingPrinter();
      final service = ReceiptService(printerService: printer);
      final pair = collidingOrders();

      await service.printOrderReceipt(pair.first, config);
      await service.printOrderReceipt(pair.second, config);

      final naiveMatches = service.receiptHistory
          .where((r) => r.orderNumber == pair.first.orderNumber)
          .toList();

      expect(naiveMatches.length, 2,
          reason: 'both receipts share the display number');
      expect(naiveMatches.first.orderId, pair.second.id,
          reason: 'a display-number lookup resolves to the newest one');
    });
  });

  group('reprint fallbacks are preserved', () {
    test('an unknown id falls back to the most recent receipt', () async {
      final printer = _RecordingPrinter();
      final service = ReceiptService(printerService: printer);
      final pair = collidingOrders();

      await service.printOrderReceipt(pair.second, config);
      printer.printed.clear();

      await service.reprintReceipt('id-that-does-not-exist');

      expect(printer.printed.length, 1);
      expect(printer.printed.single.orderId, pair.second.id,
          reason: 'fallback to last receipt is unchanged behaviour');
    });

    test('with no history at all, reprint throws', () async {
      final printer = _RecordingPrinter();
      final service = ReceiptService(printerService: printer);

      expect(
        () => service.reprintReceipt('anything'),
        throwsA(isA<StateError>()),
      );
    });

    test('reprintLastReceipt is unaffected', () async {
      final printer = _RecordingPrinter();
      final service = ReceiptService(printerService: printer);
      final pair = collidingOrders();

      await service.printOrderReceipt(pair.first, config);
      await service.printOrderReceipt(pair.second, config);
      printer.printed.clear();

      await service.reprintLastReceipt();

      expect(printer.printed.single.orderId, pair.second.id);
    });
  });
}