import '../domain/catalog_models.dart';
import '../domain/catalogo_repository.dart';
import 'catalogo_remote_data_source.dart';

class CatalogoRepositoryImpl implements CatalogoRepository {
  CatalogoRepositoryImpl({CatalogoRemoteDataSource? remote})
      : _remote = remote ?? CatalogoRemoteDataSource();

  final CatalogoRemoteDataSource _remote;

  @override
  Future<List<Marca>> listarMarcas() => _remote.listarMarcas();

  @override
  Future<List<Producto>> listarProductos() => _remote.listarProductos();

  @override
  Future<List<Sucursal>> listarSucursales() => _remote.listarSucursales();

  @override
  Future<Producto> crearProducto(NuevoProducto nuevo) =>
      _remote.crearProducto(nuevo);
}
