import 'package:flutter/foundation.dart';

class AppSyncBus {
  AppSyncBus._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void bump() {
    changes.value = changes.value + 1;
  }
}
