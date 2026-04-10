import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, Object?>> _appointments = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _clients = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _workers = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _services = const <Map<String, Object?>>[];
  String? _selectedClientId;
  String? _selectedWorkerId;
  String? _selectedServiceCode;
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 30));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final workDate = formatDateOnly(DateTime.now());
    final appointments = await db.queryRaw(
      'SELECT * FROM appointments WHERE substr(scheduled_at, 1, 10) = ? ORDER BY scheduled_at ASC',
      <Object?>[workDate],
    );
    final clients = await db.queryAll('clients', orderBy: 'name ASC');
    final workers = await db.queryAll('workers', orderBy: 'name ASC');
    final services = await db.queryAll('service_catalog', orderBy: 'name ASC');
    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _clients = clients;
      _workers = workers;
      _services = services;
      _selectedClientId ??= clients.isEmpty ? null : '${clients.first['id']}';
      _selectedWorkerId ??= workers.isEmpty ? null : '${workers.first['id']}';
      _selectedServiceCode ??= services.isEmpty ? null : '${services.first['code']}';
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt));
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveAppointment() async {
    if (_selectedClientId == null) return;
    final client = _clients.firstWhere((row) => '${row['id']}' == _selectedClientId);
    Map<String, Object?>? worker;
    for (final row in _workers) {
      if ('${row['id']}' == _selectedWorkerId) {
        worker = row;
        break;
      }
    }
    Map<String, Object?>? service;
    for (final row in _services) {
      if ('${row['code']}' == _selectedServiceCode) {
        service = row;
        break;
      }
    }
    await AppDatabase.instance.insert('appointments', <String, Object?>{
      'id': 'APT-${const Uuid().v4()}',
      'client_id': client['id'],
      'client_name': client['name'],
      'worker_id': worker?['id'],
      'worker_name': worker?['name'],
      'service_code': service?['code'],
      'service_name': service?['name'],
      'scheduled_at': _scheduledAt.toIso8601String(),
      'status': 'pendiente',
      'notes': _notesController.text.trim(),
    });
    _notesController.clear();
    await _load();
  }

  Future<void> _updateStatus(Map<String, Object?> row, String newStatus) async {
    await AppDatabase.instance.update(
      'appointments',
      <String, Object?>{'status': newStatus},
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
    await _load();
  }

  Future<void> _editAppointment(Map<String, Object?> row) async {
    String? workerId = row['worker_id'] == null ? null : '${row['worker_id']}';
    String? serviceCode = row['service_code'] == null ? null : '${row['service_code']}';
    DateTime scheduledAt = DateTime.parse('${row['scheduled_at']}');
    final notesController = TextEditingController(text: '${row['notes'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Editar cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String?>(
                  value: workerId,
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Sin asignar')),
                    ..._workers.map((item) => DropdownMenuItem<String?>(value: '${item['id']}', child: Text('${item['name']}'))),
                  ],
                  onChanged: (value) => setModalState(() => workerId = value),
                  decoration: const InputDecoration(labelText: 'Profesional'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: serviceCode,
                  items: _services.map((item) => DropdownMenuItem<String?>(value: '${item['code']}', child: Text('${item['name']}'))).toList(),
                  onChanged: (value) => setModalState(() => serviceCode = value),
                  decoration: const InputDecoration(labelText: 'Servicio'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: scheduledAt,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(scheduledAt));
                    if (time == null) return;
                    setModalState(() {
                      scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    });
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha y hora'),
                    child: Text(formatShortDateTime(scheduledAt)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notas')),
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
    Map<String, Object?>? worker;
    Map<String, Object?>? service;
    for (final item in _workers) {
      if ('${item['id']}' == workerId) worker = item;
    }
    for (final item in _services) {
      if ('${item['code']}' == serviceCode) service = item;
    }
    await AppDatabase.instance.update(
      'appointments',
      <String, Object?>{
        'worker_id': worker?['id'],
        'worker_name': worker?['name'],
        'service_code': service?['code'],
        'service_name': service?['name'],
        'scheduled_at': scheduledAt.toIso8601String(),
        'notes': notesController.text.trim(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
    await _load();
  }

  Future<void> _deleteAppointment(Map<String, Object?> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cita'),
        content: Text('¿Seguro que deseas eliminar la cita de ${row['client_name']}?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    await AppDatabase.instance.delete('appointments', where: 'id = ?', whereArgs: <Object?>[row['id']]);
    await _load();
  }

  void _goToService(Map<String, Object?> row) {
    context.push(
      '/new-service?appointmentId=${Uri.encodeComponent('${row['id']}')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Agenda',
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Nueva cita', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      items: _clients.map((row) => DropdownMenuItem<String>(value: '${row['id']}', child: Text('${row['name']} • ${row['phone']}'))).toList(),
                      onChanged: (value) => setState(() => _selectedClientId = value),
                      decoration: const InputDecoration(labelText: 'Cliente'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _selectedWorkerId,
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(value: null, child: Text('Sin asignar')),
                        ..._workers.map((row) => DropdownMenuItem<String?>(value: '${row['id']}', child: Text('${row['name']}'))),
                      ],
                      onChanged: (value) => setState(() => _selectedWorkerId = value),
                      decoration: const InputDecoration(labelText: 'Profesional'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _selectedServiceCode,
                      items: _services.map((row) => DropdownMenuItem<String?>(value: '${row['code']}', child: Text('${row['name']}'))).toList(),
                      onChanged: (value) => setState(() => _selectedServiceCode = value),
                      decoration: const InputDecoration(labelText: 'Servicio'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDateTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha y hora'),
                        child: Text(formatShortDateTime(_scheduledAt)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notas')),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _saveAppointment, child: const Text('Guardar cita'))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Citas del día', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._appointments.map(
              (row) => Card(
                child: ListTile(
                  title: Text('${row['client_name']} • ${row['service_name'] ?? 'Servicio'}'),
                  subtitle: Text(
                    '${formatShortTime(DateTime.parse('${row['scheduled_at']}'))} • ${row['worker_name'] ?? 'Sin asignar'}\n${row['notes'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (AppConstants.appointmentStatuses.contains(value)) {
                        _updateStatus(row, value);
                      } else if (value == 'service') {
                        _goToService(row);
                      } else if (value == 'edit') {
                        _editAppointment(row);
                      } else if (value == 'delete') {
                        _deleteAppointment(row);
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      ...AppConstants.appointmentStatuses
                          .map((status) => PopupMenuItem<String>(value: status, child: Text('Estado: $status'))),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(value: 'service', child: Text('Pasar a servicio')),
                      const PopupMenuItem<String>(value: 'edit', child: Text('Editar cita')),
                      const PopupMenuItem<String>(value: 'delete', child: Text('Eliminar cita')),
                    ],
                    child: Chip(label: Text('${row['status']}')),
                  ),
                ),
              ),
            ),
            if (_appointments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay citas registradas hoy.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
