import 'package:intl/intl.dart';
import 'order.dart';
import 'business_config.dart';

class ReceiptItem {
  final String name;
  final int quantity;
  final int unitPrice;
  final List<String> modifiers;
  final int totalPrice;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.modifiers = const [],
    required this.totalPrice,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'modifiers': modifiers,
        'totalPrice': totalPrice,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
      modifiers: (json['modifiers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReceiptData {
  final String businessName;
  final String address;
  final String phone;

  /// Stable internal identity of the order this receipt was produced for.
  ///
  /// Carried so a stored receipt can be located by the same key the rest of the
  /// application uses. [orderNumber] is a display label and can legitimately
  /// repeat (a rejected stale-shift order is re-prepared without advancing the
  /// sequence), so it must never be used to identify a specific transaction.
  ///
  /// Never printed; the visible receipt header still shows [orderNumber].
  final String orderId;
  final String orderNumber;
  final DateTime dateTime;
  final String cashierName;
  final String tableNumber;
  final List<ReceiptItem> items;
  final int subtotal;
  final double serviceChargeRate;
  final int serviceChargeAmount;
  final double taxRate;
  final int taxAmount;
  final int total;
  final String paymentMethod;
  final String paymentStatus;
  final int paidAmount;
  final int changeAmount;
  final String footer;
  final PrinterWidthType widthType;

  const ReceiptData({
    required this.businessName,
    required this.address,
    required this.phone,
    this.orderId = '',
    required this.orderNumber,
    required this.dateTime,
    required this.cashierName,
    required this.tableNumber,
    required this.items,
    required this.subtotal,
    required this.serviceChargeRate,
    required this.serviceChargeAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paidAmount,
    required this.changeAmount,
    required this.footer,
    this.widthType = PrinterWidthType.mm80,
  });

  factory ReceiptData.fromOrder(Order order, BusinessConfig config) {
    final receiptItems = order.items.map((cartItem) {
      final mods = cartItem.selectedModifiers.map((m) => m.name).toList();
      return ReceiptItem(
        name: cartItem.product.name,
        quantity: cartItem.quantity,
        unitPrice: cartItem.unitPrice,
        modifiers: mods,
        totalPrice: cartItem.itemTotal,
      );
    }).toList();

    return ReceiptData(
      businessName: config.businessName,
      address: config.address,
      phone: config.phone,
      orderId: order.id,
      orderNumber: order.orderNumber,
      dateTime: order.createdAt,
      cashierName: order.cashierName,
      tableNumber: order.tableNumber,
      items: receiptItems,
      subtotal: order.subtotal,
      serviceChargeRate: config.serviceChargeRate,
      serviceChargeAmount: order.serviceCharge,
      taxRate: config.taxRate,
      taxAmount: order.tax,
      total: order.grandTotal,
      paymentMethod: order.paymentMethod.label,
      paymentStatus: order.status == OrderStatus.paid ? 'PAID' : order.status.label.toUpperCase(),
      paidAmount: order.paidAmount,
      changeAmount: order.changeAmount,
      footer: config.receiptFooter,
      widthType: config.printerWidth,
    );
  }

  String get formattedDateTime {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'address': address,
        'phone': phone,
        'orderNumber': orderNumber,
        'dateTime': dateTime.toIso8601String(),
        'cashierName': cashierName,
        'tableNumber': tableNumber,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'serviceChargeRate': serviceChargeRate,
        'serviceChargeAmount': serviceChargeAmount,
        'taxRate': taxRate,
        'taxAmount': taxAmount,
        'total': total,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'paidAmount': paidAmount,
        'changeAmount': changeAmount,
        'footer': footer,
        'widthType': widthType.name,
      };
}
