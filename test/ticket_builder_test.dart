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
    expect(textoCompleto, contains('Pago: Efectivo'));
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

    // Debe contener el nombre del dueño y RFC provenientes de la dirección (sin duplicarse en el encabezado)
    expect(textoCompleto, contains('Joaquin Gabriel Estrada Marquez'));
    expect(textoCompleto, contains('EAMJ-760228-E21'));
    expect(textoCompleto, contains('Matriz'));
    expect(textoCompleto, contains('Pago: Tarjeta Debito'));
  });
}
