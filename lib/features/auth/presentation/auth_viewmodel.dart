import 'package:flutter/foundation.dart';
import '../domain/auth_repository.dart';
import '../domain/login_result.dart';
import '../domain/user_profile.dart';
import '../../../../core/network/api_exception.dart';

enum AuthStatus { inicializando, desconectado, cargando, autenticado, error }

/// ViewModel del login. Expone estado y acciones; la UI solo observa.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.inicializando;
  UserProfile? _usuario;
  String? _mensajeError;

  AuthStatus get status => _status;
  UserProfile? get usuario => _usuario;
  String? get mensajeError => _mensajeError;
  bool get cargando => _status == AuthStatus.cargando;

  /// Restaura la sesión guardada al arrancar la app.
  Future<void> restaurarSesion() async {
    _status = AuthStatus.inicializando;
    notifyListeners();

    final perfil = await _repository.restaurarSesion();
    if (perfil != null) {
      _usuario = perfil;
      _status = AuthStatus.autenticado;
    } else {
      _usuario = null;
      _status = AuthStatus.desconectado;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final LoginResult result = await _repository.login(email, password);
      _usuario = result.perfil;
      _status = AuthStatus.autenticado;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _mensajeError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.error;
      _mensajeError = 'Ocurrió un error inesperado. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _usuario = null;
    _status = AuthStatus.desconectado;
    notifyListeners();
  }
}
