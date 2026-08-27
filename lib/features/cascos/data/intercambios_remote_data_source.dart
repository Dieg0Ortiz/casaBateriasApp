import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/intercambio_models.dart';

class IntercambiosRemoteDataSource {
  IntercambiosRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<IntercambioCasco>> listarIntercambios() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/cascos/intercambios'),
    );
    return (res ?? [])
        .map((e) => IntercambioCasco.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<IntercambioCasco> obtenerIntercambio(String id) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/api/v1/cascos/intercambios/$id'),
    );
    return IntercambioCasco.fromJson(res!);
  }

  Future<dynamic> registrarIntercambio(RegistrarIntercambioInput input) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/cascos/intercambios',
        data: input.toJson(),
      ),
    );
    return res;
  }

  Future<T?> _pedir<T>(Future<Response<T>> Function() peticion) async {
    try {
      final res = await peticion();
      return res.data;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception(e.message ?? 'Error de conexión');
    }
  }
}
