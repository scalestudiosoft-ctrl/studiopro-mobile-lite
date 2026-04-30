import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_shell.dart';

class NewServicePage extends StatelessWidget {
  const NewServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Servicios',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Servicios es el catálogo del negocio', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Aquí defines los servicios que luego se pueden agendar y facturar. '
                    'La venta real se hace en Caja, porque ahí deben quedar presentes el cliente, el profesional, el servicio, el método de pago y el valor final.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () => context.go('/catalog'),
                        icon: const Icon(Icons.content_cut_outlined),
                        label: const Text('Ir al catálogo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/cash'),
                        icon: const Icon(Icons.point_of_sale_outlined),
                        label: const Text('Ir a Caja a facturar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

