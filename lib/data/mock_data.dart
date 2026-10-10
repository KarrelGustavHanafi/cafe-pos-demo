import '../models/user.dart';
import '../models/product.dart';
import '../models/table.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/shift.dart';
import '../models/stock_adjustment.dart';
import '../models/raw_material.dart';
import '../models/recipe.dart';
import '../models/modifier.dart';

class MockData {
  static final List<User> users = [
    const User(
      username: 'owner',
      displayName: 'Budi Santoso (Owner)',
      role: UserRole.owner,
    ),
    const User(
      username: 'cashier',
      displayName: 'Siti Rahma (Kasir)',
      role: UserRole.cashier,
    ),
  ];

  static const Map<String, String> presetPhotography = {
    'Kopi Susu Gula Aren': 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=600&q=80',
    'Americano': 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80',
    'Matcha Latte': 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=600&q=80',
    'Chocolate': 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?auto=format&fit=crop&w=600&q=80',
    'French Fries': 'https://images.unsplash.com/photo-1576107232684-1279f3908594?auto=format&fit=crop&w=600&q=80',
    'Croissant': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=600&q=80',
    'Chicken Katsu Rice': 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80',
    'Strawberry Matcha': 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=600&q=80',
    'Affogato Vanilla': 'https://images.unsplash.com/photo-1594911772125-07fc7a2d8d9f?auto=format&fit=crop&w=600&q=80',
    'Caramel Macchiato': 'https://images.unsplash.com/photo-1485808191679-5f86510681a2?auto=format&fit=crop&w=600&q=80',
  };

  static List<ModifierGroup> getKopiSusuModifiers() {
    return [
      const ModifierGroup(
        id: 'mg-ks-size',
        name: 'Ukuran (Size)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ks-size-reg',
        options: [
          ModifierOption(
            id: 'opt-ks-size-reg',
            name: 'Regular',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ks-size-lrg',
            name: 'Large',
            priceAdjustment: 4000,
            rawMaterialOverrides: {
              'MAT-001': 24.0, // Coffee Beans (Regular is 18g)
              'MAT-002': 180.0, // UHT Milk (Regular is 120ml)
              'MAT-003': 30.0, // Palm Sugar (Regular is 25g)
              'MAT-010': 130.0, // Ice (Regular is 100g)
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ks-temp',
        name: 'Suhu (Temperature)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ks-temp-ice',
        options: [
          ModifierOption(
            id: 'opt-ks-temp-ice',
            name: 'Ice',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ks-temp-hot',
            name: 'Hot',
            priceAdjustment: 0,
            rawMaterialOverrides: {
              'MAT-010': 0.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ks-sugar',
        name: 'Tingkat Gula (Sugar)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ks-sugar-norm',
        options: [
          ModifierOption(
            id: 'opt-ks-sugar-norm',
            name: 'Normal',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ks-sugar-less',
            name: 'Less Sugar',
            priceAdjustment: 0,
            rawMaterialOverrides: {
              'MAT-003': 15.0,
            },
          ),
          ModifierOption(
            id: 'opt-ks-sugar-no',
            name: 'No Sugar',
            priceAdjustment: 0,
            rawMaterialOverrides: {
              'MAT-003': 0.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ks-addon',
        name: 'Tambahan (Add-ons)',
        selectionType: ModifierSelectionType.multiple,
        isRequired: false,
        maxSelection: 4,
        options: [
          ModifierOption(
            id: 'opt-ks-addon-shot',
            name: 'Extra Shot',
            priceAdjustment: 5000,
            rawMaterialAdditions: {
              'MAT-001': 9.0, // +9g Coffee Beans
            },
          ),
          ModifierOption(
            id: 'opt-ks-addon-milk',
            name: 'Extra Milk',
            priceAdjustment: 3000,
            rawMaterialAdditions: {
              'MAT-002': 50.0, // +50ml Milk
            },
          ),
        ],
      ),
    ];
  }

  static List<ModifierGroup> getAmericanoModifiers() {
    return [
      const ModifierGroup(
        id: 'mg-am-size',
        name: 'Ukuran (Size)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-am-size-reg',
        options: [
          ModifierOption(
            id: 'opt-am-size-reg',
            name: 'Regular',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-am-size-lrg',
            name: 'Large',
            priceAdjustment: 4000,
            rawMaterialOverrides: {
              'MAT-001': 24.0,
              'MAT-010': 130.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-am-temp',
        name: 'Suhu (Temperature)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-am-temp-ice',
        options: [
          ModifierOption(
            id: 'opt-am-temp-ice',
            name: 'Ice',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-am-temp-hot',
            name: 'Hot',
            priceAdjustment: 0,
            rawMaterialOverrides: {
              'MAT-010': 0.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-am-addon',
        name: 'Tambahan (Add-ons)',
        selectionType: ModifierSelectionType.multiple,
        isRequired: false,
        maxSelection: 2,
        options: [
          ModifierOption(
            id: 'opt-am-addon-shot',
            name: 'Extra Shot',
            priceAdjustment: 5000,
            rawMaterialAdditions: {
              'MAT-001': 9.0,
            },
          ),
        ],
      ),
    ];
  }

  static List<ModifierGroup> getMatchaModifiers() {
    return [
      const ModifierGroup(
        id: 'mg-ml-size',
        name: 'Ukuran (Size)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ml-size-reg',
        options: [
          ModifierOption(
            id: 'opt-ml-size-reg',
            name: 'Regular',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ml-size-lrg',
            name: 'Large',
            priceAdjustment: 4000,
            rawMaterialOverrides: {
              'MAT-004': 12.0,
              'MAT-002': 240.0,
              'MAT-003': 20.0,
              'MAT-010': 130.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ml-temp',
        name: 'Suhu (Temperature)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ml-temp-ice',
        options: [
          ModifierOption(
            id: 'opt-ml-temp-ice',
            name: 'Ice',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ml-temp-hot',
            name: 'Hot',
            priceAdjustment: 0,
            rawMaterialOverrides: {
              'MAT-010': 0.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ml-sugar',
        name: 'Tingkat Gula (Sugar)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ml-sugar-norm',
        options: [
          ModifierOption(
            id: 'opt-ml-sugar-norm',
            name: 'Normal',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ml-sugar-less',
            name: 'Less Sugar',
            priceAdjustment: 0,
            rawMaterialOverrides: {
              'MAT-003': 8.0,
            },
          ),
          ModifierOption(
            id: 'opt-ml-sugar-no',
            name: 'No Sugar',
            priceAdjustment: 0,
            rawMaterialOverrides: {
              'MAT-003': 0.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ml-addon',
        name: 'Tambahan (Add-ons)',
        selectionType: ModifierSelectionType.multiple,
        isRequired: false,
        maxSelection: 3,
        options: [
          ModifierOption(
            id: 'opt-ml-addon-matcha',
            name: 'Extra Matcha',
            priceAdjustment: 5000,
            rawMaterialAdditions: {
              'MAT-004': 5.0,
            },
          ),
          ModifierOption(
            id: 'opt-ml-addon-milk',
            name: 'Extra Milk',
            priceAdjustment: 3000,
            rawMaterialAdditions: {
              'MAT-002': 50.0,
            },
          ),
        ],
      ),
    ];
  }

  static List<ModifierGroup> getFrenchFriesModifiers() {
    return [
      const ModifierGroup(
        id: 'mg-ff-size',
        name: 'Porsi (Size)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ff-size-reg',
        options: [
          ModifierOption(
            id: 'opt-ff-size-reg',
            name: 'Regular',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ff-size-lrg',
            name: 'Large',
            priceAdjustment: 5000,
            rawMaterialOverrides: {
              'MAT-006': 260.0,
              'MAT-007': 30.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ff-addon',
        name: 'Saus Tambahan',
        selectionType: ModifierSelectionType.multiple,
        isRequired: false,
        maxSelection: 2,
        options: [
          ModifierOption(
            id: 'opt-ff-cheese',
            name: 'Cheese Sauce',
            priceAdjustment: 3000,
          ),
          ModifierOption(
            id: 'opt-ff-chili',
            name: 'Chili Sauce',
            priceAdjustment: 2000,
          ),
        ],
      ),
    ];
  }

  static List<ModifierGroup> getChickenKatsuModifiers() {
    return [
      const ModifierGroup(
        id: 'mg-ck-portion',
        name: 'Porsi (Portion)',
        selectionType: ModifierSelectionType.single,
        isRequired: true,
        defaultOptionId: 'opt-ck-portion-reg',
        options: [
          ModifierOption(
            id: 'opt-ck-portion-reg',
            name: 'Regular',
            priceAdjustment: 0,
          ),
          ModifierOption(
            id: 'opt-ck-portion-lrg',
            name: 'Large',
            priceAdjustment: 6000,
            rawMaterialOverrides: {
              'MAT-009': 180.0,
              'MAT-007': 22.0,
            },
          ),
        ],
      ),
      const ModifierGroup(
        id: 'mg-ck-addon',
        name: 'Tambahan (Add-ons)',
        selectionType: ModifierSelectionType.multiple,
        isRequired: false,
        maxSelection: 2,
        options: [
          ModifierOption(
            id: 'opt-ck-rice',
            name: 'Extra Rice',
            priceAdjustment: 5000,
          ),
          ModifierOption(
            id: 'opt-ck-sauce',
            name: 'Extra Sauce',
            priceAdjustment: 2000,
          ),
        ],
      ),
    ];
  }

  static List<Product> getInitialProducts() {
    return [
      Product(
        id: 'PRD-001',
        name: 'Kopi Susu Gula Aren',
        price: 18000,
        costPrice: 7500,
        category: ProductCategory.coffee,
        stock: 38,
        lowStockThreshold: 15,
        description: 'Espresso blend pilihan dengan susu segar dingin dan sirup aren organik khas Caffe',
        imageUrl: presetPhotography['Kopi Susu Gula Aren']!,
        iconName: 'coffee',
        sku: 'CF-KSA-01',
        isActive: true,
        modifierGroups: getKopiSusuModifiers(),
      ),
      Product(
        id: 'PRD-002',
        name: 'Americano',
        price: 15000,
        costPrice: 5000,
        category: ProductCategory.coffee,
        stock: 45,
        lowStockThreshold: 15,
        description: 'Single/double shot espresso dengan air murni, aroma bold & acidity seimbang',
        imageUrl: presetPhotography['Americano']!,
        iconName: 'coffee',
        sku: 'CF-AMR-02',
        isActive: true,
        modifierGroups: getAmericanoModifiers(),
      ),
      Product(
        id: 'PRD-003',
        name: 'Matcha Latte',
        price: 20000,
        costPrice: 9000,
        category: ProductCategory.nonCoffee,
        stock: 32,
        lowStockThreshold: 15,
        description: 'Bubuk ceremonial Uji Matcha asli dengan susu creamy lembut nan menyegarkan',
        imageUrl: presetPhotography['Matcha Latte']!,
        iconName: 'matcha',
        sku: 'NC-MTC-03',
        isActive: true,
        modifierGroups: getMatchaModifiers(),
      ),
      Product(
        id: 'PRD-004',
        name: 'Chocolate',
        price: 19000,
        costPrice: 8000,
        category: ProductCategory.nonCoffee,
        stock: 0, // OUT OF STOCK for realistic demo
        lowStockThreshold: 10,
        description: 'Cokelat artisanal Belgia pekat dipadu susu hangat atau dingin',
        imageUrl: presetPhotography['Chocolate']!,
        iconName: 'chocolate',
        sku: 'NC-CHC-04',
        isActive: true,
      ),
      Product(
        id: 'PRD-005',
        name: 'French Fries',
        price: 17000,
        costPrice: 6500,
        category: ProductCategory.food,
        stock: 8, // LOW STOCK (8 <= 15) for demo scenario
        lowStockThreshold: 15,
        description: 'Kentang goreng renyah bumbu rosemary sea-salt & saus sambal spesial',
        imageUrl: presetPhotography['French Fries']!,
        iconName: 'fries',
        sku: 'FD-FFR-05',
        isActive: true,
        modifierGroups: getFrenchFriesModifiers(),
      ),
      Product(
        id: 'PRD-006',
        name: 'Croissant',
        price: 16000,
        costPrice: 7000,
        category: ProductCategory.pastry,
        stock: 24,
        lowStockThreshold: 10,
        description: 'French butter croissant berlapis garing di luar dan lembut wangi di dalam',
        imageUrl: presetPhotography['Croissant']!,
        iconName: 'croissant',
        sku: 'PS-CRS-06',
        isActive: true,
      ),
      Product(
        id: 'PRD-007',
        name: 'Chicken Katsu Rice',
        price: 28000,
        costPrice: 13000,
        category: ProductCategory.food,
        stock: 18,
        lowStockThreshold: 12,
        description: 'Nasi pulen hangat dengan dada ayam fillet katsu renyah & saus teriyaki gurih',
        imageUrl: presetPhotography['Chicken Katsu Rice']!,
        iconName: 'rice',
        sku: 'FD-CKR-07',
        isActive: true,
        modifierGroups: getChickenKatsuModifiers(),
      ),
    ];
  }

  static List<CafeTable> getInitialTables() {
    return [
      CafeTable(id: 'tbl-1', number: 'A01', status: TableStatus.available, capacity: 4),
      CafeTable(id: 'tbl-2', number: 'A02', status: TableStatus.available, capacity: 2),
      CafeTable(id: 'tbl-3', number: 'A03', status: TableStatus.occupied, capacity: 4),
      CafeTable(id: 'tbl-4', number: 'A04', status: TableStatus.available, capacity: 6),
      CafeTable(id: 'tbl-5', number: 'B01', status: TableStatus.occupied, capacity: 2),
      CafeTable(id: 'tbl-6', number: 'B02', status: TableStatus.available, capacity: 4),
      CafeTable(id: 'tbl-7', number: 'B03', status: TableStatus.available, capacity: 4),
      CafeTable(id: 'tbl-8', number: 'B04', status: TableStatus.available, capacity: 6),
      CafeTable(id: 'tbl-9', number: 'VIP-1', status: TableStatus.available, capacity: 8),
    ];
  }

  static ShiftInfo getInitialShift() {
    final now = DateTime.now();
    return ShiftInfo(
      shiftId: 'SHIFT-01',
      shiftName: 'Shift Pagi (08:00 - 16:00)',
      cashierName: 'Siti Rahma (Kasir)',
      startTime: DateTime(now.year, now.month, now.day, 8, 0),
      startingCash: 300000,
    );
  }

  static List<ShiftInfo> getPastShifts() {
    final now = DateTime.now();
    return [
      ShiftInfo(
        shiftId: 'SHIFT-YEST-02',
        shiftName: 'Shift Malam Kemarin',
        cashierName: 'Siti Rahma (Kasir)',
        startTime: DateTime(now.year, now.month, now.day - 1, 16, 0),
        startingCash: 300000,
        isClosed: true,
        closedAt: DateTime(now.year, now.month, now.day - 1, 23, 15),
        actualEndingCash: 852000,
        closingNotes: 'Semua transaksi cocok, penutupan lancar.',
      ),
      ShiftInfo(
        shiftId: 'SHIFT-YEST-01',
        shiftName: 'Shift Pagi Kemarin',
        cashierName: 'Siti Rahma (Kasir)',
        startTime: DateTime(now.year, now.month, now.day - 1, 8, 0),
        startingCash: 300000,
        isClosed: true,
        closedAt: DateTime(now.year, now.month, now.day - 1, 16, 0),
        actualEndingCash: 740000,
        closingNotes: 'Ada selisih pembulatan uang kembalian Rp1.000.',
      ),
    ];
  }

  static List<Order> getInitialOrders(List<Product> products) {
    final now = DateTime.now();

    // Sample previous order 1: Americano + Croissant (QRIS)
    final prodAmericano = products.firstWhere((p) => p.name == 'Americano');
    final prodCroissant = products.firstWhere((p) => p.name == 'Croissant');

    final items1 = [
      CartItem(product: prodAmericano, quantity: 1),
      CartItem(product: prodCroissant, quantity: 1),
    ];
    final order1 = Order.create(
      orderNumber: 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-0001',
      tableNumber: 'A03',
      items: items1,
      cashierName: 'Siti Rahma (Kasir)',
      paymentMethod: PaymentMethod.qris,
      status: OrderStatus.paid,
      paidAmount: 35650,
      createdAt: now.subtract(const Duration(hours: 3, minutes: 15)),
      taxRate: 0.10,
      serviceChargeRate: 0.05,
      isTaxEnabled: true,
      isServiceEnabled: true,
    );

    // Sample previous order 2: Matcha Latte x2 + Chicken Katsu (Cash)
    final prodMatcha = products.firstWhere((p) => p.name == 'Matcha Latte');
    final prodKatsu = products.firstWhere((p) => p.name == 'Chicken Katsu Rice');
    final items2 = [
      CartItem(product: prodMatcha, quantity: 2),
      CartItem(product: prodKatsu, quantity: 1),
    ];
    final order2 = Order.create(
      orderNumber: 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-0002',
      tableNumber: 'B01',
      items: items2,
      cashierName: 'Siti Rahma (Kasir)',
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.paid,
      paidAmount: 100000,
      changeAmount: 21800,
      createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
      taxRate: 0.10,
      serviceChargeRate: 0.05,
      isTaxEnabled: true,
      isServiceEnabled: true,
    );

    // Sample previous order 3: Kopi Susu x3 + French Fries (Debit Card)
    final prodKopi = products.firstWhere((p) => p.name == 'Kopi Susu Gula Aren');
    final prodFries = products.firstWhere((p) => p.name == 'French Fries');
    final items3 = [
      CartItem(product: prodKopi, quantity: 3),
      CartItem(product: prodFries, quantity: 1),
    ];
    final order3 = Order.create(
      orderNumber: 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-0003',
      tableNumber: 'A01',
      items: items3,
      cashierName: 'Siti Rahma (Kasir)',
      paymentMethod: PaymentMethod.debitCard,
      status: OrderStatus.paid,
      paidAmount: 81650,
      changeAmount: 0,
      createdAt: now.subtract(const Duration(minutes: 40)),
      taxRate: 0.10,
      serviceChargeRate: 0.05,
      isTaxEnabled: true,
      isServiceEnabled: true,
    );

    return [order3, order2, order1];
  }


  static List<StockAdjustment> getInitialStockAdjustments() {
    final now = DateTime.now();
    return [
      StockAdjustment(
        id: 'ADJ-001',
        productId: 'PRD-001',
        productName: 'Kopi Susu Gula Aren',
        type: AdjustmentType.add,
        quantity: 25,
        previousStock: 15,
        newStock: 40,
        reason: 'Restock biji kopi house blend & susu fresh',
        timestamp: now.subtract(const Duration(hours: 6)),
      ),
      StockAdjustment(
        id: 'ADJ-002',
        productId: 'PRD-005',
        productName: 'French Fries',
        type: AdjustmentType.remove,
        quantity: 2,
        previousStock: 10,
        newStock: 8,
        reason: 'Bahan rusak/terbuka kemasan saat penyimpanan',
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
      StockAdjustment(
        id: 'ADJ-MAT-001',
        productId: 'MAT-001',
        productName: 'Coffee Beans',
        type: AdjustmentType.add,
        quantity: 2000,
        previousStock: 3000,
        newStock: 5000,
        reason: 'Pengiriman supplier biji kopi arabika',
        timestamp: now.subtract(const Duration(days: 1)),
        unit: 'gram',
        isRawMaterial: true,
      ),
    ];
  }

  static List<RawMaterial> getInitialRawMaterials() {
    return [
      RawMaterial(
        id: 'MAT-001',
        name: 'Coffee Beans',
        category: RawMaterialCategory.coffee,
        unit: RawMaterialUnit.gram,
        stock: 5000.0,
        minimumStock: 1000.0,
      ),
      RawMaterial(
        id: 'MAT-002',
        name: 'UHT Milk',
        category: RawMaterialCategory.dairy,
        unit: RawMaterialUnit.ml,
        stock: 8000.0,
        minimumStock: 2000.0,
      ),
      RawMaterial(
        id: 'MAT-003',
        name: 'Palm Sugar',
        category: RawMaterialCategory.dairy,
        unit: RawMaterialUnit.gram,
        stock: 2000.0,
        minimumStock: 500.0,
      ),
      RawMaterial(
        id: 'MAT-004',
        name: 'Matcha Powder',
        category: RawMaterialCategory.powder,
        unit: RawMaterialUnit.gram,
        stock: 1000.0,
        minimumStock: 300.0,
      ),
      RawMaterial(
        id: 'MAT-005',
        name: 'Chocolate Powder',
        category: RawMaterialCategory.powder,
        unit: RawMaterialUnit.gram,
        stock: 1500.0,
        minimumStock: 400.0,
      ),
      RawMaterial(
        id: 'MAT-006',
        name: 'Potatoes',
        category: RawMaterialCategory.fresh,
        unit: RawMaterialUnit.gram,
        stock: 10000.0,
        minimumStock: 2500.0,
      ),
      RawMaterial(
        id: 'MAT-007',
        name: 'Cooking Oil',
        category: RawMaterialCategory.fresh,
        unit: RawMaterialUnit.ml,
        stock: 5000.0,
        minimumStock: 1500.0,
      ),
      RawMaterial(
        id: 'MAT-008',
        name: 'Croissant',
        category: RawMaterialCategory.fresh,
        unit: RawMaterialUnit.piece,
        stock: 30.0,
        minimumStock: 8.0,
      ),
      RawMaterial(
        id: 'MAT-009',
        name: 'Chicken',
        category: RawMaterialCategory.fresh,
        unit: RawMaterialUnit.gram,
        stock: 6000.0,
        minimumStock: 1500.0,
      ),
      RawMaterial(
        id: 'MAT-010',
        name: 'Ice',
        category: RawMaterialCategory.fresh,
        unit: RawMaterialUnit.gram,
        stock: 10000.0,
        minimumStock: 3000.0,
      ),
    ];
  }

  static Map<String, ProductRecipe> getInitialRecipes() {
    return {
      'PRD-001': ProductRecipe(
        productId: 'PRD-001', // Kopi Susu Gula Aren
        items: [
          const RecipeItem(materialId: 'MAT-001', materialName: 'Coffee Beans', quantity: 18.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-002', materialName: 'UHT Milk', quantity: 120.0, unit: RawMaterialUnit.ml),
          const RecipeItem(materialId: 'MAT-003', materialName: 'Palm Sugar', quantity: 25.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-010', materialName: 'Ice', quantity: 100.0, unit: RawMaterialUnit.gram),
        ],
      ),
      'PRD-002': ProductRecipe(
        productId: 'PRD-002', // Americano
        items: [
          const RecipeItem(materialId: 'MAT-001', materialName: 'Coffee Beans', quantity: 18.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-010', materialName: 'Ice', quantity: 100.0, unit: RawMaterialUnit.gram),
        ],
      ),
      'PRD-003': ProductRecipe(
        productId: 'PRD-003', // Matcha Latte
        items: [
          const RecipeItem(materialId: 'MAT-004', materialName: 'Matcha Powder', quantity: 8.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-002', materialName: 'UHT Milk', quantity: 180.0, unit: RawMaterialUnit.ml),
          const RecipeItem(materialId: 'MAT-003', materialName: 'Palm Sugar', quantity: 15.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-010', materialName: 'Ice', quantity: 100.0, unit: RawMaterialUnit.gram),
        ],
      ),
      'PRD-004': ProductRecipe(
        productId: 'PRD-004', // Chocolate
        items: [
          const RecipeItem(materialId: 'MAT-005', materialName: 'Chocolate Powder', quantity: 25.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-002', materialName: 'UHT Milk', quantity: 150.0, unit: RawMaterialUnit.ml),
          const RecipeItem(materialId: 'MAT-010', materialName: 'Ice', quantity: 100.0, unit: RawMaterialUnit.gram),
        ],
      ),
      'PRD-005': ProductRecipe(
        productId: 'PRD-005', // French Fries
        items: [
          const RecipeItem(materialId: 'MAT-006', materialName: 'Potatoes', quantity: 180.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-007', materialName: 'Cooking Oil', quantity: 20.0, unit: RawMaterialUnit.ml),
        ],
      ),
      'PRD-006': ProductRecipe(
        productId: 'PRD-006', // Croissant
        items: [
          const RecipeItem(materialId: 'MAT-008', materialName: 'Croissant', quantity: 1.0, unit: RawMaterialUnit.piece),
        ],
      ),
      'PRD-007': ProductRecipe(
        productId: 'PRD-007', // Chicken Katsu Rice
        items: [
          const RecipeItem(materialId: 'MAT-009', materialName: 'Chicken', quantity: 120.0, unit: RawMaterialUnit.gram),
          const RecipeItem(materialId: 'MAT-007', materialName: 'Cooking Oil', quantity: 15.0, unit: RawMaterialUnit.ml),
        ],
      ),
    };
  }
}
