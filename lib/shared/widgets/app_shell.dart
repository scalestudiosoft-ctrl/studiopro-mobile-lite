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
          PopupMenuButton<String>(
            tooltip: 'Atajos',
            onSelected: (value) {
              switch (value) {
                case 'clients':
                  context.push('/clients');
                  break;
                case 'workers':
                  context.push('/workers');
                  break;
                case 'catalog':
                  context.push('/catalog');
                  break;
                case 'exports':
                  context.push('/exports');
                  break;
                case 'settings':
                  context.push('/settings');
                  break;
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'clients', child: Text('Clientes')),
              PopupMenuItem<String>(value: 'workers', child: Text('Profesionales')),
              PopupMenuItem<String>(value: 'catalog', child: Text('Catálogo')),
              PopupMenuDivider(),
              PopupMenuItem<String>(value: 'exports', child: Text('Historial de cierres')),
              PopupMenuItem<String>(value: 'settings', child: Text('Configuración')),
            ],
            icon: const Icon(Icons.more_vert),
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
          NavigationDestination(icon: Icon(Icons.content_cut_outlined), label: 'Servicios'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Caja'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), label: 'Cierre'),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/agenda')) return 1;
    if (location.startsWith('/new-service') || location.startsWith('/catalog')) return 2;
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
        context.go('/catalog');
      case 3:
        context.go('/cash');
      case 4:
        context.go('/closing');
    }
  }
}

