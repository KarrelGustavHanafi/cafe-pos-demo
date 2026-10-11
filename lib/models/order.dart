import 'cart_item.dart';

enum PaymentMethod {
  cash('Tunai (Cash)'),
  qris('QRIS'),
  debitCard('Kartu Debit / EDC');

  final String label;
  const PaymentMethod(this.label);
}

enum OrderStatus {
  pending('Menunggu Pembayaran'),
  paid('Selesai / Lunas'),
  cancelled('Dibatalkan');

  final String label;
  const OrderStatus(this.label);
}

class Order {
  /// Stable internal identity of this order.
  ///
  /// Distinct from [orderNumber], which is a *display* label a human reads and
  /// which is reused: two orders prepared in the same session can legitimately
  /// render the same number (a rejected stale order is re-prepared without
  /// ever being committed, so the sequence does not advance).
  ///
  /// Anything that must not confuse two different sales — notification
  /// deduplication, idempotency keys — must key on this, never on
  /// [orderNumber].
  ///
  /// SCOPE: this is unique within one running application instance only. It is
  /// generated locally and carries no server authority, so it must NOT be
  /// treated as a globally unique or tamper-proof transaction reference. A
  /// real deployment needs a server-assigned identifier for that.
  final String id;

  /// Human-facing order label, e.g. `ORD-20260315-0004`.
  ///
  /// Kept separate from [id] precisely because this value can repeat while
  /// [id] cannot.
  final String orderNumber;
  final String tableNumber;

  /// Human-readable seating label.
  ///
  /// Seating is free-choice, so new orders carry `Takeaway` and must never be
  /// rendered as "Meja Takeaway". Legacy orders that recorded a real table
  /// (A03, B01, ...) still show it.
  String get tableLabel => tableNumber.trim().isEmpty ||
          tableNumber.toLowerCase() == 'takeaway'
      ? 'Takeaway'
      : 'Meja $tableNumber';
  final List<CartItem> items;
  final int subtotal;
  final int serviceCharge; // 5%
  final int tax; // 10%
  final int grandTotal;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final int paidAmount;
  final int changeAmount;
  final DateTime createdAt;
  final String cashierName;

  /// The shift this order was settled under, or `null` when the origin is
  /// unknown.
  ///
  /// Cash reconciliation is scoped by this field, NOT by timestamp. A shift can
  /// run past midnight and a new shift can open on the same calendar day, so a
  /// date window cannot tell two shifts apart. Only membership can.
  ///
  /// `null` means "not attributable to any shift" — such orders are deliberately
  /// EXCLUDED from shift cash reconciliation rather than silently folded into
  /// whichever shift happens to be open. See `MockData` for the explicit seed
  /// policy and `PosProvider.expectedEndingCashForShift`.
  final String? shiftId;

  const Order({
    this.id = '',
    required this.orderNumber,
    required this.tableNumber,
    required this.items,
    required this.subtotal,
    required this.serviceCharge,
    required this.tax,
    required this.grandTotal,
    this.paymentMethod = PaymentMethod.cash,
    this.status = OrderStatus.pending,
    this.paidAmount = 0,
    this.changeAmount = 0,
    required this.createdAt,
    required this.cashierName,
    this.shiftId,
  });

  /// Monotonic counter backing [create]'s generated identity.
  ///
  /// Instance-local by construction: it only ever increases for the lifetime of
  /// one running application, which is exactly the uniqueness scope [id]
  /// documents. It deliberately does not pretend to be a durable sequence.
  static int _identityCounter = 0;

  /// Generates an identity that cannot repeat within this application instance.
  ///
  /// Combines a timestamp with a monotonic counter because the counter alone
  /// resets on restart, while the timestamp alone can repeat when two orders are
  /// created inside the same millisecond.
  static String _generateId() {
    _identityCounter++;
    return 'ord_${DateTime.now().microsecondsSinceEpoch}_$_identityCounter';
  }

  static Order create({
    required String orderNumber,
    required String tableNumber,
    required List<CartItem> items,
    required String cashierName,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    OrderStatus status = OrderStatus.pending,
    int paidAmount = 0,
    int changeAmount = 0,
    DateTime? createdAt,
    double taxRate = 0.10,
    double serviceChargeRate = 0.05,
    bool isTaxEnabled = true,
    bool isServiceEnabled = true,
    String? shiftId,
    String? id,
  }) {
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.itemTotal);
    final serviceCharge = isServiceEnabled
        ? (subtotal * serviceChargeRate).round()
        : 0;
    final tax = isTaxEnabled
        ? (subtotal * taxRate).round()
        : 0;
    final grandTotal = subtotal + serviceCharge + tax;

    return Order(
      // A caller-supplied id is honoured (tests, seeds); otherwise one is
      // generated so every order created through this factory has a distinct
      // identity even when two share a display number.
      id: id ?? _generateId(),
      orderNumber: orderNumber,
      tableNumber: tableNumber,
      items: List.unmodifiable(items),
      subtotal: subtotal,
      serviceCharge: serviceCharge,
      tax: tax,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
      status: status,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      createdAt: createdAt ?? DateTime.now(),
      cashierName: cashierName,
      shiftId: shiftId,
    );
  }

  Order copyWith({
    String? orderNumber,
    String? tableNumber,
    List<CartItem>? items,
    int? subtotal,
    int? serviceCharge,
    int? tax,
    int? grandTotal,
    PaymentMethod? paymentMethod,
    OrderStatus? status,
    int? paidAmount,
    int? changeAmount,
    DateTime? createdAt,
    String? cashierName,
    String? shiftId,
    bool clearShiftId = false,
    String? id,
  }) {
    return Order(
      // Identity is immutable across the whole order lifecycle. `completePayment`
      // settles via copyWith, so a regenerated id here would break idempotency
      // and notification deduplication.
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tax: tax ?? this.tax,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      createdAt: createdAt ?? this.createdAt,
      cashierName: cashierName ?? this.cashierName,
      // `completePayment` uses copyWith to settle the order, so preserving
      // shiftId here is what keeps the sale attached to its shift.
      shiftId: clearShiftId ? null : (shiftId ?? this.shiftId),
    );
  }
}