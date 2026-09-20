import '../../../../core/utils/date_formatters.dart';
import '../../creditos/data/creditos_remote_data_source.dart';
import '../../creditos/domain/credito_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/security/device_security_service.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../cash/presentation/cash_viewmodel.dart';
import '../../catalog/data/catalogo_remote_data_source.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../inventory/data/inventory_remote_data_source.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../printing/print_models.dart';
import '../../printing/printer_screen.dart';
import '../../printing/ticket_builder.dart';
import '../domain/sales_models.dart';
import '../presentation/sales_viewmodel.dart';
import 'scan_screen.dart';

/// Punto de venta: escanear o buscar, armar el carrito y cobrar.
/// Implementa el diseño "Ultramarine Industrial" con Hero action buttons,
/// bento cards para líneas de venta, badges de casco interactivos y barra de cobro flotante.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _inventarioDs = InventoryRemoteDataSource();
  final _catalogoDs = CatalogoRemoteDataSource();
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

  DeviceRisk? _riesgo;
  List<Sucursal> _sucursales = [];
  List<ItemInventario> _inventario = [];
  String? _sucursalId;
  bool _cargando = true;
  String? _error;
  bool _dialogoCascoAbierto = false;
  bool _folioMostrado = false;
  List<LineaTicket> _ultimasLineas = const [];

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final riesgo = await DeviceSecurityService.instance.checkRisk();
    if (!mounted) return;
    setState(() => _riesgo = riesgo);
    if (riesgo != DeviceRisk.ok) return;

    final perfil = context.read<AuthViewModel>().usuario;
    _sucursalId = perfil?.sucursalId;
    await _cargarSucursales();

    if (!mounted) return;
    final cashVm = context.read<CashViewModel>();
    if (!cashVm.cargando) {
      await cashVm.cargar();
    }
  }

  Future<void> _cargarSucursales() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _catalogoDs.listarSucursales();
      if (!mounted) return;
      final defaultId = _sucursalId ?? (datos.isNotEmpty ? datos.first.id : null);
      setState(() {
        _sucursales = datos;
        _sucursalId = defaultId;
      });
      if (defaultId != null) {
        await _cargarInventario();
      } else {
        setState(() => _cargando = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is Exception ? e.toString() : 'Ocurrió un error';
        _cargando = false;
      });
    }
  }

  void _mostrarSelectorSucursal() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.storefront_rounded, color: colors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sucursal de Despacho',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Selecciona la sucursal para cargar inventario y precios',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _sucursales.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = _sucursales[i];
                      final isSelected = s.id == _sucursalId;
                      return Material(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.surfaceContainerHighest.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSelected
                                ? colors.primary
                                : colors.outlineVariant.withValues(alpha: 0.3),
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            if (s.id != _sucursalId) {
                              setState(() => _sucursalId = s.id);
                              _cargarInventario();
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                                      const SizedBox(width: 10),
                                      Text('Cambiado a ${s.nombre}'),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.nombre,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? colors.primary : colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'ACTIVA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cargarInventario() async {
    final sucursal = _sucursalId;
    if (sucursal == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _inventarioDs.listarInventario(sucursalId: sucursal);
      if (!mounted) return;
      setState(() {
        _inventario = datos;
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

  Sucursal? get _sucursalActual {
    final encontrada = _sucursales.where((s) => s.id == _sucursalId);
    if (encontrada.isNotEmpty) {
      return encontrada.first;
    }
    final matriz = _sucursales.where((s) => s.esMatriz);
    if (matriz.isNotEmpty) {
      return matriz.first;
    }
    if (_sucursales.isNotEmpty) {
      return _sucursales.first;
    }
    return null;
  }

  String get _nombreSucursal =>
      _sucursalActual?.nombre ??
      context.read<AuthViewModel>().usuario?.sucursalNombre ??
      (context.read<AuthViewModel>().usuario?.sucursalId != null
          ? 'Cargando...'
          : 'Sin Sucursal');

  String? get _direccionSucursal {
    final dir = _sucursalActual?.direccion;
    if (dir != null && dir.trim().isNotEmpty) {
      return dir.trim();
    }
    final nombre = (_sucursalActual?.nombre ?? '').toLowerCase();
    if (nombre.contains('matriz') || nombre.contains('villaflores')) {
      return 'Carretera Villaflores entre 20 y 21 Sur, C.P. 29080';
    } else if (nombre.contains('salle')) {
      return 'Boulevard La Salle, Esq. Boulevard Belisario Dominguez S/N';
    }
    return null;
  }

  ItemInventario? _buscarPorCodigo(String codigo) {
    final normalizado = codigo.trim();
    if (normalizado.isEmpty) return null;
    final sinCero = normalizado.startsWith('0') ? normalizado.substring(1) : normalizado;
    final conCero = '0$normalizado';

    for (final item in _inventario) {
      final cb = item.codigoBarras?.trim();
      if (cb == null || cb.isEmpty) continue;
      if (cb == normalizado || cb == sinCero || cb == conCero) {
        return item;
      }
    }
    return null;
  }

  Future<({String tipoPrecio, double precio})?> _preguntarPrecio(
    ItemInventario item, {
    String tipoActual = 'default',
    double? precioActual,
    bool forzarModal = false,
  }) async {
    if (!forzarModal && item.precio2 == null && item.precio3 == null) {
      return (tipoPrecio: 'default', precio: item.precio);
    }

    return showModalBottomSheet<({String tipoPrecio, double precio})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorPrecioModal(
        item: item,
        moneda: _moneda,
        tipoActual: tipoActual,
        precioActual: precioActual,
      ),
    );
  }

  Future<void> _agregarItem(ItemInventario item, {required bool manual}) async {
    if (item.cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.modelo} no tiene existencias en esta sucursal')),
      );
      return;
    }

    final seleccion = await _preguntarPrecio(item);
    if (seleccion == null || !mounted) return;

    final vm = context.read<SalesViewModel>();
    vm.agregar(
      productoId: item.productoId,
      codigoBarras: item.codigoBarras ?? item.modelo ?? '',
      modelo: item.modelo ?? 'Producto',
      marca: item.marca,
      precio: seleccion.precio,
      tipoPrecio: seleccion.tipoPrecio,
      precioDefault: item.precio,
      precio2: item.precio2,
      precio3: item.precio3,
      comisionCasco: item.comisionCasco,
      requiereCasco: item.requiereCasco,
      busquedaManual: manual,
    );
  }

  Future<void> _cambiarPrecioEnCarrito(int index, LineaVenta linea) async {
    final item = ItemInventario(
      sucursalId: _sucursalId ?? '',
      productoId: linea.productoId,
      modelo: linea.modelo,
      codigoBarras: linea.codigoBarras,
      marca: linea.marca,
      precio: linea.precioDefault ?? linea.precio,
      precio2: linea.precio2,
      precio3: linea.precio3,
      comisionCasco: linea.comisionCasco,
      requiereCasco: linea.requiereCasco,
      cantidad: 1,
      cascosDisponibles: 0,
    );

    final seleccion = await _preguntarPrecio(
      item,
      tipoActual: linea.tipoPrecio,
      precioActual: linea.precio,
      forzarModal: true,
    );
    if (seleccion != null && mounted) {
      context.read<SalesViewModel>().cambiarTipoPrecio(
        index,
        seleccion.tipoPrecio,
        precioPersonalizado: seleccion.precio,
      );
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (codigo == null || !mounted) return;
    final item = _buscarPorCodigo(codigo);
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto no encontrado en esta sucursal'),
        ),
      );
      return;
    }
    await _agregarItem(item, manual: false);
  }

  Future<void> _busquedaManual() async {
    final elegido = await showModalBottomSheet<ItemInventario>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuscadorManual(items: _inventario, moneda: _moneda),
    );
    if (elegido == null || !mounted) return;
    await _agregarItem(elegido, manual: true);
  }

  Future<void> _cobrar() async {
    final vm = context.read<SalesViewModel>();
    final sucursal = _sucursalId;
    if (sucursal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una sucursal primero')),
      );
      return;
    }
    if (vm.lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío')),
      );
      return;
    }

    final cashVm = context.read<CashViewModel>();
    String? corteId;
    if (cashVm.cajaActiva?.tieneCajaAbierta == true) {
      corteId = cashVm.cajaActiva!.corte!.id;
    } else {
      final continuar = await _avisarSinCajaAbierta();
      if (continuar != true || !mounted) return;
    }

    final resultadoPago = await _preguntarMetodoPago(vm.total);
    if (resultadoPago == null || !mounted) return;

    final lineasVendidas = List<LineaVenta>.from(vm.lineas);

    final venta = await vm.registrar(
      sucursalId: sucursal,
      corteCajaId: corteId,
      metodoPago: resultadoPago.metodoPago,
      desglosePago: resultadoPago.desglosePago,
      empresaCreditoId: resultadoPago.empresaCreditoId,
      creditoRecibidoPor: resultadoPago.creditoRecibidoPor,
      creditoVehiculoPlacas: resultadoPago.creditoVehiculoPlacas,
      creditoFolioVale: resultadoPago.creditoFolioVale,
    );
    if (venta != null && mounted) {
      _ultimasLineas = lineasVendidas
          .map(
            (l) => LineaTicket(
              modelo: l.modelo,
              marca: l.marca,
              cantidad: l.cantidad,
              precio: l.precio,
              conCasco: l.conCasco,
              tipoPrecio: l.tipoPrecio,
              comisionCasco: l.comisionCasco,
            ),
          )
          .toList();
      _folioMostrado = false;
      await _cargarInventario();
      if (corteId != null) {
        await cashVm.cargar();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.mensajeError ?? 'No se pudo registrar la venta'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<_ResultadoPago?> _preguntarMetodoPago(double totalVenta) {
    return showModalBottomSheet<_ResultadoPago>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalCobro(
        total: totalVenta,
        moneda: _moneda,
      ),
    );
  }

  Future<bool?> _avisarSinCajaAbierta() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sin Caja Abierta',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'La venta se registrará sin ligarse al corte del turno. '
                  'Abre la caja antes de vender para que el total cuente en el '
                  'monto esperado al cerrar.',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.35),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Vender sin caja', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatearMetodoPago(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta_debito':
        return 'Tarjeta Débito';
      case 'tarjeta_credito':
        return 'Tarjeta Crédito';
      case 'tarjeta':
        return 'Tarjeta';
      case 'transferencia':
        return 'Transferencia';
      case 'mixto':
        return 'Pago Mixto';
      case 'credito':
        return 'Crédito';
      default:
        return metodo;
    }
  }

  Future<List<int>> _construirTicket(VentaResultado venta) async {
    final fecha = formatFechaHora(venta.creadaEn);
    final ticket = DatosTicket(
      encabezado: 'CASA BATERIAS',
      sucursal: _nombreSucursal,
      direccionSucursal: _direccionSucursal,
      propietario: 'Joaquin Gabriel Estrada Marquez',
      rfc: 'EAMJ-760228-E21',
      folio: venta.folio,
      fecha: fecha,
      empleado: context.read<AuthViewModel>().usuario?.nombreCompleto,
      metodoPago: _formatearMetodoPago(venta.metodoPago),
      lineas: _ultimasLineas,
      total: venta.total,
    );
    return TicketBuilder().ticket(ticket);
  }

  void _atenderPendienteCasco(SalesViewModel vm) {
    final pendiente = vm.pendienteCasco;
    if (pendiente == null || _dialogoCascoAbierto) return;
    _dialogoCascoAbierto = true;
    final comision = pendiente.comisionCasco ?? 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: colorScheme.surface,
            elevation: 8,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pendiente.modelo,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'POLÍTICA DE CASCO / DEPÓSITO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '¿El cliente entrega una batería usada a cambio?',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (comision > 0)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.info_outline_rounded, color: Colors.red, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Depósito por no dejar casco: ${_moneda.format(comision)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'El cliente cuenta con 15 días naturales para entregar un casco y solicitar la devolución de su dinero.',
                                  style: TextStyle(fontSize: 12, color: Colors.red, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  // Botón Primario: Con casco
                  FilledButton(
                    onPressed: () {
                      vm.resolverCasco(true);
                      Navigator.of(ctx).pop();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Con casco (A cambio)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Botón Secundario: Sin casco (+ depósito)
                  OutlinedButton(
                    onPressed: () {
                      vm.resolverCasco(false);
                      Navigator.of(ctx).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      comision > 0 ? 'Sin casco (+${_moneda.format(comision)})' : 'Sin casco',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Botón Terciario: Cancelar
                  TextButton(
                    onPressed: () {
                      vm.cancelarCasco();
                      Navigator.of(ctx).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ).whenComplete(() => _dialogoCascoAbierto = false);
    });
  }

  void _atenderExito(SalesViewModel vm) {
    final venta = vm.ultimaVenta;
    if (venta == null || _folioMostrado) return;
    _folioMostrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: colorScheme.surface,
            elevation: 8,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF10B981),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Venta Registrada',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'FOLIO: ${venta.folio}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _moneda.format(venta.total),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Botón Primario: Nueva venta
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Nueva venta',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Botón Secundario: Imprimir ticket
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: const Text(
                        'Imprimir ticket',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ImpresoraScreen(
                              titulo: 'ticket',
                              construir: () => _construirTicket(venta),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesViewModel>();
    _atenderPendienteCasco(vm);
    _atenderExito(vm);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Punto de Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Terminal POS',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar inventario',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _sucursalId == null ? null : _cargarInventario,
          ),
        ],
      ),
      body: _riesgo == null
          ? const Center(child: CircularProgressIndicator())
          : _riesgo != DeviceRisk.ok
              ? _BloqueoDispositivo(
                  onReintentar: _iniciar,
                  comprometido: _riesgo == DeviceRisk.comprometido,
                )
              : _cuerpo(vm),
    );
  }

  Widget _cuerpo(SalesViewModel vm) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _cargarInventario,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final esAdmin = context.watch<AuthViewModel>().usuario?.esAdministrador == true;
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          children: [
            // Action Hero: Rapid Action Buttons (Stitch Ultramarine POS)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    onPressed: _escanear,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Escanear Código de Barras'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _busquedaManual,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Buscar por Modelo'),
                  ),
                ],
              ),
            ),

            // Cart Items Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Carrito Actual',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${vm.cantidadArticulos} Artículos',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Cart List
            Expanded(
              child: vm.lineas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 52, color: colors.outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            'El carrito está vacío',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Escanea un código o usa la búsqueda manual',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, esAdmin ? 200 : 140),
                      itemCount: vm.lineas.length,
                      itemBuilder: (context, i) => _LineaCarrito(
                        vm: vm,
                        index: i,
                        linea: vm.lineas[i],
                        onCambiarPrecio: () => _cambiarPrecioEnCarrito(i, vm.lineas[i]),
                      ),
                    ),
            ),
          ],
        ),

        // Sticky Bottom Checkout Bar (Stitch Ultramarine POS)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BarraTotal(
            total: vm.total,
            articulos: vm.cantidadArticulos,
            cobrando: vm.registrando,
            sucursal: _nombreSucursal,
            esAdmin: esAdmin,
            onCambiarSucursal: _mostrarSelectorSucursal,
            onCobrar: _cobrar,
          ),
        ),
      ],
    );
  }
}

class _LineaCarrito extends StatelessWidget {
  const _LineaCarrito({
    required this.vm,
    required this.index,
    required this.linea,
    this.onCambiarPrecio,
  });

  final SalesViewModel vm;
  final int index;
  final LineaVenta linea;
  final VoidCallback? onCambiarPrecio;

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final colors = Theme.of(context).colorScheme;

    final colorPrecio = linea.tipoPrecio == 'precio_especial'
        ? const Color(0xFFD946EF)
        : linea.tipoPrecio == 'precio_2'
            ? const Color(0xFFEA580C)
            : linea.tipoPrecio == 'precio_3'
                ? const Color(0xFF9333EA)
                : colors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      if (linea.marca != null && linea.marca!.isNotEmpty)
                        Text(
                          linea.marca!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        linea.modelo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${linea.codigoBarras}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      moneda.format(linea.importe),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    if (linea.cantidad > 1)
                      Text(
                        '${linea.cantidad} x ${moneda.format(linea.precio)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Badge de opción de precio (interactivo para cambiar o personalizar precio)
                InkWell(
                  onTap: onCambiarPrecio,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorPrecio.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colorPrecio.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sell_rounded, size: 13, color: colorPrecio),
                        const SizedBox(width: 4),
                        Text(
                          linea.etiquetaTipoPrecio.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorPrecio,
                          ),
                        ),
                        if (onCambiarPrecio != null) ...[
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down_rounded, size: 16, color: colorPrecio),
                        ],
                      ],
                    ),
                  ),
                ),

                if (linea.requiereCasco)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (linea.conCasco == true ? colors.secondary : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (linea.conCasco == true ? colors.secondary : const Color(0xFFDC2626)).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          linea.conCasco == true ? Icons.recycling_rounded : Icons.info_outline_rounded,
                          size: 13,
                          color: linea.conCasco == true ? colors.secondary : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          linea.conCasco == true
                              ? 'CON CASCO'
                              : (linea.comisionCasco != null && linea.comisionCasco! > 0
                                  ? 'SIN CASCO (+${moneda.format(linea.comisionCasco)})'
                                  : 'SIN CASCO'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: linea.conCasco == true ? colors.secondary : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: colors.error,
                  onPressed: () => vm.quitarEn(index),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                      onPressed: () => vm.decrementarEn(index),
                    ),
                    Text(
                      '${linea.cantidad}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      onPressed: () => vm.incrementarEn(index),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorPrecioModal extends StatefulWidget {
  const _SelectorPrecioModal({
    required this.item,
    required this.moneda,
    this.tipoActual = 'default',
    this.precioActual,
  });

  final ItemInventario item;
  final NumberFormat moneda;
  final String tipoActual;
  final double? precioActual;

  @override
  State<_SelectorPrecioModal> createState() => _SelectorPrecioModalState();
}

class _SelectorPrecioModalState extends State<_SelectorPrecioModal> {
  late String _tipoSeleccionado;
  late final TextEditingController _precioEspecialCtrl;
  late final FocusNode _precioEspecialFocus;
  String? _errorPrecioEspecial;

  @override
  void initState() {
    super.initState();
    _tipoSeleccionado = widget.tipoActual;
    final initialEspecial = widget.tipoActual == 'precio_especial'
        ? (widget.precioActual?.toStringAsFixed(2) ?? '')
        : '';
    _precioEspecialCtrl = TextEditingController(text: initialEspecial);
    _precioEspecialFocus = FocusNode();
  }

  @override
  void dispose() {
    _precioEspecialCtrl.dispose();
    _precioEspecialFocus.dispose();
    super.dispose();
  }

  double _obtenerPrecio(String tipo) {
    switch (tipo) {
      case 'precio_2':
        return widget.item.precio2 ?? widget.item.precio;
      case 'precio_3':
        return widget.item.precio3 ?? widget.item.precio;
      case 'precio_especial':
        final parsed = double.tryParse(_precioEspecialCtrl.text.replaceAll(',', ''));
        return parsed ?? (widget.precioActual ?? widget.item.precio);
      default:
        return widget.item.precio;
    }
  }

  void _seleccionarTipo(String tipo) {
    setState(() {
      _tipoSeleccionado = tipo;
      _errorPrecioEspecial = null;
    });
    if (tipo == 'precio_especial') {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _precioEspecialFocus.requestFocus();
      });
    } else {
      _precioEspecialFocus.unfocus();
    }
  }

  void _confirmar() {
    if (_tipoSeleccionado == 'precio_especial') {
      final text = _precioEspecialCtrl.text.trim().replaceAll(',', '');
      final parsed = double.tryParse(text);
      if (parsed == null || parsed < 0) {
        setState(() {
          _errorPrecioEspecial = 'Ingresa un precio válido mayor o igual a 0';
        });
        _precioEspecialFocus.requestFocus();
        return;
      }
      Navigator.of(context).pop((
        tipoPrecio: 'precio_especial',
        precio: parsed,
      ));
      return;
    }

    final precioElegido = _obtenerPrecio(_tipoSeleccionado);
    Navigator.of(context).pop((
      tipoPrecio: _tipoSeleccionado,
      precio: precioElegido,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final precioElegido = _obtenerPrecio(_tipoSeleccionado);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + paddingBottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.sell_rounded, color: colors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.modelo ?? 'Producto',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Selecciona el precio aplicable para la venta',
                            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cancelar',
                    ),
                  ],
                ),
                if (widget.item.requiereCasco &&
                    widget.item.comisionCasco != null &&
                    widget.item.comisionCasco! > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCA8A04).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCA8A04).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.battery_alert_rounded, color: Color(0xFFCA8A04), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Requiere entrega de casco (+${widget.moneda.format(widget.item.comisionCasco!)} si no deja usado)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCA8A04),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _OpcionPrecioCard(
                  titulo: 'Precio 1 (Default / Público)',
                  monto: widget.moneda.format(widget.item.precio),
                  seleccionado: _tipoSeleccionado == 'default',
                  colorBadge: colors.primary,
                  onTap: () => _seleccionarTipo('default'),
                ),
                if (widget.item.precio2 != null) ...[
                  const SizedBox(height: 10),
                  _OpcionPrecioCard(
                    titulo: 'Precio 2 (Mayoreo / Taller)',
                    monto: widget.moneda.format(widget.item.precio2!),
                    seleccionado: _tipoSeleccionado == 'precio_2',
                    colorBadge: const Color(0xFFEA580C),
                    onTap: () => _seleccionarTipo('precio_2'),
                  ),
                ],
                if (widget.item.precio3 != null) ...[
                  const SizedBox(height: 10),
                  _OpcionPrecioCard(
                    titulo: 'Precio 3 (Promoción / Especial)',
                    monto: widget.moneda.format(widget.item.precio3!),
                    seleccionado: _tipoSeleccionado == 'precio_3',
                    colorBadge: const Color(0xFF9333EA),
                    onTap: () => _seleccionarTipo('precio_3'),
                  ),
                ],
                const SizedBox(height: 10),
                _OpcionPrecioEspecialCard(
                  seleccionado: _tipoSeleccionado == 'precio_especial',
                  controller: _precioEspecialCtrl,
                  focusNode: _precioEspecialFocus,
                  errorText: _errorPrecioEspecial,
                  colorBadge: const Color(0xFFD946EF),
                  onTap: () => _seleccionarTipo('precio_especial'),
                  onChanged: (val) {
                    setState(() {
                      _errorPrecioEspecial = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _confirmar,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          'Confirmar ${widget.moneda.format(precioElegido)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpcionPrecioCard extends StatelessWidget {
  const _OpcionPrecioCard({
    required this.titulo,
    required this.monto,
    required this.seleccionado,
    required this.colorBadge,
    required this.onTap,
  });

  final String titulo;
  final String monto;
  final bool seleccionado;
  final Color colorBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: seleccionado
          ? colorBadge.withValues(alpha: 0.12)
          : colors.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionado ? colorBadge : colors.outlineVariant.withValues(alpha: 0.4),
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                seleccionado ? Icons.radio_button_checked : Icons.radio_button_off,
                color: seleccionado ? colorBadge : colors.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                monto,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorBadge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionPrecioEspecialCard extends StatelessWidget {
  const _OpcionPrecioEspecialCard({
    required this.seleccionado,
    required this.controller,
    required this.focusNode,
    required this.colorBadge,
    required this.onTap,
    required this.onChanged,
    this.errorText,
  });

  final bool seleccionado;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color colorBadge;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: seleccionado
          ? colorBadge.withValues(alpha: 0.12)
          : colors.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionado ? colorBadge : colors.outlineVariant.withValues(alpha: 0.4),
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    seleccionado ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: seleccionado ? colorBadge : colors.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio Especial (Personalizado)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
                            color: seleccionado ? colorBadge : null,
                          ),
                        ),
                        Text(
                          'Editable por el trabajador en este momento',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorBadge.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LIBRE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorBadge,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (seleccionado) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    labelText: 'Monto pactado por unidad',
                    hintText: '0.00',
                    prefixText: r'$ ',
                    prefixStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorBadge,
                    ),
                    errorText: errorText,
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBadge),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBadge.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBadge, width: 2),
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorBadge,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BarraTotal extends StatelessWidget {
  const _BarraTotal({
    required this.total,
    required this.articulos,
    required this.cobrando,
    required this.sucursal,
    required this.onCobrar,
    this.esAdmin = false,
    this.onCambiarSucursal,
  });

  final double total;
  final int articulos;
  final bool cobrando;
  final String sucursal;
  final VoidCallback onCobrar;
  final bool esAdmin;
  final VoidCallback? onCambiarSucursal;

  @override
  Widget build(BuildContext context) {
    final moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (esAdmin)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onCambiarSucursal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.storefront_rounded, size: 16, color: colors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sucursal de Despacho: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  TextSpan(
                                    text: sucursal,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Cambiar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.swap_horiz_rounded, size: 14, color: colors.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL A PAGAR',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.05,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$articulos artículo(s) · $sucursal',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  moneda.format(total),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size(double.infinity, 54),
              ),
              onPressed: cobrando ? null : onCobrar,
              icon: cobrando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.payments_rounded),
              label: Text(cobrando ? 'Procesando venta…' : 'Cobrar Venta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuscadorManual extends StatefulWidget {
  const _BuscadorManual({required this.items, required this.moneda});

  final List<ItemInventario> items;
  final NumberFormat moneda;

  @override
  State<_BuscadorManual> createState() => _BuscadorManualState();
}

class _BuscadorManualState extends State<_BuscadorManual> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final q = _filtro.trim().toLowerCase();
    final visibles = widget.items.where((i) {
      if (q.isEmpty) return true;
      final mod = (i.modelo ?? '').toLowerCase();
      final mar = (i.marca ?? '').toLowerCase();
      final cod = (i.codigoBarras ?? '').toLowerCase();
      return mod.contains(q) || mar.contains(q) || cod.contains(q);
    }).toList();

    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Container(
        height: media.size.height * 0.82,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buscar Batería en Catálogo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${visibles.length} ${visibles.length == 1 ? "resultado" : "resultados"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por modelo, marca o código de barras...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _filtro.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _filtro = ''),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 54, color: colors.outline),
                            const SizedBox(height: 12),
                            Text(
                              widget.items.isEmpty
                                  ? 'No hay baterías cargadas en el inventario de esta sucursal'
                                  : 'No se encontraron baterías que coincidan con "$_filtro"',
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (context, i) {
                        final item = visibles[i];
                        final agotado = item.cantidad <= 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: colors.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: ListTile(
                            enabled: !agotado,
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: agotado
                                    ? colors.surfaceContainerHighest
                                    : colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.battery_charging_full_rounded,
                                size: 22,
                                color: agotado ? colors.outline : colors.primary,
                              ),
                            ),
                            title: Text(
                              item.modelo ?? 'Producto',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: agotado ? colors.outline : null,
                              ),
                            ),
                            subtitle: Text(
                              '${item.marca ?? ''} · ${item.cantidad} en existencia',
                              style: TextStyle(
                                fontSize: 12,
                                color: agotado ? colors.error : colors.onSurfaceVariant,
                                fontWeight: agotado ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: Text(
                              widget.moneda.format(item.precio),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: agotado ? colors.outline : colors.primary,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(item),
                          ),
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

class _BloqueoDispositivo extends StatelessWidget {
  const _BloqueoDispositivo({
    required this.onReintentar,
    required this.comprometido,
  });

  final VoidCallback onReintentar;
  final bool comprometido;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  comprometido ? Icons.gpp_bad_rounded : Icons.shield_outlined,
                  size: 56,
                  color: colors.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Terminal Bloqueada por Seguridad',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  comprometido
                      ? 'Este dispositivo parece estar en modo depuración o comprometido (root). '
                          'Las operaciones de venta y cobro están inhabilitadas por seguridad.'
                      : 'No se pudo verificar la integridad de la terminal. Operaciones bloqueadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar verificación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resultado de la selección en el modal de cobro
class _ResultadoPago {
  const _ResultadoPago({
    required this.metodoPago,
    this.desglosePago,
    this.empresaCreditoId,
    this.creditoRecibidoPor,
    this.creditoVehiculoPlacas,
    this.creditoFolioVale,
  });

  final String metodoPago;
  final List<PagoParcial>? desglosePago;
  final String? empresaCreditoId;
  final String? creditoRecibidoPor;
  final String? creditoVehiculoPlacas;
  final String? creditoFolioVale;
}

/// Modal integral de cobro: soporta Pago Único y Pago Mixto / Combinado
class _ModalCobro extends StatefulWidget {
  const _ModalCobro({
    required this.total,
    required this.moneda,
  });

  final double total;
  final NumberFormat moneda;

  @override
  State<_ModalCobro> createState() => _ModalCobroState();
}

class _ModalCobroState extends State<_ModalCobro> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Estado Pago Único
  String _metodoUnico = 'efectivo';
  final TextEditingController _recibidoController = TextEditingController();

  // Estado Crédito Empresarial
  final CreditosRemoteDataSource _creditosDataSource = CreditosRemoteDataSource();
  List<EmpresaCredito> _empresasCredito = [];
  EmpresaCredito? _empresaSeleccionada;
  bool _cargandoEmpresas = false;
  final TextEditingController _choferController = TextEditingController();
  final TextEditingController _placasController = TextEditingController();
  final TextEditingController _valeController = TextEditingController();

  // Estado Pago Mixto
  final List<_FilaPagoMixto> _filasMixtas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _cargarEmpresasCredito();

    // Inicializar pago mixto con 2 filas por defecto (ej. Débito y Efectivo)
    final mitad = (widget.total / 2).roundToDouble();
    final resto = widget.total - mitad;
    _filasMixtas.add(_FilaPagoMixto(
      metodo: 'tarjeta_debito',
      controller: TextEditingController(text: mitad > 0 ? mitad.toStringAsFixed(2) : ''),
    ));
    _filasMixtas.add(_FilaPagoMixto(
      metodo: 'efectivo',
      controller: TextEditingController(text: resto > 0 ? resto.toStringAsFixed(2) : ''),
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recibidoController.dispose();
    _choferController.dispose();
    _placasController.dispose();
    _valeController.dispose();
    for (final f in _filasMixtas) {
      f.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarEmpresasCredito() async {
    setState(() => _cargandoEmpresas = true);
    try {
      final empresas = await _creditosDataSource.getEmpresas(soloActivas: true);
      if (mounted) {
        setState(() {
          _empresasCredito = empresas;
          _cargandoEmpresas = false;
          if (_empresasCredito.isNotEmpty) {
            _empresaSeleccionada = _empresasCredito.first;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargandoEmpresas = false);
      }
    }
  }

  double get _sumaMixta {
    double suma = 0.0;
    for (final f in _filasMixtas) {
      final val = double.tryParse(f.controller.text.replaceAll(',', '')) ?? 0.0;
      suma += val;
    }
    return (suma * 100).round() / 100;
  }

  double get _restanteMixto {
    final rest = widget.total - _sumaMixta;
    return (rest * 100).round() / 100;
  }

  void _agregarFilaMixta(String metodo) {
    setState(() {
      final restante = _restanteMixto;
      final montoDefault = restante > 0 ? restante.toStringAsFixed(2) : '';
      _filasMixtas.add(_FilaPagoMixto(
        metodo: metodo,
        controller: TextEditingController(text: montoDefault),
      ));
    });
  }

  void _eliminarFilaMixta(int index) {
    if (_filasMixtas.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El pago mixto requiere al menos 2 métodos')),
      );
      return;
    }
    setState(() {
      final eliminada = _filasMixtas.removeAt(index);
      eliminada.controller.dispose();
    });
  }

  void _completarRestanteEnFila(int index) {
    final montoFilaActual = double.tryParse(_filasMixtas[index].controller.text.replaceAll(',', '')) ?? 0.0;
    final totalOtros = _sumaMixta - montoFilaActual;
    final nuevoMonto = widget.total - totalOtros;
    if (nuevoMonto > 0) {
      setState(() {
        _filasMixtas[index].controller.text = nuevoMonto.toStringAsFixed(2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Encabezado con Total de la Venta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL A COBRAR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.moneda.format(widget.total),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancelar',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selector de pestaña: Pago Único vs Pago Mixto
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: colors.onPrimary,
                unselectedLabelColor: colors.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(
                    iconMargin: EdgeInsets.only(bottom: 2),
                    icon: Icon(Icons.payment_rounded, size: 18),
                    text: 'Pago Único',
                  ),
                  Tab(
                    iconMargin: EdgeInsets.only(bottom: 2),
                    icon: Icon(Icons.call_split_rounded, size: 18),
                    text: 'Pago Mixto',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Contenido según la pestaña activa
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabPagoUnico(colors),
                  _buildTabPagoMixto(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: PAGO ÚNICO
  // --------------------------------------------------------------------------
  Widget _buildTabPagoUnico(ColorScheme colors) {
    final recibido = double.tryParse(_recibidoController.text.replaceAll(',', '')) ?? 0.0;
    final cambio = recibido > widget.total ? recibido - widget.total : 0.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            'Selecciona la forma de pago:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),

          // Grid / Opciones de métodos de pago
          _TarjetaMetodoPago(
            icono: Icons.payments_rounded,
            titulo: 'Efectivo',
            subtitulo: 'Pago en caja con billetes/monedas',
            color: const Color(0xFF16A34A),
            seleccionado: _metodoUnico == 'efectivo',
            onTap: () => setState(() => _metodoUnico = 'efectivo'),
          ),
          const SizedBox(height: 8),
          _TarjetaMetodoPago(
            icono: Icons.credit_card_rounded,
            titulo: 'Tarjeta de Débito',
            subtitulo: 'Terminal bancaria / PIN',
            color: const Color(0xFF0284C7),
            seleccionado: _metodoUnico == 'tarjeta_debito',
            onTap: () => setState(() => _metodoUnico = 'tarjeta_debito'),
          ),
          const SizedBox(height: 8),
          _TarjetaMetodoPago(
            icono: Icons.credit_score_rounded,
            titulo: 'Tarjeta de Crédito',
            subtitulo: 'Pago con tarjeta de crédito',
            color: const Color(0xFF9333EA),
            seleccionado: _metodoUnico == 'tarjeta_credito',
            onTap: () => setState(() => _metodoUnico = 'tarjeta_credito'),
          ),
          const SizedBox(height: 8),
          _TarjetaMetodoPago(
            icono: Icons.account_balance_rounded,
            titulo: 'Transferencia Bancaria (SPEI)',
            subtitulo: 'Comprobante digital / SPEI directo',
            color: const Color(0xFFEA580C),
            seleccionado: _metodoUnico == 'transferencia',
            onTap: () => setState(() => _metodoUnico = 'transferencia'),
          ),
          const SizedBox(height: 8),
          _TarjetaMetodoPago(
            icono: Icons.business_rounded,
            titulo: 'Crédito Empresarial',
            subtitulo: 'Línea de crédito para empresas (Bimbo, Coca-Cola, etc.)',
            color: const Color(0xFF6366F1),
            seleccionado: _metodoUnico == 'credito',
            onTap: () => setState(() => _metodoUnico = 'credito'),
          ),

          // Formulario de Crédito Empresarial
          if (_metodoUnico == 'credito') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Datos de Entrega a Crédito',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_cargandoEmpresas)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_empresasCredito.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No hay empresas con línea de crédito activa registradas. Agrega una desde el Panel Web de Administración.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<EmpresaCredito>(
                      initialValue: _empresaSeleccionada,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Empresa Autorizada *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _empresasCredito.map((emp) {
                        return DropdownMenuItem<EmpresaCredito>(
                          value: emp,
                          child: Text(
                            '${emp.nombre} (${emp.diasCredito} días)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (emp) => setState(() => _empresaSeleccionada = emp),
                    ),
                    const SizedBox(height: 10),

                    if (_empresaSeleccionada != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saldo Actual: ${widget.moneda.format(_empresaSeleccionada!.saldoDeudor)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Límite: ${_empresaSeleccionada!.limiteCredito > 0 ? widget.moneda.format(_empresaSeleccionada!.limiteCredito) : 'Sin Límite'}',
                              style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _choferController,
                      decoration: InputDecoration(
                        labelText: 'Recibido por (Nombre de Chofer / Encargado) *',
                        hintText: 'Ej. Juan Pérez (Chofer Ruta 4)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _placasController,
                            decoration: InputDecoration(
                              labelText: 'Placas Vehículo',
                              hintText: 'Ej. WP-8921-A',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _valeController,
                            decoration: InputDecoration(
                              labelText: 'Folio de Vale / Orden',
                              hintText: 'Ej. VALE-1049',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Calculadora de cambio opcional si es efectivo
          if (_metodoUnico == 'efectivo') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Paga con (Efectivo Recibido):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (cambio > 0)
                        Text(
                          'Cambio: ${widget.moneda.format(cambio)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _recibidoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Ej. ${widget.total.toStringAsFixed(0)}',
                      prefixText: r'$ ',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: _recibidoController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _recibidoController.clear()),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ChipMontoRapido(
                        label: 'Exacto',
                        onTap: () => setState(() => _recibidoController.text = widget.total.toStringAsFixed(2)),
                      ),
                      ...[50, 100, 200, 500, 1000].map((extra) {
                        final sugerido = ((widget.total / extra).ceil() * extra).toDouble();
                        if (sugerido <= widget.total) return const SizedBox.shrink();
                        return _ChipMontoRapido(
                          label: widget.moneda.format(sugerido),
                          onTap: () => setState(() => _recibidoController.text = sugerido.toStringAsFixed(2)),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              'Cobrar ${widget.moneda.format(widget.total)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (_metodoUnico == 'credito') {
                if (_empresaSeleccionada == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona una empresa con crédito'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (_choferController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre de quien recibe / chofer es obligatorio'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _ResultadoPago(
                    metodoPago: 'credito',
                    empresaCreditoId: _empresaSeleccionada!.id,
                    creditoRecibidoPor: _choferController.text.trim(),
                    creditoVehiculoPlacas: _placasController.text.trim(),
                    creditoFolioVale: _valeController.text.trim(),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(_ResultadoPago(metodoPago: _metodoUnico));
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: PAGO MIXTO / COMBINADO
  // --------------------------------------------------------------------------
  Widget _buildTabPagoMixto(ColorScheme colors) {
    final suma = _sumaMixta;
    final restante = _restanteMixto;
    final balanceado = restante.abs() < 0.01;
    final excede = restante < -0.01;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de estado de liquidación
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: balanceado
                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                  : excede
                      ? colors.errorContainer.withValues(alpha: 0.4)
                      : colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: balanceado
                    ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                    : excede
                        ? colors.error.withValues(alpha: 0.5)
                        : colors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Suma de Métodos: ${widget.moneda.format(suma)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      balanceado
                          ? 'Total Cubierto'
                          : excede
                              ? 'Exceso: ${widget.moneda.format(restante.abs())}'
                              : 'Falta: ${widget.moneda.format(restante)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: balanceado
                            ? const Color(0xFF16A34A)
                            : excede
                                ? colors.error
                                : colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: widget.total > 0 ? (suma / widget.total).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: colors.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      balanceado
                          ? const Color(0xFF16A34A)
                          : excede
                              ? colors.error
                              : colors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Desglose de montos por método:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Lista de filas de pago
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filasMixtas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final fila = _filasMixtas[idx];
              return _CardFilaPagoMixto(
                key: ObjectKey(fila),
                index: idx + 1,
                metodo: fila.metodo,
                controller: fila.controller,
                moneda: widget.moneda,
                onMetodoCambiado: (m) => setState(() => fila.metodo = m),
                onCompletarRestante: () => _completarRestanteEnFila(idx),
                onEliminar: _filasMixtas.length > 2 ? () => _eliminarFilaMixta(idx) : null,
                onChanged: () => setState(() {}),
              );
            },
          ),
          const SizedBox(height: 12),

          // Botones para agregar otra forma de pago
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '+ Agregar:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              ActionChip(
                avatar: const Icon(Icons.payments_rounded, size: 14, color: Color(0xFF16A34A)),
                label: const Text('Efectivo', style: TextStyle(fontSize: 11)),
                onPressed: () => _agregarFilaMixta('efectivo'),
              ),
              ActionChip(
                avatar: const Icon(Icons.credit_card_rounded, size: 14, color: Color(0xFF0284C7)),
                label: const Text('Débito', style: TextStyle(fontSize: 11)),
                onPressed: () => _agregarFilaMixta('tarjeta_debito'),
              ),
              ActionChip(
                avatar: const Icon(Icons.credit_score_rounded, size: 14, color: Color(0xFF9333EA)),
                label: const Text('Crédito', style: TextStyle(fontSize: 11)),
                onPressed: () => _agregarFilaMixta('tarjeta_credito'),
              ),
              ActionChip(
                avatar: const Icon(Icons.account_balance_rounded, size: 14, color: Color(0xFFEA580C)),
                label: const Text('Transferencia', style: TextStyle(fontSize: 11)),
                onPressed: () => _agregarFilaMixta('transferencia'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Botón de Confirmación Mixta
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: balanceado ? colors.primary : colors.surfaceContainerHighest,
              foregroundColor: balanceado ? colors.onPrimary : colors.onSurfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: Icon(
              balanceado ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              size: 20,
            ),
            label: Text(
              balanceado
                  ? 'Confirmar Pago Mixto (${widget.moneda.format(widget.total)})'
                  : excede
                      ? 'Excede total por ${widget.moneda.format(restante.abs())}'
                      : 'Falta liquidar ${widget.moneda.format(restante)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: balanceado
                ? () {
                    final desglose = _filasMixtas.map((f) {
                      final monto = double.tryParse(f.controller.text.replaceAll(',', '')) ?? 0.0;
                      return PagoParcial(metodo: f.metodo, monto: monto);
                    }).toList();

                    Navigator.of(context).pop(_ResultadoPago(
                      metodoPago: 'mixto',
                      desglosePago: desglose,
                    ));
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _FilaPagoMixto {
  _FilaPagoMixto({
    required this.metodo,
    required this.controller,
  });

  String metodo;
  final TextEditingController controller;
}

class _CardFilaPagoMixto extends StatelessWidget {
  const _CardFilaPagoMixto({
    super.key,
    required this.index,
    required this.metodo,
    required this.controller,
    required this.moneda,
    required this.onMetodoCambiado,
    required this.onCompletarRestante,
    required this.onEliminar,
    required this.onChanged,
  });

  final int index;
  final String metodo;
  final TextEditingController controller;
  final NumberFormat moneda;
  final ValueChanged<String> onMetodoCambiado;
  final VoidCallback onCompletarRestante;
  final VoidCallback? onEliminar;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila Superior: Selector de Método y Botones de Acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: metodo,
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(
                      value: 'efectivo',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_rounded, size: 18, color: Color(0xFF16A34A)),
                          SizedBox(width: 8),
                          Text('Efectivo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'tarjeta_debito',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('T. Débito', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'tarjeta_credito',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.credit_score_rounded, size: 18, color: Color(0xFF9333EA)),
                          SizedBox(width: 8),
                          Text('T. Crédito', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'transferencia',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFFEA580C)),
                          SizedBox(width: 8),
                          Text('Transferencia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) onMetodoCambiado(val);
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                    label: const Text('Restante', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onCompletarRestante,
                  ),
                  if (onEliminar != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Eliminar forma de pago',
                      onPressed: onEliminar,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila Inferior: Campo de Precio a Ancho Completo (NUNCA SE CORTA)
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              prefixText: r'$ ',
              prefixStyle: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              hintText: '0.00',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMetodoPago extends StatelessWidget {
  const _TarjetaMetodoPago({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: seleccionado
          ? color.withValues(alpha: 0.12)
          : colors.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionado ? color : colors.outlineVariant.withValues(alpha: 0.4),
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                seleccionado ? Icons.radio_button_checked : Icons.radio_button_off,
                color: seleccionado ? color : colors.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipMontoRapido extends StatelessWidget {
  const _ChipMontoRapido({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}

