import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/business_config.dart';
import '../../state/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/payment/payment_service.dart';
import '../../services/payment/qris_payment_service.dart';

enum QrisSimulationStep {
  showQr,
  waiting,
  detected,
  verifying,
  success,
}

class PaymentScreen extends StatefulWidget {
  final PosProvider pos;
  final VoidCallback onPaymentCompleted;
  final VoidCallback onCancel;

  const PaymentScreen({
    super.key,
    required this.pos,
    required this.onPaymentCompleted,
    required this.onCancel,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final _cashController = TextEditingController();
  int _cashTendered = 0;
  bool _isProcessing = false;

  // QRIS Simulation State
  QrisSimulationStep _qrisStep = QrisSimulationStep.showQr;
  Timer? _qrisTimer;
  PaymentService? _paymentService;
  StreamSubscription<PaymentStatus>? _paymentSub;

  @override
  void initState() {
    super.initState();
    final total = widget.pos.cartGrandTotal;
    _cashTendered = total;
    _cashController.text = _cashTendered.toString();
  }

  List<int> _getDynamicDenominations(int total) {
    if (total <= 0) return [10000, 20000, 50000, 100000];

    final denoms = <int>{};
    const commonTargets = [10000, 20000, 50000, 100000, 200000, 500000];

    // 1. Next multiple of 10.000 if not aligned
    if (total % 10000 != 0) {
      final round10k = ((total / 10000).ceil()) * 10000;
      if (round10k > total) denoms.add(round10k);
    }

    // 2. Next multiple of 50.000 if not aligned
    if (total % 50000 != 0) {
      final round50k = ((total / 50000).ceil()) * 50000;
      if (round50k > total) denoms.add(round50k);
    }

    // 3. Add predefined common bill values strictly greater than total
    for (final target in commonTargets) {
      if (target > total) {
        denoms.add(target);
      }
    }

    final sorted = denoms.toList()..sort();
    return sorted.take(3).toList();
  }

  @override
  void dispose() {
    _cancelQrisSimulation();
    _cashController.dispose();
    super.dispose();
  }

  void _cancelQrisSimulation() {
    _paymentSub?.cancel();
    _paymentSub = null;
    if (_paymentService != null) {
      _paymentService!.cancelPayment('cancelled-by-cashier');
      _paymentService!.dispose();
      _paymentService = null;
    }
    _qrisTimer?.cancel();
    _qrisTimer = null;
  }

  void _resetQrisSimulation() {
    _cancelQrisSimulation();
    if (mounted) {
      setState(() => _qrisStep = QrisSimulationStep.showQr);
    }
    debugPrint('[QRIS] State: SHOW_QR');
  }

  int get _changeAmount {
    final total = widget.pos.cartGrandTotal;
    if (_cashTendered >= total) {
      return _cashTendered - total;
    }
    return 0;
  }

  bool get _isCashValid {
    if (_selectedMethod != PaymentMethod.cash) return true;
    return _cashTendered >= widget.pos.cartGrandTotal;
  }

  void _handlePay() async {
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 350));

    final total = widget.pos.cartGrandTotal;
    final paidAmount = _selectedMethod == PaymentMethod.cash ? _cashTendered : total;
    final changeAmount = _selectedMethod == PaymentMethod.cash ? _changeAmount : 0;

    widget.pos.completePayment(
      method: _selectedMethod,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      widget.onPaymentCompleted();
    }
  }

  void _triggerQrisSimulation() async {
    _cancelQrisSimulation();

    setState(() => _qrisStep = QrisSimulationStep.waiting);

    final service = widget.pos.createPaymentServiceForMethod(PaymentMethod.qris);
    _paymentService = service;

    final orderNum = widget.pos.currentOrder?.orderNumber ?? widget.pos.generateOrderNumber();

    // Listen to status stream for transitions
    _paymentSub = service.statusStream.listen((status) {
      if (!mounted) return;
      switch (status) {
        case PaymentStatus.waiting:
          setState(() => _qrisStep = QrisSimulationStep.waiting);
          break;
        case PaymentStatus.detected:
          setState(() => _qrisStep = QrisSimulationStep.detected);
          break;
        case PaymentStatus.verifying:
          setState(() => _qrisStep = QrisSimulationStep.verifying);
          break;
        case PaymentStatus.success:
          setState(() => _qrisStep = QrisSimulationStep.success);
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _selectedMethod == PaymentMethod.qris && !_isProcessing) {
              _handlePay();
            }
          });
          break;
        case PaymentStatus.cancelled:
        case PaymentStatus.failed:
        case PaymentStatus.expired:
          setState(() => _qrisStep = QrisSimulationStep.showQr);
          break;
        default:
          break;
      }
    });

    await service.createPayment(
      orderNumber: orderNum,
      amount: widget.pos.cartGrandTotal,
      method: PaymentMethod.qris,
    );

    if (service is MockQrisPaymentService) {
      service.startSimulation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.pos;
    final total = pos.cartGrandTotal;
    final orderNumber = pos.currentOrder?.orderNumber ?? pos.generateOrderNumber();
    final tableName = pos.selectedTable?.number ?? 'Takeaway';
    final isMobile = Breakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: const Text('Pembayaran'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          splashRadius: 20,
          onPressed: widget.onCancel,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visually Dominant Grand Total Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TOTAL PEMBAYARAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppCurrency.format(total),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Meja $tableName • $orderNumber',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Responsive Layout: Side-by-Side on Desktop/Tablet, Stacked on Mobile
                if (!isMobile)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildOrderSummaryCard(pos, total)),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: _buildPaymentMethodCard(total)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildPaymentMethodCard(total),
                      const SizedBox(height: 16),
                      _buildOrderSummaryCard(pos, total),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(PosProvider pos, int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rincian Pesanan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Divider(height: 18, color: AppColors.border),

            // Items list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: pos.cart.length,
                separatorBuilder: (_, _) => const Divider(height: 10, color: AppColors.borderLight),
                itemBuilder: (context, idx) {
                  final item = pos.cart[idx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.quantity}x ${item.product.name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (item.hasModifiers)
                              Text(
                                item.modifierSummary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  height: 1.3,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppCurrency.format(item.itemTotal),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(height: 18, color: AppColors.border),

            _buildCostLine('Subtotal', AppCurrency.format(pos.cartSubtotal)),
            const SizedBox(height: 4),
            _buildCostLine(
              'Biaya Layanan${pos.businessConfig.isServiceEnabled ? ' (${pos.businessConfig.serviceChargePercent.toStringAsFixed(0)}%)' : ''}',
              AppCurrency.format(pos.cartServiceCharge),
            ),
            const SizedBox(height: 4),
            _buildCostLine(
              'Pajak PB1${pos.businessConfig.isTaxEnabled ? ' (${pos.businessConfig.taxPercent.toStringAsFixed(0)}%)' : ''}',
              AppCurrency.format(pos.cartTax),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Payment Method Tabs
            Row(
              children: [
                _buildMethodOption(PaymentMethod.cash, 'Tunai (Cash)', Icons.payments_rounded),
                const SizedBox(width: 8),
                _buildMethodOption(PaymentMethod.qris, 'QRIS Demo', Icons.qr_code_2_rounded),
                const SizedBox(width: 8),
                _buildMethodOption(PaymentMethod.debitCard, 'Kartu Debit', Icons.credit_card_rounded),
              ],
            ),

            const SizedBox(height: 18),

            // Method body
            if (_selectedMethod == PaymentMethod.cash)
              _buildCashMethodView(total)
            else if (_selectedMethod == PaymentMethod.qris)
              _buildQrisMethodView(total)
            else
              _buildDebitMethodView(total),

            if (_selectedMethod != PaymentMethod.qris) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: (!_isCashValid || _isProcessing) ? null : _handlePay,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Selesaikan Pembayaran (${AppCurrency.format(total)})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodOption(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedMethod != method) {
            _cancelQrisSimulation();
            setState(() {
              _selectedMethod = method;
              if (method == PaymentMethod.qris) {
                _qrisStep = QrisSimulationStep.showQr;
                debugPrint('[QRIS] State: SHOW_QR');
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashMethodView(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Uang Tunai Diterima (Rp)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            hintText: '0',
          ),
          onChanged: (val) {
            setState(() {
              _cashTendered = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            });
          },
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildQuickCashChip('Uang Pas (${AppCurrency.format(total)})', total),
            for (final amount in _getDynamicDenominations(total))
              _buildQuickCashChip(AppCurrency.format(amount), amount),
          ],
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isCashValid ? AppColors.successSoft : AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isCashValid ? AppColors.success.withValues(alpha: 0.3) : AppColors.danger.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isCashValid ? 'Kembalian' : 'Uang Kurang',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isCashValid ? AppColors.success : AppColors.danger,
                ),
              ),
              Text(
                _isCashValid
                    ? AppCurrency.format(_changeAmount)
                    : '- ${AppCurrency.format(total - _cashTendered)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _isCashValid ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickCashChip(String label, int amount) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surfaceSubtle,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      onPressed: () {
        setState(() {
          _cashTendered = amount;
          _cashController.text = amount.toString();
        });
      },
    );
  }

  Widget _buildQrisMethodView(int total) {
    final qrisConfig = widget.pos.businessConfig.qrisConfig;
    final isStatic = qrisConfig.paymentMode == QrisPaymentMode.staticQris;
    final isRealGateway = qrisConfig.paymentMode == QrisPaymentMode.realGateway;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  qrisConfig.merchantName.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // QR Code Display Frame
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 124, color: AppColors.textPrimary),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.coffee_rounded, size: 18, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Text(
            AppCurrency.format(total),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 4),
          Text(
            qrisConfig.merchantId,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // STATIC QRIS MODE
          if (isStatic) ...[
            const Text(
              'Tunjukkan QR kepada pelanggan. Setelah dana masuk ke rekening/aplikasi merchant, klik tombol di bawah:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handlePay,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Konfirmasi Pembayaran Diterima', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else if (isRealGateway) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Mode Real Gateway (Backend STUB): Webhook backend belum aktif pada fase demo ini. Beralih ke mode Simulasi pada Pengaturan Integrasi untuk demonstrasi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            // SIMULATION MODE
            if (_qrisStep == QrisSimulationStep.showQr) ...[
              const Text(
                'Pelanggan dapat melakukan scan QR di atas menggunakan e-Wallet / M-Banking.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _triggerQrisSimulation,
                  icon: const Icon(Icons.play_circle_filled_rounded, size: 18),
                  label: const Text('Simulasi Pelanggan Scan & Bayar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else if (_qrisStep == QrisSimulationStep.waiting) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark)),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Menunggu pembayaran pelanggan...',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sesi QRIS aktif. Memantau sinyal pembayaran dari gateway...',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _resetQrisSimulation,
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                label: const Text('Batalkan Simulasi', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ] else if (_qrisStep == QrisSimulationStep.detected) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.info, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Pembayaran QRIS Terdeteksi!',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.info),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Menghubungkan ke gateway penyelesaian...',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (_qrisStep == QrisSimulationStep.verifying) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning)),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Memverifikasi Settlement...',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.warning),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Memastikan mutasi dana dan settlement transaksi valid...',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Pembayaran Berhasil!',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.success),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Menerbitkan bukti pembayaran dan struk...',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDebitMethodView(int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.contactless_rounded, size: 40, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text('Mesin EDC Siap Digunakan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            'Silakan tap atau masukkan kartu debit pelanggan untuk nominal ${AppCurrency.format(total)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCostLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
