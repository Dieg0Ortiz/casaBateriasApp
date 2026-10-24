import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../devoluciones/domain/devolucion_models.dart';
import '../domain/solicitud_models.dart';

/// Solicitudes de autorización que la caja manda al panel.
class AutorizacionesRemoteDataSource {
  AutorizacionesRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<SolicitudAutorizacion> solicitar({
    required TipoSolicitud tipo,
    required String folio,
    required String motivo,
    List<RenglonADevolver>? items,
    String? metodoReembolso,
    String? clienteNombre,
  }) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/autorizaciones',
        data: {
          'tipo': tipo.api,
          'folio': folio.trim(),
          'motivo': motivo.trim(),
          if (items != null) 'items': items.map((i) => i.toJson()).toList(),
          'metodo_reembolso': ?metodoReembolso,
          if (clienteNombre != null && clienteNombre.trim().isNotEmpty)
            'cliente_nombre': clienteNombre.trim(),
        },
      ),
    );
    return SolicitudAutorizacion.fromJson(res ?? const {});
  }

  Future<SolicitudAutorizacion> obtener(String id) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/api/v1/autorizaciones/$id'),
    );
    return SolicitudAutorizacion.fromJson(res ?? const {});
  }

  /// Las que la sucursal pidió hoy, de la más reciente a la más vieja.
  Future<List<SolicitudAutorizacion>> deHoy() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/autorizaciones'),
    );
    return (res ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SolicitudAutorizacion.fromJson)
        .toList();
  }

  Future<SolicitudAutorizacion> retirar(String id) => _accion(id, 'retirar');

  Future<SolicitudAutorizacion> marcarImpresa(String id) => _accion(id, 'impresa');

  Future<SolicitudAutorizacion> _accion(String id, String accion) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>('/api/v1/autorizaciones/$id/$accion'),
    );
    return SolicitudAutorizacion.fromJson(res ?? const {});
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
