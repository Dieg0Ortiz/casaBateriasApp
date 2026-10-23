import '../../../core/utils/date_formatters.dart';
import '../../printing/print_models.dart';
import '../../printing/ticket_builder.dart';
import '../domain/cash_models.dart';

/// Los dos cortes salen en papeles separados: el de efectivo (lo que se
/// entrega del cajón) y el de tarjetas y transferencias. Las ventas a
/// crédito no van en ninguno de los dos.

String _metodo(String metodo) {
  switch (metodo) {
    case 'tarjeta_debito':
      return 'Debito';
    case 'tarjeta_credito':
      return 'Credito';
    case 'tarjeta':
      return 'Tarjeta';
    case 'transferencia':
      return 'Transf.';
    default:
      return metodo;
  }
}

Future<List<int>> ticketCorteEfectivo(ResumenCorte r) {
  final e = r.efectivo;
  final renglones = <RenglonCorte>[
    RenglonCorte('Fondo inicial', e.montoInicial),
    RenglonCorte('(+) Ventas efectivo (${e.ventasCount})', e.ventas),
    if (e.intercambios != 0) RenglonCorte('(+) Intercambios', e.intercambios),
    if (e.abonosCredito != 0) RenglonCorte('(+) Abonos de credito', e.abonosCredito),
    if (e.devoluciones != 0) RenglonCorte('(-) Devoluciones', e.devoluciones),
    RenglonCorte('EFECTIVO ESPERADO', e.esperado, destacado: true),
    if (e.contado != null) RenglonCorte('Efectivo contado', e.contado!),
    if (e.diferencia != null)
      RenglonCorte(
        e.diferencia!.abs() < 0.005
            ? 'Diferencia'
            : e.diferencia! > 0
                ? 'Sobrante'
                : 'Faltante',
        e.diferencia!,
        destacado: true,
      ),
  ];
  return TicketBuilder().corte(
    DatosCorteTicket(
      titulo: 'CORTE DE EFECTIVO',
      sucursal: r.sucursal,
      apertura: formatFechaHora(r.abiertoEn),
      cierre: r.cerradoEn == null ? null : formatFechaHora(r.cerradoEn),
      abrio: r.abrio,
      cerro: r.cerro,
      renglones: renglones,
      nota: 'No incluye tarjetas, transferencias ni ventas a credito.',
      conFirmas: true,
    ),
  );
}

Future<List<int>> ticketCorteElectronico(ResumenCorte r) {
  final el = r.electronico;
  final renglones = <RenglonCorte>[
    RenglonCorte('Tarjeta de debito', el.tarjetaDebito),
    RenglonCorte('Tarjeta de credito', el.tarjetaCredito),
    if (el.tarjetaSinTipo != 0) RenglonCorte('Tarjeta (sin tipo)', el.tarjetaSinTipo),
    if (el.devolucionesTarjeta != 0)
      RenglonCorte('(-) Devol. a tarjeta', el.devolucionesTarjeta),
    RenglonCorte('TOTAL TARJETAS', el.totalTarjetas, destacado: true),
    RenglonCorte('Transferencias', el.transferencias),
    if (el.devolucionesTransferencia != 0)
      RenglonCorte('(-) Devol. por transf.', el.devolucionesTransferencia),
    RenglonCorte('TOTAL TRANSFERENCIAS', el.totalTransferencias, destacado: true),
    RenglonCorte('TOTAL DEL CORTE', el.total, destacado: true),
  ];
  return TicketBuilder().corte(
    DatosCorteTicket(
      titulo: 'CORTE TARJETAS Y TRANSF.',
      sucursal: r.sucursal,
      apertura: formatFechaHora(r.abiertoEn),
      cierre: r.cerradoEn == null ? null : formatFechaHora(r.cerradoEn),
      abrio: r.abrio,
      cerro: r.cerro,
      renglones: renglones,
      operaciones: el.operaciones
          .map(
            (o) => OperacionCorte(
              hora: formatHora(o.creadoEn),
              descripcion: '${o.folio ?? o.detalle ?? ''} ${_metodo(o.metodo)}'.trim(),
              monto: o.monto,
            ),
          )
          .toList(),
      nota: 'No incluye efectivo ni ventas a credito.',
    ),
  );
}
