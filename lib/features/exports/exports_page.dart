import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';

class ExportsPage extends StatefulWidget {
  const ExportsPage({super.key});

  @override
  State<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends State<ExportsPage> {
  List<Map<String, Object?>> _exports = const <Map<String, Object?>>[];

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
    await Share.shareXFiles(<XFile>[XFile(path)], text: 'Cierre Studio Pro Mobile Lite');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Historial de cierres',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ..._exports.map((row) => Card(
                child: ListTile(
                  title: Text('${row['file_name']}'),
                  subtitle: Text('${formatShortDateTime(DateTime.parse('${row['created_at']}'))}\n${row['file_path']}'),
                  isThreeLine: true,
                  trailing: IconButton(onPressed: () => _share(row), icon: const Icon(Icons.share_outlined)),
                ),
              )),
          if (_exports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavía no hay cierres exportados.'),
              ),
            ),
        ],
      ),
    );
  }
}
