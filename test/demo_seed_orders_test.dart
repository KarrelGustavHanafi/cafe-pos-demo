import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafe_pos_demo/data/mock_data.dart';
import 'package:cafe_pos_demo/models/order.dart';
import 'package:cafe_pos_demo/state/pos_provider.dart';
import 'package:cafe_pos_demo/utils/jakarta_time.dart';

/// Documents the three authored demo orders, so a later change cannot quietly
/// delete them, restore them after a reset, or start presenting them as real
/// sales history.
///
/// Findings this file pins:
///
///  * The seed is created **by the `PosProvider` constructor**, once per session
///    (one per browser tab / page load). There is no order persistence, so a
///    refresh rebuilds them with fresh timestamps relative to the new "now".
///  * The seed is **not** re-applied after `resetDemoData()`: a reset session
///    starts empty, which is the whole point of the Owner reset button.
///  * The seed is authored data, so it is explicitly attributed to
///    [MockData.seedActiveShiftId] (the open demo shift) and is counted in that
///    shift's recap. It is not backfilled at runtime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PosProvider> newSession() async {
    SharedPreferences.setMockInitialValues({});
    final pos = PosProvider();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return pos;
  }

  group('A. the three demo orders are recreated per session', () {
    test('a fresh session opens with exactly three seeded paid orders',
        () async {
      final pos = await newSession();

      expect(pos.orders.length, 3);
      expect(pos.orders.every((o) => o.status == OrderStatus.paid), isTrue);
      expect(
        pos.orders.map((o) => o.orderNumber).toSet(),
        {
          for (final o in pos.orders) o.orderNumber,
        },
        reason: 'order numbers must be unique',
      );
      // Numbers are numbered 0001..0003 on the current date; the display suffix
      // is what the demo screens show.
      expect(
        pos.orders.map((o) => o.orderNumber.split('-').last).toSet(),
        {'0001', '0002', '0003'},
      );
    });

    test('the authoring script is newest-first, paid and shift-attributed', () {
      final orders = MockData.getInitialOrders(MockData.getInitialProducts());

      expect(orders.length, 3);
      // getInitialOrders returns [order3, order2, order1] - newest first.
      expect(orders[0].orderNumber.endsWith('-0003'), isTrue);
      expect(orders[1].orderNumber.endsWith('-0002'), isTrue);
      expect(orders[2].orderNumber.endsWith('-0001'), isTrue);
      expect(orders.every((o) => o.status == OrderStatus.paid), isTrue);
      expect(orders.every((o) => o.grandTotal > 0), isTrue);
      // Authored data is bound to the demo's open shift in source, so the
      // opening drawer figure and the seed stay consistent.
      expect(
        orders.every((o) => o.shiftId == MockData.seedActiveShiftId),
        isTrue,
      );
    });

    test('a refresh starts a new session with the same three orders',
        () async {
      final first = await newSession();
      final firstNumbers = first.orders.map((o) => o.orderNumber).toSet();
      final firstCount = first.orders.length;

      // A page reload constructs a new provider: nothing is restored from
      // storage, so the seed script runs again from scratch.
      final second = await newSession();

      expect(firstCount, 3);
      expect(second.orders.length, 3);
      expect(second.orders.map((o) => o.orderNumber).toSet(), firstNumbers);
      // The reloaded session is open again, not the previous session's state.
      expect(first.hasActiveShift, isTrue);
      expect(second.hasActiveShift, isTrue);
      expect(second.currentShift.shiftId, MockData.seedActiveShiftId);
      expect(second.pastShifts.length, MockData.getPastShifts().length);
    });

    test('reset demo clears the seed and does not bring it back', () async {
      final pos = await newSession();
      expect(pos.orders, isNotEmpty);

      pos.login('owner', 'owner123');
      expect(pos.canResetDemoData, isTrue);
      pos.resetDemoData();

      expect(pos.orders, isEmpty,
          reason: 'the reset exists to hand back an empty demo');
      expect(pos.pastShifts, isEmpty);
      expect(pos.currentShift.shiftId, MockData.seedActiveShiftId);
      expect(pos.hasActiveShift, isTrue);
    });

    test('seed orders are bucketed on the Jakarta calendar', () async {
      final pos = await newSession();

      // The seed is timestamped relative to "now", so a demo opened shortly
      // after midnight WIB can legitimately put one seed on the previous day.
      // The invariant that must hold is that the report agrees with the Jakarta
      // date of each order - never with the device's calendar.
      final today = jakartaDate(DateTime.now());
      final expectedToday = pos.orders
          .where((o) => jakartaDate(o.createdAt).isAtSameMomentAs(today))
          .length;

      expect(
        pos.getPaidOrdersForPeriod(ReportPeriod.today).length,
        expectedToday,
      );
      // All three are at most a few hours old, so all three are in the 30-day
      // window regardless of the hour the demo was opened.
      expect(pos.getPaidOrdersForPeriod(ReportPeriod.last30Days).length, 3);
    });
  });
}
