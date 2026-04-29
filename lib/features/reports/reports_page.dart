import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/info_card.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _loading = true;

  double _salesTotal = 0;
  int _salesCount = 0;
  double _averageTicket = 0;
  List<Map<String, Object?>> _salesRows = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _paymentRows = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _serviceRows = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _workerRows = const <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_handleDataChanged);
    _loadReport();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleDataChanged() {
    if (mounted) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    final start = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final end = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59, 999);
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();
    final db = AppDatabase.instance;

    final salesRows = await db.queryRaw(
      '''
      SELECT
        s.id,
        s.sale_at,
        s.net_total,
        s.payment_method,
        COALESCE(s.client_name, '') AS client_name,
        COALESCE(s.worker_name, '') AS worker_name,
        COALESCE(s.service_name, '') AS service_name,
        COALESCE(s.origin_type, '') AS origin_type
      FROM sales s
      WHERE s.sale_at >= ? AND s.sale_at <= ?
      ORDER BY s.sale_at DESC
      ''',
      <Object?>[startIso, endIso],
    );

    final summaryRows = await db.queryRaw(
      '''
      SELECT
        COUNT(*) AS sales_count,
        COALESCE(SUM(net_total), 0) AS sales_total,
        COALESCE(AVG(net_total), 0) AS average_ticket
      FROM sales
      WHERE sale_at >= ? AND sale_at <= ?
      ''',
      <Object?>[startIso, endIso],
    );

    final paymentRows = await db.queryRaw(
      '''
      SELECT
        payment_method,
        COUNT(*) AS quantity,
        COALESCE(SUM(net_total), 0) AS total
      FROM sales
      WHERE sale_at >= ? AND sale_at <= ?
      GROUP BY payment_method
      ORDER BY total DESC, payment_method ASC
      ''',
      <Object?>[startIso, endIso],
    );

    final serviceRows = await db.queryRaw(
      '''
      SELECT
        COALESCE(service_name, 'Sin servicio') AS label,
        COUNT(*) AS quantity,
        COALESCE(SUM(net_total), 0) AS total
      FROM sales
      WHERE sale_at >= ? AND sale_at <= ?
      GROUP BY COALESCE(service_name, 'Sin servicio')
      ORDER BY total DESC, quantity DESC, label ASC
      LIMIT 5
      ''',
      <Object?>[startIso, endIso],
    );

    final workerRows = await db.queryRaw(
      '''
      SELECT
        COALESCE(worker_name, 'Sin profesional') AS label,
        COUNT(*) AS quantity,
        COALESCE(SUM(net_total), 0) AS total
      FROM sales
      WHERE sale_at >= ? AND sale_at <= ?
      GROUP BY COALESCE(worker_name, 'Sin profesional')
      ORDER BY total DESC, quantity DESC, label ASC
      LIMIT 5
      ''',
      <Object?>[startIso, endIso],
    );

    final summary = summaryRows.isEmpty ? null : summaryRows.first;

    if (!mounted) return;
    setState(() {
      _salesRows = salesRows;
      _paymentRows = paymentRows;
      _serviceRows = serviceRows;
      _workerRows = workerRows;
      _salesCount = ((summary?['sales_count'] as num?) ?? 0).toInt();
      _salesTotal = ((summary?['sales_total'] as num?) ?? 0).toDouble();
      _averageTicket = ((summary?['average_ticket'] as num?) ?? 0).toDouble();
      _loading = false;
    });
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = picked;
      if (_toDate.isBefore(_fromDate)) {
        _toDate = picked;
      }
    });
    await _loadReport();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _toDate = picked);
    await _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Informes de ventas',
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Rango del informe',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consulta ventas registradas entre dos fechas y revisa totales, formas de pago y detalle.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromDate,
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: Text('Desde\n${formatShortDate(_fromDate)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickToDate,
                            icon: const Icon(Icons.event_available_rounded),
                            label: Text('Hasta\n${formatShortDate(_toDate)}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 176,
                      child: InfoCard(
                        title: 'Ventas del rango',
                        value: formatCopCompact(_salesTotal),
                        subtitle: 'Total vendido en el periodo',
                        subtitleMaxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 176,
                      child: InfoCard(
                        title: 'Facturas registradas',
                        value: '$_salesCount',
                        subtitle: 'Ventas cerradas',
                        subtitleMaxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 176,
                      child: InfoCard(
                        title: 'Ticket promedio',
                        value: formatCopCompact(_averageTicket),
                        subtitle: 'Promedio por factura',
                        subtitleMaxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 176,
                      child: InfoCard(
                        title: 'Periodo',
                        value: '${formatShortDate(_fromDate)}\n-\n${formatShortDate(_toDate)}',
                        subtitle: _salesCount == 0 ? 'Sin ventas' : 'Periodo consultado',
                        valueMaxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _BreakdownCard(title: 'Ventas por método de pago', rows: _paymentRows, emptyLabel: 'No hay pagos registrados en el rango.'),
              const SizedBox(height: 16),
              _BreakdownCard(title: 'Top servicios', rows: _serviceRows, emptyLabel: 'No hay servicios vendidos todavía.'),
              const SizedBox(height: 16),
              _BreakdownCard(title: 'Top profesionales', rows: _workerRows, emptyLabel: 'No hay profesionales con ventas en el rango.'),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Detalle de ventas',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (_salesRows.isEmpty)
                        Text(
                          'No hay ventas registradas entre las fechas seleccionadas.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                        )
                      else
                        Column(
                          children: _salesRows.map((row) => _SaleRow(row: row)).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.rows,
    required this.emptyLabel,
  });

  final String title;
  final List<Map<String, Object?>> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)))
            else
              Column(
                children: rows.map((row) {
                  final label = '${row['payment_method'] ?? row['label'] ?? ''}'.trim().isEmpty
                      ? 'Sin dato'
                      : '${row['payment_method'] ?? row['label']}';
                  final quantity = ((row['quantity'] as num?) ?? 0).toInt();
                  final total = ((row['total'] as num?) ?? 0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('$quantity registros', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            formatCopCompact(total),
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.row});

  final Map<String, Object?> row;

  @override
  Widget build(BuildContext context) {
    final saleAtRaw = '${row['sale_at'] ?? ''}';
    final saleAt = saleAtRaw.isEmpty ? null : DateTime.tryParse(saleAtRaw);
    final serviceName = '${row['service_name'] ?? ''}'.trim().isEmpty ? 'Servicio sin nombre' : '${row['service_name']}';
    final clientName = '${row['client_name'] ?? ''}'.trim().isEmpty ? 'Cliente no identificado' : '${row['client_name']}';
    final workerName = '${row['worker_name'] ?? ''}'.trim().isEmpty ? 'Profesional no identificado' : '${row['worker_name']}';
    final paymentMethod = '${row['payment_method'] ?? ''}'.trim().isEmpty ? 'Sin método' : '${row['payment_method']}';
    final total = ((row['net_total'] as num?) ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  serviceName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  formatCopCompact(total),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(clientName, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text('Profesional: $workerName', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(
            '${saleAt == null ? 'Fecha inválida' : formatShortDateTime(saleAt)} • $paymentMethod',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
