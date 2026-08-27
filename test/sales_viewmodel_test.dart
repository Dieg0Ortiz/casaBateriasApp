import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/core/network/api_exception.dart';
import 'package:casabateriaserp/features/sales/domain/sales_models.dart';
import 'package:casabateriaserp/features/sales/domain/sales_repository.dart';
import 'package:casabateriaserp/features/sales/presentation/sales_viewmodel.dart';

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository({this.error});

  final String? error;
  final List<String> folios = [];
  String? ultimoCorteId;
  String? ultimoMetodoPago;

  @override
  Future<VentaResultado> registrarVenta({
    required String sucursalId,
    required List<LineaVenta> items,
    String? corteCajaId,
    String metodoPago = 'efectivo',
    List<PagoParcial>? desglosePago,
    String? empresaCreditoId,
    String? creditoRecibidoPor,
    String? creditoVehiculoPlacas,
    String? creditoFolioVale,
  }) async {
    if (error != null) throw ApiException(error!);
    ultimoCorteId = corteCajaId;
    ultimoMetodoPago = metodoPago;
    final total = items.fold(0.0, (s, l) => s + l.importe);
    folios.add('FOLIO-${folios.length + 1}');
    return VentaResultado(
      id: 'v-${folios.length}',
      folio: folios.last,
      sucursalId: sucursalId,
      total: total,
      estado: 'completada',
      creadaEn: DateTime(2026, 1, 1),
      metodoPago: metodoPago,
    );
  }
}

void main() {
  test('agregar producto sin casco lo deja en el carrito', () {
    final vm = SalesViewModel(_FakeSalesRepository());

    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    expect(vm.lineas, hasLength(1));
    expect(vm.lineas.first.modelo, 'Optima 750');
    expect(vm.total, 2300);
    expect(vm.pendienteCasco, isNull);
  });

  test('agregar producto con casco queda pendiente de decisión', () {
    final vm = SalesViewModel(_FakeSalesRepository());

    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: true,
    );

    expect(vm.lineas, isEmpty);
    expect(vm.pendienteCasco?.modelo, 'Optima 750');
  });

  test('resolverCasco(true) agrega la línea con casco', () {
    final vm = SalesViewModel(_FakeSalesRepository());

    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: true,
    );
    vm.resolverCasco(true);

    expect(vm.lineas.single.conCasco, isTrue);
    expect(vm.pendienteCasco, isNull);
  });

  test('resolverCasco(false) agrega la línea sin casco', () {
    final vm = SalesViewModel(_FakeSalesRepository());

    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: true,
    );
    vm.resolverCasco(false);

    expect(vm.lineas.single.conCasco, isFalse);
  });

  test('cancelarCasco descarta sin agregar', () {
    final vm = SalesViewModel(_FakeSalesRepository());

    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: true,
    );
    vm.cancelarCasco();

    expect(vm.lineas, isEmpty);
    expect(vm.pendienteCasco, isNull);
  });

  test('agregar dos veces el mismo producto suma cantidades', () {
    final vm = SalesViewModel(_FakeSalesRepository());
    void agregar() => vm.agregar(
          productoId: 'p1',
          codigoBarras: 'CB1',
          modelo: 'Optima 750',
          precio: 2300,
          requiereCasco: false,
        );

    agregar();
    agregar();

    expect(vm.lineas.single.cantidad, 2);
    expect(vm.total, 4600);
  });

  test('incrementar, decrementar y quitar modifican el carrito', () {
    final vm = SalesViewModel(_FakeSalesRepository());
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    vm.incrementar('p1');
    expect(vm.lineas.single.cantidad, 2);

    vm.decrementar('p1');
    expect(vm.lineas.single.cantidad, 1);

    vm.decrementar('p1');
    expect(vm.lineas, isEmpty);
  });

  test('registrar exitoso devuelve venta con folio y vacía el carrito', () async {
    final repo = _FakeSalesRepository();
    final vm = SalesViewModel(repo);
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    final venta = await vm.registrar(sucursalId: 's1');

    expect(venta?.folio, 'FOLIO-1');
    expect(vm.ultimaVenta?.folio, 'FOLIO-1');
    expect(vm.lineas, isEmpty);
    expect(vm.total, 0);
  });

  test('registrar con error del servidor expone el mensaje', () async {
    final vm = SalesViewModel(_FakeSalesRepository(error: 'Sin existencias'));
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    final venta = await vm.registrar(sucursalId: 's1');

    expect(venta, isNull);
    expect(vm.mensajeError, 'Sin existencias');
    expect(vm.lineas, hasLength(1));
  });

  test('registrar con error de casco del servidor lo expone como mensaje', () async {
    final vm = SalesViewModel(
      _FakeSalesRepository(error: kMensajeRequiereCasco),
    );
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: true,
    );
    vm.resolverCasco(true);

    final venta = await vm.registrar(sucursalId: 's1');

    expect(venta, isNull);
    expect(vm.mensajeError, kMensajeRequiereCasco);
    expect(vm.pendienteCasco, isNull);
    expect(vm.lineas, hasLength(1));
  });

  test('marca busqueda_manual al agregar desde búsqueda manual', () {
    final vm = SalesViewModel(_FakeSalesRepository());

    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
      busquedaManual: true,
    );

    expect(vm.lineas.single.busquedaManual, isTrue);
  });

  test('registrar envía el corte de caja activo al servidor', () async {
    final repo = _FakeSalesRepository();
    final vm = SalesViewModel(repo);
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    await vm.registrar(sucursalId: 's1', corteCajaId: 'corte-1');

    expect(repo.ultimoCorteId, 'corte-1');
  });

  test('registrar sin corte envía null', () async {
    final repo = _FakeSalesRepository();
    final vm = SalesViewModel(repo);
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    await vm.registrar(sucursalId: 's1');

    expect(repo.ultimoCorteId, isNull);
  });

  test('registrar envía el método de pago elegido al servidor', () async {
    final repo = _FakeSalesRepository();
    final vm = SalesViewModel(repo);
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    await vm.registrar(sucursalId: 's1', metodoPago: 'tarjeta');

    expect(repo.ultimoMetodoPago, 'tarjeta');
    expect(vm.ultimaVenta?.metodoPago, 'tarjeta');
  });

  test('registrar usa efectivo por defecto si no se indica método', () async {
    final repo = _FakeSalesRepository();
    final vm = SalesViewModel(repo);
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      requiereCasco: false,
    );

    await vm.registrar(sucursalId: 's1');

    expect(repo.ultimoMetodoPago, 'efectivo');
  });

  test('agregar productos con diferentes tipos de precio genera lineas separadas', () {
    final vm = SalesViewModel(_FakeSalesRepository());
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      tipoPrecio: 'default',
      precioDefault: 2300,
      precio2: 2100,
      precio3: 2000,
      requiereCasco: false,
    );

    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2100,
      tipoPrecio: 'precio_2',
      precioDefault: 2300,
      precio2: 2100,
      precio3: 2000,
      requiereCasco: false,
    );

    expect(vm.lineas, hasLength(2));
    expect(vm.lineas[0].tipoPrecio, 'default');
    expect(vm.lineas[0].precio, 2300);
    expect(vm.lineas[1].tipoPrecio, 'precio_2');
    expect(vm.lineas[1].precio, 2100);
    expect(vm.total, 4400);
  });

  test('cambiarTipoPrecio actualiza el precio y tipo de precio en el carrito', () {
    final vm = SalesViewModel(_FakeSalesRepository());
    vm.agregar(
      productoId: 'p1',
      codigoBarras: 'CB1',
      modelo: 'Optima 750',
      precio: 2300,
      tipoPrecio: 'default',
      precioDefault: 2300,
      precio2: 2100,
      precio3: 2000,
      requiereCasco: false,
    );

    expect(vm.lineas.single.precio, 2300);
    expect(vm.lineas.single.tipoPrecio, 'default');

    vm.cambiarTipoPrecio(0, 'precio_2');
    expect(vm.lineas.single.precio, 2100);
    expect(vm.lineas.single.tipoPrecio, 'precio_2');
    expect(vm.total, 2100);

    vm.cambiarTipoPrecio(0, 'precio_3');
    expect(vm.lineas.single.precio, 2000);
    expect(vm.lineas.single.tipoPrecio, 'precio_3');
    expect(vm.total, 2000);

    vm.cambiarTipoPrecio(0, 'default');
    expect(vm.lineas.single.precio, 2300);
    expect(vm.lineas.single.tipoPrecio, 'default');
    expect(vm.total, 2300);

    vm.cambiarTipoPrecio(0, 'precio_especial', precioPersonalizado: 1850);
    expect(vm.lineas.single.precio, 1850);
    expect(vm.lineas.single.tipoPrecio, 'precio_especial');
    expect(vm.lineas.single.etiquetaTipoPrecio, 'Precio Especial');
    expect(vm.total, 1850);
  });
}
