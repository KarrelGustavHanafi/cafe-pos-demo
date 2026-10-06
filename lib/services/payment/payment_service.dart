import 'dart:async';
import '../../models/order.dart';

enum PaymentStatus {
  idle,
  pending,
  waiting,
  detected,
  verifying,
  success,
  failed,
  cancelled,
  expired;

  bool get isTerminal => this == success || this == failed || this == cancelled || this == expired;
  bool get isSuccess => this == success;
}

class PaymentResult {
  final bool success;
  final PaymentStatus status;
  final String message;
  final String? transactionId;
  final String? qrPayload;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const PaymentResult({
    required this.success,
    required this.status,
    required this.message,
    this.transactionId,
    this.qrPayload,
    required this.timestamp,
    this.metadata,
  });

  factory PaymentResult.success({
    required String transactionId,
    String message = 'Pembayaran berhasil dikonfirmasi.',
    Map<String, dynamic>? metadata,
  }) {
    return PaymentResult(
      success: true,
      status: PaymentStatus.success,
      message: message,
      transactionId: transactionId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  factory PaymentResult.failed({
    required String message,
    String? transactionId,
    PaymentStatus status = PaymentStatus.failed,
  }) {
    return PaymentResult(
      success: false,
      status: status,
      message: message,
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }
}

abstract class PaymentService {
  PaymentStatus get currentStatus;
  Stream<PaymentStatus> get statusStream;

  Future<PaymentResult> createPayment({
    required String orderNumber,
    required int amount,
    required PaymentMethod method,
    Map<String, dynamic>? metadata,
  });

  Future<PaymentResult> getPaymentStatus(String transactionId);

  Future<PaymentResult> cancelPayment(String transactionId);

  Future<PaymentResult> completePayment(String transactionId);

  void dispose();
}
