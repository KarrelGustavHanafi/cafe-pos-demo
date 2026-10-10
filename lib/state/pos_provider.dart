import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/shift.dart';
import '../models/stock_adjustment.dart';
import '../models/cafe_settings.dart';
import '../models/raw_material.dart';
import '../models/recipe.dart';
import '../models/modifier.dart';
import '../models/business_config.dart';
import '../models/receipt_data.dart';
import '../data/mock_data.dart';
import '../services/storage/app_storage.dart';
import '../services/storage/local_app_storage.dart';
import '../services/config/business_config_service.dart';
import '../services/payment/payment_service.dart';
import '../services/payment/mock_payment_service.dart';
import '../services/payment/qris_payment_service.dart';
import '../services/printer/printer_service.dart';
import '../services/telegram/telegram_service.dart';
import '../services/telegram/telegram_bot_service.dart';
import '../services/telegram/telegram_notification_service.dart';
import '../services/receipt/receipt_service.dart';
import '../utils/cart_calculator.dart';
import '../utils/recipe_calculator.dart';
import '../utils/shift_sale_guard.dart';

class PosProvider extends ChangeNotifier {
  User? _currentUser;
  late List<Product> _products;
  late List<Order> _orders;
  late ShiftInfo _currentShift;
  late List<ShiftInfo> _pastShifts;
  late List<ProductCategory> _categories;
  late List<StockAdjustment> _stockAdjustments;
  late CafeSettings _settings;
  late BusinessConfig _businessConfig;
  late AppStorage _storage;
  late BusinessConfigService _configService;
  late ReceiptService _receiptService;
  late TelegramService _telegramService;
  late TelegramNotificationService _telegramNotificationService;
  late List<RawMaterial> _rawMaterials;
  late Map<String, ProductRecipe> _recipes;

  // Active Order Flow State
  final List<CartItem> _cart = [];
  Order? _currentOrder; // Active pending/just-paid order

  /// Builds the provider state, optionally from injected [initialOrders].
///
/// [initialOrders] exists for period-filter tests that need orders on
/// specific dates. When it is omitted the provider seeds itself from
/// [MockData] exactly as before. When supplied it *replaces* the mock orders
/// outright rather than being appended to them, so seeded totals stay
/// predictable.
  PosProvider({
    AppStorage? storage,
    BusinessConfigService? configService,
    List<Order>? initialOrders,
  }) {
    _initData(
      storage: storage,
      configService: configService,
      initialOrders: initialOrders,
    );
    loadPersistedConfig();
  }

  void _initData({
    AppStorage? storage,
    BusinessConfigService? configService,
    List<Order>? initialOrders,
  }) {
    _storage = storage ?? LocalAppStorage();
    _configService = configService ?? LocalBusinessConfigService(_storage);
    _businessConfig = _configService.config;
    _receiptService = ReceiptService();
    _receiptService.updatePrinterMode(_businessConfig.printerMode);
    _telegramService = TelegramBotService(
      config: _businessConfig.telegramConfig,
      isPublicDemo: _businessConfig.isPublicDemo,
    );
    _telegramNotificationService = TelegramNotificationService(_telegramService);

    _products = MockData.getInitialProducts();
    _currentShift = MockData.getInitialShift();
    _pastShifts = MockData.getPastShifts();
    // Replace the mock orders when a caller injects its own, so the two sets
    // are never combined and period totals remain predictable in tests.
    _orders = initialOrders != null
        ? List<Order>.from(initialOrders)
        : MockData.getInitialOrders(_products);
    _categories = [
      ProductCategory.coffee,
      ProductCategory.nonCoffee,
      ProductCategory.food,
      ProductCategory.snack,
      ProductCategory.dessert,
      ProductCategory.pastry,
    ];
    _stockAdjustments = MockData.getInitialStockAdjustments();
    _settings = const CafeSettings();
    _rawMaterials = MockData.getInitialRawMaterials();
    _recipes = MockData.getInitialRecipes();

    // Seed existing low-stock items to prevent repeat alert spam on initial run
    final initialLowStockIds = [
      ..._products.where((p) => p.stock <= _businessConfig.defaultLowStockThreshold).map((p) => p.id),
      ..._rawMaterials.where((m) => m.stock <= m.minimumStock).map((m) => m.id),
    ];
    _telegramNotificationService.seedAlreadyLowStockItems(initialLowStockIds);
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  List<Product> get products => List.unmodifiable(_products);
  List<Product> get activeProducts => _products.where((p) => p.isActive).toList();
  List<Order> get orders => List.unmodifiable(_orders);
  ShiftInfo get currentShift => _currentShift;
  List<ShiftInfo> get pastShifts => List.unmodifiable(_pastShifts);
  List<ShiftInfo> get allShifts => [_currentShift, ..._pastShifts];
  List<ProductCategory> get categories => List.unmodifiable(_categories);
  List<StockAdjustment> get stockAdjustments => List.unmodifiable(_stockAdjustments);
  CafeSettings get settings => _settings;
  BusinessConfig get businessConfig => _businessConfig;
  BusinessConfigService get configService => _configService;
  ReceiptService get receiptService => _receiptService;
  PrinterService get printerService => _receiptService.printerService;
  TelegramService get telegramService => _telegramService;
  TelegramNotificationService get telegramNotificationService => _telegramNotificationService;
  List<CartItem> get cart => List.unmodifiable(_cart);
  Order? get currentOrder => _currentOrder;

  // ==========================================
  // SHIFT GATE (Closed-Shift Guard)
  // ==========================================

  /// True when a new sale may begin. The POS always keeps exactly one current
  /// shift; a closed shift means no cashier is on duty, so no new sale,
  /// checkout or payment may be started until [startNewShift] is called.
  bool get hasActiveShift => !_currentShift.isClosed;

  /// Single centralized validation used by every cashier-facing sale operation.
  /// Throws [ShiftSaleBlockedException] so a blocked operation can never be
  /// mistaken for a successful one (no silent success reporting).
  void ensureShiftOpenForSale() {
    if (hasActiveShift) return;
    throw const ShiftSaleBlockedException(shiftClosedSaleMessage);
  }

  // Raw Material & Recipe Getters
  List<RawMaterial> get rawMaterials => List.unmodifiable(_rawMaterials);
  List<RawMaterial> get activeRawMaterials => _rawMaterials.where((m) => m.isActive).toList();
  List<RawMaterial> get lowStockRawMaterials => _rawMaterials.where((m) => m.isLowStock).toList();
  List<RawMaterial> get outOfStockRawMaterials => _rawMaterials.where((m) => m.isOutOfStock).toList();
  List<RawMaterial> get alertRawMaterials => _rawMaterials.where((m) => m.isLowStock || m.isOutOfStock).toList();
  Map<String, ProductRecipe> get recipes => Map.unmodifiable(_recipes);
  ProductRecipe? getRecipeForProduct(String productId) => _recipes[productId];

  // Authentication
  bool login(String username, String password) {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername == 'owner' && cleanPassword == 'owner123') {
      _currentUser = MockData.users.firstWhere((u) => u.role == UserRole.owner);
      notifyListeners();
      return true;
    } else if (cleanUsername == 'cashier' && cleanPassword == 'cashier123') {
      _currentUser = MockData.users.firstWhere((u) => u.role == UserRole.cashier);
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    clearCart();
    notifyListeners();
  }

  void switchUserRole(UserRole role) {
    _currentUser = MockData.users.firstWhere((u) => u.role == role);
    notifyListeners();
  }

  // Cart Management (Cashier)
  /// Adds a product to the cart.
  ///
  /// Throws [ShiftSaleBlockedException] when no active shift exists so a new
  /// sale can never start outside a shift.
  void addToCart(
    Product product, {
    int qty = 1,
    String notes = '',
    List<ModifierOption> modifiers = const [],
  }) {
    ensureShiftOpenForSale();

    final newItem = CartItem(
      product: product,
      quantity: qty,
      notes: notes,
      selectedModifiers: modifiers,
    );
    final existingIndex = _cart.indexWhere((item) => item.customKey == newItem.customKey);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += qty;
    } else {
      _cart.add(newItem);
    }
    notifyListeners();
  }

  void updateCartItemAt(
    int index, {
    int? quantity,
    List<ModifierOption>? modifiers,
    String? notes,
  }) {
    if (index < 0 || index >= _cart.length) return;
    if (quantity != null && quantity <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = _cart[index].copyWith(
        quantity: quantity,
        selectedModifiers: modifiers,
        notes: notes,
      );
    }
    notifyListeners();
  }

  void removeCartItemAt(int index) {
    if (index >= 0 && index < _cart.length) {
      _cart.removeAt(index);
      notifyListeners();
    }
  }

  /// Replaces one customized line. A different customization of the same
  /// product stays on its own line. An edit that matches another line merges.
  void replaceCartItemAt(
    int index, {
    required int quantity,
    required List<ModifierOption> modifiers,
    required String notes,
  }) {
    if (index < 0 || index >= _cart.length) return;
    if (quantity <= 0) {
      _cart.removeAt(index);
      notifyListeners();
      return;
    }

    final updated = _cart[index].copyWith(
      quantity: quantity,
      selectedModifiers: List<ModifierOption>.from(modifiers),
      notes: notes,
    );
    _cart.removeAt(index);

    final mergeIndex = _cart.indexWhere((item) => item.customKey == updated.customKey);
    if (mergeIndex >= 0) {
      _cart[mergeIndex].quantity += quantity;
    } else {
      _cart.insert(index.clamp(0, _cart.length), updated);
    }
    notifyListeners();
  }

  /// Changes quantity for one cart line only. Does not touch other
  /// customizations of the same product.
  void updateCartQuantityAt(int index, int quantity) {
    if (index < 0 || index >= _cart.length) return;
    if (quantity <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index].quantity = quantity;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void updateCartQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      removeFromCart(product);
      return;
    }
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity = quantity;
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    _currentOrder = null;
    notifyListeners();
  }

  /// Preset Demo Order: 2x Kopi Susu Gula Aren, 1x French Fries
  ///
  /// Builds a new cart, so it is guarded by the same shift check as
  /// [addToCart] and throws [ShiftSaleBlockedException] when the shift is closed.
  void loadDemoQuickOrder() {
    ensureShiftOpenForSale();

    _cart.clear();
    final kopiSusu = _products.firstWhere(
      (p) => p.name == 'Kopi Susu Gula Aren',
      orElse: () => _products.first,
    );
    final fries = _products.firstWhere(
      (p) => p.name == 'French Fries',
      orElse: () => _products.last,
    );

    final ksModifiers = kopiSusu.modifierGroups
        .where((g) => g.isEnabled)
        .map((g) => g.defaultOption)
        .whereType<ModifierOption>()
        .toList();

    final ffModifiers = fries.modifierGroups
        .where((g) => g.isEnabled)
        .map((g) => g.defaultOption)
        .whereType<ModifierOption>()
        .toList();

    _cart.add(CartItem(product: kopiSusu, quantity: 2, selectedModifiers: ksModifiers));
    _cart.add(CartItem(product: fries, quantity: 1, selectedModifiers: ffModifiers));
    notifyListeners();
  }

  // Order Calculations
  CartTotals get _cartTotals => CartCalculator.calculate(
        items: _cart,
        taxRate: _businessConfig.taxRate,
        serviceChargeRate: _businessConfig.serviceChargeRate,
        isTaxEnabled: _businessConfig.isTaxEnabled,
        isServiceEnabled: _businessConfig.isServiceEnabled,
      );

  int get cartSubtotal => _cartTotals.subtotal;
  int get cartServiceCharge => _cartTotals.serviceCharge;
  int get cartTax => _cartTotals.tax;
  int get cartGrandTotal => _cartTotals.grandTotal;
  int get cartItemCount => _cart.fold<int>(0, (sum, item) => sum + item.quantity);

  // Generate Next Order Number: ORD-YYYYMMDD-NNNN
  String generateOrderNumber() {
    final now = DateTime.now();
    final dateStr = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final count = _orders.length + 1;
    final seqStr = count.toString().padLeft(4, '0');
    return '${_businessConfig.orderNumberPrefix}-$dateStr-$seqStr';
  }

  // Checkout flow: prepare order
  ///
  /// Throws [ShiftSaleBlockedException] when checkout is started without an
  /// active shift. No order is created and [_currentOrder] stays untouched.
  Order prepareCheckoutOrder({PaymentMethod paymentMethod = PaymentMethod.cash}) {
    ensureShiftOpenForSale();

    final cashier = _currentUser?.displayName ?? 'Siti Rahma (Kasir)';
    final order = Order.create(
      orderNumber: generateOrderNumber(),
      // Seating is free-choice: no table is ever assigned by the cashier.
      tableNumber: 'Takeaway',
      items: List.from(_cart),
      cashierName: cashier,
      paymentMethod: paymentMethod,
      status: OrderStatus.pending,
      taxRate: _businessConfig.taxRate,
      serviceChargeRate: _businessConfig.serviceChargeRate,
      isTaxEnabled: _businessConfig.isTaxEnabled,
      isServiceEnabled: _businessConfig.isServiceEnabled,
    );
    _currentOrder = order;
    notifyListeners();
    return order;
  }

  // Payment Execution & Automatic Stock Depletion
  ///
  /// Rejects a new payment when no active shift exists by throwing
  /// [ShiftSaleBlockedException] before any mutation happens, so stock, stock
  /// adjustment history, table state and order status stay untouched.
  ///
  /// The duplicate-payment guard is evaluated first: an order that is already
  /// paid is returned as-is (idempotent) even if the shift has since closed.
  ///
  /// The commit runs as plan-then-apply: every mutation is computed first
  /// (including a stock sufficiency check), then applied inside a snapshot
  /// guarded block. Any error during apply rolls the whole sale back, so a
  /// failed checkout can never leave a paid order without its inventory.
  Order completePayment({
    required PaymentMethod method,
    required int paidAmount,
    required int changeAmount,
  }) {
    // Guard: prevent duplicate payment for the same order
    if (_currentOrder != null && _currentOrder!.status == OrderStatus.paid) {
      return _currentOrder!; // Return the already-paid order without reprocessing
    }

    // Guard: no new payment may be processed outside an active shift.
    ensureShiftOpenForSale();

    if (_currentOrder == null) {
      prepareCheckoutOrder(paymentMethod: method);
    }

    final order = _currentOrder!;

    // Guard: a payment cannot be settled for an order with no items.
    if (order.items.isEmpty) {
      throw const InvalidPaymentException(
        'Pesanan kosong. Tidak ada item untuk dibayar.',
      );
    }

    // Guard: cash must actually cover the total. Non-cash methods settle the
    // exact grand total at the gateway, so they are not checked here.
    if (method == PaymentMethod.cash && paidAmount < order.grandTotal) {
      throw InvalidPaymentException(
        'Uang diterima kurang dari total pembayaran (${order.grandTotal}).',
      );
    }

    // Build the full mutation plan before touching any state. Throws
    // InsufficientStockException when stock or ingredients are short.
    final plan = _buildSalePlan(order);

    final paymentTimestamp = DateTime.now();
    final finishedOrder = order.copyWith(
      paymentMethod: method,
      status: OrderStatus.paid,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      createdAt: paymentTimestamp,
    );

    final snapshot = _captureSaleSnapshot(plan);
    try {
      _applySalePlan(plan, finishedOrder, paymentTimestamp);
    } catch (_) {
      _restoreSaleSnapshot(snapshot);
      rethrow;
    }

    // Automatic Telegram Business Events Notification (non-blocking / fire-and-forget)
    unawaited(_telegramNotificationService.onTransactionCompleted(
      finishedOrder,
      deductions: plan.deductionsList,
      newlyLowStockItems: plan.newlyLowStock,
    ));

    return finishedOrder;
  }

  /// Computes every inventory/history mutation for [order] without applying it,
  /// and verifies that finished-product stock and recipe ingredients suffice.
  _SalePlan _buildSalePlan(Order order) {
    // Aggregate ingredient demand per material across every cart line, so two
    // lines sharing an ingredient are validated (and deducted) as one total.
    final materialDemand = <String, ({String name, double amount, String unit})>{};
    for (final item in order.items) {
      for (final entry in getRequiredIngredientsForItem(item).entries) {
        final matIndex = _rawMaterials.indexWhere((m) => m.id == entry.key);
        if (matIndex < 0) continue;
        final mat = _rawMaterials[matIndex];
        final existing = materialDemand[mat.id];
        materialDemand[mat.id] = (
          name: mat.name,
          amount: (existing?.amount ?? 0.0) + entry.value,
          unit: mat.unit.label,
        );
      }
    }

    // Aggregate finished-product demand per product across every cart line.
    final productDemand = <String, ({String name, int amount})>{};
    for (final item in order.items) {
      final existing = productDemand[item.product.id];
      productDemand[item.product.id] = (
        name: item.product.name,
        amount: (existing?.amount ?? 0) + item.quantity,
      );
    }

    // Validate BEFORE planning any mutation.
    final shortages = <String>[];
    for (final demand in productDemand.entries) {
      final productIndex = _products.indexWhere((p) => p.id == demand.key);
      if (productIndex < 0) continue;
      final available = _products[productIndex].stock;
      if (demand.value.amount > available) {
        shortages.add(
          '${demand.value.name}: stok tersedia $available, dibutuhkan ${demand.value.amount}',
        );
      }
    }
    for (final entry in materialDemand.entries) {
      final matIndex = _rawMaterials.indexWhere((m) => m.id == entry.key);
      if (matIndex < 0) continue;
      final mat = _rawMaterials[matIndex];
      if (entry.value.amount > mat.stock) {
        shortages.add(
          '${entry.value.name}: stok tersedia ${_formatQty(mat.stock)} ${mat.unit.label}, '
          'dibutuhkan ${_formatQty(entry.value.amount)} ${mat.unit.label}',
        );
      }
    }
    if (shortages.isNotEmpty) {
      throw InsufficientStockException(shortages);
    }

    // Finished-product deductions: one entry per cart line so that repeated
    // lines of the same product (different modifiers) each get their own
    // history row. Deducting per line keeps history in step with the deduction.
    //
    // The running balance matters: when one order carries several lines of the
    // same product, each line must deduct from the result of the previous line.
    // Reading the live stock for every line would make all lines share one
    // `previousStock` and one `newStock`, so the last line would overwrite the
    // earlier deductions and the ledger would claim more than was deducted.
    final productDeductions = <_StockDeduction>[];
    final runningProductStock = <int, int>{};
    for (final item in order.items) {
      final productIndex = _products.indexWhere((p) => p.id == item.product.id);
      if (productIndex < 0) continue;
      final previousStock = runningProductStock.putIfAbsent(
        productIndex,
        () => _products[productIndex].stock,
      );
      final newStock = (previousStock - item.quantity).clamp(0, 9999);
      runningProductStock[productIndex] = newStock;
      productDeductions.add(
        _StockDeduction(
          adjustmentId: 'ADJ-SALE-${order.orderNumber}-${item.product.id}-${_lineSuffix(item, order)}',
          collectionIndex: productIndex,
          quantity: item.quantity.toDouble(),
          previousStock: previousStock.toDouble(),
          newStock: newStock.toDouble(),
          name: item.product.name,
          unit: 'pcs',
          isRawMaterial: false,
          // The alert must use the product's own threshold, matching what
          // `Product.isLowStock` and the inventory screen show. Using the
          // business-wide default here made the two disagree for every product
          // whose threshold was configured individually.
          minimumStock: _products[productIndex].lowStockThreshold.toDouble(),
          reason: 'Penjualan #${order.orderNumber} (${item.quantity}x ${item.product.name}'
              '${item.hasModifiers ? ' [${item.modifierSummary}]' : ''})',
        ),
      );
    }

    // Raw-material deductions: one aggregated entry per material per order.
    final materialDeductions = <_StockDeduction>[];
    for (final entry in materialDemand.entries) {
      final matIndex = _rawMaterials.indexWhere((m) => m.id == entry.key);
      if (matIndex < 0) continue;
      final mat = _rawMaterials[matIndex];
      materialDeductions.add(
        _StockDeduction(
          adjustmentId: 'ADJ-MAT-${order.orderNumber}-${mat.id}',
          collectionIndex: matIndex,
          quantity: entry.value.amount,
          previousStock: mat.stock,
          newStock: (mat.stock - entry.value.amount).clamp(0.0, 999999.0),
          name: entry.value.name,
          unit: entry.value.unit,
          isRawMaterial: true,
          minimumStock: mat.minimumStock,
          reason: 'Penjualan #${order.orderNumber} (${_formatQty(entry.value.amount)} ${entry.value.unit} ${entry.value.name})',
        ),
      );
    }

    final deductionsList = <({String name, double amount, String unit})>[
      for (final d in materialDeductions)
        (name: d.name, amount: d.quantity, unit: d.unit),
    ];
    // If no raw materials were deducted, record finished product deductions
    if (deductionsList.isEmpty) {
      for (final d in productDeductions) {
        deductionsList.add((name: d.name, amount: d.quantity, unit: 'pcs'));
      }
    }

    return _SalePlan(
      orderNumber: order.orderNumber,
      productDeductions: productDeductions,
      materialDeductions: materialDeductions,
      deductionsList: deductionsList,
    );
  }

  /// Stable per-line discriminator for finished-product adjustment IDs.
  ///
  /// Uses the 1-based line position within the immutable order, so two cart
  /// lines of the same product (different modifiers) always differ, and the
  /// same line always maps to the same ID across payment retries.
  String _lineSuffix(CartItem item, Order order) {
    final index = order.items.indexOf(item);
    return 'L${index + 1}';
  }

  /// Applies a previously validated plan. Every step here is assumed to be
  /// non-throwing except for the test seam; the caller rolls back on error.
  void _applySalePlan(
    _SalePlan plan,
    Order finishedOrder,
    DateTime paymentTimestamp,
  ) {
    final newlyLowStock = <LowStockItemData>[];

    // 1. Finished-product stock deduction.
    // Each planned line carries a chained balance, so the last planned value
    // for a product is its final stock. Collecting it first means the commit
    // can never apply a stale intermediate value on top of a correct one.
    for (final d in plan.productDeductions) {
      _maybeTrackLowStock(
        d,
        newlyLowStock,
        unit: 'porsi',
      );
    }
    final finalProductStock = <int, int>{};
    for (final d in plan.productDeductions) {
      finalProductStock[d.collectionIndex] = d.newStock.round();
    }
    finalProductStock.forEach((index, stock) {
      _products[index].stock = stock;
    });

    // 2. Raw-material stock deduction
    for (final d in plan.materialDeductions) {
      _rawMaterials[d.collectionIndex].stock = d.newStock;
      _maybeTrackLowStock(d, newlyLowStock, unit: d.unit);
    }

    // 3. Commit the sale: order record, history, table and cart cleanup.
    // Reaching this point means every inventory mutation above succeeded.
    debugThrowAfterInventoryApply?.call();

    for (final d in [...plan.productDeductions, ...plan.materialDeductions]) {
      _stockAdjustments.insert(
        0,
        StockAdjustment(
          id: d.adjustmentId,
          productId: d.isRawMaterial
              ? _rawMaterials[d.collectionIndex].id
              : _products[d.collectionIndex].id,
          productName: d.name,
          type: AdjustmentType.sale,
          quantity: d.quantity,
          previousStock: d.previousStock,
          newStock: d.newStock,
          reason: d.reason,
          timestamp: paymentTimestamp,
          unit: d.unit,
          isRawMaterial: d.isRawMaterial,
          adjustedBy: 'Sistem POS (Kasir)',
        ),
      );
    }

    _orders.insert(0, finishedOrder);
    _currentOrder = finishedOrder;

    _cart.clear();

    plan.newlyLowStock.addAll(newlyLowStock);

    notifyListeners();
  }

  void _maybeTrackLowStock(
    _StockDeduction d,
    List<LowStockItemData> into, {
    required String unit,
  }) {
    if (d.previousStock > d.minimumStock && d.newStock <= d.minimumStock) {
      into.add(LowStockItemData(
        id: d.isRawMaterial
            ? _rawMaterials[d.collectionIndex].id
            : _products[d.collectionIndex].id,
        name: d.name,
        currentStock: d.newStock,
        minimumStock: d.minimumStock,
        unit: unit,
      ));
    }
  }

  /// Test-only hook invoked once the sale plan has been applied but before the
  /// order is committed. Throwing from it exercises the rollback path.
  ///
  /// Never set in production; there is no real API or I/O failure modelled
  /// inside `completePayment`, so this seam is the only way to drive the
  /// partial-commit scenario deterministically.
  @visibleForTesting
  void Function()? debugThrowAfterInventoryApply;

  /// Captures the minimal state a sale can mutate, so a failed apply can be
  /// undone completely.
  _SaleSnapshot _captureSaleSnapshot(_SalePlan plan) {
    return _SaleSnapshot(
      productStocks: {
        for (final d in plan.productDeductions)
          d.collectionIndex: _products[d.collectionIndex].stock,
      },
      materialStocks: {
        for (final d in plan.materialDeductions)
          d.collectionIndex: _rawMaterials[d.collectionIndex].stock,
      },
      ordersLength: _orders.length,
      adjustmentsLength: _stockAdjustments.length,
      currentOrder: _currentOrder,
      cart: List<CartItem>.from(_cart),
    );
  }

  void _restoreSaleSnapshot(_SaleSnapshot snapshot) {
    snapshot.productStocks.forEach((index, stock) {
      _products[index].stock = stock;
    });
    snapshot.materialStocks.forEach((index, stock) {
      _rawMaterials[index].stock = stock;
    });
    if (_orders.length > snapshot.ordersLength) {
      _orders.removeRange(snapshot.ordersLength, _orders.length);
    }
    if (_stockAdjustments.length > snapshot.adjustmentsLength) {
      _stockAdjustments.removeRange(
          snapshot.adjustmentsLength, _stockAdjustments.length);
    }
    _currentOrder = snapshot.currentOrder;
    _cart
      ..clear()
      ..addAll(snapshot.cart);
  }

  String _formatQty(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  // ==========================================
  // OWNER: PRODUCT MANAGEMENT
  // ==========================================
  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  void updateProduct(Product updatedProduct) {
    final index = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (index >= 0) {
      _products[index] = updatedProduct;
      if (updatedProduct.stock > _businessConfig.defaultLowStockThreshold) {
        _telegramNotificationService.resetLowStockAlert(updatedProduct.id);
      }
      notifyListeners();
    }
  }

  void deleteProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    _cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void toggleProductActive(String productId) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      final p = _products[index];
      _products[index] = p.copyWith(isActive: !p.isActive);
      notifyListeners();
    }
  }

  // ==========================================
  // OWNER: CATEGORY MANAGEMENT
  // ==========================================
  void addCategory(ProductCategory category) {
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
    }
  }

  void removeCategory(ProductCategory category) {
    _categories.remove(category);
    notifyListeners();
  }

  int getProductCountForCategory(ProductCategory cat) {
    if (cat == ProductCategory.all) return _products.length;
    return _products.where((p) => p.category == cat).length;
  }

  // ==========================================
  // OWNER: INVENTORY & STOCK ADJUSTMENT FLOW
  // ==========================================
  void adjustStock({
    required String productId,
    required AdjustmentType type,
    required int quantity,
    required String reason,
    String adjustedBy = 'Owner (Budi Santoso)',
  }) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;

    final product = _products[index];
    final prevStock = product.stock;
    int newStock = prevStock;

    switch (type) {
      case AdjustmentType.add:
        newStock = prevStock + quantity;
        break;
      case AdjustmentType.remove:
        newStock = (prevStock - quantity).clamp(0, 9999);
        break;
      case AdjustmentType.set:
        newStock = quantity.clamp(0, 9999);
        break;
      case AdjustmentType.sale:
        newStock = (prevStock - quantity).clamp(0, 9999);
        break;
    }

    _products[index].stock = newStock;
    if (newStock > _businessConfig.defaultLowStockThreshold) {
      _telegramNotificationService.resetLowStockAlert(product.id);
    }

    // Log adjustment in audit history
    final record = StockAdjustment(
      id: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      productName: product.name,
      type: type,
      quantity: quantity,
      previousStock: prevStock,
      newStock: newStock,
      reason: reason,
      timestamp: DateTime.now(),
      adjustedBy: adjustedBy,
    );
    _stockAdjustments.insert(0, record);

    notifyListeners();
  }

  List<Product> get lowStockProducts =>
      _products.where((p) => p.isLowStock || p.isOutOfStock).toList();

  List<Product> get outOfStockProducts =>
      _products.where((p) => p.isOutOfStock).toList();

  // ==========================================
  // OWNER: RAW MATERIAL MANAGEMENT
  // ==========================================
  void addRawMaterial(RawMaterial material) {
    _rawMaterials.add(material);
    notifyListeners();
  }

  void updateRawMaterial(RawMaterial updated) {
    final index = _rawMaterials.indexWhere((m) => m.id == updated.id);
    if (index >= 0) {
      _rawMaterials[index] = updated;
      if (updated.stock > updated.minimumStock) {
        _telegramNotificationService.resetLowStockAlert(updated.id);
      }
      notifyListeners();
    }
  }

  void deleteRawMaterial(String id) {
    _rawMaterials.removeWhere((m) => m.id == id);
    for (final recipe in _recipes.values) {
      recipe.items.removeWhere((item) => item.materialId == id);
    }
    notifyListeners();
  }

  void adjustRawMaterialStock({
    required String materialId,
    required AdjustmentType type,
    required num quantity,
    required String reason,
    String adjustedBy = 'Owner (Budi Santoso)',
  }) {
    final index = _rawMaterials.indexWhere((m) => m.id == materialId);
    if (index < 0) return;

    final mat = _rawMaterials[index];
    final prevStock = mat.stock;
    num newStock = prevStock;

    switch (type) {
      case AdjustmentType.add:
        newStock = prevStock + quantity;
        break;
      case AdjustmentType.remove:
        newStock = (prevStock - quantity).clamp(0.0, 999999.0);
        break;
      case AdjustmentType.set:
        newStock = quantity.clamp(0.0, 999999.0);
        break;
      case AdjustmentType.sale:
        newStock = (prevStock - quantity).clamp(0.0, 999999.0);
        break;
    }

    _rawMaterials[index].stock = newStock.toDouble();
    if (newStock > mat.minimumStock) {
      _telegramNotificationService.resetLowStockAlert(mat.id);
    }

    _stockAdjustments.insert(
      0,
      StockAdjustment(
        id: 'ADJ-MAT-${DateTime.now().millisecondsSinceEpoch}',
        productId: mat.id,
        productName: mat.name,
        type: type,
        quantity: quantity,
        previousStock: prevStock,
        newStock: newStock,
        reason: reason,
        timestamp: DateTime.now(),
        unit: mat.unit.label,
        isRawMaterial: true,
        adjustedBy: adjustedBy,
      ),
    );

    notifyListeners();
  }

  // ==========================================
  // OWNER: RECIPE MANAGEMENT
  // ==========================================
  void saveRecipe(ProductRecipe recipe) {
    _recipes[recipe.productId] = recipe;
    notifyListeners();
  }

  void deleteRecipe(String productId) {
    _recipes.remove(productId);
    notifyListeners();
  }

  /// Check ingredient availability for a given product and desired quantity
  ({bool canProduce, String status, List<String> issues}) checkRecipeAvailability(
    String productId, {
    int quantity = 1,
  }) {
    final recipe = _recipes[productId];
    if (recipe == null || recipe.items.isEmpty) {
      return (canProduce: true, status: 'AVAILABLE', issues: <String>[]);
    }

    bool hasOutOfStock = false;
    bool hasLowStock = false;
    final issues = <String>[];

    for (final item in recipe.items) {
      final mat = _rawMaterials.firstWhere(
        (m) => m.id == item.materialId,
        orElse: () => RawMaterial(
          id: item.materialId,
          name: item.materialName,
          category: RawMaterialCategory.packaging,
          unit: RawMaterialUnit.gram,
          stock: 0,
          minimumStock: 0,
        ),
      );

      final needed = item.quantity * quantity;
      if (mat.stock < needed) {
        hasOutOfStock = true;
        issues.add(
          '${mat.name}: butuh ${needed.toStringAsFixed(needed.truncateToDouble() == needed ? 0 : 1)} ${mat.unit.label}, '
          'tersedia ${mat.stock.toStringAsFixed(mat.stock.truncateToDouble() == mat.stock ? 0 : 1)} ${mat.unit.label}',
        );
      } else if (mat.stock - needed < mat.minimumStock) {
        hasLowStock = true;
      }
    }

    if (hasOutOfStock) {
      return (canProduce: false, status: 'UNAVAILABLE', issues: issues);
    } else if (hasLowStock) {
      return (canProduce: true, status: 'LOW INGREDIENT', issues: issues);
    }
    return (canProduce: true, status: 'AVAILABLE', issues: issues);
  }

  /// Computes the exact raw material consumption required for a CartItem
  /// taking into account base recipe, size/temperature/sugar overrides, and add-on additions.
  Map<String, double> getRequiredIngredientsForItem(CartItem item) {
    final recipe = _recipes[item.product.id];
    return RecipeCalculator.getRequiredIngredientsForItem(item: item, recipe: recipe);
  }

  /// Check all items in cart for raw material shortages taking modifiers into account
  List<String> getCartInsufficientIngredients() {
    final requiredTotals = RecipeCalculator.aggregateRequiredIngredients(
      items: _cart,
      recipes: _recipes,
    );

    final Map<String, RawMaterial> materialMap = {};

    for (final entry in requiredTotals.entries) {
      if (!materialMap.containsKey(entry.key)) {
        final mat = _rawMaterials.firstWhere(
          (m) => m.id == entry.key,
          orElse: () => RawMaterial(
            id: entry.key,
            name: 'Bahan ${entry.key}',
            category: RawMaterialCategory.packaging,
            unit: RawMaterialUnit.gram,
            stock: 0,
            minimumStock: 0,
          ),
        );
        materialMap[entry.key] = mat;
      }
    }

    final insufficient = <String>[];
    for (final entry in requiredTotals.entries) {
      final mat = materialMap[entry.key];
      if (mat != null && mat.stock < entry.value) {
        final needed = entry.value;
        final current = mat.stock;
        insufficient.add(
          '${mat.name} (dibutuhkan ${needed.toStringAsFixed(needed.truncateToDouble() == needed ? 0 : 1)} ${mat.unit.label}, '
          'tersedia ${current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 1)} ${mat.unit.label})',
        );
      }
    }
    return insufficient;
  }

  // ==========================================
  // OWNER: PRODUCT MODIFIER CONFIGURATION
  // ==========================================
  void toggleProductModifierGroup(String productId, String groupId, bool isEnabled) {
    final pIndex = _products.indexWhere((p) => p.id == productId);
    if (pIndex >= 0) {
      final p = _products[pIndex];
      final newGroups = p.modifierGroups.map((g) {
        if (g.id == groupId) {
          return g.copyWith(isEnabled: isEnabled);
        }
        return g;
      }).toList();
      _products[pIndex] = p.copyWith(modifierGroups: newGroups);
      notifyListeners();
    }
  }

  void updateModifierOptionPrice(
    String productId,
    String groupId,
    String optionId,
    int newPriceAdjustment,
  ) {
    final pIndex = _products.indexWhere((p) => p.id == productId);
    if (pIndex >= 0) {
      final p = _products[pIndex];
      final newGroups = p.modifierGroups.map((g) {
        if (g.id == groupId) {
          final newOpts = g.options.map((opt) {
            if (opt.id == optionId) {
              return opt.copyWith(priceAdjustment: newPriceAdjustment);
            }
            return opt;
          }).toList();
          return g.copyWith(options: newOpts);
        }
        return g;
      }).toList();
      _products[pIndex] = p.copyWith(modifierGroups: newGroups);
      notifyListeners();
    }
  }


  // ==========================================
  // OWNER: SETTINGS MANAGEMENT
  // ==========================================
  // OWNER: SETTINGS & BUSINESS CONFIG MANAGEMENT
  // ==========================================
  void updateSettings(CafeSettings newSettings) {
    _settings = newSettings;
    _businessConfig = _businessConfig.copyWith(
      businessName: newSettings.cafeName,
      logoUrl: newSettings.logoUrl,
      address: newSettings.address,
      phone: newSettings.phone,
      instagram: newSettings.instagram,
      isTaxEnabled: newSettings.isTaxEnabled,
      isServiceEnabled: newSettings.isServiceEnabled,
      taxPercent: newSettings.taxRate * 100,
      serviceChargePercent: newSettings.serviceChargeRate * 100,
      receiptFooter: newSettings.receiptFooter,
      orderNumberPrefix: newSettings.orderNumberPrefix,
      defaultLowStockThreshold: newSettings.defaultLowStockThreshold,
    );
    _configService.saveConfig(_businessConfig);
    notifyListeners();
  }

  Future<void>? _loadConfigFuture;

  Future<void> loadPersistedConfig() {
    _loadConfigFuture = _doLoadPersistedConfig();
    return _loadConfigFuture!;
  }

  Future<void> _doLoadPersistedConfig() async {
    try {
      await _storage.init();
      await _configService.init();
      final loaded = _configService.config;
      _businessConfig = loaded;
      _settings = _settings.copyWith(
        cafeName: loaded.businessName,
        logoUrl: loaded.logoUrl,
        address: loaded.address,
        phone: loaded.phone,
        instagram: loaded.instagram,
        isTaxEnabled: loaded.isTaxEnabled,
        isServiceEnabled: loaded.isServiceEnabled,
        taxRate: loaded.taxRate,
        serviceChargeRate: loaded.serviceChargeRate,
        receiptFooter: loaded.receiptFooter,
        orderNumberPrefix: loaded.orderNumberPrefix,
        defaultLowStockThreshold: loaded.defaultLowStockThreshold,
      );
      _receiptService.updatePrinterMode(loaded.printerMode);
      _telegramService = TelegramBotService(
        config: loaded.telegramConfig,
        isPublicDemo: loaded.isPublicDemo,
      );
      _telegramNotificationService.telegramService = _telegramService;
      notifyListeners();
    } catch (_) {
      // Graceful fallback: maintain defaults without crash
    }
  }

  Future<void> updateBusinessConfig(BusinessConfig newConfig) async {
    if (_loadConfigFuture != null) {
      await _loadConfigFuture;
    }
    _businessConfig = newConfig;
    _settings = _settings.copyWith(
      cafeName: newConfig.businessName,
      logoUrl: newConfig.logoUrl,
      address: newConfig.address,
      phone: newConfig.phone,
      instagram: newConfig.instagram,
      isTaxEnabled: newConfig.isTaxEnabled,
      isServiceEnabled: newConfig.isServiceEnabled,
      taxRate: newConfig.taxRate,
      serviceChargeRate: newConfig.serviceChargeRate,
      receiptFooter: newConfig.receiptFooter,
      orderNumberPrefix: newConfig.orderNumberPrefix,
      defaultLowStockThreshold: newConfig.defaultLowStockThreshold,
    );
    await _configService.saveConfig(newConfig);
    _receiptService.updatePrinterMode(newConfig.printerMode);
    _telegramService = TelegramBotService(
      config: newConfig.telegramConfig,
      isPublicDemo: newConfig.isPublicDemo,
    );
    _telegramNotificationService.telegramService = _telegramService;
    notifyListeners();
  }

  void setTelegramService(TelegramService service) {
    _telegramService = service;
    _telegramNotificationService.telegramService = service;
    notifyListeners();
  }

  // ==========================================
  // INTEGRATION SERVICES: PAYMENT, PRINTER & TELEGRAM
  // ==========================================
  PaymentService createPaymentServiceForMethod(PaymentMethod method) {
    if (method == PaymentMethod.qris) {
      switch (_businessConfig.qrisConfig.paymentMode) {
        case QrisPaymentMode.simulation:
          return MockQrisPaymentService();
        case QrisPaymentMode.staticQris:
          return StaticQrisPaymentService(qrisConfig: _businessConfig.qrisConfig);
        case QrisPaymentMode.realGateway:
          return RealQrisPaymentService();
      }
    }
    return MockPaymentService();
  }

  ReceiptData getOrderReceiptData(Order order) {
    return _receiptService.buildReceiptData(order, _businessConfig);
  }

  Future<PrinterResult> printOrderReceipt(Order order) async {
    return _receiptService.printOrderReceipt(order, _businessConfig);
  }

  Future<PrinterResult> reprintReceipt(String orderNumber) async {
    return _receiptService.reprintReceipt(orderNumber);
  }

  Future<PrinterResult> testPrinter() async {
    return _receiptService.printerService.testPrint();
  }

  Future<TelegramSendResult> sendTelegramDailyReport() async {
    final now = DateTime.now();
    final top = topSellingProducts;
    final lowStockNames = [
      ...lowStockProducts.map((p) => '${p.name} (stok: ${p.stock})'),
      ...alertRawMaterials.map((m) => '${m.name} (stok: ${m.stock} ${m.unit.label})'),
    ];

    final reportData = DailyReportData(
      date: now,
      totalTransactions: todayTransactionsCount,
      totalSales: todaySalesTotal,
      cashSales: todayCashSales,
      qrisSales: todayQrisSales,
      debitSales: todayDebitSales,
      totalItemsSold: todayTotalItemsSold,
      averageOrderValue: todayAverageTransactionValue,
      topProducts: top,
      lowStockItems: lowStockNames,
      shiftReport: ShiftReportData(
        shiftName: _currentShift.shiftName,
        cashierName: _currentShift.cashierName,
        startTime: _currentShift.startTime,
        endTime: _currentShift.closedAt,
        startingCash: _currentShift.startingCash,
        expectedEndingCash: _currentShift.startingCash + todayCashSales,
        actualEndingCash: _currentShift.actualEndingCash ?? (_currentShift.startingCash + todayCashSales),
        variance: (_currentShift.actualEndingCash ?? (_currentShift.startingCash + todayCashSales)) -
            (_currentShift.startingCash + todayCashSales),
        cashSales: todayCashSales,
        qrisSales: todayQrisSales,
        totalSales: todaySalesTotal,
        totalTransactions: todayTransactionsCount,
        notes: _currentShift.closingNotes,
      ),
    );

    return _telegramNotificationService.sendDailyReport(reportData);
  }

  Future<TelegramSendResult> sendTelegramLowStockAlert() async {
    final items = <LowStockItemData>[];
    for (final p in lowStockProducts) {
      items.add(LowStockItemData(
        id: p.id,
        name: p.name,
        currentStock: p.stock,
        minimumStock: _businessConfig.defaultLowStockThreshold,
        unit: 'porsi',
      ));
    }
    for (final m in alertRawMaterials) {
      items.add(LowStockItemData(
        id: m.id,
        name: m.name,
        currentStock: m.stock,
        minimumStock: m.minimumStock,
        unit: m.unit.label,
      ));
    }
    return _telegramService.sendLowStockAlert(items);
  }

  Future<TelegramSendResult> testTelegramConnection() async {
    return _telegramService.testConnection();
  }

  // ==========================================
  // SHIFT MANAGEMENT
  // ==========================================
  /// Closes the current shift and archives it.
  ///
  /// Returns null without mutating anything when the shift is already closed,
  /// which prevents accidental duplicate closure of an archived shift.
  Future<TelegramSendResult?> closeShift({required int actualEndingCash, String? notes}) async {
    if (!hasActiveShift) {
      return null;
    }

    _currentShift = _currentShift.copyWith(
      isClosed: true,
      closedAt: DateTime.now(),
      actualEndingCash: actualEndingCash,
      closingNotes: notes,
    );
    _pastShifts.insert(0, _currentShift);
    notifyListeners();

    // Automatic Telegram Shift Closed notification
    return await _telegramNotificationService.onShiftClosed(
      _currentShift,
      totalSales: todaySalesTotal,
      cashSales: todayCashSales,
      qrisSales: todayQrisSales,
      totalTransactions: todayTransactionsCount,
    );
  }

  /// Opens a fresh shift, replacing the previously closed one.
  ///
  /// Returns false without mutating anything when a shift is already active, so
  /// an open shift cannot be silently discarded.
  bool startNewShift({required int startingCash}) {
    if (hasActiveShift) {
      return false;
    }

    final now = DateTime.now();
    _currentShift = ShiftInfo(
      shiftId: 'SHIFT-${now.millisecondsSinceEpoch.toString().substring(7)}',
      shiftName: 'Shift Baru (${now.hour}:00 - Selesai)',
      cashierName: _currentUser?.displayName ?? 'Siti Rahma (Kasir)',
      startTime: now,
      startingCash: startingCash,
    );
    notifyListeners();

    // Automatic Telegram Shift Opened notification (fire-and-forget)
    unawaited(_telegramNotificationService.onShiftOpened(_currentShift));
    return true;
  }

  // ==========================================
  // SALES ANALYTICS & EXECUTIVE METRICS
  // ==========================================
  int get todaySalesTotal => _orders
      .where((o) => o.status == OrderStatus.paid)
      .fold<int>(0, (sum, o) => sum + o.grandTotal);

  int get todayGrossSales => _orders
      .where((o) => o.status == OrderStatus.paid)
      .fold<int>(0, (sum, o) => sum + o.subtotal);

  int get todayTaxTotal => _orders
      .where((o) => o.status == OrderStatus.paid)
      .fold<int>(0, (sum, o) => sum + o.tax);

  int get todayServiceTotal => _orders
      .where((o) => o.status == OrderStatus.paid)
      .fold<int>(0, (sum, o) => sum + o.serviceCharge);

  int get todayNetSales => todayGrossSales;

  int get todayTransactionsCount => _orders
      .where((o) => o.status == OrderStatus.paid)
      .length;

  int get todayAverageTransactionValue => todayTransactionsCount > 0
      ? (todaySalesTotal / todayTransactionsCount).round()
      : 0;

  int get todayTotalItemsSold {
    int total = 0;
    for (final order in _orders) {
      if (order.status == OrderStatus.paid) {
        for (final item in order.items) {
          total += item.quantity;
        }
      }
    }
    return total;
  }

  int get todayCashSales => _orders
      .where((o) => o.status == OrderStatus.paid && o.paymentMethod == PaymentMethod.cash)
      .fold<int>(0, (sum, o) => sum + o.grandTotal);

  int get todayQrisSales => _orders
      .where((o) => o.status == OrderStatus.paid && o.paymentMethod == PaymentMethod.qris)
      .fold<int>(0, (sum, o) => sum + o.grandTotal);

  int get todayDebitSales => _orders
      .where((o) => o.status == OrderStatus.paid && o.paymentMethod == PaymentMethod.debitCard)
      .fold<int>(0, (sum, o) => sum + o.grandTotal);


  Map<String, int> get productSalesCounts {
    final map = <String, int>{};
    for (final order in _orders) {
      if (order.status == OrderStatus.paid) {
        for (final item in order.items) {
          map[item.product.name] = (map[item.product.name] ?? 0) + item.quantity;
        }
      }
    }
    return map;
  }

  List<MapEntry<String, int>> get topSellingProducts {
    final counts = productSalesCounts.entries.toList();
    counts.sort((a, b) => b.value.compareTo(a.value));
    return counts;
  }

  List<Product> get lowestSellingProducts {
    final counts = productSalesCounts;
    final sorted = List<Product>.from(_products);
    sorted.sort((a, b) {
      final countA = counts[a.name] ?? 0;
      final countB = counts[b.name] ?? 0;
      return countA.compareTo(countB);
    });
    return sorted.take(3).toList();
  }

  // PERIOD-BASED FILTERING
  // ==========================================

  /// The single canonical definition of every [ReportPeriod] window.
  ///
  /// Windows are inclusive rolling calendar-date ranges that end on, and
  /// include, [reference]'s own calendar date:
  ///
  ///  * [ReportPeriod.today]      -> 1 calendar date
  ///  * [ReportPeriod.last7Days]  -> 7 calendar dates (reference minus 6)
  ///  * [ReportPeriod.last30Days] -> 30 calendar dates (reference minus 29)
  ///
  /// Both endpoints are inclusive. Only the calendar date matters, so a sale at
  /// 23:59 still belongs to that day. Times are local: [reference] is expected
  /// to already be a local time, and no UTC conversion is applied anywhere.
  ///
  /// Taking [reference] as a parameter (rather than reading the clock here)
  /// keeps the window logic deterministic and unit-testable.
  static ({DateTime start, DateTime end}) periodWindow(
    ReportPeriod period,
    DateTime reference,
  ) {
    final today = DateTime(reference.year, reference.month, reference.day);
    final backDays = switch (period) {
      ReportPeriod.today => 0,
      ReportPeriod.last7Days => 6,
      ReportPeriod.last30Days => 29,
    };
    final start = today.subtract(Duration(days: backDays));
    return (start: start, end: today);
  }

  List<Order> _getOrdersInPeriod(DateTime start, DateTime end) {
    return _orders.where((o) {
      final orderDate = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);
      return orderDate.isAtSameMomentAs(startDate) ||
          (orderDate.isAfter(startDate) && orderDate.isBefore(endDate)) ||
          orderDate.isAtSameMomentAs(endDate);
    }).toList();
  }

  List<Order> getOrdersForPeriod(ReportPeriod period) {
    final window = periodWindow(period, DateTime.now());
    return _getOrdersInPeriod(window.start, window.end);
  }

  int getSalesTotalForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    return orders.where((o) => o.status == OrderStatus.paid).fold<int>(0, (sum, o) => sum + o.grandTotal);
  }

  int getTransactionsCountForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    return orders.where((o) => o.status == OrderStatus.paid).length;
  }

  int getAverageTransactionForPeriod(ReportPeriod period) {
    final count = getTransactionsCountForPeriod(period);
    final total = getSalesTotalForPeriod(period);
    return count > 0 ? (total / count).round() : 0;
  }

  int getTotalItemsSoldForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    int total = 0;
    for (final order in orders) {
      if (order.status == OrderStatus.paid) {
        for (final item in order.items) {
          total += item.quantity;
        }
      }
    }
    return total;
  }

  Map<String, int> getProductSalesCountsForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    final map = <String, int>{};
    for (final order in orders) {
      if (order.status == OrderStatus.paid) {
        for (final item in order.items) {
          map[item.product.name] = (map[item.product.name] ?? 0) + item.quantity;
        }
      }
    }
    return map;
  }

  List<MapEntry<String, int>> getTopSellingProductsForPeriod(ReportPeriod period) {
    final counts = getProductSalesCountsForPeriod(period).entries.toList();
    counts.sort((a, b) => b.value.compareTo(a.value));
    return counts;
  }

  int getCashSalesForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    return orders.where((o) => o.status == OrderStatus.paid && o.paymentMethod == PaymentMethod.cash)
        .fold<int>(0, (sum, o) => sum + o.grandTotal);
  }

  int getQrisSalesForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    return orders.where((o) => o.status == OrderStatus.paid && o.paymentMethod == PaymentMethod.qris)
        .fold<int>(0, (sum, o) => sum + o.grandTotal);
  }

  int getDebitSalesForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    return orders.where((o) => o.status == OrderStatus.paid && o.paymentMethod == PaymentMethod.debitCard)
        .fold<int>(0, (sum, o) => sum + o.grandTotal);
  }

  List<Order> getPaidOrdersForPeriod(ReportPeriod period) {
    final orders = getOrdersForPeriod(period);
    return orders.where((o) => o.status == OrderStatus.paid).toList();
  }
}

enum ReportPeriod { today, last7Days, last30Days }

/// One planned stock deduction + matching audit-history row.
///
/// A deduction is fully described before anything is applied, so the applied
/// mutation and the recorded history row can never disagree.
class _StockDeduction {
  /// Globally unique, stable across retries.
  final String adjustmentId;

  /// Index into `_products` or `_rawMaterials`, depending on [isRawMaterial].
  final int collectionIndex;

  final double quantity;
  final double previousStock;
  final double newStock;
  final String name;
  final String unit;
  final bool isRawMaterial;
  final double minimumStock;
  final String reason;

  const _StockDeduction({
    required this.adjustmentId,
    required this.collectionIndex,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    required this.name,
    required this.unit,
    required this.isRawMaterial,
    required this.minimumStock,
    required this.reason,
  });
}

/// The complete, validated set of mutations for one sale.
class _SalePlan {
  final String orderNumber;
  final List<_StockDeduction> productDeductions;
  final List<_StockDeduction> materialDeductions;
  final List<({String name, double amount, String unit})> deductionsList;
  final List<LowStockItemData> newlyLowStock = [];

  _SalePlan({
    required this.orderNumber,
    required this.productDeductions,
    required this.materialDeductions,
    required this.deductionsList,
  });
}

/// Minimal undo record for a sale commit.
class _SaleSnapshot {
  final Map<int, int> productStocks;
  final Map<int, double> materialStocks;
  final int ordersLength;
  final int adjustmentsLength;
  final Order? currentOrder;
  final List<CartItem> cart;

  const _SaleSnapshot({
    required this.productStocks,
    required this.materialStocks,
    required this.ordersLength,
    required this.adjustmentsLength,
    required this.currentOrder,
    required this.cart,
  });
}
