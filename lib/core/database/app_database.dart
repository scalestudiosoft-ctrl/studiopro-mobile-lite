import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../shared/models/business_profile.dart';
import '../../shared/models/service_catalog_item.dart';
import '../constants/app_constants.dart';
import 'migrations.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<void> initialize() async {
    await database;
    await _seedBusinessProfile();
    await _seedCatalog();
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(directory.path, 'studio_pro_mobile.db');
    _db = await openDatabase(
      databasePath,
      version: 6,
      onCreate: (db, version) async => runMigrations(db),
      onUpgrade: (db, oldVersion, newVersion) async => runMigrations(db),
      onOpen: (db) async => runMigrations(db),
    );
    return _db!;
  }

  Future<void> _seedBusinessProfile() async {
    final db = await database;
    final existing = await db.query('business_profile', limit: 1);
    if (existing.isNotEmpty) return;
    const profile = BusinessProfile(
      businessId: AppConstants.defaultBusinessId,
      name: 'Mi Negocio',
      city: 'Tunja',
      businessType: 'barbershop',
      ownerName: 'Administrador',
      deviceName: 'Android',
      defaultOpeningCash: 0,
      primaryButtonColor: AppConstants.defaultPrimaryButtonColor,
      secondaryButtonColor: AppConstants.defaultSecondaryButtonColor,
      logoPath: null,
    );
    await db.insert('business_profile', profile.toMap());
  }

  Future<void> _seedCatalog() async {
    final db = await database;
    final seeded = await db.query('app_meta', where: 'key = ?', whereArgs: <Object?>['catalog_seeded'], limit: 1);
    if (seeded.isNotEmpty) return;
    final existing = await db.query('service_catalog', limit: 1);
    if (existing.isEmpty) {
      final items = <ServiceCatalogItem>[
        const ServiceCatalogItem(code: 'SRV-CORTE', name: 'Corte clásico', basePrice: 25000, durationMinutes: 45, commissionPercent: 50, description: 'Servicio base de corte.'),
        const ServiceCatalogItem(code: 'SRV-BARBA', name: 'Barba', basePrice: 15000, durationMinutes: 20, commissionPercent: 50, description: 'Perfilado y arreglo de barba.'),
        const ServiceCatalogItem(code: 'SRV-CORTE-BARBA', name: 'Corte + barba', basePrice: 35000, durationMinutes: 60, commissionPercent: 50, description: 'Combo de corte y barba.'),
      ];
      for (final item in items) {
        await db.insert('service_catalog', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await db.insert(
      'app_meta',
      <String, Object?>{'key': 'catalog_seeded', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insert(String table, Map<String, Object?> values) async {
    final db = await database;
    return db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, Object?>>> queryAll(String table, {String? orderBy}) async {
    final db = await database;
    return db.query(table, orderBy: orderBy ?? 'rowid DESC');
  }

  Future<List<Map<String, Object?>>> queryWhere(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<List<Map<String, Object?>>> queryRaw(String sql, [List<Object?>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<void> executeBatch(Future<void> Function(Batch batch) callback) async {
    final db = await database;
    final batch = db.batch();
    await callback(batch);
    await batch.commit(noResult: true);
  }

  Future<Map<String, Object?>?> firstRow(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final rows = await queryWhere(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }
}
