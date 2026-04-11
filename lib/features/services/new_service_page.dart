import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/services/daily_operation_validator.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';

class NewServicePage extends StatefulWidget {
  const NewServicePage({super.key});

  @override
  State<NewServicePage> createState() => _NewServicePageState();
}

class _NewServicePageState extends State<NewServicePage> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final DailyOperationValidator _validator = const DailyOperationValidator();
  List<Map<String, Object?>> _clients = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _workers = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _services = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _todayRecords = const <Map<String, Object?>>[];
  String? _selectedClientId;
  String? _selectedWorkerId;
  String? _selectedServiceCode;
  String _paymentMethod = 'efectivo';
  DateTime _performedAt = DateTime.now();
  bool _saving = false;
  bool _routePrefillDone = false;
  String? _appointmentId;
  DailyValidationResult? _validation;

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routePrefillDone) return;
    _routePrefillDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyAppointmentFromRoute());
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final clients = await db.queryAll('clients', orderBy: 'name ASC');
    final workers = await db.queryAll('workers', orderBy: 'name ASC');
    final services = await db.queryAll('service_catalog', orderBy: 'name ASC');
    final today = formatDateOnly(DateTime.now());
    final todayRecords = await db.queryRaw(
      'SELECT * FROM service_records WHERE substr(performed_at, 1, 10) = ? ORDER BY performed_at DESC',
      <Object?>[today],
    );
    final validation = await _validator.validateForDate(_performedAt);
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _workers = workers;
      _services = services;
      _todayRecords = todayRecords;
      _validation = validation;
      _selectedClientId ??= clients.isEmpty ? null : '${clients.first['id']}';
      _selectedWorkerId ??= workers.isEmpty ? null : '${workers.first['id']}';
      _selectedServiceCode ??= services.isEmpty ? null : '${services.first['code']}';
      _syncDefaultPrice(force: false);
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
      _performedAt = DateTime.parse('${row['scheduled_at']}');
      _notesController.text = '${row['notes'] ?? ''}';
      _priceController.clear();
      _syncDefaultPrice(force: true);
    });
    await _load();
  }

  void _syncDefaultPrice({required bool force}) {
    final matched = _services.where((row) => '${row['code']}' == _selectedServiceCode).toList();
    if (matched.isNotEmpty && (force || _priceController.text.trim().isEmpty)) {
      _priceController.text = '${(matched.first['base_price'] as num).toDouble().toInt()}';
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _performedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_performedAt));
    if (time == null) return;
    setState(() {
      _performedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
    await _load();
  }

  Future<void> _save() async {
    if (_selectedClientId == null || _selectedWorkerId == null || _selectedServiceCode == null) {
      _showMessage('Cliente, profesional y servicio son obligatorios.');
      return;
    }
    final parsedPrice = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    if (parsedPrice == null || parsedPrice <= 0) {
      _showMessage('Debes indicar un valor válido mayor que cero.');
      return;
    }
    final validation = await _validator.validateForDate(_performedAt);
    if (!validation.canRegisterService) {
      _showMessage(validation.blockingIssues.first);
      await _load();
      return;
    }
    setState(() => _saving = true);
    try {
      final client = _clients.firstWhere((row) => '${row['id']}' == _selectedClientId);
      final worker = _workers.firstWhere((row) => '${row['id']}' == _selectedWorkerId);
      final service = _services.firstWhere((row) => '${row['code']}' == _selectedServiceCode);
      final serviceRecordId = 'SR-${const Uuid().v4()}';
      final saleId = 'SALE-${const Uuid().v4()}';
      final db = AppDatabase.instance;
      await db.insert('service_records', <String, Object?>{
        'id': serviceRecordId,
        'performed_at': _performedAt.toIso8601String(),
        'client_id': client['id'],
        'client_name': client['name'],
        'worker_id': worker['id'],
        'worker_name': worker['name'],
        'service_code': service['code'],
        'service_name': service['name'],
        'unit_price': parsedPrice,
        'payment_method': _paymentMethod,
        'status': 'finalizado',
        'notes': _notesController.text.trim(),
      });
      await db.insert('sales', <String, Object?>{
        'id': saleId,
        'sale_at': _performedAt.toIso8601String(),
        'client_id': client['id'],
        'worker_id': worker['id'],
        'service_record_id': serviceRecordId,
        'net_total': parsedPrice,
        'payment_method': _paymentMethod,
        'payment_status': 'paid',
      });
      if (_appointmentId != null) {
        await db.update(
          'appointments',
          <String, Object?>{'status': 'finalizado'},
          where: 'id = ?',
          whereArgs: <Object?>[_appointmentId],
        );
      } else {
        final matchingAppointments = await db.queryWhere(
          'appointments',
          where: 'client_id = ? AND worker_id = ? AND service_code = ? AND substr(scheduled_at, 1, 10) = ?',
          whereArgs: <Object?>[client['id'], worker['id'], service['code'], formatDateOnly(_performedAt)],
          orderBy: 'scheduled_at ASC',
        );
        if (matchingAppointments.isNotEmpty) {
          await db.update('appointments', <String, Object?>{'status': 'finalizado'}, where: 'id = ?', whereArgs: <Object?>[matchingAppointments.first['id']]);
        }
      }
      if (!mounted) return;
      _showMessage('Servicio registrado correctamente. Venta y caja actualizadas.');
      _appointmentId = null;
      _priceController.clear();
      _notesController.clear();
      AppSyncBus.bump();
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editRecord(Map<String, Object?> record) async {
    final priceController = TextEditingController(text: '${((record['unit_price'] as num?) ?? 0).toDouble()}');
    final notesController = TextEditingController(text: '${record['notes'] ?? ''}');
    String paymentMethod = '${record['payment_method'] ?? 'efectivo'}';
    String status = '${record['status'] ?? 'finalizado'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Editar servicio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor final'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(method))).toList(),
                  onChanged: (value) => setModalState(() => paymentMethod = value ?? 'efectivo'),
                  decoration: const InputDecoration(labelText: 'Método de pago'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'pendiente', child: Text('pendiente')),
                    DropdownMenuItem(value: 'finalizado', child: Text('finalizado')),
                    DropdownMenuItem(value: 'cancelado', child: Text('cancelado')),
                  ],
                  onChanged: (value) => setModalState(() => status = value ?? 'finalizado'),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Observaciones')),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final price = double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? 0;
    if (price <= 0) {
      _showMessage('El valor del servicio debe ser mayor que cero.');
      return;
    }
    await AppDatabase.instance.update(
      'service_records',
      <String, Object?>{
        'unit_price': price,
        'payment_method': paymentMethod,
        'status': status,
        'notes': notesController.text.trim(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[record['id']],
    );
    await AppDatabase.instance.update(
      'sales',
      <String, Object?>{'net_total': price, 'payment_method': paymentMethod},
      where: 'service_record_id = ?',
      whereArgs: <Object?>[record['id']],
    );
    AppSyncBus.bump();
    await _load();
  }

  Future<void> _deleteRecord(Map<String, Object?> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('¿Seguro que deseas eliminar ${record['service_name']} de ${record['client_name']}?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    await AppDatabase.instance.delete('sales', where: 'service_record_id = ?', whereArgs: <Object?>[record['id']]);
    await AppDatabase.instance.delete('service_records', where: 'id = ?', whereArgs: <Object?>[record['id']]);
    AppSyncBus.bump();
    await _load();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final blockingIssues = _validation?.blockingIssues ?? const <String>[];
    final warnings = _validation?.warnings ?? const <String>[];
    return AppShell(
      title: 'Nuevo servicio',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (_appointmentId != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Servicio precargado desde Agenda. Al guardar, la cita se marcará como finalizada.'),
              ),
            ),
          if (_appointmentId != null) const SizedBox(height: 12),
          if (blockingIssues.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Antes de registrar servicios', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...blockingIssues.map((issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $issue'),
                        )),
                  ],
                ),
              ),
            ),
          if (warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Avisos del día', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...warnings.map((issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $issue'),
                        )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_clients.isEmpty || _workers.isEmpty || _services.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (_workers.isEmpty) ActionChip(label: const Text('Crear profesional'), onPressed: () => context.push('/workers')),
                    if (_clients.isEmpty) ActionChip(label: const Text('Crear cliente'), onPressed: () => context.push('/clients')),
                    if (_services.isEmpty) ActionChip(label: const Text('Crear servicio'), onPressed: () => context.push('/catalog')),
                    ActionChip(label: const Text('Abrir caja'), onPressed: () => context.push('/cash')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Registro rápido de servicio', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    items: _clients.map((row) => DropdownMenuItem<String>(value: '${row['id']}', child: Text('${row['name']} • ${row['phone']}'))).toList(),
                    onChanged: (value) => setState(() => _selectedClientId = value),
                    decoration: const InputDecoration(labelText: 'Cliente'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedWorkerId,
                    items: _workers.map((row) => DropdownMenuItem<String>(value: '${row['id']}', child: Text('${row['name']}'))).toList(),
                    onChanged: (value) => setState(() => _selectedWorkerId = value),
                    decoration: const InputDecoration(labelText: 'Profesional'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedServiceCode,
                    items: _services.map((row) => DropdownMenuItem<String>(value: '${row['code']}', child: Text('${row['name']} • ${copCurrency.format((row['base_price'] as num).toDouble())}'))).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedServiceCode = value;
                        _priceController.clear();
                        _syncDefaultPrice(force: true);
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Servicio'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor final'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(method))).toList(),
                    onChanged: (value) => setState(() => _paymentMethod = value ?? 'efectivo'),
                    decoration: const InputDecoration(labelText: 'Método de pago'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDateTime,
                    child: InputDecorator(decoration: const InputDecoration(labelText: 'Hora del servicio'), child: Text(formatShortDateTime(_performedAt))),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Observaciones')),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving || (blockingIssues.isNotEmpty) ? null : _save,
                      child: Text(_saving ? 'Guardando...' : 'Guardar servicio'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Servicios de hoy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._todayRecords.map(
            (record) => Card(
              child: ListTile(
                title: Text('${record['client_name']} • ${record['service_name']}'),
                subtitle: Text(
                  '${record['worker_name']} • ${formatShortDateTime(DateTime.parse('${record['performed_at']}'))}\n${record['payment_method']} • ${record['status']}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editRecord(record);
                    } else if (value == 'delete') {
                      _deleteRecord(record);
                    }
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
                  ],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(copCurrency.format((record['unit_price'] as num).toDouble())),
                      const SizedBox(height: 4),
                      const Icon(Icons.more_vert),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_todayRecords.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavía no hay servicios registrados hoy.'),
              ),
            ),
        ],
      ),
    );
  }
}
