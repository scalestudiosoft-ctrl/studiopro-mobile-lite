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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          ...?actions,
          PopupMenuButton<String>(
            tooltip: 'Atajos',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            position: PopupMenuPosition.under,
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
            icon: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E3F3)),
              ),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: theme.dividerColor)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, -2),
              color: Color(0x12000000),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex(context),
          onDestinationSelected: (index) => _onNavigate(context, index),
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded), label: 'Agenda'),
            NavigationDestination(icon: Icon(Icons.content_cut_outlined), selectedIcon: Icon(Icons.content_cut_rounded), label: 'Servicios'),
            NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'Caja'),
            NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Cierre'),
          ],
        ),
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
