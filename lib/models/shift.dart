/// Immutable, point-in-time record of a shift's trading results.
///
/// Captured once, when the shift is closed, from the orders actually attributed
/// to that shift. Closed-shift figures are then READ from here rather than
/// recomputed from the live order list, which previously made a closed shift's
/// history dependent on unrelated later activity.
///
/// This is a value type, deliberately not a new entity: it has no identity, is
/// never persisted on its own, and exists only to make a closed shift
/// auditable.
///
/// SCOPE: like everything else in this demo, the summary lives only as long as
/// the in-memory model. It survives neither a browser reload nor a restart —
/// there is no persistence layer yet. Making it durable is a storage concern,
/// not a change to this type.
class ShiftCloseSummary {
  /// Sum of grand totals of paid orders attributed to the shift.
  final int totalSales;

  /// Paid cash sales only. The only figure that belongs in a drawer total.
  final int cashSales;

  /// Paid QRIS sales. Non-cash tender never enters the physical till.
  final int qrisSales;

  /// Paid debit-card sales. Non-cash tender, reported for completeness only.
  final int debitSales;

  /// Number of paid orders attributed to the shift.
  final int paidTransactionCount;

  const ShiftCloseSummary({
    required this.totalSales,
    required this.cashSales,
    required this.qrisSales,
    required this.debitSales,
    required this.paidTransactionCount,
  });

  @override
  String toString() =>
      'ShiftCloseSummary(total: $totalSales, cash: $cashSales, '
      'qris: $qrisSales, debit: $debitSales, tx: $paidTransactionCount)';
}

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

  /// Trading results frozen at close time, or `null` when no snapshot exists.
  ///
  /// `null` is meaningful and must be respected, not treated as zero:
  ///
  ///  * an open shift has not been summarised yet;
  ///  * a seeded historical shift predates this field and genuinely has no
  ///    recorded breakdown — its `actualEndingCash` is authored sample data.
  ///
  /// Consumers must render "not available" rather than inventing figures.
  ShiftCloseSummary? summary;

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
    this.summary,
  });

  /// Cash the drawer should hold at close, derived from the frozen snapshot.
  ///
  /// `null` when there is no snapshot, so a missing summary can never be
  /// silently rendered as "the drawer balanced".
  int? get expectedEndingCash =>
      summary == null ? null : startingCash + summary!.cashSales;

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
    ShiftCloseSummary? summary,
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
      summary: summary ?? this.summary,
    );
  }
}
