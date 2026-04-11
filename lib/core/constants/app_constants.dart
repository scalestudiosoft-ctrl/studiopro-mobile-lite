class AppConstants {
  static const String appName = 'Studio Pro Mobile Lite';
  static const String syncSchemaVersion = 'sp_mobile_sync_v1';
  static const String appVersion = '1.5.0';
  static const String defaultBusinessId = 'NEG-001';
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
