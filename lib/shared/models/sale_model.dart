class SaleModel {
  const SaleModel({
    required this.id,
    required this.saleAt,
    required this.clientId,
    required this.workerId,
    required this.serviceRecordId,
    required this.netTotal,
    required this.paymentMethod,
    this.paymentStatus = 'paid',
  });

  final String id;
  final DateTime saleAt;
  final String clientId;
  final String workerId;
  final String serviceRecordId;
  final double netTotal;
  final String paymentMethod;
  final String paymentStatus;

  Map<String, Object?> toMap() => {
        'id': id,
        'sale_at': saleAt.toIso8601String(),
        'client_id': clientId,
        'worker_id': workerId,
        'service_record_id': serviceRecordId,
        'net_total': netTotal,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
      };
}
