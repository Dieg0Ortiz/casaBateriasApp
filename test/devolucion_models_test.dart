import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/features/creditos/domain/credito_models.dart';
import 'package:casabateriaserp/features/devoluciones/domain/devolucion_models.dart';
import 'package:casabateriaserp/features/devoluciones/presentation/devolucion_ticket.dart';

void main() {
  group('RenglonVentaDevolucion.maximoPara', () {
    final renglon = RenglonVentaDevolucion.fromJson({
      'venta_item_id': 'vi1',
      'marca': 'LTH',
      'modelo': 'L-42',
      'cantidad': 3,
      'devueltas': 1,
      'por_devolver': 2,
      'precio_unitario': 2000,
      'con_casco': false,
      'deposito_pendiente': 900,
    });

    test('parcial: solo el precio de las piezas', () {
      expect(renglon.maximoPara(1), 2000);
    });

    test('todo lo que queda: también el depósito pendiente', () {
      expect(renglon.maximoPara(2), 4000 + 900);
    });

    test('nombre del producto con marca', () {
      expect(renglon.producto, 'LTH L-42');
    });
  });

  test('VentaDevolucion sabe si ya no queda nada por devolver', () {
    final venta = VentaDevolucion.fromJson({
      'id': 'v1',
      'folio': 'NV-MAT-000010',
      'total': 3000,
      'metodo_pago': 'efectivo',
      'estado': 'activa',
      'es_credito': false,
      'items': [
        {'venta_item_id': 'a', 'cantidad': 1, 'devueltas': 1, 'por_devolver': 0, 'precio_unitario': 3000},
      ],
    });
    expect(venta.todoDevuelto, isTrue);
    expect(venta.cancelada, isFalse);
  });

  test('ticket de depósito usa el modelo del casco y las piezas', () {
    final dev = Devolucion.fromJson({
      'id': 'd1',
      'folio': 'DEV-MAT-000001',
      'tipo': 'deposito_casco',
      'monto': 900,
      'metodo_reembolso': 'efectivo',
      'motivo': 'Devolución de depósito por casco',
      'venta_folio': 'NV-MAT-000120',
      'sucursal': 'Matriz',
      'created_at': '2026-10-22T18:00:00Z',
      'atendio': 'Daniel',
      'items': [],
      'casco': {'modelo_vendido': 'L-42', 'modelo_recibido': 'L-42', 'piezas': 2},
    });
    final datos = datosTicketDevolucion(dev);

    expect(dev.esDeposito, isTrue);
    expect(datos.folio, 'DEV-MAT-000001');
    expect(datos.lineas.single.cantidad, 2);
    expect(datos.lineas.single.descripcion, contains('L-42'));
    expect(datos.metodo, 'Efectivo');
  });

  test('ticket de batería marca las piezas dañadas', () {
    final dev = Devolucion.fromJson({
      'folio': 'DEV-MAT-000002',
      'tipo': 'bateria',
      'monto': 1500,
      'metodo_reembolso': 'transferencia',
      'motivo': 'Garantía',
      'venta_folio': 'NV-MAT-000121',
      'sucursal': 'Matriz',
      'items': [
        {'marca': 'GONHER', 'modelo': '47', 'cantidad': 1, 'monto': 1500, 'reingresa_inventario': false},
      ],
    });
    final datos = datosTicketDevolucion(dev);

    expect(datos.lineas.single.descripcion, 'GONHER 47 (danada)');
    expect(datos.metodo, 'Transferencia');
  });

  test('EmpresaCredito lee las pilas a crédito por modelo', () {
    final empresa = EmpresaCredito.fromJson({
      'id': 'e1',
      'nombre': 'Transportes',
      'total_baterias_debidas': 5,
      'baterias_por_modelo': [
        {'marca': 'LTH', 'modelo': 'L-42', 'cantidad': 3},
        {'marca': null, 'modelo': '65', 'cantidad': 2},
      ],
    });
    expect(empresa.bateriasPorModelo.map((m) => '${m.cantidad} ${m.producto}'), [
      '3 LTH L-42',
      '2 65',
    ]);
  });
}
