import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../domain/catalog_models.dart';
import '../domain/catalogo_repository.dart';

enum CatalogoStatus { inicial, cargando, listo, error }

class CatalogoViewModel extends ChangeNotifier {
  CatalogoViewModel(this._repository);

  final CatalogoRepository _repository;

  CatalogoStatus _status = CatalogoStatus.inicial;
  List<Marca> _marcas = [];
  List<Producto> _productos = [];
  List<Sucursal> _sucursales = [];
  String? _mensajeError;
  bool _creando = false;

  CatalogoStatus get status => _status;
  List<Marca> get marcas => _marcas;
  List<Producto> get productos => _productos;
  List<Sucursal> get sucursales => _sucursales;
  String? get mensajeError => _mensajeError;
  bool get cargando => _status == CatalogoStatus.cargando;
  bool get creando => _creando;

  Future<void> cargar() async {
    _status = CatalogoStatus.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final resultados = await Future.wait<Object>([
        _repository.listarProductos(),
        _repository.listarMarcas(),
        _repository.listarSucursales(),
      ]);
      _productos = resultados[0] as List<Producto>;
      _marcas = resultados[1] as List<Marca>;
      _sucursales = resultados[2] as List<Sucursal>;
      _status = CatalogoStatus.listo;
      notifyListeners();
    } on ApiException catch (e) {
      _status = CatalogoStatus.error;
      _mensajeError = e.message;
      notifyListeners();
    } catch (_) {
      _status = CatalogoStatus.error;
      _mensajeError = 'No se pudo cargar el catálogo. Intenta de nuevo.';
      notifyListeners();
    }
  }

  /// Devuelve el producto creado (con código de barras generado) o null si
  /// hubo error (el mensaje queda en [mensajeError]).
  Future<Producto?> crearProducto(NuevoProducto nuevo) async {
    _creando = true;
    _mensajeError = null;
    notifyListeners();

    try {
      final creado = await _repository.crearProducto(nuevo);
      _productos = [creado, ..._productos];
      _creando = false;
      notifyListeners();
      return creado;
    } on ApiException catch (e) {
      _creando = false;
      _mensajeError = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _creando = false;
      _mensajeError = 'No se pudo dar de alta el producto. Intenta de nuevo.';
      notifyListeners();
      return null;
    }
  }

  void limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }
}
