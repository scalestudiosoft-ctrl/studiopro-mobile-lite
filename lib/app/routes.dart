import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/agenda/agenda_page.dart';
import '../features/cash/cash_page.dart';
import '../features/catalog/catalog_page.dart';
import '../features/clients/clients_page.dart';
import '../features/closing/closing_page.dart';
import '../features/exports/exports_page.dart';
import '../features/home/home_page.dart';
import '../features/services/new_service_page.dart';
import '../features/settings/settings_page.dart';
import '../features/workers/workers_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/agenda', builder: (context, state) => const AgendaPage()),
    GoRoute(path: '/new-service', builder: (context, state) => const NewServicePage()),
    GoRoute(path: '/clients', builder: (context, state) => const ClientsPage()),
    GoRoute(path: '/workers', builder: (context, state) => const WorkersPage()),
    GoRoute(path: '/catalog', builder: (context, state) => const CatalogPage()),
    GoRoute(path: '/cash', builder: (context, state) => const CashPage()),
    GoRoute(path: '/closing', builder: (context, state) => const ClosingPage()),
    GoRoute(path: '/exports', builder: (context, state) => const ExportsPage()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
  ],
);
