import '../domain/purchase_models.dart';
import '../domain/purchases_repository.dart';
import 'purchases_remote_data_source.dart';

class PurchasesRepositoryImpl implements PurchasesRepository {
  PurchasesRepositoryImpl({PurchasesRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? PurchasesRemoteDataSource();

  final PurchasesRemoteDataSource _dataSource;

  @override
  Future<List<Compra>> listarCompras() => _dataSource.listarCompras();

  @override
  Future<CompraDetalle> obtenerCompra(String id) => _dataSource.obtenerCompra(id);

  @override
  Future<CompraDetalle> registrarCompra(RegistrarCompraInput input) =>
      _dataSource.registrarCompra(input);

  @override
  Future<List<Proveedor>> listarProveedores() => _dataSource.listarProveedores();

  @override
  Future<Proveedor> crearProveedor(Proveedor proveedor) =>
      _dataSource.crearProveedor(proveedor);
}
