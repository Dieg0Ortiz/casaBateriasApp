import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/inventory_models.dart';

/// Acceso a la red para el inventario.
class InventoryRemoteDataSource {
  InventoryRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<ItemInventario>> listarInventario({String? sucursalId}) async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>(
        '/api/v1/inventory',
        queryParameters: {
          if (sucursalId != null && sucursalId.isNotEmpty)
            'sucursal_id': sucursalId,
        },
      ),
    );
    return (res ?? [])
        .map((e) => ItemInventario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mueve [cantidad] pilas de un modelo de una sucursal a otra: el
  /// servidor las descuenta del origen y las da de alta en el destino en
  /// una sola operación. Solo administrador.
  Future<void> transferir({
    required String productoId,
    required String origenId,
    required String destinoId,
    required int cantidad,
    String? nota,
  }) async {
    await _pedir<dynamic>(
      () => _dio.post<dynamic>(
        '/api/v1/inventory/transferencias',
        data: {
          'producto_id': productoId,
          'sucursal_origen_id': origenId,
          'sucursal_destino_id': destinoId,
          'cantidad': cantidad,
          if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
        },
      ),
    );
  }

  /// Historial de traspasos, el más reciente primero. Solo administrador.
  Future<List<Traspaso>> listarTraspasos() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/inventory/transferencias'),
    );
    return (res ?? [])
        .map((e) => Traspaso.fromJson(e as Map<String, dynamic>))
        .toList();
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
