import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../catalog/data/catalogo_remote_data_source.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/purchase_models.dart';
import 'purchases_viewmodel.dart';

class NuevaCompraScreen extends StatefulWidget {
  const NuevaCompraScreen({super.key});

  @override
  State<NuevaCompraScreen> createState() => _NuevaCompraScreenState();
}

class _NuevaCompraScreenState extends State<NuevaCompraScreen> {
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
  final _catalogoDs = CatalogoRemoteDataSource();

  List<Sucursal> _sucursales = const [];
  List<Producto> _productos = const [];
  String? _sucursalId;
  String? _proveedorId;

  String _tipoItem = 'bateria'; // 'bateria' | 'casco'
  Producto? _productoSeleccionado;
  final _cantidadCtrl = TextEditingController(text: '1');
  final _costoCtrl = TextEditingController();

  final List<CompraItemInput> _carrito = [];
  bool _cargandoBase = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _costoCtrl.text = '';
    _cargarDatosBase();
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosBase() async {
    setState(() => _cargandoBase = true);
    try {
      final sucs = await _catalogoDs.listarSucursales();
      final prods = await _catalogoDs.listarProductos();
      await context.read<PurchasesViewModel>().cargarProveedores();

      if (!mounted) return;
      setState(() {
        _sucursales = sucs;
        _productos = prods.where((p) => p.activo).toList();
        if (_sucursales.isNotEmpty) {
          _sucursalId = _sucursales.first.id;
        }
        if (_productos.isNotEmpty) {
          _productoSeleccionado = _productos.first;
          _costoCtrl.text = _productos.first.precio.toStringAsFixed(2);
        }
        _cargandoBase = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargandoBase = false;
      });
    }
  }

  void _agregarAlCarrito() {
    final cant = int.tryParse(_cantidadCtrl.text.trim());
    if (cant == null || cant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad válida mayor a 0')),
      );
      return;
    }

    final costo = double.tryParse(_costoCtrl.text.trim());
    if (costo == null || costo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un costo unitario válido')),
      );
      return;
    }

    if (_tipoItem == 'bateria') {
      if (_productoSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una batería del catálogo')),
        );
        return;
      }

      setState(() {
        _carrito.add(
          CompraItemInput(
            tipoItem: 'bateria',
            productoId: _productoSeleccionado!.id,
            cantidad: cant,
            precioUnitario: costo,
            descripcionVisual: _productoSeleccionado!.modelo,
            marcaVisual: _productoSeleccionado!.marcaNombre,
          ),
        );
        _cantidadCtrl.text = '1';
      });
    } else {
      setState(() {
        _carrito.add(
          CompraItemInput(
            tipoItem: 'casco',
            productoId: null,
            cantidad: cant,
            precioUnitario: costo,
            descripcionVisual: 'Lote de Cascos / Baterías Viejas',
          ),
        );
        _cantidadCtrl.text = '1';
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Artículo agregado al resumen'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _guardarCompra() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un producto a la compra')),
      );
      return;
    }
    if (_sucursalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la sucursal de destino')),
      );
      return;
    }

    final vm = context.read<PurchasesViewModel>();
    final ok = await vm.registrarCompra(
      RegistrarCompraInput(
        sucursalId: _sucursalId!,
        proveedorId: _proveedorId,
        items: _carrito,
      ),
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Compra registrada y stock actualizado con éxito!')),
      );
      Navigator.of(context).pop(true);
    } else if (mounted && vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirBuscadorBaterias() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SelectorBateriaSheet(
        productos: _productos,
        moneda: _moneda,
        onSeleccionado: (prod) {
          setState(() {
            _productoSeleccionado = prod;
            _costoCtrl.text = prod.precio.toStringAsFixed(2);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final vm = context.watch<PurchasesViewModel>();

    final totalCompra = _carrito.fold<double>(0.0, (sum, i) => sum + i.subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Compra'),
      ),
      body: _cargandoBase
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: TextStyle(color: colors.error)),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _cargarDatosBase,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    // Card 1: Destino y Proveedor
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront_outlined, size: 20, color: colors.primary),
                                const SizedBox(width: 8),
                                const Text('1. Destino y Proveedor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _sucursalId,
                              decoration: const InputDecoration(
                                labelText: 'Sucursal de Destino *',
                                border: OutlineInputBorder(),
                              ),
                              items: _sucursales
                                  .map((s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text('${s.nombre} ${s.esMatriz ? "(Matriz)" : ""}'),
                                      ))
                                  .toList(),
                              onChanged: (val) => setState(() => _sucursalId = val),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _proveedorId,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor Externo (Opcional)',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('(Sin especificar / Directo)'),
                                ),
                                ...vm.proveedores.map((p) => DropdownMenuItem<String?>(
                                      value: p.id,
                                      child: Text(p.nombre),
                                    )),
                              ],
                              onChanged: (val) => setState(() => _proveedorId = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card 2: Agregar Productos
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.add_box_outlined, size: 20, color: colors.primary),
                                const SizedBox(width: 8),
                                const Text('2. Agregar Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Segmented Button
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'bateria', label: Text('Baterías'), icon: Icon(Icons.battery_full)),
                                ButtonSegment(value: 'casco', label: Text('Cascos'), icon: Icon(Icons.recycling)),
                              ],
                              selected: {_tipoItem},
                              onSelectionChanged: (val) {
                                setState(() => _tipoItem = val.first);
                              },
                            ),
                            const SizedBox(height: 16),

                            if (_tipoItem == 'bateria') ...[
                              InkWell(
                                onTap: _abrirBuscadorBaterias,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: colors.outlineVariant),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.search_rounded, color: colors.primary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _productoSeleccionado?.modelo ?? 'Toca para buscar batería…',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            if (_productoSeleccionado != null)
                                              Text(
                                                '${_productoSeleccionado!.marcaNombre} • Código: ${_productoSeleccionado!.codigoBarras}',
                                                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.recycling_rounded, color: colors.secondary),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Lote de Cascos / Baterías Viejas\n(Se sumarán a cascos disponibles)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _cantidadCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Cantidad',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.numbers_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _costoCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Costo Unitario',
                                      border: OutlineInputBorder(),
                                      prefixText: r'$ ',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            FilledButton.tonalIcon(
                              onPressed: _agregarAlCarrito,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Añadir a la Compra'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card 3: Resumen de Compra
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Resumen de Artículos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    '${_carrito.length} ítems',
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
                            const SizedBox(height: 12),
                            if (_carrito.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No has agregado artículos al lote',
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _carrito.length,
                                separatorBuilder: (_, __) => const Divider(height: 14),
                                itemBuilder: (_, idx) {
                                  final item = _carrito[idx];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.descripcionVisual ?? (item.tipoItem == 'casco' ? 'Lote de Cascos' : 'Batería'),
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                            Text(
                                              '${item.cantidad} x ${_moneda.format(item.precioUnitario)}',
                                              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _moneda.format(item.subtotal),
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: colors.primary,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        onPressed: () => setState(() => _carrito.removeAt(idx)),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total de Compra:', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                    Text(
                      _moneda.format(totalCompra),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _carrito.isEmpty || vm.guardando ? null : _guardarCompra,
                icon: vm.guardando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(vm.guardando ? 'Guardando…' : 'Confirmar'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorBateriaSheet extends StatefulWidget {
  const _SelectorBateriaSheet({
    required this.productos,
    required this.moneda,
    required this.onSeleccionado,
  });

  final List<Producto> productos;
  final NumberFormat moneda;
  final ValueChanged<Producto> onSeleccionado;

  @override
  State<_SelectorBateriaSheet> createState() => _SelectorBateriaSheetState();
}

class _SelectorBateriaSheetState extends State<_SelectorBateriaSheet> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtrados = widget.productos.where((p) {
      if (_busqueda.trim().isEmpty) return true;
      final q = _busqueda.trim().toLowerCase();
      return p.modelo.toLowerCase().contains(q) ||
          p.marcaNombre.toLowerCase().contains(q) ||
          p.codigoBarras.toLowerCase().contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por modelo, marca, código…',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            onChanged: (val) => setState(() => _busqueda = val),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(child: Text('No se encontraron baterías'))
                : ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final p = filtrados[idx];
                      return ListTile(
                        title: Text(p.modelo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p.marcaNombre} • Código: ${p.codigoBarras}'),
                        trailing: Text(
                          widget.moneda.format(p.precio),
                          style: TextStyle(fontFamily: 'monospace', color: colors.primary, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          widget.onSeleccionado(p);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
