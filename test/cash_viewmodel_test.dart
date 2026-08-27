import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/core/network/api_exception.dart';
import 'package:casabateriaserp/features/cash/domain/cash_models.dart';
import 'package:casabateriaserp/features/cash/domain/cash_repository.dart';
import 'package:casabateriaserp/features/cash/presentation/cash_viewmodel.dart';

CorteCaja _corte({
  String id = 'c1',
  String estado = 'abierto',
  double inicial = 500,
  double? reportado,
  double? calculado,
  double? diferencia,
}) {
  return CorteCaja(
    id: id,
    sucursalId: 's1',
    usuarioId: 'u1',
    montoInicial: inicial,
    estado: estado,
    abiertoEn: DateTime(2026, 1, 1, 8),
    montoFinalReportado: reportado,
    montoCalculado: calculado,
    diferencia: diferencia,
    cerradoEn: reportado == null ? null : DateTime(2026, 1, 1, 20),
  );
}

class _FakeCashRepository implements CashRepository {
  _FakeCashRepository({
    this.errorAbrir,
    this.errorCerrar,
  });

  final String? errorAbrir;
  final String? errorCerrar;

  CajaActiva activa = const CajaActiva(corte: null, totalVentas: 0, montoEsperado: 0);
  final List<CorteCaja> cortes = [];
  bool abrio = false;
  bool cerro = false;

  @override
  Future<CajaActiva> obtenerActiva() async => activa;

  @override
  Future<List<CorteCaja>> historial() async => cortes;

  @override
  Future<CorteCaja> abrir({required double montoInicial}) async {
    if (errorAbrir != null) throw ApiException(errorAbrir!);
    abrio = true;
    final corte = _corte(inicial: montoInicial);
    activa = CajaActiva(
      corte: corte,
      totalVentas: 0,
      montoEsperado: montoInicial,
    );
    return corte;
  }

  @override
  Future<CorteCaja> cerrar({
    required String corteId,
    required double montoFinal,
  }) async {
    if (errorCerrar != null) throw ApiException(errorCerrar!);
    cerro = true;
    final corte = _corte(
      id: corteId,
      estado: 'cerrado',
      inicial: 500,
      reportado: montoFinal,
      calculado: 800,
      diferencia: montoFinal - 800,
    );
    activa = const CajaActiva(corte: null, totalVentas: 0, montoEsperado: 0);
    return corte;
  }
}

void main() {
  test('cargar sin caja abierta deja cajaActiva sin corte', () async {
    final vm = CashViewModel(_FakeCashRepository());

    await vm.cargar();

    expect(vm.cargando, isFalse);
    expect(vm.cajaActiva, isNotNull);
    expect(vm.cajaActiva!.tieneCajaAbierta, isFalse);
  });

  test('cargar con caja abierta expone el acumulado del turno', () async {
    final repo = _FakeCashRepository()
      ..activa = CajaActiva(
        corte: _corte(inicial: 500),
        totalVentas: 1300,
        montoEsperado: 1800,
      );
    final vm = CashViewModel(repo);

    await vm.cargar();

    expect(vm.cajaActiva!.tieneCajaAbierta, isTrue);
    expect(vm.cajaActiva!.montoEsperado, 1800);
  });

  test('abrir exitoso deja la caja abierta con el monto inicial', () async {
    final repo = _FakeCashRepository();
    final vm = CashViewModel(repo);

    final exito = await vm.abrir(500);

    expect(exito, isTrue);
    expect(repo.abrio, isTrue);
    expect(vm.cajaActiva!.tieneCajaAbierta, isTrue);
    expect(vm.cajaActiva!.corte!.montoInicial, 500);
    expect(vm.cajaActiva!.montoEsperado, 500);
    expect(vm.mensajeError, isNull);
  });

  test('abrir con error del servidor expone el mensaje', () async {
    final vm = CashViewModel(_FakeCashRepository(errorAbrir: 'Caja ya abierta'));

    final exito = await vm.abrir(500);

    expect(exito, isFalse);
    expect(vm.cajaActiva, isNull);
    expect(vm.mensajeError, 'Caja ya abierta');
  });

  test('cerrar exitoso deja el cierre y limpia la caja activa', () async {
    final repo = _FakeCashRepository()
      ..activa = CajaActiva(
        corte: _corte(inicial: 500),
        totalVentas: 300,
        montoEsperado: 800,
      );
    final vm = CashViewModel(repo);

    await vm.cargar();
    final exito = await vm.cerrar(820);

    expect(exito, isTrue);
    expect(repo.cerro, isTrue);
    expect(vm.cajaActiva, isNull);
    expect(vm.ultimoCierre, isNotNull);
    expect(vm.ultimoCierre!.estado, 'cerrado');
    expect(vm.ultimoCierre!.diferencia, 20);
  });

  test('cerrar sin caja abierta no hace nada', () async {
    final vm = CashViewModel(_FakeCashRepository());

    final exito = await vm.cerrar(800);

    expect(exito, isFalse);
    expect(vm.ultimoCierre, isNull);
  });

  test('cerrar con error del servidor conserva la caja activa', () async {
    final repo = _FakeCashRepository(errorCerrar: 'Monto inválido')
      ..activa = CajaActiva(
        corte: _corte(inicial: 500),
        totalVentas: 300,
        montoEsperado: 800,
      );
    final vm = CashViewModel(repo);

    await vm.cargar();
    final exito = await vm.cerrar(820);

    expect(exito, isFalse);
    expect(vm.mensajeError, 'Monto inválido');
    expect(vm.cajaActiva!.tieneCajaAbierta, isTrue);
  });

  test('historial se actualiza tras cerrar', () async {
    final repo = _FakeCashRepository()
      ..activa = CajaActiva(
        corte: _corte(inicial: 500),
        totalVentas: 300,
        montoEsperado: 800,
      )
      ..cortes.add(_corte(
        estado: 'cerrado',
        reportado: 820,
        calculado: 800,
        diferencia: 20,
      ));
    final vm = CashViewModel(repo);

    await vm.cargar();
    await vm.cerrar(820);

    expect(vm.historial, isNotEmpty);
    expect(vm.historial.first.estado, 'cerrado');
  });
}
