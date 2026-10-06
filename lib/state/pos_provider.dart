import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/table.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/shift.dart';
import '../models/customer.dart';
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
import '../services/receipt/receipt_service.dart';

class PosProvider extends ChangeNotifier {
  User? _currentUser;
  late List<Product> _products;
  late List<CafeTable> _tables;
  late List<Order> _orders;
  late ShiftInfo _currentShift;
  late List<ShiftInfo> _pastShifts;
  late List<ProductCategory> _categories;
  late List<Customer> _customers;
  late List<StockAdjustment> _stockAdjustments;
  late CafeSettings _settings;
  late BusinessConfig _businessConfig;
  late AppStorage _storage;
  late BusinessConfigService _configService;
  late ReceiptService _receiptService;
  late TelegramService _telegramService;
  late List<RawMaterial> _rawMaterials;
  late Map<String, ProductRecipe> _recipes;

  // Active Order Flow State
  CafeTable? _selectedTable;
  final List<CartItem> _cart = [];
  Order? _currentOrder; // Active pending/just-paid order

  PosProvider({AppStorage? storage, BusinessConfigService? configService}) {
    _initData(storage: storage, configService: configService);
    loadPersistedConfig();
  }

  void _initData({AppStorage? storage, BusinessConfigService? configService}) {
    _storage = storage ?? LocalAppStorage();
    _configService = configService ?? LocalBusinessConfigService(_storage);
    _businessConfig = _configService.config;
    _receiptService = ReceiptService();
    _receiptService.updatePrinterMode(_businessConfig.printerMode);
    _telegramService = TelegramBotService(config: _businessConfig.telegramConfig);

    _products = MockData.getInitialProducts();
    _tables = MockData.getInitialTables();
    _currentShift = MockData.getInitialShift();
    _pastShifts = MockData.getPastShifts();
    _orders = MockData.getInitialOrders(_products);
    _categories = [
      ProductCategory.coffee,
      ProductCategory.nonCoffee,
      ProductCategory.food,
      ProductCategory.snack,
      ProductCategory.dessert,
      ProductCategory.pastry,
    ];
    _customers = MockData.getInitialCustomers();
    _stockAdjustments = MockData.getInitialStockAdjustments();
    _settings = const CafeSettings();
    _rawMaterials = MockData.getInitialRawMaterials();
    _recipes = MockData.getInitialRecipes();
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  List<Product> get products => List.unmodifiable(_products);
  List<Product> get activeProducts => _products.where((p) => p.isActive).toList();
  List<CafeTable> get tables => List.unmodifiable(_tables);
  List<Order> get orders => List.unmodifiable(_orders);
  ShiftInfo get currentShift => _currentShift;
  List<ShiftInfo> get pastShifts => List.unmodifiable(_pastShifts);
  List<ShiftInfo> get allShifts => [_currentShift, ..._pastShifts];
  List<ProductCategory> get categories => List.unmodifiable(_categories);
  List<Customer> get customers => List.unmodifiable(_customers);
  List<StockAdjustment> get stockAdjustments => List.unmodifiable(_stockAdjustments);
  CafeSettings get settings => _settings;
  BusinessConfig get businessConfig => _businessConfig;
  BusinessConfigService get configService => _configService;
  ReceiptService get receiptService => _receiptService;
  PrinterService get printerService => _receiptService.printerService;
  TelegramService get telegramService => _telegramService;
  CafeTable? get selectedTable => _selectedTable;
  List<CartItem> get cart => List.unmodifiable(_cart);
  Order? get currentOrder => _currentOrder;

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
    _selectedTable = null;
    _currentOrder = null;
    notifyListeners();
  }

  void switchUserRole(UserRole role) {
    _currentUser = MockData.users.firstWhere((u) => u.role == role);
    notifyListeners();
  }

  // Table Selection (Cashier)
  void selectTable(CafeTable table) {
    _selectedTable = table;
    notifyListeners();
  }

  void clearSelectedTable() {
    _selectedTable = null;
    notifyListeners();
  }

  // Cart Management (Cashier)
  void addToCart(
    Product product, {
    int qty = 1,
    String notes = '',
    List<ModifierOption> modifiers = const [],
  }) {
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
    notifyListeners();
  }

  /// Preset Demo Order: 2x Kopi Susu Gula Aren, 1x French Fries
  void loadDemoQuickOrder() {
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
  int get cartSubtotal => _cart.fold<int>(0, (sum, item) => sum + item.itemTotal);
  int get cartServiceCharge => _businessConfig.isServiceEnabled
      ? (cartSubtotal * _businessConfig.serviceChargeRate).round()
      : 0;
  int get cartTax => _businessConfig.isTaxEnabled
      ? (cartSubtotal * _businessConfig.taxRate).round()
      : 0;
  int get cartGrandTotal => cartSubtotal + cartServiceCharge + cartTax;
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
  Order prepareCheckoutOrder({PaymentMethod paymentMethod = PaymentMethod.cash}) {
    final tableNum = _selectedTable?.number ?? 'Takeaway';
    final cashier = _currentUser?.displayName ?? 'Siti Rahma (Kasir)';
    final order = Order.create(
      orderNumber: generateOrderNumber(),
      tableNumber: tableNum,
      items: List.from(_cart),
      cashierName: cashier,
      paymentMethod: paymentMethod,
      status: OrderStatus.pending,
    );
    _currentOrder = order;
    notifyListeners();
    return order;
  }

  // Payment Execution & Automatic Stock Depletion
  Order completePayment({
    required PaymentMethod method,
    required int paidAmount,
    required int changeAmount,
  }) {
    if (_currentOrder == null) {
      prepareCheckoutOrder(paymentMethod: method);
    }

    final finishedOrder = _currentOrder!.copyWith(
      paymentMethod: method,
      status: OrderStatus.paid,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      createdAt: DateTime.now(),
    );

    // 1. Add to completed orders
    _orders.insert(0, finishedOrder);
    _currentOrder = finishedOrder;

    // 2. Finished-Product Stock Deduction
    for (final item in finishedOrder.items) {
      final productIndex = _products.indexWhere((p) => p.id == item.product.id);
      if (productIndex >= 0) {
        final currentStock = _products[productIndex].stock;
        final newStock = (currentStock - item.quantity).clamp(0, 9999);
        _products[productIndex].stock = newStock;
      }
    }

    // 2b. Raw Material Auto-Deduction based on Recipes and Modifiers
    for (final item in finishedOrder.items) {
      final ingredientsNeeded = getRequiredIngredientsForItem(item);
      for (final entry in ingredientsNeeded.entries) {
        final matIndex = _rawMaterials.indexWhere((m) => m.id == entry.key);
        if (matIndex >= 0) {
          final mat = _rawMaterials[matIndex];
          final prevStock = mat.stock;
          final deductAmount = entry.value;
          final newStock = (prevStock - deductAmount).clamp(0.0, 999999.0);
          _rawMaterials[matIndex].stock = newStock;

          final modInfo = item.hasModifiers ? ' [${item.modifierSummary}]' : '';
          _stockAdjustments.insert(
            0,
            StockAdjustment(
              id: 'ADJ-SALE-${DateTime.now().millisecondsSinceEpoch}-${mat.id}',
              productId: mat.id,
              productName: mat.name,
              type: AdjustmentType.sale,
              quantity: deductAmount,
              previousStock: prevStock,
              newStock: newStock,
              reason: 'Penjualan #${finishedOrder.orderNumber} (${item.quantity}x ${item.product.name}$modInfo)',
              timestamp: DateTime.now(),
              unit: mat.unit.label,
              isRawMaterial: true,
              adjustedBy: 'Sistem POS (Kasir)',
            ),
          );
        }
      }
    }

    // 3. Update Table Status if dine-in
    if (_selectedTable != null) {
      final tableIndex = _tables.indexWhere((t) => t.id == _selectedTable!.id);
      if (tableIndex >= 0) {
        _tables[tableIndex].status = TableStatus.occupied;
        _tables[tableIndex].currentOrderId = finishedOrder.orderNumber;
      }
    }

    // 4. Clear active cart
    _cart.clear();

    notifyListeners();
    return finishedOrder;
  }

  void freeTable(String tableNumber) {
    final index = _tables.indexWhere((t) => t.number == tableNumber);
    if (index >= 0) {
      _tables[index].status = TableStatus.available;
      _tables[index].currentOrderId = null;
      notifyListeners();
    }
  }

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
    if (recipe == null) return {};

    final Map<String, double> requiredPerUnit = {};

    // 1. Base recipe items
    for (final ing in recipe.items) {
      requiredPerUnit[ing.materialId] = ing.quantity;
    }

    // 2. Modifier overrides (e.g. Large size, Hot 0g ice, Less sugar, No sugar)
    for (final mod in item.selectedModifiers) {
      if (mod.rawMaterialOverrides != null) {
        for (final entry in mod.rawMaterialOverrides!.entries) {
          requiredPerUnit[entry.key] = entry.value;
        }
      }
    }

    // 3. Modifier additions (e.g. Extra Shot +9g beans, Extra Milk +50ml milk, Extra Matcha +5g matcha)
    for (final mod in item.selectedModifiers) {
      for (final entry in mod.rawMaterialAdditions.entries) {
        requiredPerUnit[entry.key] = (requiredPerUnit[entry.key] ?? 0.0) + entry.value;
      }
    }

    // Multiply by item quantity
    return requiredPerUnit.map((matId, qty) => MapEntry(matId, qty * item.quantity));
  }

  /// Check all items in cart for raw material shortages taking modifiers into account
  List<String> getCartInsufficientIngredients() {
    final Map<String, double> requiredTotals = {};
    final Map<String, RawMaterial> materialMap = {};

    for (final item in _cart) {
      final itemIngredients = getRequiredIngredientsForItem(item);
      for (final entry in itemIngredients.entries) {
        requiredTotals[entry.key] = (requiredTotals[entry.key] ?? 0.0) + entry.value;
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
  // OWNER: TABLE MANAGEMENT
  // ==========================================
  void addTable(CafeTable table) {
    _tables.add(table);
    notifyListeners();
  }

  void updateTable(CafeTable updatedTable) {
    final index = _tables.indexWhere((t) => t.id == updatedTable.id);
    if (index >= 0) {
      _tables[index] = updatedTable;
      notifyListeners();
    }
  }

  void deleteTable(String id) {
    _tables.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ==========================================
  // OWNER: CUSTOMER MANAGEMENT
  // ==========================================
  void addCustomer(Customer customer) {
    _customers.add(customer);
    notifyListeners();
  }

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
      _telegramService = TelegramBotService(config: loaded.telegramConfig);
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
    _telegramService = TelegramBotService(config: newConfig.telegramConfig);
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
        totalTransactions: todayTransactionsCount,
        notes: _currentShift.closingNotes,
      ),
    );

    return _telegramService.sendDailyReport(reportData);
  }

  Future<TelegramSendResult> sendTelegramShiftReport(ShiftInfo shift) async {
    final cashSales = todayCashSales;
    final expectedCash = shift.startingCash + cashSales;
    final actualCash = shift.actualEndingCash ?? expectedCash;
    final variance = actualCash - expectedCash;

    final shiftData = ShiftReportData(
      shiftName: shift.shiftName,
      cashierName: shift.cashierName,
      startTime: shift.startTime,
      endTime: shift.closedAt,
      startingCash: shift.startingCash,
      expectedEndingCash: expectedCash,
      actualEndingCash: actualCash,
      variance: variance,
      cashSales: cashSales,
      totalTransactions: todayTransactionsCount,
      notes: shift.closingNotes,
    );

    return _telegramService.sendShiftReport(shiftData);
  }

  Future<TelegramSendResult> sendTelegramLowStockAlert() async {
    final items = <LowStockItemData>[];
    for (final p in lowStockProducts) {
      items.add(LowStockItemData(
        name: p.name,
        currentStock: p.stock,
        minimumStock: _businessConfig.defaultLowStockThreshold,
        unit: 'porsi',
      ));
    }
    for (final m in alertRawMaterials) {
      items.add(LowStockItemData(
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
  void closeShift({required int actualEndingCash, String? notes}) {
    _currentShift = _currentShift.copyWith(
      isClosed: true,
      closedAt: DateTime.now(),
      actualEndingCash: actualEndingCash,
      closingNotes: notes,
    );
    _pastShifts.insert(0, _currentShift);
    notifyListeners();
  }

  void startNewShift({required int startingCash}) {
    final now = DateTime.now();
    _currentShift = ShiftInfo(
      shiftId: 'SHIFT-${now.millisecondsSinceEpoch.toString().substring(7)}',
      shiftName: 'Shift Baru (${now.hour}:00 - Selesai)',
      cashierName: _currentUser?.displayName ?? 'Siti Rahma (Kasir)',
      startTime: now,
      startingCash: startingCash,
    );
    notifyListeners();
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

  int get availableTablesCount => _tables.where((t) => t.isAvailable).length;
  int get occupiedTablesCount => _tables.where((t) => t.isOccupied).length;

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case ReportPeriod.today:
        return _getOrdersInPeriod(today, today);
      case ReportPeriod.last7Days:
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        return _getOrdersInPeriod(sevenDaysAgo, today);
      case ReportPeriod.last30Days:
        final thirtyDaysAgo = today.subtract(const Duration(days: 30));
        return _getOrdersInPeriod(thirtyDaysAgo, today);
    }
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
