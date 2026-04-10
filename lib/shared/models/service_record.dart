class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.performedAt,
    required this.clientId,
    required this.clientName,
    required this.workerId,
    required this.workerName,
    required this.serviceCode,
    required this.serviceName,
    required this.unitPrice,
    required this.paymentMethod,
    required this.status,
    this.notes = '',
  });

  final String id;
  final DateTime performedAt;
  final String clientId;
  final String clientName;
  final String workerId;
  final String workerName;
  final String serviceCode;
  final String serviceName;
  final double unitPrice;
  final String paymentMethod;
  final String status;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'performed_at': performedAt.toIso8601String(),
        'client_id': clientId,
        'client_name': clientName,
        'worker_id': workerId,
        'worker_name': workerName,
        'service_code': serviceCode,
        'service_name': serviceName,
        'unit_price': unitPrice,
        'payment_method': paymentMethod,
        'status': status,
        'notes': notes,
      };
}
