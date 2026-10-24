import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/features/autorizaciones/domain/solicitud_models.dart';
import 'package:casabateriaserp/features/sales/presentation/ticket_reimpresion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ventaJson = {
    'folio': 'NV-MAT-000124',
    'total': 2500,
    'created_at': '2026-10-23T17:05:00Z',
    'metodo_pago': 'mixto',
    'desglose_pago': [
      {'metodo': 'efectivo', 'monto': 1000},
      {'metodo': 'transferencia', 'monto': 1500},
    ],
    'sucursal': 'Matriz',
    'leyenda_ticket': 'Presentar la nota y la poliza.',
    'empleado': 'Daniel',
    'items': [
      {
        'marca': 'LTH',
        'modelo': 'L-42',
        'cantidad': 1,
        'precio_unitario': 2500,
        'con_casco': true,
        'comision_casco': 0,
      },
    ],
  };

  test('reimpresión aprobada sin imprimir trae su ticket', () {
    final s = SolicitudAutorizacion.fromJson({
      'id': 's1',
      'tipo': 'reimpresion',
      'estado': 'aprobada',
      'folio': 'NV-MAT-000124',
      'motivo': 'Lo perdio',
      'autorizador': 'Admin',
      'impresa_en': null,
      'ticket': {'numero': 2, 'autorizo': 'Admin', 'motivo': 'Lo perdio', 'venta': ventaJson},
    });

    expect(s.tipo, TipoSolicitud.reimpresion);
    expect(s.estado, EstadoSolicitud.aprobada);
    expect(s.reimpresionPorImprimir, isTrue);
  });

  test('una reimpresión ya impresa no se vuelve a ofrecer', () {
    final s = SolicitudAutorizacion.fromJson({
      'id': 's1',
      'tipo': 'reimpresion',
      'estado': 'aprobada',
      'folio': 'NV-MAT-000124',
      'motivo': 'x',
      'impresa_en': '2026-10-23T17:10:00Z',
    });
    expect(s.reimpresionPorImprimir, isFalse);
  });

  test('devolución: tipo, monto pedido y resultado', () {
    final s = SolicitudAutorizacion.fromJson({
      'id': 's2',
      'tipo': 'devolucion_bateria',
      'estado': 'pendiente',
      'folio': 'NV-MAT-000120',
      'motivo': 'Garantia',
      'devolucion': {'total': 1500, 'metodo': 'efectivo', 'piezas': []},
      'resultado': null,
    });
    expect(s.tipo, TipoSolicitud.devolucionBateria);
    expect(s.pendiente, isTrue);
    expect(s.montoDevolucion, 1500);
    expect(s.resultado, isNull);
  });

  test('valores desconocidos no rompen la pantalla', () {
    final s = SolicitudAutorizacion.fromJson({'id': 's3', 'tipo': 'otro', 'estado': 'raro'});
    expect(s.tipo, TipoSolicitud.reimpresion);
    expect(s.estado, EstadoSolicitud.pendiente);
  });

  test('el ticket de una reimpresión autorizada lleva la marca, el pago y la garantía', () async {
    final ticket = TicketReimpresion.fromJson({
      'numero': 2,
      'autorizo': 'Admin',
      'motivo': 'Lo perdio',
      'venta': ventaJson,
    });
    final texto = String.fromCharCodes(await ticket.construir());

    expect(texto, contains('REIMPRESION'));
    expect(texto, contains('Reimpresion 2'));
    expect(texto, contains('FORMA DE PAGO: PAGO MIXTO'));
    expect(texto, contains('Transferencia'));
    expect(texto, contains('Presentar la nota y la poliza.'));
  });
}
