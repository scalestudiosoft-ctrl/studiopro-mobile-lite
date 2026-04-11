import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/services/closing_export_service.dart';
import '../../core/services/daily_operation_validator.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/info_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ClosingExportService _closingExportService = const ClosingExportService();
  final DailyOperationValidator _validator = const DailyOperationValidator();
  String _businessName = 'Mi Negocio';
  bool _cashOpen = false;
  double _salesTotal = 0;
  int _servicesCount = 0;
  int _appointmentsCount = 0;
  int _clientsCount = 0;
  DailyValidationResult? _validation;

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
    final business = await db.firstRow('business_profile');
    final summary = await _closingExportService.buildTodaySummary();
    final appointments = await db.queryRaw(
      'SELECT * FROM appointments WHERE substr(scheduled_at, 1, 10) = ?',
      <Object?>['${summary['workDate']}'],
    );
    final clients = await db.queryAll('clients');
    final validation = await _validator.validateForDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _businessName = '${business?['name'] ?? 'Mi Negocio'}';
      _cashOpen = summary['session'] != null;
      _salesTotal = (summary['salesTotal'] as num).toDouble();
      _servicesCount = (summary['servicesCount'] as num).toInt();
      _appointmentsCount = appointments.length;
      _clientsCount = clients.length;
      _validation = validation;
    });
  }

  @override
  Widget build(BuildContext context) {
    final warnings = <String>[...?_validation?.blockingIssues, ...?_validation?.warnings];
    return AppShell(
      title: _businessName,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Operación de hoy', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(width: 220, child: InfoCard(title: 'Caja', value: _cashOpen ? 'Abierta' : 'Cerrada', subtitle: formatShortDate(DateTime.now()))),
                SizedBox(width: 220, child: InfoCard(title: 'Vendido hoy', value: copCurrency.format(_salesTotal))),
                SizedBox(width: 220, child: InfoCard(title: 'Servicios', value: '$_servicesCount')),
                SizedBox(width: 220, child: InfoCard(title: 'Citas del día', value: '$_appointmentsCount', subtitle: 'Clientes registrados: $_clientsCount')),
              ],
            ),
            if (warnings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Pendientes para operar mejor', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...warnings.take(3).map((warning) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $warning'),
                          )),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Accesos rápidos', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(onPressed: () => context.go('/new-service'), icon: const Icon(Icons.add), label: const Text('Nuevo servicio')),
                        OutlinedButton.icon(onPressed: () => context.go('/agenda'), icon: const Icon(Icons.event_note), label: const Text('Agenda')),
                        OutlinedButton.icon(onPressed: () => context.go('/cash'), icon: const Icon(Icons.payments), label: const Text('Caja')),
                        OutlinedButton.icon(onPressed: () => context.go('/closing'), icon: const Icon(Icons.task_alt), label: const Text('Cerrar día')),
                        OutlinedButton.icon(onPressed: () => context.push('/workers'), icon: const Icon(Icons.badge_outlined), label: const Text('Profesionales')),
                        OutlinedButton.icon(onPressed: () => context.push('/clients'), icon: const Icon(Icons.people_outline), label: const Text('Clientes')),
                        OutlinedButton.icon(onPressed: () => context.push('/catalog'), icon: const Icon(Icons.content_cut_outlined), label: const Text('Servicios')),
                      ],
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
                    const Text('Flujo correcto del día', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Configura negocio, profesionales, clientes y catálogo.
'
                      '2. Abre caja.
'
                      '3. Registra citas o servicios.
'
                      '4. Cada servicio debe facturar a un cliente, quedar ligado a un profesional y afectar ventas/caja.
'
                      '5. Revisa el cierre y exporta el JSON por WhatsApp.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ActionChip(label: const Text('Configurar negocio'), onPressed: () => context.push('/settings')),
                        ActionChip(label: const Text('Crear profesional'), onPressed: () => context.push('/workers')),
                        ActionChip(label: const Text('Crear cliente'), onPressed: () => context.push('/clients')),
                        ActionChip(label: const Text('Abrir caja'), onPressed: () => context.go('/cash')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
