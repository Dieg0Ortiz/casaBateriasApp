import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../domain/cash_models.dart';
import '../domain/cash_repository.dart';

/// ViewModel de caja: expone la caja activa, permite abrir/cerrar y el
/// historial de cortes. La UI solo observa el estado.
class CashViewModel extends ChangeNotifier {
  CashViewModel(this._repository);

  final CashRepository _repository;

  CajaActiva? _cajaActiva;
  List<CorteCaja> _historial = [];
  bool _cargando = false;
  bool _procesando = false;
  String? _mensajeError;
  CorteCaja? _ultimoCierre;

  CajaActiva? get cajaActiva => _cajaActiva;
  List<CorteCaja> get historial => List.unmodifiable(_historial);
  bool get cargando => _cargando;
  bool get procesando => _procesando;
  String? get mensajeError => _mensajeError;
  CorteCaja? get ultimoCierre => _ultimoCierre;

  /// Carga la caja activa de la sucursal y el historial de cortes.
  Future<void> cargar() async {
    _cargando = true;
    _mensajeError = null;
    notifyListeners();
    try {
      _cajaActiva = await _repository.obtenerActiva();
      await _cargarHistorial();
      _cargando = false;
      notifyListeners();
    } on ApiException catch (e) {
      _cargando = false;
      _mensajeError = e.message;
      notifyListeners();
    } catch (_) {
      _cargando = false;
      _mensajeError = 'No se pudo consultar la caja. Intenta de nuevo.';
      notifyListeners();
    }
  }

  /// Abre la caja con el efectivo inicial. Recarga el estado al terminar.
  Future<bool> abrir(double montoInicial) async {
    _mensajeError = null;
    _ultimoCierre = null;
    _procesando = true;
    notifyListeners();
    try {
      final corte = await _repository.abrir(montoInicial: montoInicial);
      _cajaActiva = CajaActiva(
        corte: corte,
        totalVentas: 0,
        montoEsperado: corte.montoInicial,
      );
      _procesando = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _procesando = false;
      _mensajeError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _procesando = false;
      _mensajeError = 'No se pudo abrir la caja. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  /// Cierra el corte activo. En éxito deja [ultimoCierre] con los montos
  /// esperado/reportado y la diferencia calculada por el servidor.
  Future<bool> cerrar(double montoFinal) async {
    final corteId = _cajaActiva?.corte?.id;
    if (corteId == null) return false;

    _mensajeError = null;
    _procesando = true;
    notifyListeners();
    try {
      final corte = await _repository.cerrar(
        corteId: corteId,
        montoFinal: montoFinal,
      );
      _ultimoCierre = corte;
      _cajaActiva = null;
      await _cargarHistorial();
      _procesando = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _procesando = false;
      _mensajeError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _procesando = false;
      _mensajeError = 'No se pudo cerrar la caja. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  /// Resumen de un corte del historial, para verlo o reimprimirlo. Lanza
  /// [ApiException] si el servidor lo rechaza.
  Future<ResumenCorte> resumenDe(String corteId) => _repository.resumen(corteId);

  Future<void> _cargarHistorial() async {
    try {
      _historial = await _repository.historial();
    } catch (_) {
      _historial = [];
    }
  }

  void limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }
}
