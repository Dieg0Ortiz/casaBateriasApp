/// Modelos de impresión térmica (Fase 9): ticket de venta y etiqueta de
/// código de barras. Solo datos; los bytes ESC/POS los genera
/// [TicketBuilder].
library;

/// Una línea del ticket de venta.
class LineaTicket {
  const LineaTicket({
    required this.modelo,
    required this.cantidad,
    required this.precio,
    this.marca,
    this.conCasco,
    this.tipoPrecio,
    this.comisionCasco,
  });

  final String modelo;
  final String? marca;
  final int cantidad;
  final double precio;
  final bool? conCasco;
  final String? tipoPrecio;
  final double? comisionCasco;

  double get importe {
    final comision = (conCasco == false) ? (comisionCasco ?? 0.0) : 0.0;
    return (precio + comision) * cantidad;
  }
}

/// Contenido del ticket de una venta.
class DatosTicket {
  const DatosTicket({
    required this.encabezado,
    required this.sucursal,
    required this.folio,
    required this.fecha,
    required this.lineas,
    required this.total,
    this.empleado,
    this.rfc,
    this.propietario,
    this.direccionSucursal,
    this.metodoPago,
    this.reimpresionNumero,
    this.reimpresionAutorizo,
    this.reimpresionMotivo,
  });

  final String encabezado;
  final String sucursal;
  final String folio;
  final String fecha;
  final List<LineaTicket> lineas;
  final double total;
  final String? empleado;

  /// R.F.C. del propietario o razón social.
  final String? rfc;

  /// Nombre completo del propietario / razón social.
  final String? propietario;

  /// Dirección completa de la sucursal donde se expide el ticket.
  final String? direccionSucursal;

  /// Método de pago utilizado (Efectivo, Tarjeta, Crédito, etc.).
  final String? metodoPago;

  /// Si viene informado, el papel es una reimpresión autorizada y no
  /// un ticket nuevo ni la copia del comercio.
  final int? reimpresionNumero;
  final String? reimpresionAutorizo;
  final String? reimpresionMotivo;
}

/// Para quién es cada papel cuando un ticket sale dos veces. Como en los
/// vouchers bancarios: uno se lo lleva el cliente y otro se queda en el
/// comercio. La leyenda ocupa un solo renglón.
enum CopiaTicket {
  cliente('CLIENTE'),
  comercio('COMERCIO');

  const CopiaTicket(this.leyenda);

  final String leyenda;
}

/// Un renglón de un corte de caja: concepto e importe.
class RenglonCorte {
  const RenglonCorte(this.concepto, this.monto, {this.destacado = false});

  final String concepto;
  final double monto;

  /// Totales y diferencias: van en negritas.
  final bool destacado;
}

/// Una operación listada en el corte de tarjetas y transferencias.
class OperacionCorte {
  const OperacionCorte({
    required this.hora,
    required this.descripcion,
    required this.monto,
  });

  final String hora;
  final String descripcion;
  final double monto;
}

/// Contenido de un corte impreso. Cada corte (efectivo, o tarjetas y
/// transferencias) sale en su propio papel.
class DatosCorteTicket {
  const DatosCorteTicket({
    required this.titulo,
    required this.sucursal,
    required this.apertura,
    required this.renglones,
    this.cierre,
    this.abrio,
    this.cerro,
    this.operaciones = const [],
    this.nota,
    this.conFirmas = false,
  });

  final String titulo;
  final String sucursal;
  final String apertura;
  final String? cierre;
  final String? abrio;
  final String? cerro;
  final List<RenglonCorte> renglones;
  final List<OperacionCorte> operaciones;

  /// Aclaración al pie, p. ej. qué no incluye este corte.
  final String? nota;

  /// Renglones para firma de quien entrega y quien recibe el efectivo.
  final bool conFirmas;
}

/// Una pieza devuelta en el ticket de devolución.
class LineaDevolucionTicket {
  const LineaDevolucionTicket({
    required this.descripcion,
    required this.cantidad,
    required this.monto,
  });

  final String descripcion;
  final int cantidad;
  final double monto;
}

/// Contenido del ticket de una devolución de dinero (folio DEV).
class DatosDevolucionTicket {
  const DatosDevolucionTicket({
    required this.encabezado,
    required this.folio,
    required this.fecha,
    required this.sucursal,
    required this.tipo,
    required this.ventaFolio,
    required this.lineas,
    required this.monto,
    required this.metodo,
    required this.motivo,
    this.direccionSucursal,
    this.propietario,
    this.rfc,
    this.cliente,
    this.atendio,
    this.autorizo,
  });

  final String encabezado;
  final String folio;
  final String fecha;
  final String sucursal;

  /// "Devolucion de deposito de casco" o "Devolucion de bateria".
  final String tipo;
  final String ventaFolio;
  final List<LineaDevolucionTicket> lineas;
  final double monto;
  final String metodo;
  final String motivo;
  final String? direccionSucursal;
  final String? propietario;
  final String? rfc;
  final String? cliente;
  final String? atendio;
  final String? autorizo;
}

/// Contenido de la etiqueta de código de barras de un producto.
class EtiquetaBateria {
  const EtiquetaBateria({
    required this.marca,
    required this.modelo,
    required this.precio,
    required this.codigoBarras,
  });

  final String marca;
  final String modelo;
  final double precio;
  final String codigoBarras;
}
