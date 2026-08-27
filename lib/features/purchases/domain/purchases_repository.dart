import 'purchase_models.dart';

abstract class PurchasesRepository {
  Future<List<Compra>> listarCompras();
  Future<CompraDetalle> obtenerCompra(String id);
  Future<CompraDetalle> registrarCompra(RegistrarCompraInput input);
  Future<List<Proveedor>> listarProveedores();
  Future<Proveedor> crearProveedor(Proveedor proveedor);
}
