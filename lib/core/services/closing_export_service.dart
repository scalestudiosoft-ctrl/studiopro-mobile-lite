import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../utils/formatters.dart';

class ClosingExportService {
  const ClosingExportService();

  List<Map<String, Object?>> _dedupePendingAppointments(List<Map<String, Object?>> rows) {
    final uniqueById = <String, Map<String, Object?>>{};
    final uniqueByLogicalKey = <String, Map<String, Object?>>{};

    for (final row in rows) {
      final appointmentId = '${row['id'] ?? ''}'.trim();
      final scheduledAt = '${row['scheduled_at'] ?? ''}'.trim();
      final clientId = '${row['client_id'] ?? ''}'.trim();
      final workerId = '${row['worker_id'] ?? ''}'.trim();
      final serviceCode = '${row['service_code'] ?? ''}'.trim();
      final status = '${row['status'] ?? ''}'.trim();
      final updatedAt = '${row['updated_at'] ?? row['scheduled_at'] ?? ''}'.trim();
      final logicalKey = [clientId, workerId, serviceCode, scheduledAt, status].join('|');

      final existingById = appointmentId.isEmpty ? null : uniqueById[appointmentId];
      if (existingById == null || _isRowNewer(row, existingById)) {
        if (appointmentId.isNotEmpty) {
          uniqueById[appointmentId] = row;
        }
      }

      final existingByLogicalKey = uniqueByLogicalKey[logicalKey];
      if (existingByLogicalKey == null || updatedAt.compareTo('${existingByLogicalKey['updated_at'] ?? existingByLogicalKey['scheduled_at'] ?? ''}') > 0) {
        uniqueByLogicalKey[logicalKey] = row;
      }
    }

    final merged = <Map<String, Object?>>[];
    final usedIds = <String>{};
    for (final row in uniqueByLogicalKey.values) {
      final appointmentId = '${row['id'] ?? ''}'.trim();
      if (appointmentId.isNotEmpty) {
        final byId = uniqueById[appointmentId] ?? row;
        merged.add(byId);
        usedIds.add(appointmentId);
      } else {
        merged.add(row);
      }
    }
    for (final entry in uniqueById.entries) {
      if (!usedIds.contains(entry.key)) {
        merged.add(entry.value);
      }
    }

    merged.sort((a, b) => '${a['scheduled_at'] ?? ''}'.compareTo('${b['scheduled_at'] ?? ''}'));
    return merged;
  }

  bool _isRowNewer(Map<String, Object?> current, Map<String, Object?> previous) {
    final currentUpdated = '${current['updated_at'] ?? current['scheduled_at'] ?? ''}';
    final previousUpdated = '${previous['updated_at'] ?? previous['scheduled_at'] ?? ''}';
    return currentUpdated.compareTo(previousUpdated) >= 0;
  }

  Future<Map<String, Object?>> buildTodaySummary() async {
    final db = AppDatabase.instance;
    final now = DateTime.now();
    final workDate = formatDateOnly(now);
    final session = await db.firstRow(
      'cash_sessions',
      where: 'work_date = ? AND status = ?',
      whereArgs: <Object?>[workDate, 'open'],
      orderBy: 'opened_at DESC',
    );

    if (session == null) {
      return <String, Object?>{
        'workDate': workDate,
        'session': null,
        'services': <Map<String, Object?>>[],
        'sales': <Map<String, Object?>>[],
        'cashMovements': <Map<String, Object?>>[],
        'salesTotal': 0.0,
        'expensesTotal': 0.0,
        'clientsCount': 0,
        'servicesCount': 0,
        'openingCash': 0.0,
        'expectedCashClosing': 0.0,
        'paymentTotals': <String, double>{
          'cash_total': 0,
          'transfer_total': 0,
          'card_total': 0,
          'digital_wallet_total': 0,
          'other_total': 0,
        },
      };
    }

    final sessionId = '${session['id']}';
    final services = await db.queryRaw(
      'SELECT * FROM service_records WHERE cash_session_id = ? ORDER BY performed_at ASC',
      <Object?>[sessionId],
    );
    final sales = await db.queryRaw(
      'SELECT * FROM sales WHERE cash_session_id = ? ORDER BY sale_at ASC',
      <Object?>[sessionId],
    );
    final cashMovements = await db.queryRaw(
      'SELECT * FROM cash_movements WHERE cash_session_id = ? ORDER BY movement_at ASC',
      <Object?>[sessionId],
    );

    double salesTotal = 0;
    double expensesTotal = 0;
    final paymentTotals = <String, double>{
      'cash_total': 0,
      'transfer_total': 0,
      'card_total': 0,
      'digital_wallet_total': 0,
      'other_total': 0,
    };

    for (final sale in sales) {
      final total = (sale['net_total'] as num).toDouble();
      salesTotal += total;
      switch ('${sale['payment_method']}'.toLowerCase()) {
        case 'efectivo':
          paymentTotals['cash_total'] = paymentTotals['cash_total']! + total;
          break;
        case 'transferencia':
          paymentTotals['transfer_total'] = paymentTotals['transfer_total']! + total;
          break;
        case 'tarjeta':
          paymentTotals['card_total'] = paymentTotals['card_total']! + total;
          break;
        case 'nequi':
        case 'daviplata':
        case 'billetera digital':
          paymentTotals['digital_wallet_total'] = paymentTotals['digital_wallet_total']! + total;
          break;
        default:
          paymentTotals['other_total'] = paymentTotals['other_total']! + total;
      }
    }

    for (final movement in cashMovements) {
      final amount = (movement['amount'] as num).toDouble();
      if ('${movement['type']}'.toLowerCase() == 'expense') {
        expensesTotal += amount;
      }
    }

    double manualCashIncome = 0;
    for (final movement in cashMovements) {
      final amount = (movement['amount'] as num).toDouble();
      if ('${movement['type']}'.toLowerCase() == 'income' && '${movement['sale_id'] ?? ''}'.isEmpty && '${movement['payment_method']}'.toLowerCase() == 'efectivo') {
        manualCashIncome += amount;
      }
    }

    final openingCash = (session['opening_cash'] as num).toDouble();

    return <String, Object?>{
      'workDate': workDate,
      'session': session,
      'services': services,
      'sales': sales,
      'cashMovements': cashMovements,
      'salesTotal': salesTotal,
      'expensesTotal': expensesTotal,
      'clientsCount': services.map((e) => e['client_id']).whereType<Object?>().toSet().length,
      'servicesCount': services.length,
      'openingCash': openingCash,
      'expectedCashClosing': openingCash + paymentTotals['cash_total']! + manualCashIncome - expensesTotal,
      'paymentTotals': paymentTotals,
    };
  }

  Future<File> exportTodayClose({String notes = '', String closedBy = 'mobile_user'}) async {
    final db = AppDatabase.instance;
    final now = DateTime.now();
    final summary = await buildTodaySummary();
    final workDate = '${summary['workDate']}';
    final clients = await db.queryAll('clients');
    final workers = await db.queryAll('workers');
    final catalog = await db.queryAll('service_catalog', orderBy: 'name ASC');
    final rawPendingAppointments = await db.queryRaw(
      "SELECT * FROM appointments WHERE status NOT IN ('finalizado', 'cancelado') ORDER BY scheduled_at ASC",
    );
    final pendingAppointments = _dedupePendingAppointments(rawPendingAppointments);
    final businessRows = await db.queryAll('business_profile');
    if (businessRows.isEmpty) {
      throw StateError('No existe perfil del negocio configurado.');
    }
    final business = businessRows.first;
    final services = summary['services'] as List<Map<String, Object?>>;
    final sales = summary['sales'] as List<Map<String, Object?>>;
    final cashMovements = summary['cashMovements'] as List<Map<String, Object?>>;
    final exportedCashMovements = cashMovements.where((movement) {
      final type = '${movement['type'] ?? ''}'.toLowerCase();
      final saleId = '${movement['sale_id'] ?? ''}'.trim();
      if (type == 'income' && saleId.isNotEmpty) {
        return false;
      }
      return true;
    }).toList();
    if (services.isEmpty || sales.isEmpty) {
      throw StateError('No puedes generar ventas móviles sin servicios y ventas registradas.');
    }
    final paymentTotals = summary['paymentTotals'] as Map<String, double>;
    final session = summary['session'] as Map<String, Object?>?;
    if (session == null) {
      throw StateError('No hay una caja abierta para este día.');
    }

    final closeBatchId = 'MOBILE-SALE-${const Uuid().v4()}';
    final fileName = 'sp_ventas_moviles_${workDate}_${DateTime.now().millisecondsSinceEpoch}.json';
    final payload = <String, Object?>{
      'schema_version': AppConstants.syncSchemaVersion,
      'source_app': <String, Object?>{'name': AppConstants.appName, 'version': AppConstants.appVersion},
      'export_meta': <String, Object?>{
        'exported_at': now.toIso8601String(),
        'export_channel': 'manual_share',
        'file_name': fileName,
        'appointments_pending_mode': 'snapshot',
      },
      'business': <String, Object?>{
        'business_id': business['business_id'],
        'business_name': business['name'],
        'business_type': business['business_type'],
        'city': business['city'],
      },
      'device': <String, Object?>{
        'device_id': '${business['business_id']}-android',
        'device_name': business['device_name'] ?? 'Android',
      },
      'close_batch': <String, Object?>{
        'close_batch_id': closeBatchId,
        'cash_session_id': session['id'],
        'work_date': workDate,
        'opened_at': session['opened_at'],
        'closed_at': now.toIso8601String(),
        'opening_cash': summary['openingCash'],
        'closing_notes': notes,
        'closed_by': closedBy,
      },
      'workers': workers.map((e) => <String, Object?>{
            'worker_id': e['id'],
            'worker_name': e['name'],
            'active': (e['active'] as num) == 1,
          }).toList(),
      'clients': clients.map((e) => <String, Object?>{
            'client_id': e['id'],
            'client_name': e['name'],
            'client_phone': e['phone'],
            'client_notes': e['notes'],
            'birthday': e['birthday'],
          }).toList(),
      'services_catalog': catalog.map((e) => <String, Object?>{
            'service_code': e['code'],
            'service_name': e['name'],
            'base_price': e['base_price'],
            'duration_minutes': e['duration_minutes'] ?? 45,
            'commission_percent': e['commission_percent'] ?? 0,
            'description': e['description'] ?? '',
          }).toList(),
      'appointments_pending_meta': <String, Object?>{
        'mode': 'snapshot',
        'record_count': pendingAppointments.length,
        'exported_at': now.toIso8601String(),
        'device_id': '${business['business_id']}-android',
        'close_batch_id': closeBatchId,
      },
      'appointments_pending': pendingAppointments.map((e) => <String, Object?>{
            'appointment_id': e['id'],
            'scheduled_at': e['scheduled_at'],
            'status': e['status'],
            'client_id': e['client_id'],
            'client_name': e['client_name'],
            'worker_id': e['worker_id'],
            'worker_name': e['worker_name'],
            'service_code': e['service_code'],
            'service_name': e['service_name'],
            'notes': e['notes'],
            'created_at': e['created_at'],
            'updated_at': e['updated_at'],
            'origin_type': e['origin_type'],
            'origin_device_id': e['origin_device_id'],
            'restored_from_sale_id': e['restored_from_sale_id'],
            'source': 'mobile',
          }).toList(),
      'services_performed': services.map((e) => <String, Object?>{
            'performed_id': e['id'],
            'performed_at': e['performed_at'],
            'client_id': e['client_id'],
            'client_name': e['client_name'],
            'worker_id': e['worker_id'],
            'worker_name': e['worker_name'],
            'service_code': e['service_code'],
            'service_name': e['service_name'],
            'unit_price': e['unit_price'],
            'payment_method': e['payment_method'],
            'status': e['status'],
            'notes': e['notes'],
            'cash_session_id': e['cash_session_id'],
            'source_appointment_id': e['source_appointment_id'],
            'origin_type': e['origin_type'],
            'source': 'mobile',
          }).toList(),
      'sales': sales.map((e) => <String, Object?>{
            'sale_id': e['id'],
            'sale_at': e['sale_at'],
            'client_id': e['client_id'],
            'client_name': e['client_name'],
            'worker_id': e['worker_id'],
            'worker_name': e['worker_name'],
            'performed_id': e['service_record_id'],
            'service_code': e['service_code'],
            'service_name': e['service_name'],
            'gross_total': e['net_total'],
            'discount_total': 0,
            'net_total': e['net_total'],
            'payment_method': e['payment_method'],
            'payment_status': e['payment_status'],
            'cash_session_id': e['cash_session_id'],
            'source_appointment_id': e['source_appointment_id'],
            'origin_type': e['origin_type'],
            'sale_type': 'service',
            'source': 'mobile',
          }).toList(),
      'cash_movements': exportedCashMovements.map((e) => <String, Object?>{
            'movement_id': e['id'],
            'movement_at': e['movement_at'],
            'type': e['type'],
            'concept': e['concept'],
            'amount': e['amount'],
            'payment_method': e['payment_method'],
            'sale_id': e['sale_id'],
            'client_id': e['client_id'],
            'client_name': e['client_name'],
            'worker_id': e['worker_id'],
            'worker_name': e['worker_name'],
            'service_code': e['service_code'],
            'service_name': e['service_name'],
            'cash_session_id': e['cash_session_id'],
            'source_appointment_id': e['source_appointment_id'],
            'origin_type': e['origin_type'],
            'notes': e['notes'],
          }).toList(),
      'daily_summary': <String, Object?>{
        'clients_served': summary['clientsCount'],
        'services_count': summary['servicesCount'],
        'sales_total': summary['salesTotal'],
        ...paymentTotals,
        'expenses_total': summary['expensesTotal'],
        'expected_cash_closing': summary['expectedCashClosing'],
      },
      'integrity': <String, Object?>{
        'record_count': services.length,
        'hash': 'pending',
        'app_signature': 'pending',
      },
    };

    final docs = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(docs.path, 'exports'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final file = File(p.join(exportsDir.path, fileName));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    await db.insert('export_history', <String, Object?>{
      'id': const Uuid().v4(),
      'created_at': now.toIso8601String(),
      'file_name': fileName,
      'file_path': file.path,
      'share_channel': 'local',
      'close_id': closeBatchId,
    });
    return file;
  }

  Future<void> shareCloseFile({String notes = '', String closedBy = 'mobile_user'}) async {
    final file = await exportTodayClose(notes: notes, closedBy: closedBy);
    await Share.shareXFiles(<XFile>[XFile(file.path)], text: 'Ventas móviles Studio Pro');
  }
}

