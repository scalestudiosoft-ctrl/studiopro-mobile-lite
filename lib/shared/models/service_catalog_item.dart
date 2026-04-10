class ServiceCatalogItem {
  const ServiceCatalogItem({
    required this.code,
    required this.name,
    required this.basePrice,
    this.active = true,
  });

  final String code;
  final String name;
  final double basePrice;
  final bool active;

  Map<String, Object?> toMap() => {
        'code': code,
        'name': name,
        'base_price': basePrice,
        'active': active ? 1 : 0,
      };
}
