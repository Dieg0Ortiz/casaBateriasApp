import '../../../../core/utils/date_formatters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../domain/purchase_models.dart';
import 'nueva_compra_screen.dart';
import 'purchases_viewmodel.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
  // Fecha formateada con formatFechaHora
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchasesViewModel>().cargarCompras();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final esAdmin = authVm.usuario?.esAdministrador == true;

    if (!esAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Restringido')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                const Text(
                  'Acceso exclusivo para Administradores',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No cuentas con permisos para consultar o registrar compras de inventario.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final vm = context.watch<PurchasesViewModel>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final comprasFiltradas = vm.compras.where((c) {
      if (_filtro.trim().isEmpty) return true;
      final q = _filtro.trim().toLowerCase();
      return c.folio.toLowerCase().contains(q) ||
          (c.proveedorNombre ?? '').toLowerCase().contains(q) ||
          c.sucursalNombre.toLowerCase().contains(q) ||
          c.usuarioNombre.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras de Stock'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: vm.cargando ? null : () => vm.cargarCompras(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NuevaCompraScreen()),
          );
          if (res == true && mounted) {
            vm.cargarCompras();
          }
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Nueva Compra'),
      ),
      body: vm.cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => vm.cargarCompras(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  // Stat Cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Facturas',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    Icon(Icons.receipt_long_outlined, size: 18, color: colors.primary),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${vm.compras.length}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'REGISTRADAS',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurfaceVariant,
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
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Inversión Total',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    Icon(Icons.attach_money_rounded, size: 18, color: colors.secondary),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _moneda.format(vm.totalInvertido),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'COMPLETADAS',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Buscador
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por folio, proveedor, sucursal…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    onChanged: (val) => setState(() => _filtro = val),
                  ),
                  const SizedBox(height: 12),

                  // Error Banner si ocurrió un error al consultar
                  if (vm.error != null && vm.compras.isEmpty) ...[
                    Card(
                      color: colors.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Error al cargar el historial de compras:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: colors.onErrorContainer),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vm.error!,
                              style: TextStyle(fontSize: 12, color: colors.onErrorContainer),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () => vm.cargarCompras(),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Lista de Compras
                  if (comprasFiltradas.isEmpty && vm.error == null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inventory_outlined, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              vm.compras.isEmpty
                                  ? 'No hay compras registradas en el sistema'
                                  : 'No se encontraron resultados para la búsqueda',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ...comprasFiltradas.map((c) => _TarjetaCompra(
                          compra: c,
                          moneda: _moneda,
                          
                          onTap: () => _mostrarDetalle(context, c.id),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  void _mostrarDetalle(BuildContext context, String compraId) async {
    final vm = context.read<PurchasesViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalDetalleCompra(
        compraId: compraId,
        vm: vm,
        moneda: _moneda,
        
      ),
    );
  }
}

class _TarjetaCompra extends StatelessWidget {
  const _TarjetaCompra({
    required this.compra,
    required this.moneda,
    
    required this.onTap,
  });

  final Compra compra;
  final NumberFormat moneda;
  
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      compra.folio,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: compra.esCompletada
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      compra.estado.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: compra.esCompletada ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compra.proveedorNombre ?? 'Sin proveedor especificado',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${compra.sucursalNombre} • Registró: ${compra.usuarioNombre.split(' ').first}',
                          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        moneda.format(compra.total),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      Text(
                        formatFechaHora(compra.fecha),
                        style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalDetalleCompra extends StatefulWidget {
  const _ModalDetalleCompra({
    required this.compraId,
    required this.vm,
    required this.moneda,
    
  });

  final String compraId;
  final PurchasesViewModel vm;
  final NumberFormat moneda;
  

  @override
  State<_ModalDetalleCompra> createState() => _ModalDetalleCompraState();
}

class _ModalDetalleCompraState extends State<_ModalDetalleCompra> {
  CompraDetalle? _detalle;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await widget.vm.obtenerDetalle(widget.compraId);
    if (mounted) {
      setState(() {
        _detalle = d;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_detalle == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No se pudo cargar el detalle de la compra')),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Folio: ${_detalle!.folio}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(formatFechaHora(_detalle!.fecha), style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Destino: ${_detalle!.sucursalNombre}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              'Proveedor: ${_detalle!.proveedorNombre ?? "Sin proveedor"}',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            const Text(
              'Artículos Adquiridos',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _detalle!.items.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (_, idx) {
                  final item = _detalle!.items[idx];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.tipoItem == 'bateria'
                              ? colors.primary.withValues(alpha: 0.12)
                              : colors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.tipoItem.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: item.tipoItem == 'bateria' ? colors.primary : colors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.modelo ?? (item.tipoItem == 'casco' ? 'Lote de Cascos' : 'Producto'),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              '${item.cantidad} x ${widget.moneda.format(item.precioUnitario)}',
                              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        widget.moneda.format(item.subtotal),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Factura:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  widget.moneda.format(_detalle!.total),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  }
}
