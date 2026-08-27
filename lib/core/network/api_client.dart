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
/// desde almacenamiento seguro y traduce errores HTTP a [ApiException].
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

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
          final status = e.response?.statusCode;
          final msg = _messageFromError(e);
          handler.next(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              error: ApiException(
                msg,
                statusCode: status,
                tipo: status == 401
                    ? 'no_autorizado'
                    : status == 403
                        ? 'prohibido'
                        : 'error',
              ),
            ),
          );
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

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
