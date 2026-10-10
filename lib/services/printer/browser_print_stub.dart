// Stub implementation for non-web platforms
Future<void> triggerBrowserPrint({
  required String businessName,
  required String address,
  required String phone,
  required String orderNumber,
  required String dateTime,
  required String cashierName,
  required String tableNumber,
  required List<Map<String, dynamic>> items,
  required int subtotal,
  required double serviceChargeRate,
  required int serviceChargeAmount,
  required double taxRate,
  required int taxAmount,
  required int total,
  required String paymentMethod,
  required String paymentStatus,
  required int paidAmount,
  required int changeAmount,
  required String footer,
  required String widthType,
}) async {
  // No-op on non-web platforms
}
