class DailyClosingModel {
  const DailyClosingModel({
    required this.id,
    required this.workDate,
    required this.openedAt,
    required this.closedAt,
    required this.openingCash,
    required this.salesTotal,
    required this.expensesTotal,
    required this.expectedCashClosing,
    required this.exportFileName,
  });

  final String id;
  final String workDate;
  final DateTime openedAt;
  final DateTime closedAt;
  final double openingCash;
  final double salesTotal;
  final double expensesTotal;
  final double expectedCashClosing;
  final String exportFileName;

  Map<String, Object?> toMap() => {
        'id': id,
        'work_date': workDate,
        'opened_at': openedAt.toIso8601String(),
        'closed_at': closedAt.toIso8601String(),
        'opening_cash': openingCash,
        'sales_total': salesTotal,
        'expenses_total': expensesTotal,
        'expected_cash_closing': expectedCashClosing,
        'export_file_name': exportFileName,
      };
}
