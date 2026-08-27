import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/core/network/api_exception.dart';
import 'package:casabateriaserp/features/catalog/domain/catalog_models.dart';
import 'package:casabateriaserp/features/catalog/domain/catalogo_repository.dart';
import 'package:casabateriaserp/features/catalog/presentation/catalogo_viewmodel.dart';

class _FakeCatalogoRepository implements CatalogoRepository {
  _FakeCatalogoRepository({this.fallarCarga = false, this.fallarAlta = false});

  final bool fallarCarga;
  final bool fallarAlta;

  static const _marca = Marca(id: 'm1', nombre: 'Optima');

  static final _producto = Producto(
    id: 'p1',
    marcaNombre: 'Optima',
    modelo: '750',
    precio: 2300,
    requiereCasco: true,
    codigoBarras: 'CB000000000001',
    codigoBarrasOrigen: 'generado',
    activo: true,
    existencias: const [],
  );

  @override
  Future<List<Marca>> listarMarcas() async {
    if (fallarCarga) throw const ApiException('Error de carga');
    return const [_marca];
  }

  @override
  Future<List<Producto>> listarProductos() async {
    if (fallarCarga) throw const ApiException('Error de carga');
    return [_producto];
  }

  @override
  Future<List<Sucursal>> listarSucursales() async {
    if (fallarCarga) throw const ApiException('Error de carga');
    return const [Sucursal(id: 's1', nombre: 'Norte', esMatriz: true)];
  }

  @override
  Future<Producto> crearProducto(NuevoProducto nuevo) async {
    if (fallarAlta) {
      throw const ApiException('Indica la sucursal donde se recibe el producto');
    }
    return Producto(
      id: 'p2',
      marcaNombre: 'Optima',
      modelo: nuevo.modelo,
      precio: nuevo.precio,
      requiereCasco: nuevo.requiereCasco,
      codigoBarras: 'CB000000000002',
      codigoBarrasOrigen: 'generado',
      activo: true,
      existencias: const [],
    );
  }
}

void main() {
  test('cargar llena marcas, productos y sucursales', () async {
    final vm = CatalogoViewModel(_FakeCatalogoRepository());

    await vm.cargar();

    expect(vm.status, CatalogoStatus.listo);
    expect(vm.marcas.single.nombre, 'Optima');
    expect(vm.productos.single.codigoBarras, 'CB000000000001');
    expect(vm.sucursales.single.nombre, 'Norte');
  });

  test('cargar con error deja el mensaje', () async {
    final vm = CatalogoViewModel(_FakeCatalogoRepository(fallarCarga: true));

    await vm.cargar();

    expect(vm.status, CatalogoStatus.error);
    expect(vm.mensajeError, 'Error de carga');
  });

  test('crearProducto exitoso lo agrega a la lista', () async {
    final vm = CatalogoViewModel(_FakeCatalogoRepository());
    await vm.cargar();

    final creado = await vm.crearProducto(const NuevoProducto(
      marcaId: 'm1',
      modelo: '1000',
      precio: 3100,
      requiereCasco: false,
    ));

    expect(creado?.codigoBarras, 'CB000000000002');
    expect(vm.productos.first.modelo, '1000');
    expect(vm.status, CatalogoStatus.listo);
  });

  test('crearProducto con error del RPC expone el mensaje', () async {
    final vm = CatalogoViewModel(_FakeCatalogoRepository(fallarAlta: true));

    final creado = await vm.crearProducto(const NuevoProducto(
      marcaId: 'm1',
      modelo: '750',
      precio: 2300,
      requiereCasco: true,
    ));

    expect(creado, isNull);
    expect(vm.mensajeError, 'Indica la sucursal donde se recibe el producto');
  });
}
