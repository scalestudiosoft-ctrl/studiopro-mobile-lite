class AppConstants {
  static const String appName = 'Studio Pro';
  static const String syncSchemaVersion = 'sp_mobile_sync_v1';
  static const String appVersion = '2.6.0';
  static const String defaultBusinessId = 'NEG-001';
  static const String defaultPrimaryButtonColor = '#374151';
  static const String defaultSecondaryButtonColor = '#6B7280';

  static const List<String> paymentMethods = <String>[
    'efectivo',
    'transferencia',
    'tarjeta',
    'nequi',
    'daviplata',
    'otro',
  ];

  static const List<String> appointmentStatuses = <String>[
    'pendiente',
    'llego',
    'en proceso',
    'finalizado',
    'cancelado',
  ];
}
