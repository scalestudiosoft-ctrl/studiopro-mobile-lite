import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_sync_bus.dart';
import '../../core/services/closing_export_service.dart';
import '../../core/services/daily_operation_validator.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/info_card.dart';

class ClosingPage extends StatefulWidget {
  const ClosingPage({super.key});

  @override
  State<ClosingPage> createState() => _ClosingPageState();
}

class _ClosingPageState extends State<ClosingPage> {
  final ClosingExportService _closingExportService = const ClosingExportService();
  final DailyOperationValidator _validator = const DailyOperationValidator();
  final TextEditingController _notesController = TextEditingController();
  bool _busy = false;
  Map<String, Object?> _summary = const <String, Object?>{};
  DailyValidationResult? _validation;

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _loadSummary();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await _closingExportService.buildTodaySummary();
    final validation = await _validator.validateForDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _validation = validation;
    });
  }

  Future<void> _exportOnly() async {
    final confirm = await _confirmAction('Generar JSON', 'Se va a cerrar la caja del día y generar el archivo JSON.');
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final file = await _closingExportService.exportTodayClose(notes: _notesController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('JSON generado en ${file.path}')));
      AppSyncBus.bump();
      await _loadSummary();
      if (!mounted) return;
      context.go('/exports');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final confirm = await _confirmAction('Compartir cierre', 'Se va a cerrar la caja del día, generar el JSON y abrir el menú nativo para compartir.');
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await _closingExportService.shareCloseFile(notes: _notesController.text.trim());
      if (!mounted) return;
      AppSyncBus.bump();
      await _loadSummary();
      if (!mounted) return;
      context.go('/exports');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmAction(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );
  }

  String _paymentLabel(String key) {
    switch (key) {
      case 'cash_total':
        return 'Efectivo';
      case 'transfer_total':
        return 'Transferencia';
      case 'card_total':
        return 'Tarjeta';
      case 'digital_wallet_total':
        return 'Billetera digital';
      default:
        return 'Otro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesTotal = (_summary['salesTotal'] as num?)?.toDouble() ?? 0;
    final expensesTotal = (_summary['expensesTotal'] as num?)?.toDouble() ?? 0;
    final openingCash = (_summary['openingCash'] as num?)?.toDouble() ?? 0;
    final expectedCash = (_summary['expectedCashClosing'] as num?)?.toDouble() ?? 0;
    final paymentTotals = (_summary['paymentTotals'] as Map<String, double>?) ?? const <String, double>{};
    final blockingIssues = _validation?.blockingIssues ?? const <String>[];
    final warnings = <String>[...?_validation?.warnings];
    if ((_validation?.hasOpenSession ?? false) && (_validation?.servicesCount ?? 0) == 0) {
      warnings.add('Aún no hay nada para cerrar hoy.');
    }

    return AppShell(
      title: 'Cierre del día',
      actions: <Widget>[
        TextButton(onPressed: () => context.go('/exports'), child: const Text('Historial')),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Resumen de ${formatShortDate(DateTime.now())}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Verifica el resultado del día y luego genera el JSON para enviarlo al escritorio.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SizedBox(width: 220, child: InfoCard(title: 'Apertura', value: copCurrency.format(openingCash))),
              SizedBox(width: 220, child: InfoCard(title: 'Servicios', value: '${_summary['servicesCount'] ?? 0}')),
              SizedBox(width: 220, child: InfoCard(title: 'Clientes atendidos', value: '${_summary['clientsCount'] ?? 0}')),
              SizedBox(width: 220, child: InfoCard(title: 'Ventas', value: copCurrency.format(salesTotal))),
              SizedBox(width: 220, child: InfoCard(title: 'Gastos', value: copCurrency.format(expensesTotal))),
              SizedBox(width: 220, child: InfoCard(title: 'Caja esperada', value: copCurrency.format(expectedCash))),
            ],
          ),
          if (blockingIssues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('No puedes cerrar todavía', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...blockingIssues.map((issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $issue'),
                        )),
                  ],
                ),
              ),
            ),
          ],
          if (warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Revisa antes de exportar', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...warnings.map((issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $issue'),
                        )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Totales por método de pago', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ...<String>['cash_total', 'transfer_total', 'card_total', 'digital_wallet_total', 'other_total'].map(
                    (key) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(_paymentLabel(key))),
                          Text(copCurrency.format(paymentTotals[key] ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
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
                  Text('Observaciones del cierre', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(controller: _notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas del día')), 
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(child: FilledButton(onPressed: _busy || blockingIssues.isNotEmpty ? null : _exportOnly, child: Text(_busy ? 'Procesando...' : 'Generar JSON'))),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton(onPressed: _busy || blockingIssues.isNotEmpty ? null : _share, child: const Text('Compartir'))),
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
