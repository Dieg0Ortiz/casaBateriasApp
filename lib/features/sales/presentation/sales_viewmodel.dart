import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';

/// Mensaje que el servidor usa para pedir la decisión de casco cuando el
/// producto lo requiere y no se envió (Sección 3.3).
const kMensajeRequiereCasco = 'Indica si el producto es con casco o sin casco';

class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this._repository);

  final SalesRepository _repository;

  List<LineaVenta> _lineas = [];
  LineaVenta? _pendienteCasco;
  bool _registrando = false;
  String? _mensajeError;
  VentaResultado? _ultimaVenta;

  List<LineaVenta> get lineas => List.unmodifiable(_lineas);
  LineaVenta? get pendienteCasco => _pendienteCasco;
  bool get registrando => _registrando;
  String? get mensajeError => _mensajeError;
  VentaResultado? get ultimaVenta => _ultimaVenta;

  double get total =>
      _lineas.fold(0.0, (suma, linea) => suma + linea.importe);

  /// Monto total acumulado en comisiones por baterías vendidas sin casco
  double get totalComisionesCasco =>
      _lineas.fold(0.0, (suma, linea) => suma + (linea.comisionUnitariaEfectiva * linea.cantidad));

  int get cantidadArticulos =>
      _lineas.fold(0, (suma, linea) => suma + linea.cantidad);

  /// Agrega un artículo al carrito. Si requiere casco y aún no se decide,
  /// queda como [pendienteCasco] para que la interfaz pregunte
  /// "¿con casco o sin casco?" antes de agregarlo.
  void agregar({
    required String? productoId,
    required String codigoBarras,
    required String modelo,
    required double precio,
    required bool requiereCasco,
    bool busquedaManual = false,
    String? marca,
    String tipoPrecio = 'default',
    double? precioDefault,
    double? precio2,
    double? precio3,
    double? comisionCasco,
    String? nombreCliente,
    String? telefonoCliente,
  }) {
    _mensajeError = null;
    final linea = LineaVenta(
      productoId: productoId,
      codigoBarras: codigoBarras,
      modelo: modelo,
      marca: marca,
      precio: precio,
      requiereCasco: requiereCasco,
      cantidad: 1,
      busquedaManual: busquedaManual,
      tipoPrecio: tipoPrecio,
      precioDefault: precioDefault ?? precio,
      precio2: precio2,
      precio3: precio3,
      comisionCasco: comisionCasco,
      nombreCliente: nombreCliente,
      telefonoCliente: telefonoCliente,
    );

    if (requiereCasco) {
      _pendienteCasco = linea;
      notifyListeners();
      return;
    }
    _agregarLinea(linea);
  }

  /// Resuelve la pregunta de casco pendiente y agrega la línea al carrito.
  void resolverCasco(bool conCasco) {
    final pendiente = _pendienteCasco;
    if (pendiente == null) return;
    _pendienteCasco = null;
    _agregarLinea(pendiente.copyWith(conCasco: conCasco));
  }

  /// Descarta la pregunta de casco sin agregar el artículo.
  void cancelarCasco() {
    _pendienteCasco = null;
    notifyListeners();
  }

  void _agregarLinea(LineaVenta linea) {
    final existente = _lineas.indexWhere(
      (l) =>
          l.productoId == linea.productoId &&
          l.conCasco == linea.conCasco &&
          l.tipoPrecio == linea.tipoPrecio,
    );
    if (existente >= 0) {
      final actual = _lineas[existente];
      _lineas[existente] = actual.copyWith(cantidad: actual.cantidad + 1);
    } else {
      _lineas = [..._lineas, linea];
    }
    notifyListeners();
  }

  void cambiarTipoPrecio(int index, String nuevoTipoPrecio, {double? precioPersonalizado}) {
    if (index < 0 || index >= _lineas.length) return;
    final linea = _lineas[index];
    double nuevoPrecio = linea.precioDefault ?? linea.precio;
    if (nuevoTipoPrecio == 'precio_especial' && precioPersonalizado != null) {
      nuevoPrecio = precioPersonalizado;
    } else if (nuevoTipoPrecio == 'precio_2' && linea.precio2 != null) {
      nuevoPrecio = linea.precio2!;
    } else if (nuevoTipoPrecio == 'precio_3' && linea.precio3 != null) {
      nuevoPrecio = linea.precio3!;
    }

    _lineas[index] = linea.copyWith(
      tipoPrecio: nuevoTipoPrecio,
      precio: nuevoPrecio,
    );
    notifyListeners();
  }

  void incrementarEn(int index) {
    _mensajeError = null;
    if (index < 0 || index >= _lineas.length) return;
    final actual = _lineas[index];
    _lineas[index] = actual.copyWith(cantidad: actual.cantidad + 1);
    notifyListeners();
  }

  void decrementarEn(int index) {
    _mensajeError = null;
    if (index < 0 || index >= _lineas.length) return;
    final actual = _lineas[index];
    if (actual.cantidad <= 1) {
      _lineas = [..._lineas]..removeAt(index);
    } else {
      _lineas[index] = actual.copyWith(cantidad: actual.cantidad - 1);
    }
    notifyListeners();
  }

  void quitarEn(int index) {
    _mensajeError = null;
    if (index < 0 || index >= _lineas.length) return;
    _lineas = [..._lineas]..removeAt(index);
    notifyListeners();
  }

  void incrementar(String? productoId) {
    _mensajeError = null;
    final idx = _lineas.indexWhere((l) => l.productoId == productoId);
    if (idx < 0) return;
    incrementarEn(idx);
  }

  void decrementar(String? productoId) {
    _mensajeError = null;
    final idx = _lineas.indexWhere((l) => l.productoId == productoId);
    if (idx < 0) return;
    decrementarEn(idx);
  }

  void quitar(String? productoId) {
    _mensajeError = null;
    _lineas = _lineas.where((l) => l.productoId != productoId).toList();
    notifyListeners();
  }

  /// Registra la venta en el servidor (precio, stock y casco los valida el
  /// RPC). Devuelve la venta creada o null si hubo error (el detalle queda
  /// en [mensajeError] o en [pendienteCasco] si falta decidir el casco).
  /// Si [corteCajaId] está presente, la venta queda ligada al corte abierto
  /// para que el monto esperado de la caja incluya su total (Fase 7).
  Future<VentaResultado?> registrar({
    required String sucursalId,
    String? corteCajaId,
    String metodoPago = 'efectivo',
    List<PagoParcial>? desglosePago,
    String? empresaCreditoId,
    String? creditoRecibidoPor,
    String? creditoVehiculoPlacas,
    String? creditoFolioVale,
  }) async {
    _mensajeError = null;
    _ultimaVenta = null;

    // Seguridad: ninguna línea con casco sin decidir debe llegar al RPC.
    final sinCasco = _lineas.where(
      (l) => l.requiereCasco && l.conCasco == null,
    );
    if (sinCasco.isNotEmpty) {
      _pendienteCasco = sinCasco.first;
      notifyListeners();
      return null;
    }

    _registrando = true;
    notifyListeners();
    try {
      final venta = await _repository.registrarVenta(
        sucursalId: sucursalId,
        items: _lineas,
        corteCajaId: corteCajaId,
        metodoPago: metodoPago,
        desglosePago: desglosePago,
        empresaCreditoId: empresaCreditoId,
        creditoRecibidoPor: creditoRecibidoPor,
        creditoVehiculoPlacas: creditoVehiculoPlacas,
        creditoFolioVale: creditoFolioVale,
      );
      _lineas = [];
      _ultimaVenta = venta;
      _registrando = false;
      notifyListeners();
      return venta;
    } on ApiException catch (e) {
      _registrando = false;
      if (e.message.contains(kMensajeRequiereCasco)) {
        // El RPC pide la decisión: volver a preguntar por la primera línea
        // con casco que no tenga decisión.
        final falta = _lineas.where(
          (l) => l.requiereCasco && l.conCasco == null,
        );
        if (falta.isNotEmpty) {
          _pendienteCasco = falta.first;
        } else {
          _mensajeError = e.message;
        }
      } else {
        _mensajeError = e.message;
      }
      notifyListeners();
      return null;
    } catch (_) {
      _registrando = false;
      _mensajeError = 'No se pudo registrar la venta. Intenta de nuevo.';
      notifyListeners();
      return null;
    }
  }

  void limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }
}
