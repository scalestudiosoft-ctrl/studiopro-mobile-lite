import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/theme_controller.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.initialize();
  await ThemeController.instance.load();
  runApp(const StudioProMobileApp());
}
