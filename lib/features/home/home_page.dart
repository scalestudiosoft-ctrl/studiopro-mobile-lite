import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/services/closing_export_service.dart';
import '../../core/services/daily_operation_validator.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/module_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ClosingExportService _closingExportService = const ClosingExportService();
  final DailyOperationValidator _validator = const DailyOperationValidator();

  String _businessName = 'Studio Pro';
  String _businessType = 'barbershop';
  String _city = '';
  String? _logoPath;
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
      _businessName = '${business?['name'] ?? 'Studio Pro'}';
      _businessType = '${business?['business_type'] ?? 'barbershop'}';
      _city = '${business?['city'] ?? ''}';
      _logoPath = '${business?['logo_path'] ?? ''}'.trim().isEmpty ? null : '${business?['logo_path']}';
      _cashOpen = summary['session'] != null;
      _salesTotal = (summary['salesTotal'] as num).toDouble();
      _servicesCount = (summary['servicesCount'] as num).toInt();
      _appointmentsCount = appointments.length;
      _clientsCount = clients.length;
      _validation = validation;
    });
  }

  String get _segmentLabel {
    switch (_businessType) {
      case 'beauty_salon':
        return 'Salón de belleza';
      case 'nails_studio':
        return 'Nails studio';
      case 'spa':
        return 'Spa';
      default:
        return 'Barbería';
    }
  }

  @override
  Widget build(BuildContext context) {
    final warnings = <String>[...?_validation?.blockingIssues, ...?_validation?.warnings];
    final moduleTiles = <Widget>[
      ModuleTile(
        title: 'Caja',
        subtitle: _cashOpen ? 'Registrar ventas y movimientos' : 'Abrir caja y empezar el día',
        icon: Icons.point_of_sale_rounded,
        tint: const Color(0xFF0F766E),
        onTap: () => context.go('/cash'),
      ),
      ModuleTile(
        title: 'Agenda',
        subtitle: 'Citas del día y programación',
        icon: Icons.event_note_rounded,
        tint: const Color(0xFF2563EB),
        onTap: () => context.go('/agenda'),
      ),
      ModuleTile(
        title: 'Servicios',
        subtitle: 'Catálogo con precio y duración',
        icon: Icons.design_services_rounded,
        tint: const Color(0xFF7C3AED),
        onTap: () => context.go('/catalog'),
      ),
      ModuleTile(
        title: 'Clientes',
        subtitle: 'Base de clientes y seguimiento',
        icon: Icons.people_alt_rounded,
        tint: const Color(0xFFEA580C),
        onTap: () => context.push('/clients'),
      ),
      ModuleTile(
        title: 'Profesionales',
        subtitle: 'Equipo, comisiones y control',
        icon: Icons.badge_rounded,
        tint: const Color(0xFF4F46E5),
        onTap: () => context.push('/workers'),
      ),
      ModuleTile(
        title: 'Cierre',
        subtitle: 'Revisión diaria y exportación',
        icon: Icons.task_alt_rounded,
        tint: const Color(0xFFDC2626),
        onTap: () => context.go('/closing'),
      ),
      ModuleTile(
        title: 'Ventas móviles',
        subtitle: 'Enviar ventas al escritorio',
        icon: Icons.ios_share_rounded,
        tint: const Color(0xFF0891B2),
        onTap: () => context.push('/exports'),
      ),
      ModuleTile(
        title: 'Informes',
        subtitle: 'Ventas por fecha y resumen comercial',
        icon: Icons.insights_rounded,
        tint: const Color(0xFF059669),
        onTap: () => context.push('/reports'),
      ),
      ModuleTile(
        title: 'Configurar',
        subtitle: 'Negocio y dispositivo',
        icon: Icons.settings_rounded,
        tint: const Color(0xFF64748B),
        onTap: () => context.push('/settings'),
      ),
    ];

    return AppShell(
      title: _businessName,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF4B5563), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1A111827),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _BusinessLogoPreview(path: _logoPath),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _businessName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_segmentLabel${_city.trim().isEmpty ? '' : ' • $_city'}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.88),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _HeroMetricChip(
                        icon: _cashOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        label: _cashOpen ? 'Caja abierta' : 'Caja cerrada',
                      ),
                      _HeroMetricChip(icon: Icons.today_rounded, label: formatShortDate(DateTime.now())),
                      _HeroMetricChip(icon: Icons.sell_rounded, label: '${_servicesCount} servicios'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Módulos principales',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo lo importante del negocio a uno o dos toques.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: moduleTiles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.98,
              ),
              itemBuilder: (context, index) => moduleTiles[index],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickStatCard(
                    title: 'Ventas hoy',
                    value: copCurrency.format(_salesTotal),
                    icon: Icons.payments_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStatCard(
                    title: 'Citas',
                    value: '$_appointmentsCount',
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickStatCard(
                    title: 'Clientes',
                    value: '$_clientsCount',
                    icon: Icons.groups_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStatCard(
                    title: 'Servicios',
                    value: '$_servicesCount',
                    icon: Icons.content_cut_rounded,
                  ),
                ),
              ],
            ),
            if (warnings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF9A3412)),
                        const SizedBox(width: 8),
                        Text(
                          'Pendientes para operar mejor',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...warnings.take(4).map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $warning'),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _BusinessLogoPreview extends StatelessWidget {
  const _BusinessLogoPreview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final logoPath = path;
    if (logoPath == null || logoPath.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 34),
      );
    }
    final file = File(logoPath);
    if (!file.existsSync()) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.broken_image_rounded, color: Colors.white, size: 34),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.file(file, width: 64, height: 64, fit: BoxFit.cover),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {
  const _HeroMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF374151)),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}


