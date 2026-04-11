import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
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
  DateTime _selectedDay = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    _notesController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  String get _selectedDayText => formatDateOnly(_selectedDay);

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final appointments = await db.queryRaw(
      'SELECT * FROM appointments WHERE substr(scheduled_at, 1, 10) = ? ORDER BY scheduled_at ASC',
      <Object?>[_selectedDayText],
    );
    final clients = await db.queryAll('clients', orderBy: 'name ASC');
    final workers = await db.queryWhere('workers', where: 'active = ?', whereArgs: <Object?>[1], orderBy: 'name ASC');
    final services = await db.queryWhere('service_catalog', where: 'active = ?', whereArgs: <Object?>[1], orderBy: 'name ASC');
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
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickSelectedDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _selectedDay = DateTime(date.year, date.month, date.day);
    });
    await _load();
  }

  Future<void> _saveAppointment() async {
    if (_selectedClientId == null || _selectedServiceCode == null) {
      _showMessage('Cliente y servicio son obligatorios.');
      return;
    }
    setState(() => _saving = true);
    final savedAt = _scheduledAt;
    try {
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
      setState(() {
        _selectedDay = DateTime(_scheduledAt.year, _scheduledAt.month, _scheduledAt.day);
        _scheduledAt = DateTime.now().add(const Duration(minutes: 30));
      });
      AppSyncBus.bump();
      await _load();
      if (!mounted) return;
      _showMessage('Cita guardada para ${client['name']} el ${formatShortDateTime(savedAt)}.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateStatus(Map<String, Object?> row, String newStatus) async {
    await AppDatabase.instance.update(
      'appointments',
      <String, Object?>{'status': newStatus},
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
    AppSyncBus.bump();
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
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(scheduledAt),
                    );
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
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Cita actualizada correctamente.');
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
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Cita eliminada.');
  }

  void _goToCash(Map<String, Object?> row) {
    context.push('/cash?appointmentId=${Uri.encodeComponent('${row['id']}')}');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _dayChipLabel(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (normalizedDate == normalizedToday) return 'Hoy';
    if (normalizedDate == normalizedToday.add(const Duration(days: 1))) return 'Mañana';
    return formatShortDate(date);
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'finalizado':
        return Theme.of(context).colorScheme.primaryContainer;
      case 'cancelado':
        return Theme.of(context).colorScheme.errorContainer;
      case 'en proceso':
      case 'llego':
        return Theme.of(context).colorScheme.secondaryContainer;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = <DateTime>[
      DateTime.now(),
      DateTime.now().add(const Duration(days: 1)),
      DateTime.now().add(const Duration(days: 2)),
    ];

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
                    Text('Programar cita', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Agenda la visita. La facturación real se hace en Caja cuando llegue el cliente.'),
                    const SizedBox(height: 12),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveAppointment,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Guardando...' : 'Guardar cita'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(child: Text('Citas del día', style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(onPressed: _pickSelectedDay, icon: const Icon(Icons.calendar_month_outlined), label: const Text('Elegir fecha')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((date) {
                final normalized = DateTime(date.year, date.month, date.day);
                final selected = normalized == DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                return ChoiceChip(
                  selected: selected,
                  label: Text(_dayChipLabel(date)),
                  onSelected: (_) async {
                    setState(() => _selectedDay = normalized);
                    await _load();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (_appointments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay citas para el día seleccionado.'),
                ),
              ),
            ..._appointments.map((row) {
              final scheduledAt = DateTime.parse('${row['scheduled_at']}');
              final status = '${row['status']}';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('${row['client_name']}', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text('${row['service_name'] ?? 'Sin servicio'} · ${row['worker_name'] ?? 'Sin profesional'}'),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(context, status),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Hora: ${formatShortDateTime(scheduledAt)}'),
                      if ('${row['notes'] ?? ''}'.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text('Notas: ${row['notes']}'),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: () => _goToCash(row),
                            icon: const Icon(Icons.point_of_sale_outlined),
                            label: const Text('Pasar a caja'),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              switch (value) {
                                case 'edit':
                                  await _editAppointment(row);
                                  break;
                                case 'delete':
                                  await _deleteAppointment(row);
                                  break;
                                default:
                                  await _updateStatus(row, value);
                              }
                            },
                            itemBuilder: (context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                              const PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
                              const PopupMenuDivider(),
                              ...AppConstants.appointmentStatuses.map((statusItem) => PopupMenuItem<String>(
                                    value: statusItem,
                                    child: Text('Marcar $statusItem'),
                                  )),
                            ],
                            child: const Chip(label: Text('Estado y acciones')),
                          ),
                        ],
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
