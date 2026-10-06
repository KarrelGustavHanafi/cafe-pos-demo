import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/order.dart';
import '../../models/business_config.dart';
import 'payment_service.dart';

/// Simulated QRIS service that models realistic state transitions:
/// idle -> waiting -> detected -> verifying -> success.
class MockQrisPaymentService implements PaymentService {
  final Duration waitingDelay;
  final Duration detectionDelay;
  final Duration verificationDelay;

  PaymentStatus _status = PaymentStatus.idle;
  final _controller = StreamController<PaymentStatus>.broadcast();
  Timer? _stepTimer1;
  Timer? _stepTimer2;
  Timer? _stepTimer3;
  String? _currentTxId;

  MockQrisPaymentService({
    this.waitingDelay = const Duration(milliseconds: 2000),
    this.detectionDelay = const Duration(milliseconds: 2000),
    this.verificationDelay = const Duration(milliseconds: 1500),
  }) {
    debugPrint('[QRIS] Service initialized');
  }

  @override
  PaymentStatus get currentStatus => _status;

  @override
  Stream<PaymentStatus> get statusStream => _controller.stream;

  void _setStatus(PaymentStatus status) {
    if (_controller.isClosed) return;
    _status = status;
    debugPrint('[QRIS] State: ${status.name.toUpperCase()}');
    _controller.add(status);
  }

  @override
  Future<PaymentResult> createPayment({
    required String orderNumber,
    required int amount,
    required PaymentMethod method,
    Map<String, dynamic>? metadata,
  }) async {
    _cancelTimers();
    _currentTxId = 'QRIS-SIM-${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[QRIS] Payment session created: $_currentTxId for $orderNumber (Rp$amount)');
    _setStatus(PaymentStatus.waiting);

    return PaymentResult(
      success: true,
      status: PaymentStatus.waiting,
      message: 'QRIS simulasi siap dipindai untuk $orderNumber (Rp$amount)',
      transactionId: _currentTxId,
      qrPayload: '00020101021226610016ID.CO.CAFFE.POS0118${orderNumber}520458125303360540${amount}5802ID5914CAFFE OFFICIAL6007JAKARTA6304ABCD',
      timestamp: DateTime.now(),
    );
  }

  /// Starts automated simulation:
  /// WAITING (±2s) -> DETECTED (±4s) -> VERIFYING (±5-6s) -> SUCCESS (±6-7s)
  void startSimulation({VoidCallback? onComplete}) {
    _cancelTimers();
    debugPrint('[QRIS] Simulation started');

    if (_status != PaymentStatus.waiting) {
      _setStatus(PaymentStatus.waiting);
    }

    _stepTimer1 = Timer(waitingDelay, () {
      if (_status.isTerminal) return;
      _setStatus(PaymentStatus.detected);

      _stepTimer2 = Timer(detectionDelay, () {
        if (_status.isTerminal) return;
        _setStatus(PaymentStatus.verifying);

        _stepTimer3 = Timer(verificationDelay, () {
          if (_status.isTerminal) return;
          _setStatus(PaymentStatus.success);
          debugPrint('[QRIS] Payment completed');
          onComplete?.call();
        });
      });
    });
  }

  /// Backward-compatible alias for existing callers
  void triggerAutoFlow({VoidCallback? onComplete}) => startSimulation(onComplete: onComplete);

  @override
  Future<PaymentResult> getPaymentStatus(String transactionId) async {
    return PaymentResult(
      success: _status == PaymentStatus.success,
      status: _status,
      message: 'Status QRIS: ${_status.name}',
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> cancelPayment(String transactionId) async {
    _cancelTimers();
    _setStatus(PaymentStatus.cancelled);
    debugPrint('[QRIS] Simulation cancelled for $transactionId');
    return PaymentResult(
      success: true,
      status: PaymentStatus.cancelled,
      message: 'Pembayaran QRIS dibatalkan',
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> completePayment(String transactionId) async {
    _cancelTimers();
    _setStatus(PaymentStatus.success);
    debugPrint('[QRIS] Payment completed explicitly for $transactionId');
    return PaymentResult.success(
      transactionId: transactionId,
      message: 'Pembayaran QRIS simulasi sukses.',
    );
  }

  void _cancelTimers() {
    _stepTimer1?.cancel();
    _stepTimer1 = null;
    _stepTimer2?.cancel();
    _stepTimer2 = null;
    _stepTimer3?.cancel();
    _stepTimer3 = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    _controller.close();
  }
}

/// Static QRIS Payment Service:
/// Displays the cafe's registered static QRIS / NMID and allows cashier verification.
class StaticQrisPaymentService implements PaymentService {
  final QrisConfig qrisConfig;
  PaymentStatus _status = PaymentStatus.idle;
  final _controller = StreamController<PaymentStatus>.broadcast();
  String? _currentTxId;

  StaticQrisPaymentService({required this.qrisConfig});

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
    _currentTxId = 'QRIS-STATIC-${DateTime.now().millisecondsSinceEpoch}';
    _setStatus(PaymentStatus.waiting);

    return PaymentResult(
      success: true,
      status: PaymentStatus.waiting,
      message: 'Menunggu konfirmasi QRIS statis merchant ${qrisConfig.merchantName}',
      transactionId: _currentTxId,
      qrPayload: qrisConfig.merchantId,
      timestamp: DateTime.now(),
      metadata: {
        'merchantName': qrisConfig.merchantName,
        'merchantId': qrisConfig.merchantId,
        'amount': amount,
      },
    );
  }

  @override
  Future<PaymentResult> getPaymentStatus(String transactionId) async {
    return PaymentResult(
      success: _status == PaymentStatus.success,
      status: _status,
      message: 'Menunggu verifikasi kasir untuk transaksi QRIS statis',
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
      message: 'Pembayaran QRIS statis dibatalkan oleh kasir.',
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> completePayment(String transactionId) async {
    _setStatus(PaymentStatus.success);
    return PaymentResult.success(
      transactionId: transactionId,
      message: 'Pembayaran QRIS statis telah diverifikasi dan diterima oleh kasir.',
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// STUB/INTERFACE ONLY:
/// Prepared architecture for future backend gateway integration (e.g. Midtrans, Xendit, Bank Open API).
/// Never puts payment provider API secrets on the client!
class RealQrisPaymentService implements PaymentService {
  final String backendRelayUrl;
  PaymentStatus _status = PaymentStatus.idle;
  final _controller = StreamController<PaymentStatus>.broadcast();

  RealQrisPaymentService({this.backendRelayUrl = 'https://api.caffepos.id/v1/payments/qris'});

  @override
  PaymentStatus get currentStatus => _status;

  @override
  Stream<PaymentStatus> get statusStream => _controller.stream;

  @override
  Future<PaymentResult> createPayment({
    required String orderNumber,
    required int amount,
    required PaymentMethod method,
    Map<String, dynamic>? metadata,
  }) async {
    _status = PaymentStatus.pending;
    _controller.add(_status);

    // STUB NOTICE: Production implementation will query backend relay endpoint
    return PaymentResult.failed(
      message: 'RealQrisPaymentService adalah STUB arsitektur. Backend gateway belum aktif pada fase demo ini.',
      status: PaymentStatus.failed,
    );
  }

  @override
  Future<PaymentResult> getPaymentStatus(String transactionId) async {
    return PaymentResult(
      success: false,
      status: _status,
      message: 'STUB: Menunggu webhook backend gateway',
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> cancelPayment(String transactionId) async {
    _status = PaymentStatus.cancelled;
    _controller.add(_status);
    return PaymentResult(
      success: true,
      status: PaymentStatus.cancelled,
      message: 'STUB: Transaksi dibatalkan',
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<PaymentResult> completePayment(String transactionId) async {
    return PaymentResult.failed(
      message: 'STUB: Selesai pembayaran hanya via verifikasi webhook backend.',
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}
