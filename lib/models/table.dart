enum TableStatus {
  available('Tersedia'),
  occupied('Terisi');

  final String label;
  const TableStatus(this.label);
}

class CafeTable {
  final String id;
  final String number;
  TableStatus status;
  final int capacity;
  String? currentOrderId;

  CafeTable({
    required this.id,
    required this.number,
    this.status = TableStatus.available,
    this.capacity = 4,
    this.currentOrderId,
  });

  bool get isAvailable => status == TableStatus.available;
  bool get isOccupied => status == TableStatus.occupied;

  CafeTable copyWith({
    String? id,
    String? number,
    TableStatus? status,
    int? capacity,
    String? currentOrderId,
  }) {
    return CafeTable(
      id: id ?? this.id,
      number: number ?? this.number,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      currentOrderId: currentOrderId ?? this.currentOrderId,
    );
  }
}
