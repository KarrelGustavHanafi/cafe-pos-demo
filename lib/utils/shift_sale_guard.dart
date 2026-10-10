/// Guard helpers for cashier sale operations.
///
/// Covers every condition that must refuse a sale before it is committed:
///
/// * [ShiftSaleBlockedException] - no active shift (closed-shift guard).
/// * [InsufficientStockException] - finished-product stock or recipe
///   ingredients are insufficient for the cart.
/// * [InvalidPaymentException] - the payment itself cannot be settled
///   (empty order, or cash that does not cover the grand total).
///
/// All three share [PosSaleBlockedException] so the UI can render exactly one
/// cashier-facing message per blocked action.
///
/// The POS always holds exactly one current shift (`PosProvider.currentShift`).
/// There is no separate "no shift started" representation: an unopened shift and
/// a closed shift are both expressed by `ShiftInfo.isClosed == true`. Only a new
/// `startNewShift()` call re-opens the cashier.
library;

/// Base class for every cashier-facing "operation refused" condition.
///
/// Business logic throws instead of returning a "successful" no-op so callers
/// can never mistake a rejected operation for a completed one.
class PosSaleBlockedException implements Exception {
  /// Cashier-facing, user friendly explanation.
  final String message;

  const PosSaleBlockedException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a sale operation (add to cart, checkout, payment) is attempted
/// while no active shift exists.
class ShiftSaleBlockedException extends PosSaleBlockedException {
  const ShiftSaleBlockedException(super.message);
}

/// Thrown when a sale is refused because finished-product stock or the required
/// recipe ingredients are insufficient.
///
/// Validation runs before any mutation, so stock, adjustment history, cart,
/// order state and sales history all stay untouched.
class InsufficientStockException extends PosSaleBlockedException {
  /// Individual shortage descriptions, safe to show to the cashier.
  final List<String> issues;

  InsufficientStockException(List<String> issues)
      : issues = List<String>.unmodifiable(issues),
        super(_buildMessage(issues));

  static String _buildMessage(List<String> issues) {
    if (issues.isEmpty) return 'Stok tidak mencukupi untuk memproses pesanan.';
    return 'Stok tidak mencukupi: ${issues.join('; ')}';
  }
}

/// Raised when a payment is submitted for an order that cannot be settled,
/// e.g. an order with no items, or cash that does not cover the grand total.
class InvalidPaymentException extends PosSaleBlockedException {
  const InvalidPaymentException(super.message);
}

/// Default message used when a sale is blocked by the closed-shift guard.
const String shiftClosedSaleMessage =
    'Shift kasir sudah ditutup. Buka shift baru sebelum memproses penjualan.';