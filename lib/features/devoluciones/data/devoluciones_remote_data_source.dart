import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/devolucion_models.dart';

/// Acceso a la red para las devoluciones de dinero (folio DEV).
class DevolucionesRemoteDataSource {
  DevolucionesRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  /// Depósitos de casco pendientes de la sucursal; [folio] filtra por venta.
  Future<List<DepositoPendiente>> depositosPendientes({String? folio}) async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>(
        '/api/v1/devoluciones/depositos',
        queryParameters: {
          if (folio != null && folio.trim().isNotEmpty) 'folio': folio.trim(),
        },
      ),
    );
    return (res ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DepositoPendiente.fromJson)
        .toList();
  }

  /// El cliente trajo el casco: se le devuelve el depósito.
  Future<Devolucion> devolverDeposito({
    required String cascoId,
    required double monto,
    required String metodoReembolso,
    String? notas,
  }) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/devoluciones/deposito',
        data: {
          'casco_id': cascoId,
          'monto': monto,
          'metodo_reembolso': metodoReembolso,
          if (notas != null && notas.trim().isNotEmpty) 'notas': notas.trim(),
        },
      ),
    );
    return Devolucion.fromJson(res ?? const {});
  }

  /// Venta por folio con las piezas que todavía se pueden devolver.
  Future<VentaDevolucion> ventaPorFolio(String folio) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/api/v1/devoluciones/venta',
        queryParameters: {'folio': folio.trim()},
      ),
    );
    return VentaDevolucion.fromJson(res ?? const {});
  }

  /// El cliente regresa baterías; autoriza un administrador con su clave.
  Future<Devolucion> devolverBateria({
    required String ventaId,
    required List<RenglonADevolver> items,
    required String motivo,
    required String metodoReembolso,
    required String email,
    required String password,
    String? clienteNombre,
  }) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/devoluciones/bateria',
        data: {
          'venta_id': ventaId,
          'items': items.map((i) => i.toJson()).toList(),
          'motivo': motivo.trim(),
          'metodo_reembolso': metodoReembolso,
          if (clienteNombre != null && clienteNombre.trim().isNotEmpty)
            'cliente_nombre': clienteNombre.trim(),
          'email': email.trim(),
          'password': password,
        },
      ),
    );
    return Devolucion.fromJson(res ?? const {});
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
