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
  /// un ticket nuevo ni el duplicado de caja.
  final int? reimpresionNumero;
  final String? reimpresionAutorizo;
  final String? reimpresionMotivo;
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
