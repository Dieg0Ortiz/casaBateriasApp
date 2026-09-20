import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'token_storage.dart';
import '../config/app_config.dart';

/// Convierte un error de red ([DioException]) en una [ApiException] legible.
/// Dio siempre entrega el error como [DioException] aunque el interceptor lo
/// envuelva; aquí se extrae la [ApiException] que el interceptor incrustó.
ApiException desenmascararError(Object error) {
  if (error is ApiException) return error;
  if (error is DioException && error.error is ApiException) {
    return error.error! as ApiException;
  }
  return const ApiException('Ocurrió un error. Intenta de nuevo.');
}

/// Cliente HTTP único del API. Interceptor que agrega el token de sesión
/// desde almacenamiento seguro, renueva la sesión cuando el token vence y
/// traduce errores HTTP a [ApiException].
class ApiClient {
  ApiClient._internal() {
    final opciones = BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    );
    _dio = Dio(opciones);
    // Cliente aparte para renovar: si usara el principal, el 401 del refresh
    // volvería a disparar el interceptor.
    _dioRenovacion = Dio(opciones);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.instance.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // El access token de Supabase dura una hora. Al vencer, se renueva
          // con el refresh token y se repite la petición, para que el cajero
          // no tenga que cerrar la app y volver a entrar.
          if (_debeRenovar(e)) {
            final renovada = await _renovarSesion();
            if (renovada) {
              try {
                final respuesta = await _repetir(e.requestOptions);
                return handler.resolve(respuesta);
              } on DioException catch (errorRepeticion) {
                return handler.next(_traducir(errorRepeticion));
              }
            }
          }
          handler.next(_traducir(e));
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  late final Dio _dioRenovacion;

  /// Renovación en curso, para que varias peticiones que fallan a la vez
  /// compartan un solo intento.
  Future<bool>? _renovacionEnCurso;

  /// Se invoca cuando el refresh token ya no sirve y hay que volver al login.
  void Function()? onSesionExpirada;

  Dio get dio => _dio;

  bool _debeRenovar(DioException e) {
    if (e.response?.statusCode != 401) return false;
    if (e.requestOptions.extra['reintentado'] == true) return false;
    final ruta = e.requestOptions.path;
    return !ruta.contains('/auth/login') && !ruta.contains('/auth/refresh');
  }

  Future<bool> _renovarSesion() {
    return _renovacionEnCurso ??= _pedirTokenNuevo()
        .whenComplete(() => _renovacionEnCurso = null);
  }

  Future<bool> _pedirTokenNuevo() async {
    final refresh = await TokenStorage.instance.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final res = await _dioRenovacion.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final access = res.data?['access_token'] as String?;
      final nuevoRefresh = res.data?['refresh_token'] as String?;
      if (access == null ||
          access.isEmpty ||
          nuevoRefresh == null ||
          nuevoRefresh.isEmpty) {
        return false;
      }
      await TokenStorage.instance.saveTokens(access, nuevoRefresh);
      return true;
    } on DioException {
      // El refresh token también venció o fue revocado: toca iniciar sesión.
      await TokenStorage.instance.clear();
      onSesionExpirada?.call();
      return false;
    }
  }

  Future<Response<dynamic>> _repetir(RequestOptions original) {
    original.extra = {...original.extra, 'reintentado': true};
    // Pasa de nuevo por onRequest, que adjunta el token ya renovado.
    return _dio.fetch<dynamic>(original);
  }

  DioException _traducir(DioException e) {
    final status = e.response?.statusCode;
    return DioException(
      requestOptions: e.requestOptions,
      response: e.response,
      error: ApiException(
        _messageFromError(e),
        statusCode: status,
        tipo: status == 401
            ? 'no_autorizado'
            : status == 403
                ? 'prohibido'
                : 'error',
      ),
    );
  }

  String _messageFromError(DioException e) {
    if (e.response == null) {
      return 'Sin conexión con el servidor. Intenta de nuevo.';
    }
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      return message is List ? message.join('\n') : message.toString();
    }
    return 'Ocurrió un error. Intenta de nuevo.';
  }
}
