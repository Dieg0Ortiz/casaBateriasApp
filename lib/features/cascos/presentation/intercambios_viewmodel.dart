import 'package:flutter/material.dart';
import '../domain/intercambio_models.dart';
import '../domain/intercambios_repository.dart';

class IntercambiosViewModel extends ChangeNotifier {
  IntercambiosViewModel(this._repository);

  final IntercambiosRepository _repository;

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _error;
  String? get error => _error;

  List<IntercambioCasco> _intercambios = [];
  List<IntercambioCasco> get intercambios => _intercambios;

  String _filtro = '';
  String get filtro => _filtro;

  List<IntercambioCasco> get intercambiosFiltrados {
    if (_filtro.trim().isEmpty) return _intercambios;
    final q = _filtro.toLowerCase();
    return _intercambios.where((i) {
      final matchFolio = i.folio.toLowerCase().contains(q);
      final matchCliente = (i.clienteNombre ?? '').toLowerCase().contains(q);
      final matchSucursal = (i.sucursalNombre ?? '').toLowerCase().contains(q);
      final matchItems = i.items.any((it) =>
          (it.cascoSalienteModelo ?? '').toLowerCase().contains(q) ||
          (it.cascoEntranteModelo ?? '').toLowerCase().contains(q));
      return matchFolio || matchCliente || matchSucursal || matchItems;
    }).toList();
  }

  double get totalGanancia =>
      _intercambios.fold(0.0, (acc, i) => acc + i.montoCobrado);

  void setFiltro(String valor) {
    _filtro = valor;
    notifyListeners();
  }

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _intercambios = await _repository.listarIntercambios();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> registrarIntercambio(RegistrarIntercambioInput input) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.registrarIntercambio(input);
      await cargar();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _cargando = false;
      notifyListeners();
      return false;
    }
  }
}
