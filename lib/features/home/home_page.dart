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
    final theme = Theme.of(context);
    final warnings = <String>[...?_validation?.blockingIssues, ...?_validation?.warnings];

    return AppShell(
      title: _businessName,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _HeroPanel(
              businessName: _businessName,
              cashOpen: _cashOpen,
              salesTotal: _salesTotal,
              onPrimaryTap: () => context.go(_cashOpen ? '/cash' : '/cash'),
              onSecondaryTap: () => context.go('/closing'),
            ),
            const SizedBox(height: 16),
            Text('Resumen de hoy', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
              childAspectRatio: 1.35,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                InfoCard(title: 'Caja', value: _cashOpen ? 'Abierta' : 'Cerrada', subtitle: formatShortDate(DateTime.now())),
                InfoCard(title: 'Vendido hoy', value: copCurrency.format(_salesTotal)),
                InfoCard(title: 'Servicios', value: '$_servicesCount'),
                InfoCard(title: 'Citas', value: '$_appointmentsCount', subtitle: 'Clientes: $_clientsCount'),
              ],
            ),
            if (warnings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _CalloutCard(
                title: 'Pendientes por revisar',
                icon: Icons.warning_amber_rounded,
                tone: const Color(0xFFFFF3DB),
                items: warnings.take(3).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Text('Acciones rápidas', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
              childAspectRatio: 1.45,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                _QuickActionTile(icon: Icons.content_cut_rounded, title: 'Servicios', subtitle: 'Catálogo y precios base', onTap: () => context.go('/catalog')),
                _QuickActionTile(icon: Icons.event_note_rounded, title: 'Agenda', subtitle: 'Programa citas del día', onTap: () => context.go('/agenda')),
                _QuickActionTile(icon: Icons.payments_rounded, title: 'Caja', subtitle: 'Abre, factura y controla', onTap: () => context.go('/cash')),
                _QuickActionTile(icon: Icons.task_alt_rounded, title: 'Cierre', subtitle: 'Valida y exporta JSON', onTap: () => context.go('/closing')),
                _QuickActionTile(icon: Icons.badge_rounded, title: 'Profesionales', subtitle: 'Equipo activo del negocio', onTap: () => context.push('/workers')),
                _QuickActionTile(icon: Icons.people_alt_rounded, title: 'Clientes', subtitle: 'Base de clientes y ficha', onTap: () => context.push('/clients')),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Flujo operativo recomendado', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 14),
                    const _StepRow(index: 1, text: 'Configura negocio, profesionales, clientes y catálogo.'),
                    const _StepRow(index: 2, text: 'Abre caja antes de empezar a cobrar.'),
                    const _StepRow(index: 3, text: 'Registra citas o servicios con cliente y profesional.'),
                    const _StepRow(index: 4, text: 'Cada servicio debe facturar y afectar ventas/caja.'),
                    const _StepRow(index: 5, text: 'Cierra el día y comparte el JSON por WhatsApp.'),
                    const SizedBox(height: 14),
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.businessName,
    required this.cashOpen,
    required this.salesTotal,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });

  final String businessName;
  final bool cashOpen;
  final double salesTotal;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1F1637), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            blurRadius: 30,
            offset: Offset(0, 12),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              cashOpen ? 'Caja activa' : 'Caja pendiente',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            businessName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Administra agenda, catálogo, caja y cierre diario desde un solo lugar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 18),
          Text(
            copCurrency.format(salesTotal),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Venta acumulada hoy',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.82)),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: onPrimaryTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4C1D95),
                  ),
                  child: Text(cashOpen ? 'Ir a caja' : 'Abrir caja'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondaryTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: const Text('Revisar cierre'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalloutCard extends StatelessWidget {
  const _CalloutCard({
    required this.title,
    required this.icon,
    required this.tone,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color tone;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1ECFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF5B21B6)),
              ),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF1ECFB),
              shape: BoxShape.circle,
            ),
            child: Text('$index', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5B21B6))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
