class BusinessProfile {
  const BusinessProfile({
    required this.businessId,
    required this.name,
    required this.city,
    required this.businessType,
    this.ownerName = '',
    this.deviceName = 'Android',
    this.defaultOpeningCash = 0,
    this.primaryButtonColor = '#B14E8A',
    this.secondaryButtonColor = '#6B6475',
    this.logoPath,
  });

  final String businessId;
  final String name;
  final String city;
  final String businessType;
  final String ownerName;
  final String deviceName;
  final double defaultOpeningCash;
  final String primaryButtonColor;
  final String secondaryButtonColor;
  final String? logoPath;

  Map<String, Object?> toMap() => {
        'business_id': businessId,
        'name': name,
        'city': city,
        'business_type': businessType,
        'owner_name': ownerName,
        'device_name': deviceName,
        'default_opening_cash': defaultOpeningCash,
        'primary_button_color': primaryButtonColor,
        'secondary_button_color': secondaryButtonColor,
        'logo_path': logoPath,
      };
}
