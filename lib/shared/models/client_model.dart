class ClientModel {
  const ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    this.notes = '',
  });

  final String id;
  final String name;
  final String phone;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
      };
}
