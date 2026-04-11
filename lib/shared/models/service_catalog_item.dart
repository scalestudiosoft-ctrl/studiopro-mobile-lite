class ServiceCatalogItem {
  const ServiceCatalogItem({
    required this.code,
    required this.name,
    required this.basePrice,
    this.durationMinutes = 45,
    this.commissionPercent = 0,
    this.description = '',
    this.active = true,
  });

  final String code;
  final String name;
  final double basePrice;
  final int durationMinutes;
  final double commissionPercent;
  final String description;
  final bool active;

  Map<String, Object?> toMap() => {
        'code': code,
        'name': name,
        'base_price': basePrice,
        'duration_minutes': durationMinutes,
        'commission_percent': commissionPercent,
        'description': description,
        'active': active ? 1 : 0,
      };
}
