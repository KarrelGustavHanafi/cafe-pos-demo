import '../models/cart_item.dart';

/// Result of cart total calculations
class CartTotals {
  final int subtotal;
  final int serviceCharge;
  final int tax;
  final int grandTotal;

  const CartTotals({
    required this.subtotal,
    required this.serviceCharge,
    required this.tax,
    required this.grandTotal,
  });

  @override
  String toString() =>
      'CartTotals(subtotal: $subtotal, serviceCharge: $serviceCharge, tax: $tax, grandTotal: $grandTotal)';
}

/// Pure utility for calculating cart totals.
/// Does not depend on ChangeNotifier, storage, or side effects.
class CartCalculator {
  /// Calculate cart totals from cart items and configuration.
  ///
  /// Parameters:
  /// - [items]: List of cart items (will not be mutated)
  /// - [taxRate]: Tax rate as a decimal (e.g., 0.10 for 10%)
  /// - [serviceChargeRate]: Service charge rate as a decimal (e.g., 0.05 for 5%)
  /// - [isTaxEnabled]: Whether tax should be applied
  /// - [isServiceEnabled]: Whether service charge should be applied
  ///
  /// Returns a [CartTotals] object with calculated values.
  static CartTotals calculate({
    required List<CartItem> items,
    required double taxRate,
    required double serviceChargeRate,
    required bool isTaxEnabled,
    required bool isServiceEnabled,
  }) {
    // Calculate subtotal: sum of each item's itemTotal
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.itemTotal);

    // Calculate service charge: zero if disabled, else (subtotal * rate).round()
    final serviceCharge = isServiceEnabled
        ? (subtotal * serviceChargeRate).round()
        : 0;

    // Calculate tax: zero if disabled, else (subtotal * rate).round()
    final tax = isTaxEnabled
        ? (subtotal * taxRate).round()
        : 0;

    // Grand total: subtotal + service charge + tax
    final grandTotal = subtotal + serviceCharge + tax;

    return CartTotals(
      subtotal: subtotal,
      serviceCharge: serviceCharge,
      tax: tax,
      grandTotal: grandTotal,
    );
  }
}
