import 'catalog_models.dart';

/// Contrato del catálogo. Implementación concreta según red (Dio/API).
abstract class CatalogoRepository {
  Future<List<Marca>> listarMarcas();

  Future<List<Producto>> listarProductos();

  Future<List<Sucursal>> listarSucursales();

  /// Da de alta un producto. Devuelve el producto creado (con su código de
  /// barras generado por el servidor).
  Future<Producto> crearProducto(NuevoProducto nuevo);
}
