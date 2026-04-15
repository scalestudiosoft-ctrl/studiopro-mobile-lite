import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  DateTime? _birthday;
  List<Map<String, Object?>> _clients = const <Map<String, Object?>>[];
  Map<String, Map<String, Object?>> _stats = <String, Map<String, Object?>>{};
  String _search = '';

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _searchController.addListener(() => setState(() => _search = _searchController.text));
    _load();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final clients = await db.queryAll('clients', orderBy: 'name ASC');
    final services = await db.queryAll('service_records', orderBy: 'performed_at DESC');
    final stats = <String, Map<String, Object?>>{};
    for (final service in services) {
      final clientId = '${service['client_id']}';
      final bucket = stats.putIfAbsent(
        clientId,
        () => <String, Object?>{'count': 0, 'last_visit': service['performed_at'], 'last_service': service['service_name']},
      );
      bucket['count'] = ((bucket['count'] as int?) ?? 0) + 1;
      bucket['last_visit'] ??= service['performed_at'];
      bucket['last_service'] ??= service['service_name'];
    }
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _stats = stats;
    });
  }

  Future<void> _pickBirthday({DateTime? initialDate, required ValueChanged<DateTime?> onSelected}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    onSelected(picked == null ? initialDate : DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      _showMessage('Nombre y teléfono son obligatorios.');
      return;
    }
    await AppDatabase.instance.insert('clients', <String, Object?>{
      'id': 'CLI-${const Uuid().v4()}',
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'notes': _notesController.text.trim(),
      'birthday': _birthday?.toIso8601String(),
    });
    _nameController.clear();
    _phoneController.clear();
    _notesController.clear();
    _birthday = null;
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Cliente guardado correctamente.');
  }

  List<Map<String, Object?>> get _filteredClients {
    if (_search.trim().isEmpty) return _clients;
    final term = _search.trim().toLowerCase();
    return _clients.where((client) {
      final name = '${client['name']}'.toLowerCase();
      final phone = '${client['phone']}'.toLowerCase();
      return name.contains(term) || phone.contains(term);
    }).toList();
  }

  Future<void> _editClient(Map<String, Object?> client) async {
    final nameController = TextEditingController(text: '${client['name'] ?? ''}');
    final phoneController = TextEditingController(text: '${client['phone'] ?? ''}');
    final notesController = TextEditingController(text: '${client['notes'] ?? ''}');
    DateTime? birthday = client['birthday'] == null || '${client['birthday']}'.isEmpty ? null : DateTime.tryParse('${client['birthday']}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Editar cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 12),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickBirthday(initialDate: birthday, onSelected: (value) => setModalState(() => birthday = value)),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Cumpleaños'),
                    child: Text(birthday == null ? 'Sin fecha registrada' : formatDateOnly(birthday!)),
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
    await AppDatabase.instance.update(
      'clients',
      <String, Object?>{
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'notes': notesController.text.trim(),
        'birthday': birthday?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[client['id']],
    );
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Cliente actualizado correctamente.');
  }

  Future<void> _deleteClient(Map<String, Object?> client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Seguro que deseas eliminar a ${client['name']}?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    await AppDatabase.instance.delete('clients', where: 'id = ?', whereArgs: <Object?>[client['id']]);
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Cliente eliminado.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Clientes',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Nuevo cliente', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre completo')),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _pickBirthday(initialDate: _birthday, onSelected: (value) => setState(() => _birthday = value)),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Cumpleaños'),
                      child: Text(_birthday == null ? 'Toca para registrar la fecha' : formatDateOnly(_birthday!)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notas')),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Guardar cliente'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(labelText: 'Buscar por nombre o teléfono', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 16),
          if (_filteredClients.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Todavía no hay clientes registrados.'))),
          ..._filteredClients.map((client) {
            final stats = _stats['${client['id']}'];
            final birthday = client['birthday'] == null || '${client['birthday']}'.isEmpty ? null : DateTime.tryParse('${client['birthday']}');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text('${client['name']}', style: Theme.of(context).textTheme.titleMedium)),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _editClient(client);
                            } else if (value == 'delete') {
                              await _deleteClient(client);
                            }
                          },
                          itemBuilder: (context) => const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                            PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Teléfono: ${client['phone']}'),
                    if (birthday != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text('Cumpleaños: ${formatDateOnly(birthday)}'),
                    ],
                    if ('${client['notes'] ?? ''}'.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text('Notas: ${client['notes']}'),
                    ],
                    if (stats != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(label: Text('Visitas: ${stats['count'] ?? 0}')),
                          if (stats['last_service'] != null) Chip(label: Text('Último servicio: ${stats['last_service']}')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
