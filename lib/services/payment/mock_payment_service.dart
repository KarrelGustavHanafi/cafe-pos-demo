import 'dart:async';
import '../../models/order.dart';
import 'payment_service.dart';

class MockPaymentService implements PaymentService {
  PaymentStatus _status = PaymentStatus.idle;
  final _controller = StreamController<PaymentStatus>.broadcast();
  String? _activeTxId;

  @override
  PaymentStatus get currentStatus => _status;

  @override
  Stream<PaymentStatus> get statusStream => _controller.stream;

  void _setStatus(PaymentStatus status) {
    _status = status;
    _controller.add(status);
  }

  @override
  Future<PaymentResult> createPayment({
    required String orderNumber,
    required int amount,
    required PaymentMethod method,
    Map<String, dynamic>? metadata,
  }) async {
    _activeTxId = 'TX-${DateTime.now().millisecondsSinceEpoch}';
    _setStatus(PaymentStatus.pending);

    // Instant/near-instant for cash or manual methods
    await Future.delayed(const Duration(milliseconds: 250));
    _setStatus(PaymentStatus.waiting);

    return PaymentResult(
      success: true,
      status: _status,
      message: 'Transaksi $orderNumber siap diproses',
      transactionId: _activeTxId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> getPaymentStatus(String transactionId) async {
    return PaymentResult(
      success: _status == PaymentStatus.success,
      status: _status,
      message: 'Status: ${_status.name}',
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> cancelPayment(String transactionId) async {
    _setStatus(PaymentStatus.cancelled);
    return PaymentResult(
      success: true,
      status: PaymentStatus.cancelled,
      message: 'Pembayaran dibatalkan',
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> completePayment(String transactionId) async {
    _setStatus(PaymentStatus.success);
    return PaymentResult.success(
      transactionId: transactionId,
      message: 'Pembayaran tunai/manual berhasil diselesaikan.',
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}
