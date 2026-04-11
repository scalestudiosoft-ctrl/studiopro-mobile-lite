import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/services/app_sync_bus.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/info_card.dart';

class CashPage extends StatefulWidget {
  const CashPage({super.key});

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  final _openingController = TextEditingController();
  final _conceptController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _movementType = 'expense';
  String _paymentMethod = 'efectivo';
  Map<String, Object?>? _session;
  List<Map<String, Object?>> _movements = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _salesRows = const <Map<String, Object?>>[];
  double _salesTotal = 0;
  double _expensesTotal = 0;
  Map<String, double> _paymentTotals = <String, double>{};

  @override
  void initState() {
    super.initState();
    AppSyncBus.changes.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    AppSyncBus.changes.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final workDate = formatDateOnly(DateTime.now());
    final session = await db.firstRow('cash_sessions', where: 'work_date = ? AND status = ?', whereArgs: <Object?>[workDate, 'open']);
    final business = await db.firstRow('business_profile');
    final movements = await db.queryRaw(
      'SELECT * FROM cash_movements WHERE substr(movement_at, 1, 10) = ? ORDER BY movement_at DESC',
      <Object?>[workDate],
    );
    final salesRows = await db.queryRaw(
      'SELECT * FROM sales WHERE substr(sale_at, 1, 10) = ? ORDER BY sale_at DESC',
      <Object?>[workDate],
    );
    double salesTotal = 0;
    double expensesTotal = 0;
    final paymentTotals = <String, double>{for (final method in AppConstants.paymentMethods) method: 0};
    for (final row in salesRows) {
      final total = (row['net_total'] as num).toDouble();
      salesTotal += total;
      paymentTotals['${row['payment_method']}'] = (paymentTotals['${row['payment_method']}'] ?? 0) + total;
    }
    for (final row in movements) {
      final amount = (row['amount'] as num).toDouble();
      if ('${row['type']}' == 'expense') {
        expensesTotal += amount;
      }
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _movements = movements;
      _salesRows = salesRows;
      _salesTotal = salesTotal;
      _expensesTotal = expensesTotal;
      _paymentTotals = paymentTotals;
      if (session == null && _openingController.text.trim().isEmpty) {
        _openingController.text = '${((business?['default_opening_cash'] as num?) ?? 0).toDouble().toInt()}';
      }
    });
  }

  Future<void> _openCash() async {
    final amount = double.tryParse(_openingController.text.trim()) ?? 0;
    await AppDatabase.instance.insert('cash_sessions', <String, Object?>{
      'id': 'SESSION-${const Uuid().v4()}',
      'work_date': formatDateOnly(DateTime.now()),
      'opened_at': DateTime.now().toIso8601String(),
      'opening_cash': amount,
      'status': 'open',
      'opened_by': 'mobile_user',
      'closing_notes': '',
    });
    AppSyncBus.bump();
    await _load();
  }

  Future<void> _closeCash() async {
    if (_session == null) return;
    await AppDatabase.instance.update(
      'cash_sessions',
      <String, Object?>{'status': 'closed', 'closed_at': DateTime.now().toIso8601String(), 'closing_notes': _notesController.text.trim()},
      where: 'id = ?',
      whereArgs: <Object?>[_session!['id']],
    );
    _notesController.clear();
    AppSyncBus.bump();
    await _load();
  }

  Future<void> _saveMovement() async {
    if (_conceptController.text.trim().isEmpty || _amountController.text.trim().isEmpty) return;
    await AppDatabase.instance.insert('cash_movements', <String, Object?>{
      'id': 'MOV-${const Uuid().v4()}',
      'movement_at': DateTime.now().toIso8601String(),
      'type': _movementType,
      'concept': _conceptController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'payment_method': _paymentMethod,
      'notes': _notesController.text.trim(),
    });
    _conceptController.clear();
    _amountController.clear();
    _notesController.clear();
    AppSyncBus.bump();
    await _load();
  }

  Future<void> _editMovement(Map<String, Object?> movement) async {
    final conceptController = TextEditingController(text: '${movement['concept'] ?? ''}');
    final amountController = TextEditingController(text: '${((movement['amount'] as num?) ?? 0).toDouble()}');
    final notesController = TextEditingController(text: '${movement['notes'] ?? ''}');
    String movementType = '${movement['type'] ?? 'expense'}';
    String paymentMethod = '${movement['payment_method'] ?? 'efectivo'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Editar movimiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: movementType,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'expense', child: Text('Gasto / salida')),
                    DropdownMenuItem(value: 'income', child: Text('Ingreso extra')),
                  ],
                  onChanged: (value) => setModalState(() => movementType = value ?? 'expense'),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 12),
                TextField(controller: conceptController, decoration: const InputDecoration(labelText: 'Concepto')),
                const SizedBox(height: 12),
                TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(method))).toList(),
                  onChanged: (value) => setModalState(() => paymentMethod = value ?? 'efectivo'),
                  decoration: const InputDecoration(labelText: 'Método de pago'),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notas')),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await AppDatabase.instance.update(
      'cash_movements',
      <String, Object?>{
        'type': movementType,
        'concept': conceptController.text.trim(),
        'amount': double.tryParse(amountController.text.trim()) ?? 0,
        'payment_method': paymentMethod,
        'notes': notesController.text.trim(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[movement['id']],
    );
    AppSyncBus.bump();
    await _load();
  }

  Future<void> _deleteMovement(Map<String, Object?> movement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text('¿Seguro que deseas eliminar ${movement['concept']}?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    await AppDatabase.instance.delete('cash_movements', where: 'id = ?', whereArgs: <Object?>[movement['id']]);
    AppSyncBus.bump();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final openingCash = _session == null ? 0.0 : (_session!['opening_cash'] as num).toDouble();
    final expectedCash = openingCash + (_paymentTotals['efectivo'] ?? 0) - _expensesTotal;
    return AppShell(
      title: 'Caja',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SizedBox(width: 220, child: InfoCard(title: 'Estado', value: _session == null ? 'Cerrada' : 'Abierta')),
              SizedBox(width: 220, child: InfoCard(title: 'Apertura', value: copCurrency.format(openingCash))),
              SizedBox(width: 220, child: InfoCard(title: 'Ventas', value: copCurrency.format(_salesTotal))),
              SizedBox(width: 220, child: InfoCard(title: 'Gastos', value: copCurrency.format(_expensesTotal))),
              SizedBox(width: 220, child: InfoCard(title: 'Caja esperada', value: copCurrency.format(expectedCash))),
            ],
          ),
          const SizedBox(height: 16),
          if (_session == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    const Text('Antes de vender, abre caja y luego registra servicios para que ventas, caja y cierre cuadren bien.'),
                    ActionChip(label: const Text('Ir a servicio'), onPressed: () => context.push('/new-service')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_session == null ? 'Abrir caja' : 'Registrar movimiento', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_session == null) ...<Widget>[
                    TextField(controller: _openingController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto inicial')),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _openCash, child: const Text('Abrir caja'))),
                  ] else ...<Widget>[
                    DropdownButtonFormField<String>(
                      value: _movementType,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'expense', child: Text('Gasto / salida')),
                        DropdownMenuItem(value: 'income', child: Text('Ingreso extra')),
                      ],
                      onChanged: (value) => setState(() => _movementType = value ?? 'expense'),
                      decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _conceptController, decoration: const InputDecoration(labelText: 'Concepto')),
                    const SizedBox(height: 12),
                    TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      items: AppConstants.paymentMethods.map((method) => DropdownMenuItem<String>(value: method, child: Text(method))).toList(),
                      onChanged: (value) => setState(() => _paymentMethod = value ?? 'efectivo'),
                      decoration: const InputDecoration(labelText: 'Método de pago'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notas')),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(child: FilledButton(onPressed: _saveMovement, child: const Text('Guardar movimiento'))),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton(onPressed: _closeCash, child: const Text('Cerrar caja'))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_session == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    const Text('Antes de vender, abre caja y luego registra servicios para que ventas, caja y cierre cuadren bien.'),
                    ActionChip(label: const Text('Ir a servicio'), onPressed: () => context.push('/new-service')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Pagos del día', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...AppConstants.paymentMethods.map((method) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(method),
                        trailing: Text(copCurrency.format(_paymentTotals[method] ?? 0)),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_salesRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Ventas registradas', style: Theme.of(context).textTheme.titleMedium),
            ),
          ..._salesRows.map((sale) => Card(
                child: ListTile(
                  title: Text('Servicio vendido'),
                  subtitle: Text('${sale['payment_method']} • ${formatShortDateTime(DateTime.parse('${sale['sale_at']}'))}'),
                  trailing: Text(copCurrency.format((sale['net_total'] as num).toDouble())),
                ),
              )),
          if (_movements.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text('Movimientos manuales', style: Theme.of(context).textTheme.titleMedium),
            ),
          ..._movements.map((movement) => Card(
                child: ListTile(
                  title: Text('${movement['concept']}'),
                  subtitle: Text('${movement['type']} • ${movement['payment_method']} • ${formatShortDateTime(DateTime.parse('${movement['movement_at']}'))}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editMovement(movement);
                      } else if (value == 'delete') {
                        _deleteMovement(movement);
                      }
                    },
                    itemBuilder: (context) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                      PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
                    ],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(copCurrency.format((movement['amount'] as num).toDouble())),
                        const SizedBox(height: 4),
                        const Icon(Icons.more_vert),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
