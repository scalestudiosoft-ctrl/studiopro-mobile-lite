import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/services/close_reopen_service.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';

class ExportsPage extends StatefulWidget {
  const ExportsPage({super.key});

  @override
  State<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends State<ExportsPage> {
  final CloseReopenService _reopenService = const CloseReopenService();
  List<Map<String, Object?>> _exports = const <Map<String, Object?>>[];
  String? _busyId;
  bool _importing = false;

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
    final rows = await AppDatabase.instance.queryAll('export_history', orderBy: 'created_at DESC');
    if (!mounted) return;
    setState(() => _exports = rows);
  }

  Future<void> _share(Map<String, Object?> row) async {
    final path = '${row['file_path']}';
    if (!await File(path).exists()) return;
    await Share.shareXFiles(<XFile>[XFile(path)], text: 'Ventas móviles Studio Pro');
  }

  Future<void> _importBackup() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) {
        return;
      }
      await _reopenService.importBackupFromExternalFile(path);
      if (!mounted) return;
      AppSyncBus.bump();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup JSON importado. El lote de ventas quedo reabierto para seguir operando.')),
      );
      context.go('/cash');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _reopen(Map<String, Object?> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reabrir lote de ventas'),
        content: const Text(
          'Se volverá a abrir el último lote de ventas móviles desde este JSON para que puedas corregir ventas, gastos o citas antes de enviarlo otra vez.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reabrir')),
        ],
      ),
    );
    if (confirm != true) return;

    final id = '${row['id']}';
    setState(() => _busyId = id);
    try {
      await _reopenService.reopenFromExportFile('${row['file_path']}');
      if (!mounted) return;
      AppSyncBus.bump();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lote de ventas reabierto. Ya puedes corregirlo y volver a enviarlo.')),
      );
      context.go('/cash');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Ventas móviles',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Último JSON de ventas móviles', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Consulta, comparte o reabre el último lote enviado al escritorio si necesitas corregir ventas antes de enviarlo otra vez.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _importing ? null : _importBackup,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_importing ? 'Importando...' : 'Importar backup JSON'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._exports.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isLatest = index == 0;
            final busy = _busyId == '${row['id']}';
            return Card(
              child: ListTile(
                title: Text('${row['file_name']}'),
                subtitle: Text('${formatShortDateTime(DateTime.parse('${row['created_at']}'))}\n${row['file_path']}'),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    if (isLatest)
                      OutlinedButton(
                        onPressed: busy ? null : () => _reopen(row),
                        child: Text(busy ? 'Abriendo...' : 'Reabrir'),
                      ),
                    IconButton(onPressed: () => _share(row), icon: const Icon(Icons.share_outlined)),
                  ],
                ),
              ),
            );
          }),
          if (_exports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavía no hay lotes de ventas móviles generados.'),
              ),
            ),
        ],
      ),
    );
  }
}

