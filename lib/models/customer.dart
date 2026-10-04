class Customer {
  final String id;
  final String name;
  final String phone;
  final int totalOrders;
  final int totalSpend;
  final DateTime lastTransaction;
  final String notes;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalOrders,
    required this.totalSpend,
    required this.lastTransaction,
    this.notes = '',
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    int? totalOrders,
    int? totalSpend,
    DateTime? lastTransaction,
    String? notes,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpend: totalSpend ?? this.totalSpend,
      lastTransaction: lastTransaction ?? this.lastTransaction,
      notes: notes ?? this.notes,
    );
  }
}
