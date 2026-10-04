class ShiftInfo {
  final String shiftId;
  final String shiftName;
  final String cashierName;
  final DateTime startTime;
  final int startingCash;
  bool isClosed;
  DateTime? closedAt;
  int? actualEndingCash;
  String? closingNotes;

  ShiftInfo({
    required this.shiftId,
    required this.shiftName,
    required this.cashierName,
    required this.startTime,
    required this.startingCash,
    this.isClosed = false,
    this.closedAt,
    this.actualEndingCash,
    this.closingNotes,
  });

  ShiftInfo copyWith({
    String? shiftId,
    String? shiftName,
    String? cashierName,
    DateTime? startTime,
    int? startingCash,
    bool? isClosed,
    DateTime? closedAt,
    int? actualEndingCash,
    String? closingNotes,
  }) {
    return ShiftInfo(
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      cashierName: cashierName ?? this.cashierName,
      startTime: startTime ?? this.startTime,
      startingCash: startingCash ?? this.startingCash,
      isClosed: isClosed ?? this.isClosed,
      closedAt: closedAt ?? this.closedAt,
      actualEndingCash: actualEndingCash ?? this.actualEndingCash,
      closingNotes: closingNotes ?? this.closingNotes,
    );
  }
}
