import 'package:flutter/material.dart';

import '../../../core/utils/date_formatters.dart';
import '../../printing/print_models.dart';
import '../../printing/printer_screen.dart';
import '../../printing/ticket_builder.dart';
import '../domain/devolucion_models.dart';

/// Datos del papel de una devolución. Como en la venta, el propietario y el
/// R.F.C. van fijos en el encabezado.
DatosDevolucionTicket datosTicketDevolucion(Devolucion d) {
  final lineas = d.esDeposito
      ? [
          LineaDevolucionTicket(
            descripcion: 'Deposito casco ${d.cascoVendido ?? ''}'.trim(),
            cantidad: d.piezasCasco ?? 1,
            monto: d.monto,
          ),
        ]
      : d.items
          .map(
            (i) => LineaDevolucionTicket(
              descripcion:
                  '${i.producto}${i.reingresaInventario ? '' : ' (danada)'}',
              cantidad: i.cantidad,
              monto: i.monto,
            ),
          )
          .toList();

  return DatosDevolucionTicket(
    encabezado: 'CASA BATERIAS',
    propietario: 'Joaquin Gabriel Estrada Marquez',
    rfc: 'EAMJ-760228-E21',
    folio: d.folio,
    fecha: formatFechaHora(d.creadaEn ?? DateTime.now()),
    sucursal: d.sucursal,
    direccionSucursal: d.sucursalDireccion,
    tipo: d.esDeposito ? 'Devolucion de deposito de casco' : 'Devolucion de bateria',
    ventaFolio: d.ventaFolio,
    lineas: lineas,
    monto: d.monto,
    metodo: metodosReembolso[d.metodoReembolso] ?? d.metodoReembolso,
    motivo: d.motivo,
    cliente: d.clienteNombre,
    atendio: d.atendio,
    autorizo: d.autorizo,
  );
}

/// Imprime el comprobante para el cliente y la copia firmada del comercio.
Future<void> imprimirDevolucion(BuildContext context, Devolucion d) {
  final datos = datosTicketDevolucion(d);
  return imprimirDocumento(
    context,
    titulo: 'la devolución ${d.folio}',
    construir: () => TicketBuilder().devolucion(datos, copia: CopiaTicket.cliente),
    construirCopia: () =>
        TicketBuilder().devolucion(datos, copia: CopiaTicket.comercio),
  );
}

/// Aviso de devolución registrada con su folio y el botón para imprimir.
Future<void> mostrarDevolucionRegistrada(BuildContext context, Devolucion d) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
        title: const Text('Devolución registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              d.folio,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${TicketBuilder.moneda(d.monto)} en ${(metodosReembolso[d.metodoReembolso] ?? d.metodoReembolso).toLowerCase()}. '
              'Se resta del corte de la caja.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              imprimirDevolucion(context, d);
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimir'),
          ),
        ],
      );
    },
  );
}
