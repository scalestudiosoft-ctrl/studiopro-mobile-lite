import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme_controller.dart';

class StudioProMobileApp extends StatelessWidget {
  const StudioProMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Studio Pro',
          debugShowCheckedModeBanner: false,
          theme: ThemeController.instance.theme,
          routerConfig: appRouter,
        );
      },
    );
  }
}
