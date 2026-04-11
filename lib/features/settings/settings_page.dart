import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../shared/widgets/app_shell.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _businessIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _ownerController = TextEditingController();
  final _deviceController = TextEditingController();
  final _openingCashController = TextEditingController();
  Map<String, Object?>? _profile;

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
    final profile = await AppDatabase.instance.firstRow('business_profile');
    if (!mounted || profile == null) return;
    _profile = profile;
    _businessIdController.text = '${profile['business_id'] ?? ''}';
    _nameController.text = '${profile['name'] ?? ''}';
    _cityController.text = '${profile['city'] ?? ''}';
    _ownerController.text = '${profile['owner_name'] ?? ''}';
    _deviceController.text = '${profile['device_name'] ?? ''}';
    _openingCashController.text = '${((profile['default_opening_cash'] as num?) ?? 0).toDouble().toInt()}';
    setState(() {});
  }

  Future<void> _save() async {
    if (_profile == null) return;
    if (_businessIdController.text.trim().isEmpty || _nameController.text.trim().isEmpty || _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business ID, nombre y ciudad son obligatorios.')));
      return;
    }
    await AppDatabase.instance.update(
      'business_profile',
      <String, Object?>{
        'business_id': _businessIdController.text.trim(),
        'name': _nameController.text.trim(),
        'city': _cityController.text.trim(),
        'business_type': 'barbershop',
        'owner_name': _ownerController.text.trim(),
        'device_name': _deviceController.text.trim().isEmpty ? 'Android' : _deviceController.text.trim(),
        'default_opening_cash': double.tryParse(_openingCashController.text.trim()) ?? 0,
      },
      where: 'business_id = ?',
      whereArgs: <Object?>[_profile!['business_id']],
    );
    if (!mounted) return;
    AppSyncBus.bump();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración guardada.')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Configuración',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  TextField(controller: _businessIdController, decoration: const InputDecoration(labelText: 'Business ID')),
                  const SizedBox(height: 12),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre del negocio')),
                  const SizedBox(height: 12),
                  TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ciudad')),
                  const SizedBox(height: 12),
                  TextField(controller: _ownerController, decoration: const InputDecoration(labelText: 'Responsable')),
                  const SizedBox(height: 12),
                  TextField(controller: _deviceController, decoration: const InputDecoration(labelText: 'Nombre del dispositivo')),
                  const SizedBox(height: 12),
                  TextField(controller: _openingCashController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Apertura sugerida')),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: const Text('Guardar'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Accesos', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Usa Catálogo de servicios para mantener precios base y usar esos mismos datos al exportar el cierre.'),
                  const SizedBox(height: 8),
                  const Text('Configura aquí el Business ID real del negocio para que el JSON salga listo para importar en escritorio.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ActionChip(label: const Text('Profesionales'), onPressed: () => context.push('/workers')),
                      ActionChip(label: const Text('Clientes'), onPressed: () => context.push('/clients')),
                      ActionChip(label: const Text('Catálogo'), onPressed: () => context.push('/catalog')),
                      ActionChip(label: const Text('Historial de cierres'), onPressed: () => context.push('/exports')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
