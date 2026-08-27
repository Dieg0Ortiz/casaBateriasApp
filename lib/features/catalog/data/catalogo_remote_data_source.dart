import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/catalog_models.dart';

/// Acceso a la red para el catálogo.
class CatalogoRemoteDataSource {
  CatalogoRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<Marca>> listarMarcas() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/catalog/marcas'),
    );
    return (res ?? [])
        .map((e) => Marca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Producto>> listarProductos() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/catalog/productos'),
    );
    return (res ?? [])
        .map((e) => Producto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Sucursal>> listarSucursales() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/catalog/sucursales'),
    );
    return (res ?? [])
        .map((e) => Sucursal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Producto> crearProducto(NuevoProducto nuevo) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/catalog/productos',
        data: nuevo.toJson(),
      ),
    );
    return Producto.fromJson(res!);
  }

  /// Ejecuta la petición y convierte el error de red a [ApiException] para
  /// que los ViewModels puedan atraparla directamente.
  Future<T?> _pedir<T>(Future<Response<T>> Function() peticion) async {
    try {
      final res = await peticion();
      return res.data;
    } on DioException catch (e) {
      throw desenmascararError(e);
    }
  }
}
