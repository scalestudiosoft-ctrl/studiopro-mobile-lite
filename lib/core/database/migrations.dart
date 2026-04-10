import 'package:sqflite/sqflite.dart';
import 'schema.dart';

Future<void> runMigrations(Database db) async {
  for (final statement in appSchema) {
    try {
      await db.execute(statement);
    } catch (_) {
      // Ignora ALTER/CREATE repetidos para mantener la app ligera y tolerante.
    }
  }
}
