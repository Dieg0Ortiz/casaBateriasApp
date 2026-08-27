import 'login_result.dart';
import 'user_profile.dart';

/// Contrato de autenticación. La implementación concreta depende de la red
/// (inversión de dependencia: el ViewModel no conoce HTTP).
abstract class AuthRepository {
  Future<LoginResult> login(String email, String password);

  /// Restaura la sesión guardada al arrancar la app.
  /// Devuelve el perfil si hay sesión válida; null si no hay sesión
  /// o si el token ya no es válido.
  Future<UserProfile?> restaurarSesion();

  Future<void> logout();
}
