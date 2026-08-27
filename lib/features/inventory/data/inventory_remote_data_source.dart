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

  Future<T?> _pedir<T>(Future<Response<T>> Function() peticion) async {
    try {
      final res = await peticion();
      return res.data;
    } on DioException catch (e) {
      throw desenmascararError(e);
    }
  }
}
