import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/cash_models.dart';

/// Acceso a la red para apertura/cierre de caja.
class CashRemoteDataSource {
  CashRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<CajaActiva> obtenerActiva() async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/api/v1/cash/activa'),
    );
    return CajaActiva.fromJson(res!);
  }

  Future<List<CorteCaja>> historial() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/cash'),
    );
    return (res ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CorteCaja.fromJson)
        .toList();
  }

  Future<CorteCaja> abrir({required double montoInicial}) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/cash/abrir',
        data: {'monto_inicial': montoInicial},
      ),
    );
    return CorteCaja.fromJson(res!);
  }

  Future<CorteCaja> cerrar({
    required String corteId,
    required double montoFinal,
  }) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/cash/cerrar',
        data: {'corte_id': corteId, 'monto_final': montoFinal},
      ),
    );
    return CorteCaja.fromJson(res!);
  }

  Future<ResumenCorte> resumen(String corteId) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/api/v1/cash/$corteId/resumen'),
    );
    return ResumenCorte.fromJson(res ?? const {});
  }

  Future<T?> _pedir<T>(Future<Response<T>> Function() peticion) async {
    try {
      final res = await peticion();
      return res.data;
    } on DioException catch (e) {
      throw desenmascararError(e);
    }
  }
}
