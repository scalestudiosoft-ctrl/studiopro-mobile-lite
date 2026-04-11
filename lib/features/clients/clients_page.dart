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
  List<Map<String, Object?>> _clients = const <Map<String, Object?>>[];
  Map<String, Map<String, Object?>> _stats = <String, Map<String, Object?>>{};
  String _search = '';

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
    });
    _nameController.clear();
    _phoneController.clear();
    _notesController.clear();
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
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
    );
    if (saved != true) return;
    await AppDatabase.instance.update(
      'clients',
      <String, Object?>{
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'notes': notesController.text.trim(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[client['id']],
    );
    AppSyncBus.bump();
    await _load();
  }

  Future<void> _showHistory(Map<String, Object?> client) async {
    final rows = await AppDatabase.instance.queryWhere(
      'service_records',
      where: 'client_id = ?',
      whereArgs: <Object?>[client['id']],
      orderBy: 'performed_at DESC',
      limit: 20,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Historial de ${client['name']}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Teléfono: ${client['phone']}'),
              if ('${client['notes']}'.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text('Notas: ${client['notes']}'),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: rows.isEmpty
                    ? const Text('Este cliente todavía no tiene servicios registrados.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${row['service_name']} • ${row['worker_name']}'),
                            subtitle: Text(formatShortDateTime(DateTime.parse('${row['performed_at']}'))),
                            trailing: Text(copCurrency.format((row['unit_price'] as num).toDouble())),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteClient(Map<String, Object?> client) async {
    final serviceCount = (await AppDatabase.instance.queryWhere(
      'service_records',
      where: 'client_id = ?',
      whereArgs: <Object?>[client['id']],
      limit: 1,
    ))
        .length;
    if (serviceCount > 0) {
      _showMessage('No se puede eliminar un cliente con historial.');
      return;
    }
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
                children: <Widget>[
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre del cliente')),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
                  const SizedBox(height: 12),
                  TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notas')),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(onPressed: _save, child: const Text('Guardar cliente')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: const InputDecoration(labelText: 'Buscar cliente', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 16),
          ..._filteredClients.map((client) {
            final stat = _stats['${client['id']}'];
            final lastVisit = stat?['last_visit'];
            final lastService = stat?['last_service'];
            return Card(
              child: ListTile(
                onTap: () => _showHistory(client),
                title: Text('${client['name']}'),
                subtitle: Text(
                  '${client['phone']}\n'
                  'Última visita: ${lastVisit == null ? 'Sin historial' : formatShortDateTime(DateTime.parse('$lastVisit'))}\n'
                  'Último servicio: ${lastService ?? 'Sin registros'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'history') {
                      _showHistory(client);
                    } else if (value == 'edit') {
                      _editClient(client);
                    } else if (value == 'delete') {
                      _deleteClient(client);
                    }
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'history', child: Text('Ver historial')),
                    PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
                leading: CircleAvatar(child: Text('${stat?['count'] ?? 0}')),
              ),
            );
          }),
          if (_filteredClients.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay clientes que coincidan con la búsqueda.'),
              ),
            ),
        ],
      ),
    );
  }
}
