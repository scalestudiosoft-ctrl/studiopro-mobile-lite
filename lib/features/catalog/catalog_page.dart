import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
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
  List<Map<String, Object?>> _items = const <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    _load();
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
      'base_price': double.tryParse(_priceController.text.trim()) ?? 0,
      'active': 1,
    });
    _codeController.clear();
    _nameController.clear();
    _priceController.clear();
    await _load();
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
                children: <Widget>[
                  TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'Código')),
                  const SizedBox(height: 12),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio base')),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: const Text('Guardar servicio'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._items.map((row) => Card(child: ListTile(title: Text('${row['name']}'), subtitle: Text('${row['code']}'), trailing: Text(copCurrency.format((row['base_price'] as num).toDouble()))))),
        ],
      ),
    );
  }
}
