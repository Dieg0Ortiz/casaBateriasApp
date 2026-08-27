import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/credito_models.dart';

class CreditosRemoteDataSource {
  CreditosRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<EmpresaCredito>> getEmpresas({bool soloActivas = false}) async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>(
        '/api/v1/creditos/empresas',
        queryParameters: {
          if (soloActivas) 'activas': 'true',
        },
      ),
    );
    if (res == null) return [];
    return res.map((e) => EmpresaCredito.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CreditoVenta>> getVentas({String? estado, String? sucursalId}) async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>(
        '/api/v1/creditos/ventas',
        queryParameters: {
          if (estado != null && estado.isNotEmpty) 'estado': estado,
          if (sucursalId != null && sucursalId.isNotEmpty) 'sucursal_id': sucursalId,
        },
      ),
    );
    if (res == null) return [];
    return res.map((e) => CreditoVenta.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EstadoCuentaEmpresa> getEstadoCuenta(String empresaId) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/api/v1/creditos/empresas/$empresaId/estado-cuenta',
      ),
    );
    return EstadoCuentaEmpresa.fromJson(res!);
  }

  Future<void> registrarAbono({
    required String empresaId,
    required double monto,
    required String metodoPago,
    String? creditoVentaId,
    String? sucursalId,
    String? referencia,
    String? notas,
  }) async {
    await _pedir<dynamic>(
      () => _dio.post(
        '/api/v1/creditos/abonos',
        data: {
          'empresa_id': empresaId,
          'monto': monto,
          'metodo_pago': metodoPago,
          if (creditoVentaId != null) 'credito_venta_id': creditoVentaId,
          if (sucursalId != null) 'sucursal_id': sucursalId,
          if (referencia != null && referencia.isNotEmpty) 'referencia': referencia,
          if (notas != null && notas.isNotEmpty) 'notas': notas,
        },
      ),
    );
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
