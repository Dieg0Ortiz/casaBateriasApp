import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../domain/purchase_models.dart';

class PurchasesRemoteDataSource {
  PurchasesRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<Compra>> listarCompras() async {
    debugPrint('[PurchasesDS] Solicitando GET /api/v1/purchases');
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/purchases'),
    );
    debugPrint('[PurchasesDS] Recibidos ${res?.length ?? 0} registros: $res');
    return (res ?? [])
        .map((e) => Compra.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CompraDetalle> obtenerCompra(String id) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/api/v1/purchases/$id'),
    );
    return CompraDetalle.fromJson(res!);
  }

  Future<CompraDetalle> registrarCompra(RegistrarCompraInput input) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/purchases',
        data: input.toJson(),
      ),
    );
    return CompraDetalle.fromJson(res!);
  }

  Future<List<Proveedor>> listarProveedores() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/purchases/providers'),
    );
    return (res ?? [])
        .map((e) => Proveedor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Proveedor> crearProveedor(Proveedor proveedor) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/purchases/providers',
        data: proveedor.toJson(),
      ),
    );
    return Proveedor.fromJson(res!);
  }

  Future<T?> _pedir<T>(Future<Response<T>> Function() peticion) async {
    try {
      final res = await peticion();
      return res.data;
    } on DioException catch (e) {
      debugPrint('[PurchasesDS ERROR] ${e.message} (status ${e.response?.statusCode})');
      throw desenmascararError(e);
    } catch (e) {
      debugPrint('[PurchasesDS ERROR GENERAL] $e');
      rethrow;
    }
  }
}
