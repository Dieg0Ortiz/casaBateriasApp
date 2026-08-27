import '../../../../core/network/api_exception.dart';
import '../../../../core/network/token_storage.dart';
import '../domain/auth_repository.dart';
import '../domain/login_result.dart';
import '../domain/user_profile.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    AuthRemoteDataSource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? AuthRemoteDataSource(),
        _tokenStorage = tokenStorage ?? TokenStorage.instance;

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  @override
  Future<LoginResult> login(String email, String password) async {
    final result = await _remote.login(email, password);
    await _tokenStorage.saveTokens(result.accessToken, result.refreshToken);
    return result;
  }

  @override
  Future<UserProfile?> restaurarSesion() async {
    final token = await _tokenStorage.accessToken;
    if (token == null || token.isEmpty) return null;

    try {
      return await _remote.me();
    } on ApiException catch (e) {
      // Token vencido o inválido: se limpia la sesión.
      if (e.esNoAutorizado) {
        await _tokenStorage.clear();
      }
      return null;
    } catch (_) {
      // Sin conexión: se deja la sesión guardada pero no se restaura.
      return null;
    }
  }

  @override
  Future<void> logout() => _tokenStorage.clear();
}
