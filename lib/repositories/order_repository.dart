/// Storage and query boundary for orders.
///
/// ## Why this exists
///
/// Before this boundary, `PosProvider` held orders in a private `List<Order>`
/// and every report re-derived the same filters from that raw list. The
/// "paid only" rule was written out seven separate times, the shift-membership
/// rule twice, and the date-window rule once more. That duplication is what let
/// the dashboard and the period reports disagree: nothing forced them to share a
/// definition, because each simply re-implemented one.
///
/// This repository owns the storage and the *selection* of orders, so those
/// predicates now exist exactly once. `PosProvider` keeps business meaning:
/// what a shift is, when one may be opened, when a sale may be committed, and
/// how a drawer total is derived. It still owns orchestration and settlement.
///
/// ## Deliberately NOT here
///
///  * No persistence, database, API or backend. The implementation is in-memory
///    and process-local.
///  * No other entity. Products, materials, stock adjustments and shifts are
///    untouched; a repository per entity would be structure without a caller.
///  * No business rules that need a clock or a shift: [periodWindow] semantics,
///    shift opening/closing and sale eligibility deliberately stay in the
///    provider.
///  * No events, no dependency-injection container.
///
/// ## Identity
///
/// Orders are identified by [Order.id], never by [Order.orderNumber]. The order
/// number is a human-facing label that can legitimately repeat (a rejected
/// stale-shift order is re-prepared without advancing the sequence), so using it
/// as a key lets one real sale suppress another's notification.
library;

import '../models/order.dart';

/// Read/write access to the order collection.
abstract class OrderRepository {
  /// Every stored order, newest first (most recently added is index 0).
  ///
  /// The returned list is unmodifiable: callers must not mutate stored state
  /// through it.
  List<Order> get all;

  /// Number of stored orders.
  int get count;

  /// Stores [order] as the newest entry.
  void insert(Order order);

  /// Stores [orders] in order, so `orders.first` becomes the newest entry.
  ///
  /// Used for seeding. Existing contents are replaced.
  void replaceAll(List<Order> orders);

  /// Drops every stored entry after index [length].
  ///
  /// This exists solely so a failed sale can roll its order list back to the
  /// length captured before the attempt, mirroring how stock and adjustment
  /// history are rolled back.
  ///
  /// NOT a general delete contract. Positional truncation is meaningless
  /// against a durable store; a persistent implementation must delete by
  /// [Order.id] and the caller must be updated in step. Throws [RangeError]
  /// when [length] is outside `0..count`, in every build mode.
  void truncateTo(int length);

  /// The stored order with [id], or `null` when no such order exists.
  Order? findById(String id);

  /// Every stored order whose status is `paid`.
  List<Order> get paidOrders;

  /// Every paid order attributed to [shiftId].
  ///
  /// Membership is decided by [Order.shiftId] alone, never by timestamp: a
  /// shift may cross midnight and a second shift may open on the same calendar
  /// day, so a date window cannot separate them.
  ///
  /// Orders whose `shiftId` is `null` are excluded. They are unknown-origin and
  /// must never be folded into whichever shift happens to be open; use
  /// [unattributedPaidCashOrders] to surface them instead.
  List<Order> paidOrdersForShift(String? shiftId);

  /// Every paid order attributed to [shiftId] and settled with [method].
  ///
  /// This is what keeps non-cash tender out of a physical drawer: only a `cash`
  /// query result may contribute to expected ending cash.
  List<Order> paidOrdersForShiftAndMethod(String? shiftId, PaymentMethod method);

  /// Every paid order whose calendar date lies within [start]..[end].
  ///
  /// The composition of the two independent filters above, provided because
  /// "paid sales in a reporting window" is the question nearly every report
  /// actually asks. Returning it from here keeps the paid rule from being
  /// re-stated in each report getter, which is how those getters previously
  /// drifted apart.
  List<Order> paidOrdersInDateRange(DateTime start, DateTime end);

  /// Every stored order whose calendar date lies within [start]..[end].
  ///
  /// Both endpoints are inclusive and only the calendar date is compared, so a
  /// sale at 23:59 still belongs to that day. Times are local; no UTC
  /// conversion is applied. Status is deliberately NOT filtered — callers
  /// decide eligibility, because "orders in range" and "paid orders in range"
  /// are genuinely different questions.
  List<Order> ordersInDateRange(DateTime start, DateTime end);

  /// Every paid cash order with no shift attribution.
  ///
  /// These are deliberately excluded from every shift total. Exposing them lets
  /// the UI state the excluded amount instead of quietly dropping it.
  List<Order> get unattributedPaidCashOrders;
}

/// In-memory [OrderRepository].
///
/// Process-local and non-durable: a reload starts empty. That is an accepted
/// demo limitation, not an oversight — no operational data is persisted
/// anywhere in this application yet.
class InMemoryOrderRepository implements OrderRepository {
  final List<Order> _orders = <Order>[];

  InMemoryOrderRepository([List<Order>? initialOrders]) {
    if (initialOrders != null) {
      replaceAll(initialOrders);
    }
  }

  @override
  List<Order> get all => List.unmodifiable(_orders);

  @override
  int get count => _orders.length;

  @override
  void insert(Order order) {
    _orders.insert(0, order);
  }

  @override
  void replaceAll(List<Order> orders) {
    _orders
      ..clear()
      ..addAll(orders);
  }

  @override
  void truncateTo(int length) {
    // Runtime validation, not `assert`: assertions are stripped from release
    // builds, and a bad length here would throw a bare RangeError from
    // `removeRange` *inside PosProvider's catch handler* — turning a recoverable
    // rollback failure into half-restored state. Failing loudly here keeps the
    // rollback guarantee debuggable in every build mode.
    //
    // NOTE: this is an internal rollback seam for the current synchronous
    // design (see the atomicity contract on `PosProvider.completePayment`). It
    // is deliberately NOT a general delete contract: positional truncation has
    // no meaning against a database. A durable implementation must delete by
    // `Order.id` instead, and `PosProvider` must change with it.
    if (length < 0 || length > _orders.length) {
      throw RangeError.range(
        length,
        0,
        _orders.length,
        'truncateTo',
        'Rollback target length is outside the current order count; the order '
            'collection changed during settlement, so a length-based rollback '
            'is no longer safe.',
      );
    }
    if (length < _orders.length) {
      _orders.removeRange(length, _orders.length);
    }
  }

  @override
  Order? findById(String id) {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  @override
  List<Order> get paidOrders =>
      _orders.where((o) => o.status == OrderStatus.paid).toList();

  @override
  List<Order> paidOrdersForShift(String? shiftId) {
    if (shiftId == null) return const <Order>[];
    final target = shiftId.trim();
    return _orders
        .where((o) =>
            o.status == OrderStatus.paid && o.shiftId == target)
        .toList();
  }

  @override
  List<Order> paidOrdersForShiftAndMethod(
      String? shiftId, PaymentMethod method) {
    if (shiftId == null) return const <Order>[];
    final target = shiftId.trim();
    return _orders
        .where((o) =>
            o.status == OrderStatus.paid &&
            o.shiftId == target &&
            o.paymentMethod == method)
        .toList();
  }

  @override
  List<Order> paidOrdersInDateRange(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return _orders.where((o) {
      if (o.status != OrderStatus.paid) return false;
      final orderDate =
          DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
      return !orderDate.isBefore(startDate) && !orderDate.isAfter(endDate);
    }).toList();
  }

  @override
  List<Order> ordersInDateRange(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return _orders.where((o) {
      final orderDate =
          DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
      return !orderDate.isBefore(startDate) && !orderDate.isAfter(endDate);
    }).toList();
  }

  @override
  List<Order> get unattributedPaidCashOrders => _orders
      .where((o) =>
          o.status == OrderStatus.paid &&
          o.shiftId == null &&
          o.paymentMethod == PaymentMethod.cash)
      .toList();
}