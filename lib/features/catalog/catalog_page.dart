import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController(text: '45');
  final _commissionController = TextEditingController(text: '50');
  final _descriptionController = TextEditingController();
  List<Map<String, Object?>> _items = const <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    _codeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _commissionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final rows = await AppDatabase.instance.queryAll('service_catalog', orderBy: 'name ASC');
    if (!mounted) return;
    setState(() => _items = rows);
  }

  Future<void> _save() async {
    if (_codeController.text.trim().isEmpty || _nameController.text.trim().isEmpty || _priceController.text.trim().isEmpty) return;
    await AppDatabase.instance.insert('service_catalog', <String, Object?>{
      'code': _codeController.text.trim(),
      'name': _nameController.text.trim(),
      'base_price': double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ?? 0,
      'duration_minutes': int.tryParse(_durationController.text.trim()) ?? 45,
      'commission_percent': double.tryParse(_commissionController.text.trim().replaceAll(',', '.')) ?? 0,
      'description': _descriptionController.text.trim(),
      'active': 1,
    });
    _codeController.clear();
    _nameController.clear();
    _priceController.clear();
    _durationController.text = '45';
    _commissionController.text = '50';
    _descriptionController.clear();
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio guardado en catálogo.')));
  }

  Future<void> _deleteService(Map<String, Object?> row) async {
    final code = '${row['code'] ?? ''}';
    final usedInAppointments = await AppDatabase.instance.queryWhere(
      'appointments',
      where: 'service_code = ?',
      whereArgs: <Object?>[code],
      limit: 1,
    );
    final usedInRecords = await AppDatabase.instance.queryWhere(
      'service_records',
      where: 'service_code = ?',
      whereArgs: <Object?>[code],
      limit: 1,
    );
    if (usedInAppointments.isNotEmpty || usedInRecords.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede eliminar porque el servicio ya tiene historial.')),
      );
      return;
    }
    final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar servicio'),
            content: Text('¿Eliminar ${row['name']} del catálogo?'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
    if (!approved) return;
    await AppDatabase.instance.delete('service_catalog', where: 'code = ?', whereArgs: <Object?>[code]);
    AppSyncBus.bump();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio eliminado del catálogo.')));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Catálogo de servicios',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Crear servicio del catálogo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'Código')),
                  const SizedBox(height: 12),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio base')),
                  const SizedBox(height: 12),
                  Row(children: <Widget>[
                    Expanded(child: TextField(controller: _durationController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duración (min)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _commissionController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Porcentaje'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: _descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción')),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: const Text('Guardar servicio'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._items.map((row) => Card(
            child: ListTile(
              title: Text('${row['name']}'),
              subtitle: Text(
                'Código: ${row['code']} • ${row['duration_minutes'] ?? 45} min • ${row['commission_percent'] ?? 0}%\n'
                '${(row['description'] ?? '').toString().isEmpty ? 'Sin descripción' : row['description']}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(copCurrency.format((row['base_price'] as num).toDouble())),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Eliminar servicio',
                    onPressed: () => _deleteService(row),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
