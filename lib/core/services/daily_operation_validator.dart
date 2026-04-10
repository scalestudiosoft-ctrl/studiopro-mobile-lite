import '../database/app_database.dart';
import '../utils/formatters.dart';

class DailyValidationResult {
  const DailyValidationResult({
    required this.blockingIssues,
    required this.warnings,
    required this.hasOpenSession,
    required this.hasBusinessProfile,
    required this.hasWorkers,
    required this.hasClients,
    required this.hasCatalog,
    required this.servicesCount,
    required this.salesCount,
  });

  final List<String> blockingIssues;
  final List<String> warnings;
  final bool hasOpenSession;
  final bool hasBusinessProfile;
  final bool hasWorkers;
  final bool hasClients;
  final bool hasCatalog;
  final int servicesCount;
  final int salesCount;

  bool get canRegisterService =>
      hasBusinessProfile && hasOpenSession && hasWorkers && hasClients && hasCatalog;

  bool get canCloseDay => hasBusinessProfile && hasOpenSession && servicesCount > 0 && salesCount > 0;
}

class DailyOperationValidator {
  const DailyOperationValidator();

  Future<DailyValidationResult> validateForDate(DateTime date) async {
    final db = AppDatabase.instance;
    final workDate = formatDateOnly(date);
    final business = await db.firstRow('business_profile');
    final workers = await db.queryWhere('workers', where: 'active = ?', whereArgs: <Object?>[1], limit: 1);
    final clients = await db.queryWhere('clients', limit: 1);
    final catalog = await db.queryWhere('service_catalog', where: 'active = ?', whereArgs: <Object?>[1], limit: 1);
    final openSession = await db.firstRow(
      'cash_sessions',
      where: 'work_date = ? AND status = ?',
      whereArgs: <Object?>[workDate, 'open'],
      orderBy: 'opened_at DESC',
    );
    final services = await db.queryRaw(
      'SELECT COUNT(*) AS total FROM service_records WHERE substr(performed_at, 1, 10) = ?',
      <Object?>[workDate],
    );
    final sales = await db.queryRaw(
      'SELECT COUNT(*) AS total FROM sales WHERE substr(sale_at, 1, 10) = ?',
      <Object?>[workDate],
    );

    final blocking = <String>[];
    final warnings = <String>[];

    final hasBusiness = business != null && '${business['business_id'] ?? ''}'.trim().isNotEmpty && '${business['name'] ?? ''}'.trim().isNotEmpty;
    final hasWorkers = workers.isNotEmpty;
    final hasClients = clients.isNotEmpty;
    final hasCatalog = catalog.isNotEmpty;
    final hasOpenSession = openSession != null;
    final servicesCount = ((services.first['total'] as num?) ?? 0).toInt();
    final salesCount = ((sales.first['total'] as num?) ?? 0).toInt();

    if (!hasBusiness) {
      blocking.add('Configura el negocio antes de operar o exportar.');
    }
    if (!hasWorkers) {
      blocking.add('Debes registrar al menos un profesional activo.');
    }
    if (!hasClients) {
      warnings.add('Todavía no hay clientes creados.');
    }
    if (!hasCatalog) {
      blocking.add('Debes crear al menos un servicio activo en el catálogo.');
    }
    if (!hasOpenSession) {
      blocking.add('Abre la caja del día antes de registrar servicios o cerrar el día.');
    }
    if (hasOpenSession && servicesCount == 0) {
      warnings.add('No hay servicios registrados para este día.');
    }
    if (hasOpenSession && salesCount == 0) {
      warnings.add('No hay ventas registradas para este día.');
    }

    return DailyValidationResult(
      blockingIssues: blocking,
      warnings: warnings,
      hasOpenSession: hasOpenSession,
      hasBusinessProfile: hasBusiness,
      hasWorkers: hasWorkers,
      hasClients: hasClients,
      hasCatalog: hasCatalog,
      servicesCount: servicesCount,
      salesCount: salesCount,
    );
  }
}
