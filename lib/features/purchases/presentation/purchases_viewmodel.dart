import 'package:flutter/foundation.dart';
import '../domain/purchase_models.dart';
import '../domain/purchases_repository.dart';

class PurchasesViewModel extends ChangeNotifier {
  PurchasesViewModel(this._repository);

  final PurchasesRepository _repository;

  List<Compra> _compras = const [];
  List<Proveedor> _proveedores = const [];
  CompraDetalle? _compraSeleccionada;
  bool _cargando = false;
  bool _guardando = false;
  String? _error;

  List<Compra> get compras => _compras;
  List<Proveedor> get proveedores => _proveedores;
  CompraDetalle? get compraSeleccionada => _compraSeleccionada;
  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;

  double get totalInvertido => _compras.fold(
        0.0,
        (sum, c) => sum + (c.esCompletada ? c.total : 0.0),
      );

  Future<void> cargarCompras() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _compras = await _repository.listarCompras();
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cargarProveedores() async {
    try {
      _proveedores = await _repository.listarProveedores();
      notifyListeners();
    } catch (_) {
      // Proveedores es opcional para la captura
    }
  }

  Future<CompraDetalle?> obtenerDetalle(String id) async {
    try {
      final detalle = await _repository.obtenerCompra(id);
      _compraSeleccionada = detalle;
      notifyListeners();
      return detalle;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> registrarCompra(RegistrarCompraInput input) async {
    _guardando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.registrarCompra(input);
      _guardando = false;
      await cargarCompras();
      return true;
    } catch (e) {
      _error = e.toString();
      _guardando = false;
      notifyListeners();
      return false;
    }
  }

  Future<Proveedor?> crearProveedor({
    required String nombre,
    String? contacto,
    String? telefono,
    String? email,
  }) async {
    try {
      final nuevo = await _repository.crearProveedor(
        Proveedor(
          id: '',
          nombre: nombre,
          contacto: contacto,
          telefono: telefono,
          email: email,
        ),
      );
      await cargarProveedores();
      return nuevo;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
