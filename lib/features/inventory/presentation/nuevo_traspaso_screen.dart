import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/data/catalogo_remote_data_source.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/inventory_remote_data_source.dart';
import '../domain/inventory_models.dart';

/// Mueve pilas de un modelo de una sucursal a otra. Solo se ofrecen los
/// modelos con existencia en el origen y no se puede pedir más de lo que
/// hay; el servidor descuenta del origen y da de alta en el destino.
class NuevoTraspasoScreen extends StatefulWidget {
  const NuevoTraspasoScreen({super.key});

  @override
  State<NuevoTraspasoScreen> createState() => _NuevoTraspasoScreenState();
}

class _NuevoTraspasoScreenState extends State<NuevoTraspasoScreen> {
  final _inventarioDs = InventoryRemoteDataSource();
  final _catalogoDs = CatalogoRemoteDataSource();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _notaCtrl = TextEditingController();

  List<Sucursal> _sucursales = const [];
  List<ItemInventario> _existencias = const [];
  String? _origenId;
  String? _destinoId;
  ItemInventario? _item;

  bool _cargandoBase = true;
  bool _cargandoExistencias = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  int get _cantidad => int.tryParse(_cantidadCtrl.text.trim()) ?? 0;

  String _nombreSucursal(String? id) =>
      _sucursales.where((s) => s.id == id).map((s) => s.nombre).firstOrNull ?? '';

  static String _nombreItem(ItemInventario i) {
    final modelo = (i.modelo ?? '').trim();
    final marca = (i.marca ?? '').trim();
    if (marca.isEmpty || modelo.toLowerCase().contains(marca.toLowerCase())) {
      return modelo;
    }
    return '$marca $modelo';
  }

  Future<void> _cargarSucursales() async {
    setState(() {
      _cargandoBase = true;
      _error = null;
    });
    try {
      final sucs = await _catalogoDs.listarSucursales();
      if (!mounted) return;
      final matriz = sucs.where((s) => s.esMatriz).firstOrNull ?? sucs.firstOrNull;
      setState(() {
        _sucursales = sucs;
        _origenId = matriz?.id;
        _destinoId = sucs.where((s) => s.id != _origenId).firstOrNull?.id;
        _cargandoBase = false;
      });
      await _cargarExistencias();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargandoBase = false;
      });
    }
  }

  Future<void> _cargarExistencias() async {
    final origen = _origenId;
    if (origen == null) return;
    setState(() {
      _cargandoExistencias = true;
      _existencias = const [];
      _item = null;
    });
    try {
      final datos = await _inventarioDs.listarInventario(sucursalId: origen);
      if (!mounted || origen != _origenId) return;
      final conExistencia = datos
          .where((i) => i.productoId != null && i.cantidad > 0)
          .toList()
        ..sort((a, b) => _nombreItem(a).compareTo(_nombreItem(b)));
      setState(() {
        _existencias = conExistencia;
        _cargandoExistencias = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoExistencias = false);
      _avisar(e.toString(), error: true);
    }
  }

  void _cambiarOrigen(String? id) {
    if (id == null || id == _origenId) return;
    setState(() {
      _origenId = id;
      if (_destinoId == id) {
        _destinoId = _sucursales.where((s) => s.id != id).firstOrNull?.id;
      }
    });
    _cargarExistencias();
  }

  void _ajustarCantidad(int delta) {
    final max = _item?.cantidad ?? 1;
    final nueva = (_cantidad + delta).clamp(1, max < 1 ? 1 : max);
    setState(() => _cantidadCtrl.text = '$nueva');
  }

  void _avisar(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: error ? Colors.red : null),
    );
  }

  /// Lo que falta para poder traspasar, o null si todo está listo.
  String? get _faltante {
    if (_origenId == null || _destinoId == null) return 'Elige el origen y el destino';
    if (_origenId == _destinoId) return 'El origen y el destino deben ser distintos';
    if (_item == null) return 'Elige el modelo de pila';
    if (_cantidad < 1) return 'La cantidad debe ser al menos 1';
    if (_cantidad > _item!.cantidad) {
      return 'Solo hay ${_item!.cantidad} en ${_nombreSucursal(_origenId)}';
    }
    return null;
  }

  Future<void> _traspasar() async {
    final faltante = _faltante;
    if (faltante != null) {
      _avisar(faltante, error: true);
      return;
    }
    final item = _item!;
    final cantidad = _cantidad;
    final origen = _nombreSucursal(_origenId);
    final destino = _nombreSucursal(_destinoId);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Hacer el traspaso?'),
        content: Text(
          'Se descontarán $cantidad ${_nombreItem(item)} de $origen '
          'y se darán de alta en $destino.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Traspasar')),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      await _inventarioDs.transferir(
        productoId: item.productoId!,
        origenId: _origenId!,
        destinoId: _destinoId!,
        cantidad: cantidad,
        nota: _notaCtrl.text,
      );
      if (!mounted) return;
      _avisar('Listo: $cantidad ${_nombreItem(item)} pasaron de $origen a $destino');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _avisar(e.toString(), error: true);
    }
  }

  void _elegirModelo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SelectorExistencia(
        existencias: _existencias,
        nombre: _nombreItem,
        onSeleccionado: (item) => setState(() {
          _item = item;
          if (_cantidad > item.cantidad || _cantidad < 1) _cantidadCtrl.text = '1';
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo traspaso')),
      body: _cargandoBase
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: TextStyle(color: colors.error), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(onPressed: _cargarSucursales, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _Seccion(
                      icono: Icons.storefront_outlined,
                      titulo: '1. Sucursales',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _origenId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sale de',
                            border: OutlineInputBorder(),
                          ),
                          items: _sucursales
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre)))
                              .toList(),
                          onChanged: _enviando ? null : _cambiarOrigen,
                        ),
                        const SizedBox(height: 12),
                        // La key lo vuelve a crear al cambiar el origen, que
                        // puede cambiar también el destino.
                        DropdownButtonFormField<String>(
                          key: ValueKey('destino-$_origenId'),
                          initialValue: _destinoId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Llega a',
                            border: OutlineInputBorder(),
                          ),
                          items: _sucursales
                              .where((s) => s.id != _origenId)
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre)))
                              .toList(),
                          onChanged: _enviando ? null : (id) => setState(() => _destinoId = id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Seccion(
                      icono: Icons.battery_full_rounded,
                      titulo: '2. Pila y cantidad',
                      children: [
                        InkWell(
                          onTap: _cargandoExistencias || _enviando || _existencias.isEmpty ? null : _elegirModelo,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
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
                                  child: _cargandoExistencias
                                      ? const Text('Cargando existencias…')
                                      : _existencias.isEmpty
                                          ? Text(
                                              'No hay pilas en existencia en ${_nombreSucursal(_origenId)}',
                                              style: TextStyle(color: colors.onSurfaceVariant),
                                            )
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _item == null ? 'Toca para elegir el modelo' : _nombreItem(_item!),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                if (_item != null)
                                                  Text(
                                                    'Hay ${_item!.cantidad} en ${_nombreSucursal(_origenId)}',
                                                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                                                  ),
                                              ],
                                            ),
                                ),
                                if (_cargandoExistencias)
                                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                else
                                  const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Quitar uno',
                              onPressed: _item == null || _enviando || _cantidad <= 1 ? null : () => _ajustarCantidad(-1),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _cantidadCtrl,
                                enabled: _item != null && !_enviando,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  labelText: 'Cantidad',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Agregar uno',
                              onPressed: _item == null || _enviando || _cantidad >= _item!.cantidad
                                  ? null
                                  : () => _ajustarCantidad(1),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notaCtrl,
                          enabled: !_enviando,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Nota (opcional)',
                            hintText: 'Ej. pedido de la sucursal, quién la lleva',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
      bottomNavigationBar: _cargandoBase || _error != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_faltante != null && _item != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_faltante!, style: TextStyle(color: colors.error, fontSize: 13)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _enviando || _faltante != null ? null : _traspasar,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _enviando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.swap_horiz_rounded),
                      label: Text(_enviando ? 'Traspasando…' : 'Traspasar', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.icono, required this.titulo, required this.children});

  final IconData icono;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Buscador de los modelos con existencia en la sucursal de origen.
class _SelectorExistencia extends StatefulWidget {
  const _SelectorExistencia({
    required this.existencias,
    required this.nombre,
    required this.onSeleccionado,
  });

  final List<ItemInventario> existencias;
  final String Function(ItemInventario) nombre;
  final ValueChanged<ItemInventario> onSeleccionado;

  @override
  State<_SelectorExistencia> createState() => _SelectorExistenciaState();
}

class _SelectorExistenciaState extends State<_SelectorExistencia> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final q = _filtro.trim().toLowerCase();
    final visibles = q.isEmpty
        ? widget.existencias
        : widget.existencias
            .where((i) =>
                widget.nombre(i).toLowerCase().contains(q) ||
                (i.codigoBarras ?? '').toLowerCase().contains(q))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar modelo o código',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _filtro = v),
              ),
            ),
            Expanded(
              child: visibles.isEmpty
                  ? Center(
                      child: Text('Sin coincidencias', style: TextStyle(color: colors.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (_, i) {
                        final item = visibles[i];
                        return ListTile(
                          title: Text(widget.nombre(item), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: item.codigoBarras == null ? null : Text(item.codigoBarras!),
                          trailing: Text(
                            '${item.cantidad} disp.',
                            style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
                          ),
                          onTap: () {
                            widget.onSeleccionado(item);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
