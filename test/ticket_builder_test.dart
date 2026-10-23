import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/features/printing/print_models.dart';
import 'package:casabateriaserp/features/printing/ticket_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final builder = TicketBuilder();

  test('moneda formatea montos con separadores y dos decimales', () {
    expect(TicketBuilder.moneda(2300), r'$2,300.00');
    expect(TicketBuilder.moneda(1), r'$1.00');
    expect(TicketBuilder.moneda(1234567.5), r'$1,234,567.50');
    expect(TicketBuilder.moneda(0), r'$0.00');
    expect(TicketBuilder.moneda(-123), r'-$123.00');
    expect(TicketBuilder.moneda(-1234.5), r'-$1,234.50');
    expect(TicketBuilder.moneda(-0.001), r'$0.00');
  });

  test('sanitizarTexto remueve acentos, diéresis, eñes y signos invertidos', () {
    expect(TicketBuilder.sanitizarTexto('CASA BATERÍAS'), 'CASA BATERIAS');
    expect(TicketBuilder.sanitizarTexto('Batería LTH Ácido-Plomo'), 'Bateria LTH Acido-Plomo');
    expect(TicketBuilder.sanitizarTexto('Ramón Pérez Gómez'), 'Ramon Perez Gomez');
    expect(TicketBuilder.sanitizarTexto('Pingüino / Cigüeña'), 'Pinguino / Ciguena');
    expect(TicketBuilder.sanitizarTexto('¡Hola! ¿Cómo estás?'), 'Hola! Como estas?');
    expect(TicketBuilder.sanitizarTexto('áéíóúÁÉÍÓÚñÑüÜ'), 'aeiouAEIOUnNuU');
  });

  test('ticket genera comandos ESC/POS con el total y el folio', () async {
    final datos = DatosTicket(
      encabezado: 'CASA BATERÍAS',
      sucursal: 'Matriz',
      folio: 'MT-20260805-000001',
      fecha: '05/08/2026 10:30',
      empleado: 'Juan Pérez',
      lineas: [
        LineaTicket(
          modelo: 'Optima 750',
          cantidad: 2,
          precio: 2300,
          conCasco: true,
        ),
        LineaTicket(modelo: 'EverStart Max', cantidad: 1, precio: 1800),
      ],
      total: 6400,
    );

    final bytes = await builder.ticket(datos);

    expect(bytes, isNotEmpty);
    // Empieza con ESC (reset) y termina con corte de papel GS V 0.
    expect(bytes.first, 0x1B);
    expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x30]);
  });

  test('etiqueta genera comando de código de barras CODE128', () async {
    final bytes = await builder.etiqueta(
      const EtiquetaBateria(
        marca: 'ACDelco',
        modelo: '48AGM',
        precio: 2500,
        codigoBarras: 'CB-48AGM-001',
      ),
    );

    expect(bytes, isNotEmpty);
    // El comando GS k para barcode se marca con 0x1D 0x6B.
    expect(bytes, contains(0x1D));
    expect(bytes, contains(0x6B));
  });

  test('ticket con carrito vacío aún imprime encabezado y total cero', () async {
    final datos = DatosTicket(
      encabezado: 'CASA BATERÍAS',
      sucursal: 'Norte',
      folio: 'NV-20260805-000002',
      fecha: '05/08/2026 11:00',
      lineas: const [],
      total: 0,
    );

    final bytes = await builder.ticket(datos);

    expect(bytes, isNotEmpty);
    expect(bytes.first, 0x1B);
  });

  test('ticket agrega datos del dueño cuando la dirección no los contiene', () async {
    final datos = DatosTicket(
      encabezado: 'CASA BATERIAS',
      sucursal: 'LA SALLE',
      direccionSucursal: 'BOULEVARD LA SALLE, ESQUINA BOULEVARD BELISARIO DOMINGUEZ S/N',
      propietario: 'Joaquin Gabriel Estrada Marquez',
      rfc: 'EAMJ-760228-E21',
      folio: 'LS-20260827-000001',
      fecha: '27/08/2026 11:30',
      empleado: 'Daniel',
      metodoPago: 'Efectivo',
      lineas: [
        const LineaTicket(modelo: 'LTH L-48/91-700', cantidad: 1, precio: 2850),
      ],
      total: 2850,
    );

    final bytes = await builder.ticket(datos);
    final textoCompleto = String.fromCharCodes(bytes);

    expect(textoCompleto, contains('Joaquin Gabriel Estrada Marquez'));
    expect(textoCompleto, contains('EAMJ-760228-E21'));
    expect(textoCompleto, contains('LA SALLE'));
    expect(textoCompleto, contains('FORMA DE PAGO: EFECTIVO'));
    expect(textoCompleto, contains('Solicitar factura el dia de su compra'));
  });

  test('ticket no duplica datos del dueño si la dirección de la sucursal ya los incluye', () async {
    final datos = DatosTicket(
      encabezado: 'CASA BATERIAS',
      sucursal: 'Matriz',
      direccionSucursal: 'Joaquin Gabriel Estrada Marquez R.F.C. EAMJ-760228-E21 Carretera Villaflores entre 20 y 21 sur C.P. 29080',
      propietario: 'Joaquin Gabriel Estrada Marquez',
      rfc: 'EAMJ-760228-E21',
      folio: 'MT-20260827-000002',
      fecha: '27/08/2026 11:35',
      empleado: 'Daniel',
      metodoPago: 'Tarjeta Débito',
      lineas: [
        const LineaTicket(modelo: 'Optima Red Top', cantidad: 1, precio: 3900),
      ],
      total: 3900,
    );

    final bytes = await builder.ticket(datos);
    final textoCompleto = String.fromCharCodes(bytes);

    // Debe contener el nombre del dueño y RFC provenientes del encabezado y la dirección limpia
    expect(textoCompleto, contains('Joaquin Gabriel Estrada Marquez'));
    expect(textoCompleto, contains('EAMJ-760228-E21'));
    expect(textoCompleto, contains('Matriz'));
    expect(textoCompleto, contains('Carretera Villaflores'));
    expect(textoCompleto, contains('FORMA DE PAGO: TARJETA DEBITO'));
    expect(textoCompleto, contains('Solicitar factura el dia de su compra'));
  });

  test('nombreArticuloCompleto combina marca y modelo sin duplicar', () {
    expect(TicketBuilder.nombreArticuloCompleto('65', 'LTH'), 'LTH 65');
    expect(TicketBuilder.nombreArticuloCompleto('65', 'LTH HI-TEC'), 'LTH HI-TEC 65');
    expect(TicketBuilder.nombreArticuloCompleto('G-42', 'Gonher'), 'Gonher G-42');
    expect(TicketBuilder.nombreArticuloCompleto('NS40', 'Voltar'), 'Voltar NS40');
    expect(TicketBuilder.nombreArticuloCompleto('LTH 65', 'LTH'), 'LTH 65');
    expect(TicketBuilder.nombreArticuloCompleto('48 AGM', null), '48 AGM');
  });

  test('ticket incluye marca del producto en las lineas de venta', () async {
    final datos = DatosTicket(
      encabezado: 'CASA BATERIAS',
      sucursal: 'Matriz',
      folio: 'NV-20260827-000086',
      fecha: '27/08/2026 12:35',
      empleado: 'PABLO DIAZ',
      metodoPago: 'Tarjeta Débito',
      lineas: [
        const LineaTicket(
          marca: 'LTH',
          modelo: '65',
          cantidad: 1,
          precio: 2900,
          conCasco: true,
        ),
      ],
      total: 2900,
    );

    final bytes = await builder.ticket(datos);
    final textoCompleto = String.fromCharCodes(bytes);

    expect(textoCompleto, contains('LTH 65'));
    expect(textoCompleto, contains('2,900.00'));
    expect(textoCompleto, contains('(con casco / a cambio)'));
    expect(textoCompleto, contains('Solicitar factura el dia de su compra'));
  });

  test('cada copia dice para quién es, en un renglón y sin DUPLICADO', () async {
    final datos = DatosTicket(
      encabezado: 'CASA BATERIAS',
      sucursal: 'Matriz',
      folio: 'NV-MAT-000001',
      fecha: '25/09/2026 12:00',
      lineas: const [
        LineaTicket(modelo: 'GONHER 47', cantidad: 1, precio: 2100),
      ],
      total: 2100,
    );

    final sinLeyenda = await builder.ticket(datos);
    final cliente = await builder.ticket(datos, copia: CopiaTicket.cliente);
    final comercio = await builder.ticket(datos, copia: CopiaTicket.comercio);
    final textoCliente = String.fromCharCodes(cliente);
    final textoComercio = String.fromCharCodes(comercio);

    expect(textoCliente, contains('CLIENTE'));
    expect(textoCliente, isNot(contains('COMERCIO')));
    expect(textoComercio, contains('COMERCIO'));
    expect(textoComercio, contains('NV-MAT-000001'));
    expect(textoCliente, isNot(contains('DUPLICADO')));
    expect(textoComercio, isNot(contains('DUPLICADO')));
    // La leyenda ocupa un solo renglón: el papel apenas crece.
    expect(comercio.length - sinLeyenda.length, lessThan(40));
  });

  test('corte de caja imprime sus renglones y las firmas', () async {
    final bytes = await builder.corte(
      const DatosCorteTicket(
        titulo: 'CORTE DE EFECTIVO',
        sucursal: 'Matriz',
        apertura: '22/10/2026 08:00',
        cierre: '22/10/2026 20:00',
        abrio: 'Daniel',
        renglones: [
          RenglonCorte('Fondo inicial', 500),
          RenglonCorte('(+) Ventas efectivo (3)', 6450),
          RenglonCorte('EFECTIVO ESPERADO', 6950, destacado: true),
          RenglonCorte('Faltante', -50, destacado: true),
        ],
        nota: 'No incluye tarjetas, transferencias ni ventas a credito.',
        conFirmas: true,
      ),
    );
    final texto = String.fromCharCodes(bytes);

    expect(texto, contains('CORTE DE EFECTIVO'));
    expect(texto, contains('Fondo inicial'));
    expect(texto, contains('6,950.00'));
    expect(texto, contains('Faltante'));
    expect(texto, contains('Entrego'));
    expect(texto, contains('Recibio'));
    expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x30]);
  });

  test('corte sin cierre se marca como parcial', () async {
    final texto = String.fromCharCodes(await builder.corte(
      const DatosCorteTicket(
        titulo: 'CORTE TARJETAS Y TRANSF.',
        sucursal: 'Norte',
        apertura: '22/10/2026 08:00',
        renglones: [RenglonCorte('TOTAL DEL CORTE', 2100, destacado: true)],
        operaciones: [
          OperacionCorte(hora: '10:15', descripcion: 'NV-NOR-000004 Debito', monto: 2100),
        ],
      ),
    ));

    expect(texto, contains('CORTE PARCIAL'));
    expect(texto, contains('NV-NOR-000004'));
    expect(texto, isNot(contains('Entrego')));
  });

  test('devolución: folio DEV y firma solo en la copia del comercio', () async {
    const datos = DatosDevolucionTicket(
      encabezado: 'CASA BATERIAS',
      folio: 'DEV-MAT-000001',
      fecha: '22/10/2026 12:00',
      sucursal: 'Matriz',
      tipo: 'Devolucion de deposito de casco',
      ventaFolio: 'NV-MAT-000120',
      lineas: [
        LineaDevolucionTicket(descripcion: 'Casco LTH L-42', cantidad: 1, monto: 450),
      ],
      monto: 450,
      metodo: 'Efectivo',
      motivo: 'Trajo el casco',
      atendio: 'Daniel',
    );

    final cliente = String.fromCharCodes(
      await builder.devolucion(datos, copia: CopiaTicket.cliente),
    );
    final comercio = String.fromCharCodes(
      await builder.devolucion(datos, copia: CopiaTicket.comercio),
    );

    expect(cliente, contains('DEVOLUCION'));
    expect(cliente, contains('DEV-MAT-000001'));
    expect(cliente, contains('NV-MAT-000120'));
    expect(cliente, contains('450.00'));
    expect(cliente, contains('CLIENTE'));
    expect(cliente, isNot(contains('Recibi de conformidad')));
    expect(comercio, contains('Recibi de conformidad'));
    expect(comercio, contains('COMERCIO'));
  });

  test('reimpresion marca el papel y no lo presenta como original', () async {
    final datos = DatosTicket(
      encabezado: 'CASA BATERIAS',
      sucursal: 'PLAN DE AYALA',
      folio: 'NV-20261003-000177',
      fecha: '03/10/2026 13:25',
      lineas: const [
        LineaTicket(marca: 'GONHER', modelo: '35', cantidad: 1, precio: 2100),
      ],
      total: 2100,
      reimpresionNumero: 2,
      reimpresionAutorizo: 'Administrador Prueba',
      reimpresionMotivo: 'No imprimio la primera vez',
    );

    final texto = String.fromCharCodes(await builder.ticket(datos));

    expect(texto, contains('REIMPRESION'));
    expect(texto, contains('NO ES UN TICKET NUEVO'));
    expect(texto, contains('Administrador Prueba'));
    expect(texto, contains('No imprimio la primera vez'));
    expect(texto, contains('Reimpresion 2'));
    expect(texto, contains('NV-20261003-000177'));
    expect(texto, isNot(contains('COMERCIO')));
  });

  group('forma de pago y garantía', () {
    const garantia = 'REQUISITOS DE GARANTÍA\n'
        '1. El acumulador debe ser revisado y evaluado por personal de la empresa.\n'
        '\n'
        'CENTROS DE SERVICIO\n'
        'Gonher y Voltar: Carret. Panamericana, Plan de Ayala.';

    DatosTicket venta({
      String metodo = 'Efectivo',
      List<PagoTicket> desglose = const [],
      String? leyenda = garantia,
      int? reimpresion,
    }) {
      return DatosTicket(
        encabezado: 'CASA BATERIAS',
        sucursal: 'Matriz',
        folio: 'NV-MAT-000124',
        fecha: '23/10/2026 11:00',
        lineas: const [
          LineaTicket(marca: 'LTH', modelo: 'L-42', cantidad: 1, precio: 2500),
        ],
        total: 2500,
        metodoPago: metodo,
        desglosePago: desglose,
        leyenda: leyenda,
        reimpresionNumero: reimpresion,
        reimpresionAutorizo: reimpresion == null ? null : 'Admin',
        reimpresionMotivo: reimpresion == null ? null : 'Lo perdio',
      );
    }

    test('la forma de pago sale en las dos copias, en mayúsculas', () async {
      for (final copia in CopiaTicket.values) {
        final texto = String.fromCharCodes(
          await builder.ticket(venta(metodo: 'Tarjeta Débito'), copia: copia),
        );
        expect(texto, contains('FORMA DE PAGO: TARJETA DEBITO'));
      }
    });

    test('pago mixto: cuánto fue con cada forma', () async {
      final texto = String.fromCharCodes(await builder.ticket(
        venta(
          metodo: 'Pago Mixto',
          desglose: const [
            PagoTicket('Efectivo', 1000),
            PagoTicket('Transferencia', 1500),
          ],
        ),
        copia: CopiaTicket.cliente,
      ));
      expect(texto, contains('FORMA DE PAGO: PAGO MIXTO'));
      expect(texto, contains('Efectivo'));
      expect(texto, contains(r'$1,000.00'));
      expect(texto, contains('Transferencia'));
      expect(texto, contains(r'$1,500.00'));
    });

    test('la garantía va en el papel del cliente, no en el del comercio', () async {
      final cliente = String.fromCharCodes(
        await builder.ticket(venta(), copia: CopiaTicket.cliente),
      );
      final comercio = String.fromCharCodes(
        await builder.ticket(venta(), copia: CopiaTicket.comercio),
      );

      expect(cliente, contains('REQUISITOS DE GARANTIA'));
      expect(cliente, contains('CENTROS DE SERVICIO'));
      expect(cliente, contains('Plan de Ayala.'));
      expect(comercio, isNot(contains('GARANTIA')));
      // CLIENTE sigue siendo el último renglón del papel.
      expect(cliente.lastIndexOf('CLIENTE'), greaterThan(cliente.lastIndexOf('Plan de Ayala')));
    });

    test('la garantía se parte en renglones de 32 caracteres sin cortar palabras', () async {
      final texto = String.fromCharCodes(
        await builder.ticket(venta(), copia: CopiaTicket.cliente),
      );
      expect(texto, contains('1. El acumulador debe ser'));
      expect(texto, isNot(contains('1. El acumulador debe ser revisado y evaluado')));
    });

    test('la reimpresión también lleva la garantía', () async {
      final texto = String.fromCharCodes(await builder.ticket(venta(reimpresion: 1)));
      expect(texto, contains('REIMPRESION'));
      expect(texto, contains('CENTROS DE SERVICIO'));
    });

    test('sucursal sin leyenda: el ticket sale como antes', () async {
      final sin = await builder.ticket(venta(leyenda: null), copia: CopiaTicket.cliente);
      final vacia = await builder.ticket(venta(leyenda: '  \n '), copia: CopiaTicket.cliente);
      expect(String.fromCharCodes(sin), isNot(contains('GARANTIA')));
      expect(vacia, sin);
    });
  });

  test('nombreMetodoPago traduce las claves de la base', () {
    expect(nombreMetodoPago('tarjeta_credito'), 'Tarjeta Crédito');
    expect(nombreMetodoPago('mixto'), 'Pago Mixto');
    expect(nombreMetodoPago('credito'), 'Crédito');
    expect(nombreMetodoPago('efectivo'), 'Efectivo');
  });
}
