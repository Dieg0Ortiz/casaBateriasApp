import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/inventory_remote_data_source.dart';
import '../domain/inventory_models.dart';

/// Vista de inventario por sucursal: cantidad, cascos disponibles y
/// precio vigente (todo desde el servidor).
/// Implementa el diseño "Ultramarine Industrial".
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _ds = InventoryRemoteDataSource();
  List<ItemInventario> _items = const [];
  bool _cargando = true;
  String? _error;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _ds.listarInventario();
      if (!mounted) return;
      setState(() {
        _items = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is Exception ? e.toString() : 'Ocurrió un error';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario & Existencias'),
        actions: [
          IconButton(
            tooltip: 'Actualizar existencias',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargando ? null : _cargar,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _MensajeError(mensaje: _error!, onReintentar: _cargar);
    }

    final totalNuevas = _items.fold<int>(0, (sum, i) => sum + i.cantidad);
    final totalCascos = _items.fold<int>(0, (sum, i) => sum + i.cascosDisponibles);

    final visibles = _items.where((i) {
      final q = _filtro.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (i.modelo?.toLowerCase().contains(q) ?? false) ||
          (i.codigoBarras?.contains(q) ?? false) ||
          (i.marca?.toLowerCase().contains(q) ?? false);
    }).toList();

    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // KPI Bento Cards: Total Nuevas & Total Cascos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  color: colors.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BATERÍAS NUEVAS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.05,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Icon(Icons.battery_charging_full_rounded, size: 16, color: colors.primary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalNuevas uds',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  color: colors.secondary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CASCOS / CHATARRA',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.05,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Icon(Icons.recycling_rounded, size: 16, color: colors.secondary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalCascos uds',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por modelo, marca o código…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _filtro.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _filtro = ''),
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _filtro = v.trim()),
          ),
        ),

        // Items List
        Expanded(
          child: visibles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warehouse_outlined, size: 52, color: colors.outlineVariant),
                      const SizedBox(height: 12),
                      Text(
                        _filtro.isEmpty ? 'Aún no hay existencias registradas' : 'Sin coincidencias para "$_filtro"',
                        style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  itemCount: visibles.length,
                  itemBuilder: (context, i) => _TarjetaItem(visibles[i]),
                ),
        ),
      ],
    );
  }
}

class _TarjetaItem extends StatelessWidget {
  const _TarjetaItem(this.item);

  final ItemInventario item;

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.marca != null && item.marca!.isNotEmpty)
                        Text(
                          item.marca!.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        item.modelo ?? 'Sin modelo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (item.codigoBarras != null && item.codigoBarras!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${item.codigoBarras}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  moneda.format(item.precio),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 14, color: colors.primary),
                      const SizedBox(width: 5),
                      Text(
                        '${item.cantidad} en existencia',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item.requiereCasco)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.secondary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.recycling_rounded, size: 14, color: colors.secondary),
                        const SizedBox(width: 5),
                        Text(
                          '${item.cascosDisponibles} cascos',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
