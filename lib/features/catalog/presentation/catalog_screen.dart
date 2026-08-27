import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../domain/catalog_models.dart';
import 'alta_producto_screen.dart';
import 'catalogo_viewmodel.dart';

/// Catálogo de productos: búsqueda, listado con tarjetas Bento, marcas y precios.
/// Implementa el diseño "Ultramarine Industrial".
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _busquedaCtrl = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogoViewModel>().cargar();
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _nuevoProducto() async {
    final vm = context.read<CatalogoViewModel>();
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AltaProductoScreen()),
    );
    if (creado == true) {
      await vm.cargar();
    }
  }

  List<Producto> _filtrar(List<Producto> items) {
    final q = _filtro.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((p) {
      final m = p.modelo.toLowerCase();
      final marca = p.marcaNombre.toLowerCase();
      final cb = p.codigoBarras.toLowerCase();
      return m.contains(q) || marca.contains(q) || cb.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final esAdmin = authVm.usuario?.esAdministrador == true;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibles = _filtrar(vm.productos);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Baterías'),
        actions: [
          IconButton(
            tooltip: 'Recargar catálogo',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: vm.cargando ? null : () => vm.cargar(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: esAdmin
          ? FloatingActionButton.extended(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'NUEVO PRODUCTO',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.05),
              ),
              onPressed: _nuevoProducto,
            )
          : null,
      body: switch (vm.status) {
        CatalogoStatus.inicial || CatalogoStatus.cargando =>
          const Center(child: CircularProgressIndicator()),
        CatalogoStatus.error => _MensajeError(
            mensaje: vm.mensajeError ?? 'Error al cargar el catálogo',
            onReintentar: vm.cargar,
          ),
        CatalogoStatus.listo => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por modelo, marca o código de barras…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _filtro.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _busquedaCtrl.clear();
                              setState(() => _filtro = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _filtro = v),
                ),
              ),
              if (visibles.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 52, color: colors.outlineVariant),
                        const SizedBox(height: 12),
                        Text(
                          _filtro.isEmpty ? 'No hay productos en catálogo' : 'Sin coincidencias para "$_filtro"',
                          style: TextStyle(fontSize: 16, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: visibles.length,
                    itemBuilder: (context, i) {
                      final p = visibles[i];
                      return _TarjetaProducto(p);
                    },
                  ),
                ),
            ],
          ),
      },
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto(this.producto);

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.battery_charging_full_rounded,
                    color: colors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (producto.marcaNombre.isNotEmpty)
                        Text(
                          producto.marcaNombre.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        producto.modelo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  moneda.format(producto.precio),
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
                if (producto.codigoBarras.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          producto.codigoBarras,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                if (producto.requiereCasco)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Casco',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${producto.stockTotal} uds',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (!producto.activo) ...[
              const SizedBox(height: 8),
              Text(
                'DADO DE BAJA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.error,
                ),
              ),
            ],
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
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: colors.error,
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
