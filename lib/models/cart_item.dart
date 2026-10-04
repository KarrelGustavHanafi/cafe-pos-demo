import 'product.dart';
import 'modifier.dart';

class CartItem {
  final Product product;
  int quantity;
  String notes;
  final List<ModifierOption> selectedModifiers;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes = '',
    this.selectedModifiers = const [],
  });

  /// Total price adjustment from selected modifiers for one unit
  int get modifierPriceTotal =>
      selectedModifiers.fold<int>(0, (sum, m) => sum + m.priceAdjustment);

  /// Single unit price including product base price + all modifiers
  int get unitPrice => product.price + modifierPriceTotal;

  /// Total price for this cart line = unitPrice * quantity
  int get itemTotal => unitPrice * quantity;

  /// Formatted single-line summary of selected modifiers
  String get modifierSummary => selectedModifiers.map((m) => m.name).join(' • ');

  bool get hasModifiers => selectedModifiers.isNotEmpty;

  /// Unique signature to keep differently customized products separate in cart
  String get customKey {
    final sortedModifierIds = selectedModifiers.map((m) => m.id).toList()..sort();
    return '${product.id}__${sortedModifierIds.join("__")}__${notes.trim()}';
  }

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? notes,
    List<ModifierOption>? selectedModifiers,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      selectedModifiers: selectedModifiers ?? List.from(this.selectedModifiers),
    );
  }
}
