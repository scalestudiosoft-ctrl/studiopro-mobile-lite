import 'package:flutter/material.dart';

import 'theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  final ThemeData _theme = buildStudioTheme();

  ThemeData get theme => _theme;

  Future<void> load() async {}
}
