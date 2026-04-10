class CashMovementModel {
  const CashMovementModel({
    required this.id,
    required this.movementAt,
    required this.type,
    required this.concept,
    required this.amount,
    this.notes = '',
  });

  final String id;
  final DateTime movementAt;
  final String type;
  final String concept;
  final double amount;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'movement_at': movementAt.toIso8601String(),
        'type': type,
        'concept': concept,
        'amount': amount,
        'notes': notes,
      };
}
