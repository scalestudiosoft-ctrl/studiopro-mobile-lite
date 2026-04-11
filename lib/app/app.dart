import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart';

class StudioProMobileApp extends StatelessWidget {
  const StudioProMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Studio Pro',
      debugShowCheckedModeBanner: false,
      theme: buildStudioTheme(),
      routerConfig: appRouter,
    );
  }
}
