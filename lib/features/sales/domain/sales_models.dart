/// Modelos del punto de venta. El precio siempre viene del servidor
/// (inventario/catálogo vigente); la app nunca lo captura (Sección 3.7).
library;

/// Línea de un carrito de venta. Para productos que requieren casco,
/// [conCasco] debe quedar decidido antes de cobrar (Sección 3.3).
class LineaVenta {
  const LineaVenta({
    required this.productoId,
    required this.codigoBarras,
    required this.modelo,
    required this.precio,
    required this.requiereCasco,
    required this.cantidad,
    this.marca,
    this.conCasco,
    this.busquedaManual = false,
    this.tipoPrecio = 'default',
    this.precioDefault,
    this.precio2,
    this.precio3,
    this.comisionCasco,
    this.nombreCliente,
    this.telefonoCliente,
  });

  final String? productoId;
  final String codigoBarras;
  final String modelo;
  final String? marca;
  final double precio;
  final bool requiereCasco;
  final int cantidad;
  final bool? conCasco;
  final bool busquedaManual;
  final String tipoPrecio;
  final double? precioDefault;
  final double? precio2;
  final double? precio3;
  final double? comisionCasco;
  final String? nombreCliente;
  final String? telefonoCliente;

  /// Comisión unitaria adicional por venta sin casco
  double get comisionUnitariaEfectiva =>
      (requiereCasco && conCasco == false) ? (comisionCasco ?? 0.0) : 0.0;

  /// Importe total de la línea incluyendo la comisión de casco si aplica
  double get importe => (precio + comisionUnitariaEfectiva) * cantidad;

  String get etiquetaTipoPrecio {
    switch (tipoPrecio) {
      case 'precio_2':
        return 'Precio 2';
      case 'precio_3':
        return 'Precio 3';
      case 'precio_especial':
        return 'Precio Especial';
      default:
        return 'Default';
    }
  }

  LineaVenta copyWith({
    String? productoId,
    String? codigoBarras,
    String? modelo,
    String? marca,
    double? precio,
    bool? requiereCasco,
    int? cantidad,
    bool? conCasco,
    bool clearConCasco = false,
    bool? busquedaManual,
    String? tipoPrecio,
    double? precioDefault,
    double? precio2,
    double? precio3,
    double? comisionCasco,
    String? nombreCliente,
    String? telefonoCliente,
  }) {
    return LineaVenta(
      productoId: productoId ?? this.productoId,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      modelo: modelo ?? this.modelo,
      marca: marca ?? this.marca,
      precio: precio ?? this.precio,
      requiereCasco: requiereCasco ?? this.requiereCasco,
      cantidad: cantidad ?? this.cantidad,
      conCasco: clearConCasco ? null : (conCasco ?? this.conCasco),
      busquedaManual: busquedaManual ?? this.busquedaManual,
      tipoPrecio: tipoPrecio ?? this.tipoPrecio,
      precioDefault: precioDefault ?? this.precioDefault,
      precio2: precio2 ?? this.precio2,
      precio3: precio3 ?? this.precio3,
      comisionCasco: comisionCasco ?? this.comisionCasco,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      telefonoCliente: telefonoCliente ?? this.telefonoCliente,
    );
  }
}

/// Detalle de un pago parcial cuando se utiliza pago mixto o múltiple
class PagoParcial {
  const PagoParcial({
    required this.metodo,
    required this.monto,
    this.referencia,
  });

  final String metodo;
  final double monto;
  final String? referencia;

  Map<String, dynamic> toJson() => {
        'metodo': metodo,
        'monto': monto,
        if (referencia != null && referencia!.isNotEmpty) 'referencia': referencia,
      };

  factory PagoParcial.fromJson(Map<String, dynamic> json) => PagoParcial(
        metodo: json['metodo'] as String,
        monto: (json['monto'] as num).toDouble(),
        referencia: json['referencia'] as String?,
      );

  String get nombreLegible {
    switch (metodo) {
      case 'tarjeta_debito':
        return 'Tarjeta Débito';
      case 'tarjeta_credito':
        return 'Tarjeta Crédito';
      case 'transferencia':
        return 'Transferencia';
      case 'efectivo':
        return 'Efectivo';
      default:
        return metodo;
    }
  }
}

/// Resultado de registrar una venta: folio único generado por el servidor.
class VentaResultado {
  const VentaResultado({
    required this.id,
    required this.folio,
    required this.sucursalId,
    required this.total,
    required this.estado,
    required this.creadaEn,
    this.metodoPago = 'efectivo',
    this.desglosePago,
  });

  final String id;
  final String folio;
  final String sucursalId;
  final double total;
  final String estado;
  final DateTime creadaEn;
  final String metodoPago;
  final List<PagoParcial>? desglosePago;

  factory VentaResultado.fromJson(Map<String, dynamic> json) {
    return VentaResultado(
      id: json['id'] as String,
      folio: json['folio'] as String,
      sucursalId: json['sucursal_id'] as String,
      total: (json['total'] as num).toDouble(),
      estado: json['estado'] as String? ?? 'completada',
      creadaEn:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      metodoPago: json['metodo_pago'] as String? ?? 'efectivo',
      desglosePago: (json['desglose_pago'] as List<dynamic>?)
          ?.map((p) => PagoParcial.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
