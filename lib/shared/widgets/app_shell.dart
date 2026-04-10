import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          ...?actions,
          IconButton(
            tooltip: 'Configuración',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) => _onNavigate(context, index),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Servicio'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Caja'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), label: 'Cierre'),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/agenda')) return 1;
    if (location.startsWith('/new-service')) return 2;
    if (location.startsWith('/cash')) return 3;
    if (location.startsWith('/closing') || location.startsWith('/exports')) return 4;
    return 0;
  }

  void _onNavigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/agenda');
      case 2:
        context.go('/new-service');
      case 3:
        context.go('/cash');
      case 4:
        context.go('/closing');
    }
  }
}
