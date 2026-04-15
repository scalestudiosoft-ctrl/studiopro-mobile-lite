import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  final ImagePicker _picker = ImagePicker();

  Map<String, Object?>? _profile;
  String _businessType = 'barbershop';
  String? _logoPath;
  bool _saving = false;

  static const List<Map<String, String>> _businessTypes = <Map<String, String>>[
    <String, String>{'value': 'barbershop', 'label': 'Barbería'},
    <String, String>{'value': 'beauty_salon', 'label': 'Salón de belleza'},
    <String, String>{'value': 'nails_studio', 'label': 'Nails studio'},
    <String, String>{'value': 'spa', 'label': 'Spa'},
  ];

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    _businessIdController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _ownerController.dispose();
    _deviceController.dispose();
    _openingCashController.dispose();
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
    _businessType = '${profile['business_type'] ?? 'barbershop'}';
    _logoPath = '${profile['logo_path'] ?? ''}'.trim().isEmpty ? null : '${profile['logo_path']}';
    setState(() {});
  }

  Future<void> _pickLogo() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final docs = await getApplicationDocumentsDirectory();
    final logosDir = Directory(p.join(docs.path, 'branding'));
    if (!await logosDir.exists()) {
      await logosDir.create(recursive: true);
    }
    final extension = p.extension(picked.path).isEmpty ? '.png' : p.extension(picked.path);
    final targetPath = p.join(logosDir.path, 'business_logo$extension');
    await File(picked.path).copy(targetPath);
    setState(() => _logoPath = targetPath);
  }

  Future<void> _removeLogo() async {
    final current = _logoPath;
    setState(() => _logoPath = null);
    if (current != null && current.isNotEmpty) {
      final file = File(current);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _save() async {
    if (_profile == null || _saving) return;
    if (_businessIdController.text.trim().isEmpty || _nameController.text.trim().isEmpty || _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business ID, nombre y ciudad son obligatorios.')));
      return;
    }
    setState(() => _saving = true);
    await AppDatabase.instance.update(
      'business_profile',
      <String, Object?>{
        'business_id': _businessIdController.text.trim(),
        'name': _nameController.text.trim(),
        'city': _cityController.text.trim(),
        'business_type': _businessType,
        'owner_name': _ownerController.text.trim(),
        'device_name': _deviceController.text.trim().isEmpty ? 'Android' : _deviceController.text.trim(),
        'default_opening_cash': double.tryParse(_openingCashController.text.trim()) ?? 0,
        'logo_path': _logoPath,
      },
      where: 'business_id = ?',
      whereArgs: <Object?>[_profile!['business_id']],
    );
    if (!mounted) return;
    AppSyncBus.bump();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración guardada.')));
    setState(() => _saving = false);
    await _load();
  }

  Widget _buildLogoPreview() {
    final logoPath = _logoPath;
    if (logoPath == null || logoPath.isEmpty) {
      return Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.storefront_rounded, size: 42, color: Color(0xFF6B7280)),
      );
    }
    final file = File(logoPath);
    if (!file.existsSync()) {
      return Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.broken_image_rounded, size: 42, color: Color(0xFF6B7280)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.file(file, width: 92, height: 92, fit: BoxFit.cover),
    );
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Branding y datos del negocio', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildLogoPreview(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Logo del negocio', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                FilledButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.photo_library_rounded),
                                  label: const Text('Seleccionar'),
                                ),
                                if ((_logoPath ?? '').isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: _removeLogo,
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    label: const Text('Quitar'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Este logo se verá en Inicio y queda guardado en el dispositivo.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _businessIdController, decoration: const InputDecoration(labelText: 'Business ID')),
                  const SizedBox(height: 12),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre del negocio')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _businessType,
                    decoration: const InputDecoration(labelText: 'Tipo de negocio'),
                    items: _businessTypes
                        .map((item) => DropdownMenuItem<String>(value: item['value'], child: Text(item['label']!)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _businessType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ciudad')),
                  const SizedBox(height: 12),
                  TextField(controller: _ownerController, decoration: const InputDecoration(labelText: 'Responsable')),
                  const SizedBox(height: 12),
                  TextField(controller: _deviceController, decoration: const InputDecoration(labelText: 'Nombre del dispositivo')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _openingCashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Apertura sugerida'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                    ),
                  ),
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
                  const Text('Configura aquí los datos del negocio. El JSON saldrá con el Business ID, el tipo de negocio y el dispositivo correcto para escritorio.'),
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
