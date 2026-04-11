import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';

class WorkersPage extends StatefulWidget {
  const WorkersPage({super.key});

  @override
  State<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends State<WorkersPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commissionController = TextEditingController(text: '40');
  List<Map<String, Object?>> _workers = const <Map<String, Object?>>[];
  Map<String, Map<String, Object?>> _stats = <String, Map<String, Object?>>{};

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
    final workers = await db.queryAll('workers', orderBy: 'name ASC');
    final today = formatDateOnly(DateTime.now());
    final records = await db.queryRaw('SELECT * FROM service_records WHERE substr(performed_at, 1, 10) = ?', <Object?>[today]);
    final stats = <String, Map<String, Object?>>{};
    for (final row in records) {
      final workerId = '${row['worker_id']}';
      final bucket = stats.putIfAbsent(workerId, () => <String, Object?>{'count': 0, 'total': 0.0});
      bucket['count'] = ((bucket['count'] as int?) ?? 0) + 1;
      bucket['total'] = ((bucket['total'] as double?) ?? 0) + (row['unit_price'] as num).toDouble();
    }
    if (!mounted) return;
    setState(() {
      _workers = workers;
      _stats = stats;
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('El nombre del profesional es obligatorio.');
      return;
    }
    await AppDatabase.instance.insert('workers', <String, Object?>{
      'id': 'WRK-${const Uuid().v4()}',
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'commission_type': 'percentage',
      'commission_value': double.tryParse(_commissionController.text.trim()) ?? 40,
      'active': 1,
    });
    _nameController.clear();
    _phoneController.clear();
    _commissionController.text = '40';
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    _showMessage('Profesional guardado correctamente.');
  }

  Future<void> _editWorker(Map<String, Object?> worker) async {
    final nameController = TextEditingController(text: '${worker['name'] ?? ''}');
    final phoneController = TextEditingController(text: '${worker['phone'] ?? ''}');
    final commissionController = TextEditingController(text: '${((worker['commission_value'] as num?) ?? 0).toDouble()}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar profesional'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
              const SizedBox(height: 12),
              TextField(
                controller: commissionController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Comisión %'),
              ),
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
      'workers',
      <String, Object?>{
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'commission_type': 'percentage',
        'commission_value': double.tryParse(commissionController.text.trim()) ?? 40,
      },
      where: 'id = ?',
      whereArgs: <Object?>[worker['id']],
    );
    AppSyncBus.bump();
    await _load();
  }

  Future<void> _deleteWorker(Map<String, Object?> worker) async {
    final used = await AppDatabase.instance.queryWhere(
      'service_records',
      where: 'worker_id = ?',
      whereArgs: <Object?>[worker['id']],
      limit: 1,
    );
    if (used.isNotEmpty) {
      _showMessage('No se puede eliminar un profesional con servicios registrados.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar profesional'),
        content: Text('¿Seguro que deseas eliminar a ${worker['name']}?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    await AppDatabase.instance.delete('workers', where: 'id = ?', whereArgs: <Object?>[worker['id']]);
    AppSyncBus.bump();
    await _load();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Profesionales',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre del profesional')),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Teléfono (opcional)')),
                  const SizedBox(height: 12),
                  TextField(controller: _commissionController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Comisión %')),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(onPressed: _save, child: const Text('Guardar profesional')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._workers.map((worker) {
            final stat = _stats['${worker['id']}'];
            final production = ((stat?['total'] as double?) ?? 0);
            return Card(
              child: ListTile(
                title: Text('${worker['name']}'),
                subtitle: Text('Comisión ${worker['commission_value']}% • ${stat?['count'] ?? 0} servicios hoy'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editWorker(worker);
                    } else if (value == 'delete') {
                      _deleteWorker(worker);
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
                      Text(copCurrency.format(production)),
                      const SizedBox(height: 4),
                      const Icon(Icons.more_vert),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
