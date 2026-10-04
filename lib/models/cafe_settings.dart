class CafeSettings {
  final String cafeName;
  final String logoUrl;
  final String address;
  final String phone;
  final String instagram;
  final double taxRate; // e.g. 0.10 (10%)
  final double serviceChargeRate; // e.g. 0.05 (5%)
  final bool isTaxEnabled;
  final bool isServiceEnabled;
  final String receiptFooter;
  final String currencySymbol;
  final String orderNumberPrefix;
  final int defaultLowStockThreshold;

  const CafeSettings({
    this.cafeName = 'CAFFE',
    this.logoUrl = '',
    this.address = 'Jl. Senopati No. 45, Kebayoran Baru, Jakarta Selatan',
    this.phone = '+62 812-3456-7890',
    this.instagram = '@caffe.id',
    this.taxRate = 0.10,
    this.serviceChargeRate = 0.05,
    this.isTaxEnabled = true,
    this.isServiceEnabled = true,
    this.receiptFooter = 'Terima kasih atas kunjungan Anda di Caffe!\nSemoga hari Anda menyenangkan.',
    this.currencySymbol = 'Rp',
    this.orderNumberPrefix = 'ORD',
    this.defaultLowStockThreshold = 15,
  });

  CafeSettings copyWith({
    String? cafeName,
    String? logoUrl,
    String? address,
    String? phone,
    String? instagram,
    double? taxRate,
    double? serviceChargeRate,
    bool? isTaxEnabled,
    bool? isServiceEnabled,
    String? receiptFooter,
    String? currencySymbol,
    String? orderNumberPrefix,
    int? defaultLowStockThreshold,
  }) {
    return CafeSettings(
      cafeName: cafeName ?? this.cafeName,
      logoUrl: logoUrl ?? this.logoUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      instagram: instagram ?? this.instagram,
      taxRate: taxRate ?? this.taxRate,
      serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
      isTaxEnabled: isTaxEnabled ?? this.isTaxEnabled,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      orderNumberPrefix: orderNumberPrefix ?? this.orderNumberPrefix,
      defaultLowStockThreshold: defaultLowStockThreshold ?? this.defaultLowStockThreshold,
    );
  }
}
