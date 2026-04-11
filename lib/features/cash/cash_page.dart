import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/services/daily_operation_validator.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/info_card.dart';

class CashPage extends StatefulWidget {
  const CashPage({super.key});

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  final _openingController = TextEditingController();
  final _movementConceptController = TextEditingController();
  final _movementAmountController = TextEditingController();
  final _movementNotesController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _saleNotesController = TextEditingController();
  final DailyOperationValidator _validator = const DailyOperationValidator();

  String _movementType = 'expense';
  String _movementPaymentMethod = 'efectivo';
  String _salePaymentMethod = 'efectivo';
  String? _selectedClientId;
  String? _selectedWorkerId;
  String? _selectedServiceCode;
  String? _appointmentId;
  bool _routePrefillDone = false;

  Map<String, Object?>? _session;
  List<Map<String, Object?>> _movements = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _salesRows = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _clients = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _workers = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _services = const <Map<String, Object?>>[];
  double _salesTotal = 0;
  double _expensesTotal = 0;
  Map<String, double> _paymentTotals = <String, double>{};

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routePrefillDone) return;
    _routePrefillDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyAppointmentFromRoute());
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    _openingController.dispose();
    _movementConceptController.dispose();
    _movementAmountController.dispose();
    _movementNotesController.dispose();
    _salePriceController.dispose();
    _saleNotesController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final workDate = formatDateOnly(DateTime.now());
    final session = await db.firstRow('cash_sessions', where: 'work_date = ? AND status = ?', whereArgs: <Object?>[workDate, 'open']);
    final business = await db.firstRow('business_profile');
    final clients = await db.queryAll('clients', orderBy: 'name ASC');
    final workers = await db.queryWhere('workers', where: 'active = ?', whereArgs: <Object?>[1], orderBy: 'name ASC');
    final services = await db.queryWhere('service_catalog', where: 'active = ?', whereArgs: <Object?>[1], orderBy: 'name ASC');
    final movements = await db.queryRaw('SELECT * FROM cash_movements WHERE substr(movement_at, 1, 10) = ? ORDER BY movement_at DESC', <Object?>[workDate]);
    final salesRows = await db.queryRaw('''
      SELECT
        s.*,
        sr.client_name AS client_name,
        sr.worker_name AS worker_name,
        sr.service_name AS service_name,
        sr.notes AS service_notes,
        sr.service_code AS service_code
      FROM sales s
      LEFT JOIN service_records sr ON sr.id = s.service_record_id
      WHERE substr(s.sale_at, 1, 10) = ?
      ORDER BY s.sale_at DESC
    ''', <Object?>[workDate]);

    double salesTotal = 0;
    double expensesTotal = 0;
    final paymentTotals = <String, double>{for (final method in AppConstants.paymentMethods) method: 0};
    for (final row in salesRows) {
      final total = (row['net_total'] as num).toDouble();
      salesTotal += total;
      final method = '${row['payment_method']}';
      paymentTotals[method] = (paymentTotals[method] ?? 0) + total;
    }
    for (final row in movements) {
      final amount = (row['amount'] as num).toDouble();
      if ('${row['type']}' == 'expense') expensesTotal += amount;
      if ('${row['type']}' == 'income' && '${row['payment_method']}' == 'efectivo') {
        paymentTotals['efectivo'] = (paymentTotals['efectivo'] ?? 0) + amount;
      }
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _movements = movements.where((m) => '${m['sale_id'] ?? ''}'.isEmpty).toList();
      _salesRows = salesRows;
      _clients = clients;
      _workers = workers;
      _services = services;
      _salesTotal = salesTotal;
      _expensesTotal = expensesTotal;
      _paymentTotals = paymentTotals;
      _selectedClientId ??= clients.isEmpty ? null : '${clients.first['id']}';
      _selectedWorkerId ??= workers.isEmpty ? null : '${workers.first['id']}';
      _selectedServiceCode ??= services.isEmpty ? null : '${services.first['code']}';
      _syncDefaultPrice(force: false);
      if (session == null && _openingController.text.trim().isEmpty) {
        _openingController.text = '${((business?['default_opening_cash'] as num?) ?? 0).toDouble().toInt()}';
      }
    });
  }

  Future<void> _applyAppointmentFromRoute() async {
    final appointmentId = GoRouterState.of(context).uri.queryParameters['appointmentId'];
    if (appointmentId == null || appointmentId.isEmpty) return;
    final row = await AppDatabase.instance.firstRow('appointments', where: 'id = ?', whereArgs: <Object?>[appointmentId]);
    if (!mounted || row == null) return;
    setState(() {
      _appointmentId = appointmentId;
      _selectedClientId = '${row['client_id']}';
      _selectedWorkerId = row['worker_id'] == null ? _selectedWorkerId : '${row['worker_id']}';
      _selectedServiceCode = row['service_code'] == null ? _selectedServiceCode : '${row['service_code']}';
      _saleNotesController.text = '${row['notes'] ?? ''}';
      _syncDefaultPrice(force: true);
    });
  }

  void _syncDefaultPrice({required bool force}) {
    final matched = _services.where((row) => '${row['code']}' == _selectedServiceCode).toList();
    if (matched.isNotEmpty && (force || _salePriceController.text.trim().isEmpty)) {
      _salePriceController.text = '${(matched.first['base_price'] as num).toDouble().toInt()}';
    }
  }

  Future<void> _openCash() async {
    final amount = double.tryParse(_openingController.text.trim().replaceAll(',', '.')) ?? 0;
    await AppDatabase.instance.insert('cash_sessions', <String, Object?>{
      'id': 'SESSION-${const Uuid().v4()}',
      'work_date': formatDateOnly(DateTime.now()),
      'opened_at': DateTime.now().toIso8601String(),
      'opening_cash': amount,
      'status': 'open',
      'opened_by': 'mobile_user',
      'closing_notes': '',
    });
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Caja abierta correctamente.');
  }

  Future<void> _closeCash() async {
    if (_session == null) return;
    await AppDatabase.instance.update('cash_sessions', <String, Object?>{
      'status': 'closed',
      'closed_at': DateTime.now().toIso8601String(),
      'closing_notes': _movementNotesController.text.trim(),
    }, where: 'id = ?', whereArgs: <Object?>[_session!['id']]);
    _movementNotesController.clear();
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Caja cerrada. Revisa el cierre del día para exportar el JSON.');
  }

  Future<void> _saveServiceSale() async {
    final validation = await _validator.validateForDate(DateTime.now());
    if (!validation.canRegisterService) {
      _showMessage(validation.blockingIssues.first);
      return;
    }
    if (_selectedClientId == null || _selectedWorkerId == null || _selectedServiceCode == null) {
      _showMessage('Cliente, profesional y servicio son obligatorios para facturar.');
      return;
    }
    final parsedPrice = double.tryParse(_salePriceController.text.trim().replaceAll(',', '.'));
    if (parsedPrice == null || parsedPrice <= 0) {
      _showMessage('Debes indicar un valor válido mayor que cero.');
      return;
    }
    final client = _clients.firstWhere((row) => '${row['id']}' == _selectedClientId);
    final worker = _workers.firstWhere((row) => '${row['id']}' == _selectedWorkerId);
    final service = _services.firstWhere((row) => '${row['code']}' == _selectedServiceCode);
    final now = DateTime.now();
    final serviceRecordId = 'SR-${const Uuid().v4()}';
    final saleId = 'SALE-${const Uuid().v4()}';
    final movementId = 'MOV-${const Uuid().v4()}';
    final db = AppDatabase.instance;
    await db.insert('service_records', <String, Object?>{
      'id': serviceRecordId,
      'performed_at': now.toIso8601String(),
      'client_id': client['id'],
      'client_name': client['name'],
      'worker_id': worker['id'],
      'worker_name': worker['name'],
      'service_code': service['code'],
      'service_name': service['name'],
      'unit_price': parsedPrice,
      'payment_method': _salePaymentMethod,
      'status': 'finalizado',
      'notes': _saleNotesController.text.trim(),
    });
    await db.insert('sales', <String, Object?>{
      'id': saleId,
      'sale_at': now.toIso8601String(),
      'client_id': client['id'],
      'worker_id': worker['id'],
      'service_record_id': serviceRecordId,
      'net_total': parsedPrice,
      'payment_method': _salePaymentMethod,
      'payment_status': 'paid',
    });
    await db.insert('cash_movements', <String, Object?>{
      'id': movementId,
      'movement_at': now.toIso8601String(),
      'type': 'income',
      'concept': 'Venta de servicio',
      'amount': parsedPrice,
      'payment_method': _salePaymentMethod,
      'notes': _saleNotesController.text.trim(),
      'sale_id': saleId,
      'client_id': client['id'],
      'client_name': client['name'],
      'worker_id': worker['id'],
      'worker_name': worker['name'],
      'service_code': service['code'],
      'service_name': service['name'],
    });
    if (_appointmentId != null) {
      await db.update('appointments', <String, Object?>{'status': 'finalizado'}, where: 'id = ?', whereArgs: <Object?>[_appointmentId]);
    }
    _appointmentId = null;
    _saleNotesController.clear();
    _syncDefaultPrice(force: true);
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Venta facturada en caja correctamente.');
  }

  Future<void> _saveMovement() async {
    if (_session == null) {
      _showMessage('Abre caja antes de registrar movimientos manuales.');
      return;
    }
    if (_movementConceptController.text.trim().isEmpty || _movementAmountController.text.trim().isEmpty) {
      _showMessage('Concepto y valor son obligatorios.');
      return;
    }
    final amount = double.tryParse(_movementAmountController.text.trim().replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      _showMessage('El valor del movimiento debe ser mayor que cero.');
      return;
    }
    await AppDatabase.instance.insert('cash_movements', <String, Object?>{
      'id': 'MOV-${const Uuid().v4()}',
      'movement_at': DateTime.now().toIso8601String(),
      'type': _movementType,
      'concept': _movementConceptController.text.trim(),
      'amount': amount,
      'payment_method': _movementPaymentMethod,
      'notes': _movementNotesController.text.trim(),
    });
    _movementConceptController.clear();
    _movementAmountController.clear();
    _movementNotesController.clear();
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Movimiento guardado.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final openingCash = _session == null ? 0.0 : (_session!['opening_cash'] as num).toDouble();
    final expectedCash = openingCash + (_paymentTotals['efectivo'] ?? 0) - _expensesTotal;
    return AppShell(
      title: 'Caja',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SizedBox(width: 220, child: InfoCard(title: 'Estado', value: _session == null ? 'Cerrada' : 'Abierta')),
              SizedBox(width: 220, child: InfoCard(title: 'Apertura', value: copCurrency.format(openingCash))),
              SizedBox(width: 220, child: InfoCard(title: 'Ventas de servicios', value: copCurrency.format(_salesTotal))),
              SizedBox(width: 220, child: InfoCard(title: 'Gastos / salidas', value: copCurrency.format(_expensesTotal))),
              SizedBox(width: 220, child: InfoCard(title: 'Caja esperada', value: copCurrency.format(expectedCash))),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_session == null ? 'Abrir caja' : 'Facturar servicio en caja', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_session == null
                      ? 'Abre caja antes de empezar a facturar.'
                      : 'La venta real nace aquí. Debe quedar ligado el cliente, el profesional, el servicio, el pago y el valor final.'),
                  const SizedBox(height: 12),
                  if (_session == null) ...<Widget>[
                    TextField(controller: _openingController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto inicial')),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _openCash, icon: const Icon(Icons.lock_open_outlined), label: const Text('Abrir caja')),
                  ] else ...<Widget>[
                    if (_appointmentId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                        child: const Text('Venta precargada desde Agenda. Revisa los datos y confirma la facturación.'),
                      ),
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      items: _clients.map((item) => DropdownMenuItem<String>(value: '${item['id']}', child: Text('${item['name']}'))).toList(),
                      onChanged: (value) => setState(() => _selectedClientId = value),
                      decoration: const InputDecoration(labelText: 'Cliente'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedWorkerId,
                      items: _workers.map((item) => DropdownMenuItem<String>(value: '${item['id']}', child: Text('${item['name']}'))).toList(),
                      onChanged: (value) => setState(() => _selectedWorkerId = value),
                      decoration: const InputDecoration(labelText: 'Profesional'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedServiceCode,
                      items: _services.map((item) => DropdownMenuItem<String>(value: '${item['code']}', child: Text('${item['name']}'))).toList(),
                      onChanged: (value) => setState(() { _selectedServiceCode = value; _syncDefaultPrice(force: true); }),
                      decoration: const InputDecoration(labelText: 'Servicio'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _salePriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor final')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _salePaymentMethod,
                      items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(method))).toList(),
                      onChanged: (value) => setState(() => _salePaymentMethod = value ?? 'efectivo'),
                      decoration: const InputDecoration(labelText: 'Método de pago'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _saleNotesController, decoration: const InputDecoration(labelText: 'Observaciones')),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _saveServiceSale, icon: const Icon(Icons.point_of_sale_outlined), label: const Text('Facturar servicio')),
                  ],
                ],
              ),
            ),
          ),
          if (_session != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Movimiento manual', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _movementType,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'expense', child: Text('Gasto / salida')),
                        DropdownMenuItem(value: 'income', child: Text('Ingreso extra')),
                      ],
                      onChanged: (value) => setState(() => _movementType = value ?? 'expense'),
                      decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _movementConceptController, decoration: const InputDecoration(labelText: 'Concepto')),
                    const SizedBox(height: 12),
                    TextField(controller: _movementAmountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _movementPaymentMethod,
                      items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(method))).toList(),
                      onChanged: (value) => setState(() => _movementPaymentMethod = value ?? 'efectivo'),
                      decoration: const InputDecoration(labelText: 'Método de pago'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _movementNotesController, decoration: const InputDecoration(labelText: 'Notas')),
                    const SizedBox(height: 12),
                    Row(children: <Widget>[
                      Expanded(child: FilledButton.icon(onPressed: _saveMovement, icon: const Icon(Icons.save_outlined), label: const Text('Guardar movimiento'))),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(onPressed: _closeCash, icon: const Icon(Icons.task_alt_outlined), label: const Text('Cerrar caja'))),
                    ]),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Ventas registradas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_salesRows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Todavía no hay ventas de servicios registradas hoy.'))),
          ..._salesRows.map((sale) {
            final amount = (sale['net_total'] as num).toDouble();
            final saleAt = DateTime.tryParse('${sale['sale_at']}');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(child: Text('${sale['service_name'] ?? 'Servicio'}', style: Theme.of(context).textTheme.titleMedium)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(999)), child: const Text('Venta de servicio')),
                  ]),
                  const SizedBox(height: 10),
                  _detailLine(context, Icons.person_outline, 'Cliente', '${sale['client_name'] ?? 'Cliente sin nombre'}'),
                  _detailLine(context, Icons.badge_outlined, 'Profesional', '${sale['worker_name'] ?? 'Profesional sin asignar'}'),
                  _detailLine(context, Icons.payments_outlined, 'Pago', '${sale['payment_method']}'),
                  if (saleAt != null) _detailLine(context, Icons.schedule_outlined, 'Hora', formatShortDateTime(saleAt)),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: Text(copCurrency.format(amount), style: Theme.of(context).textTheme.headlineSmall)),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text('Movimientos manuales', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_movements.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay ingresos extras ni gastos manuales registrados hoy.'))),
          ..._movements.map((movement) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              title: Text('${movement['concept']}'),
              subtitle: Text('${movement['type'] == 'expense' ? 'Gasto / salida' : 'Ingreso extra'} • ${movement['payment_method']} • ${formatShortDateTime(DateTime.parse('${movement['movement_at']}'))}'),
              trailing: Text(copCurrency.format((movement['amount'] as num).toDouble())),
            ),
          )),
        ],
      ),
    );
  }

  Widget _detailLine(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value')),
        ],
      ),
    );
  }
}
