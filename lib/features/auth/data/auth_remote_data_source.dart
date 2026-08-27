import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/login_result.dart';
import '../domain/user_profile.dart';

/// Acceso a la red para autenticación.
class AuthRemoteDataSource {
  AuthRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<LoginResult> login(String email, String password) async {
    final data = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      ),
    );

    final perfilData = data!['perfil'] as Map<String, dynamic>;

    return LoginResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      perfil: UserProfile.fromJson(perfilData),
    );
  }

  /// Recupera el perfil del usuario con la sesión guardada.
  Future<UserProfile> me() async {
    final data = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/api/v1/auth/me'),
    );
    final perfilData = data!['perfil'] as Map<String, dynamic>;
    return UserProfile.fromJson(perfilData);
  }

  /// Ejecuta la petición y convierte el error de red a [ApiException] para
  /// que los ViewModels puedan atraparla directamente.
  Future<T?> _pedir<T>(Future<Response<T>> Function() peticion) async {
    try {
      final res = await peticion();
      return res.data;
    } on DioException catch (e) {
      throw desenmascararError(e);
    }
  }
}
