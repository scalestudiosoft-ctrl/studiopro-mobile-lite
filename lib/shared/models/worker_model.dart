class WorkerModel {
  const WorkerModel({
    required this.id,
    required this.name,
    required this.commissionType,
    required this.commissionValue,
    this.phone,
    this.active = true,
  });

  final String id;
  final String name;
  final String commissionType;
  final double commissionValue;
  final String? phone;
  final bool active;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'commission_type': commissionType,
        'commission_value': commissionValue,
        'phone': phone,
        'active': active ? 1 : 0,
      };
}
