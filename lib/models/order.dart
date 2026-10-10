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
  final String orderNumber;
  final String tableNumber;
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

  const Order({
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
  });

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
  }) {
    return Order(
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
    );
  }
}
