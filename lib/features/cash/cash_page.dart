import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
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
  String? _salePaymentMethod;
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

    List<Map<String, Object?>> movements = const <Map<String, Object?>>[];
    List<Map<String, Object?>> salesRows = const <Map<String, Object?>>[];
    double salesTotal = 0;
    double expensesTotal = 0;
    final paymentTotals = <String, double>{for (final method in AppConstants.paymentMethods) method: 0};

    if (session != null) {
      movements = await db.queryRaw(
        'SELECT * FROM cash_movements WHERE cash_session_id = ? ORDER BY movement_at DESC',
        <Object?>[session['id']],
      );
      salesRows = await db.queryRaw(
        '''
        SELECT
          s.*,
          sr.client_name AS client_name,
          sr.worker_name AS worker_name,
          sr.service_name AS service_name,
          sr.notes AS service_notes,
          sr.service_code AS service_code,
          sr.status AS service_status,
          sr.origin_type AS origin_type
        FROM sales s
        LEFT JOIN service_records sr ON sr.id = s.service_record_id
        WHERE s.cash_session_id = ?
        ORDER BY s.sale_at DESC
      ''',
        <Object?>[session['id']],
      );
      for (final row in salesRows) {
        final total = (row['net_total'] as num).toDouble();
        salesTotal += total;
        final method = '${row['payment_method']}';
        paymentTotals[method] = (paymentTotals[method] ?? 0) + total;
      }
      for (final row in movements) {
        final amount = (row['amount'] as num).toDouble();
        if ('${row['type']}' == 'expense') expensesTotal += amount;
        if ('${row['type']}' == 'income' && '${row['sale_id'] ?? ''}'.isEmpty) {
          final method = '${row['payment_method'] ?? 'efectivo'}';
          paymentTotals[method] = (paymentTotals[method] ?? 0) + amount;
        }
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
    final serviceCode = row['service_code'] == null ? null : '${row['service_code']}';
    final matched = _services.where((item) => '${item['code']}' == serviceCode).toList();
    setState(() {
      _appointmentId = appointmentId;
      _selectedClientId = '${row['client_id']}';
      _selectedWorkerId = row['worker_id'] == null ? null : '${row['worker_id']}';
      _selectedServiceCode = serviceCode;
      _saleNotesController.text = '${row['notes'] ?? ''}';
      if (matched.isNotEmpty) {
        _salePriceController.text = '${(matched.first['base_price'] as num).toDouble().toInt()}';
      }
    });
    _showMessage('Datos traídos desde Agenda. Revisa y confirma la venta.');
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
    _showMessage('Caja cerrada. La siguiente apertura empezará un historial nuevo.');
  }

  Future<void> _saveServiceSale() async {
    final validation = await _validator.validateForDate(DateTime.now());
    if (!validation.canRegisterService) {
      _showMessage(validation.blockingIssues.first);
      return;
    }
    if (_session == null) {
      _showMessage('Debes abrir caja antes de facturar.');
      return;
    }
    if (_selectedClientId == null || _selectedWorkerId == null || _selectedServiceCode == null || _salePaymentMethod == null) {
      _showMessage('Cliente, profesional, servicio y método de pago son obligatorios para facturar.');
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
    final originType = _appointmentId == null ? 'cash_manual' : 'appointment';
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
      'cash_session_id': _session!['id'],
      'source_appointment_id': _appointmentId,
      'origin_type': originType,
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
      'client_name': client['name'],
      'worker_name': worker['name'],
      'service_code': service['code'],
      'service_name': service['name'],
      'cash_session_id': _session!['id'],
      'source_appointment_id': _appointmentId,
      'origin_type': originType,
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
      'cash_session_id': _session!['id'],
      'source_appointment_id': _appointmentId,
      'origin_type': originType,
    });
    if (_appointmentId != null) {
      await db.update(
        'appointments',
        <String, Object?>{
          'status': 'finalizado',
          'worker_id': worker['id'],
          'worker_name': worker['name'],
          'service_code': service['code'],
          'service_name': service['name'],
          'notes': _saleNotesController.text.trim(),
        },
        where: 'id = ?',
        whereArgs: <Object?>[_appointmentId],
      );
    }
    _appointmentId = null;
    _selectedClientId = null;
    _selectedWorkerId = null;
    _selectedServiceCode = null;
    _salePaymentMethod = null;
    _salePriceController.clear();
    _saleNotesController.clear();
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Venta registrada y enviada al cierre como servicio real.');
  }


  Future<void> _deleteSale(Map<String, Object?> sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar factura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Se eliminará la venta y su impacto en caja.'),
            const SizedBox(height: 12),
            Text('Cliente: ${sale['client_name'] ?? '-'}'),
            Text('Profesional: ${sale['worker_name'] ?? '-'}'),
            Text('Servicio: ${sale['service_name'] ?? '-'}'),
            Text('Valor: ${copCurrency.format((sale['net_total'] as num).toDouble())}'),
            Text('Pago: ${_paymentLabel('${sale['payment_method']}')}'),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar factura')),
        ],
      ),
    );
    if (confirm != true) return;

    final db = AppDatabase.instance;
    final saleId = '${sale['id']}';
    final serviceRecordId = '${sale['service_record_id'] ?? ''}';
    final appointmentId = '${sale['source_appointment_id'] ?? ''}'.trim();
    final saleAt = DateTime.tryParse('${sale['sale_at'] ?? ''}') ?? DateTime.now();

    await db.executeBatch((batch) async {
      batch.delete('cash_movements', where: 'sale_id = ?', whereArgs: <Object?>[saleId]);
      batch.delete('sales', where: 'id = ?', whereArgs: <Object?>[saleId]);
      if (serviceRecordId.isNotEmpty) {
        batch.delete('service_records', where: 'id = ?', whereArgs: <Object?>[serviceRecordId]);
      }
      if (appointmentId.isNotEmpty) {
        batch.insert(
          'appointments',
          <String, Object?>{
            'id': appointmentId,
            'client_id': sale['client_id'] ?? '',
            'client_name': sale['client_name'] ?? '',
            'worker_id': sale['worker_id'],
            'worker_name': sale['worker_name'],
            'service_code': sale['service_code'],
            'service_name': sale['service_name'],
            'scheduled_at': saleAt.toIso8601String(),
            'status': 'pendiente',
            'notes': 'Restaurada desde factura eliminada',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage(appointmentId.isNotEmpty
        ? 'Factura eliminada. La cita volvió a Agenda como pendiente.'
        : 'Factura eliminada correctamente.');
  }

  Future<void> _saveMovement() async {
    if (_session == null) {
      _showMessage('Abre caja para registrar movimientos manuales.');
      return;
    }
    if (_movementConceptController.text.trim().isEmpty) {
      _showMessage('Debes indicar el concepto.');
      return;
    }
    final amount = double.tryParse(_movementAmountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showMessage('Debes indicar un valor válido.');
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
      'cash_session_id': _session!['id'],
      'origin_type': 'manual',
    });
    _movementConceptController.clear();
    _movementAmountController.clear();
    _movementNotesController.clear();
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Movimiento guardado correctamente.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'efectivo':
        return 'Efectivo';
      case 'transferencia':
        return 'Transferencia';
      case 'tarjeta':
        return 'Tarjeta';
      case 'nequi':
        return 'Nequi';
      case 'daviplata':
        return 'Daviplata';
      default:
        return 'Otro';
    }
  }

  String _serviceHelperText() {
    final service = _services.cast<Map<String, Object?>?>().firstWhere(
          (row) => '${row?['code']}' == _selectedServiceCode,
          orElse: () => null,
        );
    if (service == null) return 'Selecciona el servicio que realmente se hizo para que el escritorio lo reciba bien.';
    final duration = '${service['duration_minutes'] ?? 0}';
    final percent = '${(service['commission_percent'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}';
    return 'Duración: $duration min · Comisión de referencia: $percent%';
  }

  Widget _miniPill(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expectedCash = ((_session?['opening_cash'] as num?)?.toDouble() ?? 0) + (_paymentTotals['efectivo'] ?? 0) - _expensesTotal;

    return AppShell(
      title: 'Caja',
      actions: <Widget>[
        TextButton(onPressed: () => context.go('/closing'), child: const Text('Ir a cierre')),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Operación monetaria del día', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              _session == null
                  ? 'Abre caja para empezar a registrar ventas, ingresos y gastos.'
                  : 'Toda venta válida debe salir desde Caja y quedar ligada a cliente, profesional y servicio.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(width: 220, child: InfoCard(title: 'Estado', value: _session == null ? 'Cerrada' : 'Abierta', subtitle: formatShortDate(DateTime.now()))),
                SizedBox(width: 220, child: InfoCard(title: 'Ventas', value: copCurrency.format(_salesTotal))),
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
                    Text(_session == null ? 'Abrir caja' : 'Facturar servicio', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_session == null) ...<Widget>[
                      TextField(
                        controller: _openingController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Monto inicial en efectivo'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _openCash, icon: const Icon(Icons.lock_open_outlined), label: const Text('Abrir caja')),
                    ] else ...<Widget>[
                      if (_appointmentId != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('Datos traídos desde Agenda. Cuando confirmes, la cita saldrá de Agenda para evitar facturarla dos veces.'),
                        ),
                      DropdownButtonFormField<String>(
                        value: _selectedClientId,
                        hint: const Text('Selecciona un cliente'),
                        items: _clients.map((item) => DropdownMenuItem<String>(value: '${item['id']}', child: Text('${item['name']}'))).toList(),
                        onChanged: (value) => setState(() => _selectedClientId = value),
                        decoration: const InputDecoration(labelText: 'Cliente a facturar'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedWorkerId,
                        hint: const Text('Selecciona un profesional'),
                        items: _workers.map((item) => DropdownMenuItem<String>(value: '${item['id']}', child: Text('${item['name']}'))).toList(),
                        onChanged: (value) => setState(() => _selectedWorkerId = value),
                        decoration: const InputDecoration(labelText: 'Profesional que atendió'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedServiceCode,
                        hint: const Text('Selecciona un servicio'),
                        items: _services.map((item) => DropdownMenuItem<String>(value: '${item['code']}', child: Text('${item['name']}'))).toList(),
                        onChanged: (value) => setState(() {
                          _selectedServiceCode = value;
                          if (value == null) {
                            _salePriceController.clear();
                          } else {
                            final matched = _services.where((row) => '${row['code']}' == value).toList();
                            _salePriceController.text = matched.isEmpty ? '' : '${(matched.first['base_price'] as num).toDouble().toInt()}';
                          }
                        }),
                        decoration: const InputDecoration(labelText: 'Servicio realizado'),
                      ),
                      const SizedBox(height: 8),
                      Text(_serviceHelperText(), style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _salePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Valor final cobrado'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _salePaymentMethod,
                        hint: const Text('Selecciona un método de pago'),
                        items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(_paymentLabel(method)))).toList(),
                        onChanged: (value) => setState(() => _salePaymentMethod = value),
                        decoration: const InputDecoration(labelText: 'Método de pago'),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _saleNotesController, decoration: const InputDecoration(labelText: 'Observaciones de la venta')),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(onPressed: _saveServiceSale, icon: const Icon(Icons.point_of_sale_outlined), label: const Text('Confirmar venta en caja')),
                      ),
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
                      const SizedBox(height: 8),
                      const Text('Usa esto solo para ingresos extra o gastos que no vienen de una venta.'),
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
                      TextField(controller: _movementAmountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _movementPaymentMethod,
                        items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(_paymentLabel(method)))).toList(),
                        onChanged: (value) => setState(() => _movementPaymentMethod = value ?? 'efectivo'),
                        decoration: const InputDecoration(labelText: 'Método de pago'),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _movementNotesController, decoration: const InputDecoration(labelText: 'Notas')),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(child: FilledButton.icon(onPressed: _saveMovement, icon: const Icon(Icons.save_outlined), label: const Text('Guardar movimiento'))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(onPressed: _closeCash, icon: const Icon(Icons.task_alt_outlined), label: const Text('Cerrar caja'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Ventas registradas en la caja actual', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_salesRows.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Todavía no hay ventas en la caja actual.'))),
            ..._salesRows.map((sale) {
              final amount = (sale['net_total'] as num).toDouble();
              final saleAt = DateTime.tryParse('${sale['sale_at']}');
              final originType = '${sale['origin_type'] ?? ''}' == 'appointment' ? 'Cita agendada' : 'Venta desde caja';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: Text('${sale['service_name'] ?? 'Servicio'}', style: Theme.of(context).textTheme.titleMedium)),
                          Chip(label: Text(originType)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _miniPill(context, Icons.person_outline, '${sale['client_name'] ?? 'Cliente sin nombre'}'),
                          _miniPill(context, Icons.badge_outlined, '${sale['worker_name'] ?? 'Profesional sin asignar'}'),
                          _miniPill(context, Icons.payments_outlined, _paymentLabel('${sale['payment_method']}')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Hora: ${saleAt == null ? '-' : formatShortDateTime(saleAt)}'),
                      Text('Valor: ${copCurrency.format(amount)}'),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteSale(sale),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar factura'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
