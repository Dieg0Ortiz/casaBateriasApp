/// Devoluciones de dinero con folio DEV (migración 035). Las dos salen de la
/// caja abierta de la sucursal y se restan de su corte:
///   * depósito de casco: el cliente trae el casco dentro del plazo;
///   * batería: el cliente regresa una batería (autoriza un administrador).
library;

double _num(dynamic valor) => valor is num ? valor.toDouble() : 0;

int _entero(dynamic valor) => valor is num ? valor.toInt() : 0;

String _producto(String? marca, String? modelo) =>
    [marca, modelo].where((p) => p != null && p.trim().isNotEmpty).join(' ');

/// Formas en que se regresa el dinero.
const metodosReembolso = <String, String>{
  'efectivo': 'Efectivo',
  'transferencia': 'Transferencia',
  'tarjeta': 'Tarjeta',
};

/// Depósito cobrado por no dejar casco, todavía sin devolver.
class DepositoPendiente {
  const DepositoPendiente({
    required this.id,
    required this.ventaId,
    required this.piezas,
    required this.deposito,
    required this.vencido,
    this.folio,
    this.ventaFecha,
    this.marca,
    this.modelo,
    this.fechaLimite,
    this.clienteNombre,
    this.clienteTelefono,
  });

  final String id;
  final String ventaId;
  final String? folio;
  final DateTime? ventaFecha;
  final String? marca;
  final String? modelo;
  final int piezas;
  final double deposito;
  final DateTime? fechaLimite;
  final bool vencido;
  final String? clienteNombre;
  final String? clienteTelefono;

  String get producto => _producto(marca, modelo);

  factory DepositoPendiente.fromJson(Map<String, dynamic> json) {
    return DepositoPendiente(
      id: json['id'] as String,
      ventaId: json['venta_id'] as String? ?? '',
      folio: json['folio'] as String?,
      ventaFecha: DateTime.tryParse(json['venta_fecha'] as String? ?? ''),
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      piezas: _entero(json['piezas']),
      deposito: _num(json['deposito']),
      fechaLimite: DateTime.tryParse(json['fecha_limite'] as String? ?? ''),
      vencido: json['vencido'] as bool? ?? false,
      clienteNombre: json['cliente_nombre'] as String?,
      clienteTelefono: json['cliente_telefono'] as String?,
    );
  }
}

/// Renglón de una venta con lo que todavía se puede devolver.
class RenglonVentaDevolucion {
  const RenglonVentaDevolucion({
    required this.ventaItemId,
    required this.cantidad,
    required this.devueltas,
    required this.porDevolver,
    required this.precioUnitario,
    this.marca,
    this.modelo,
    this.conCasco,
    this.depositoPendiente,
  });

  final String ventaItemId;
  final String? marca;
  final String? modelo;
  final int cantidad;
  final int devueltas;
  final int porDevolver;
  final double precioUnitario;
  final bool? conCasco;

  /// Depósito de casco sin devolver del renglón. Solo se reembolsa junto con
  /// la batería si se devuelve el renglón completo.
  final double? depositoPendiente;

  String get producto => _producto(marca, modelo);

  /// Lo más que se puede devolver por [piezas] de este renglón.
  double maximoPara(int piezas) {
    final deposito =
        piezas == porDevolver && depositoPendiente != null ? depositoPendiente! : 0.0;
    return precioUnitario * piezas + deposito;
  }

  factory RenglonVentaDevolucion.fromJson(Map<String, dynamic> json) {
    return RenglonVentaDevolucion(
      ventaItemId: json['venta_item_id'] as String,
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      cantidad: _entero(json['cantidad']),
      devueltas: _entero(json['devueltas']),
      porDevolver: _entero(json['por_devolver']),
      precioUnitario: _num(json['precio_unitario']),
      conCasco: json['con_casco'] as bool?,
      depositoPendiente: json['deposito_pendiente'] is num
          ? _num(json['deposito_pendiente'])
          : null,
    );
  }
}

/// Venta buscada por folio para devolver baterías.
class VentaDevolucion {
  const VentaDevolucion({
    required this.id,
    required this.folio,
    required this.total,
    required this.metodoPago,
    required this.estado,
    required this.esCredito,
    required this.items,
    this.creadaEn,
  });

  final String id;
  final String folio;
  final DateTime? creadaEn;
  final double total;
  final String metodoPago;
  final String estado;
  final bool esCredito;
  final List<RenglonVentaDevolucion> items;

  bool get cancelada => estado == 'cancelada';

  bool get todoDevuelto => items.every((i) => i.porDevolver == 0);

  factory VentaDevolucion.fromJson(Map<String, dynamic> json) {
    return VentaDevolucion(
      id: json['id'] as String,
      folio: json['folio'] as String? ?? '',
      creadaEn: DateTime.tryParse(json['created_at'] as String? ?? ''),
      total: _num(json['total']),
      metodoPago: json['metodo_pago'] as String? ?? 'efectivo',
      estado: json['estado'] as String? ?? 'activa',
      esCredito: json['es_credito'] as bool? ?? false,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RenglonVentaDevolucion.fromJson)
          .toList(),
    );
  }
}

/// Pieza devuelta en una devolución registrada.
class ItemDevuelto {
  const ItemDevuelto({
    required this.cantidad,
    required this.monto,
    required this.reingresaInventario,
    this.marca,
    this.modelo,
  });

  final String? marca;
  final String? modelo;
  final int cantidad;
  final double monto;
  final bool reingresaInventario;

  String get producto => _producto(marca, modelo);

  factory ItemDevuelto.fromJson(Map<String, dynamic> json) {
    return ItemDevuelto(
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      cantidad: _entero(json['cantidad']),
      monto: _num(json['monto']),
      reingresaInventario: json['reingresa_inventario'] as bool? ?? true,
    );
  }
}

/// Devolución registrada, con todo lo que va en el ticket.
class Devolucion {
  const Devolucion({
    required this.id,
    required this.folio,
    required this.tipo,
    required this.monto,
    required this.metodoReembolso,
    required this.motivo,
    required this.ventaFolio,
    required this.sucursal,
    required this.items,
    this.creadaEn,
    this.clienteNombre,
    this.sucursalDireccion,
    this.atendio,
    this.autorizo,
    this.cascoVendido,
    this.cascoRecibido,
    this.piezasCasco,
  });

  final String id;
  final String folio;

  /// deposito_casco | bateria
  final String tipo;
  final double monto;
  final String metodoReembolso;
  final String motivo;
  final String ventaFolio;
  final String sucursal;
  final List<ItemDevuelto> items;
  final DateTime? creadaEn;
  final String? clienteNombre;
  final String? sucursalDireccion;
  final String? atendio;
  final String? autorizo;
  final String? cascoVendido;
  final String? cascoRecibido;
  final int? piezasCasco;

  bool get esDeposito => tipo == 'deposito_casco';

  factory Devolucion.fromJson(Map<String, dynamic> json) {
    final casco = json['casco'];
    final datosCasco =
        casco is Map<String, dynamic> ? casco : const <String, dynamic>{};
    return Devolucion(
      id: json['id'] as String? ?? '',
      folio: json['folio'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'bateria',
      monto: _num(json['monto']),
      metodoReembolso: json['metodo_reembolso'] as String? ?? 'efectivo',
      motivo: json['motivo'] as String? ?? '',
      ventaFolio: json['venta_folio'] as String? ?? '',
      sucursal: json['sucursal'] as String? ?? '',
      sucursalDireccion: json['sucursal_direccion'] as String?,
      creadaEn: DateTime.tryParse(json['created_at'] as String? ?? ''),
      clienteNombre: json['cliente_nombre'] as String?,
      atendio: json['atendio'] as String?,
      autorizo: json['autorizo'] as String?,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ItemDevuelto.fromJson)
          .toList(),
      cascoVendido: datosCasco['modelo_vendido'] as String?,
      cascoRecibido: datosCasco['modelo_recibido'] as String?,
      piezasCasco: datosCasco['piezas'] is num ? _entero(datosCasco['piezas']) : null,
    );
  }
}

/// Pieza a devolver que se manda al servidor.
class RenglonADevolver {
  const RenglonADevolver({
    required this.ventaItemId,
    required this.cantidad,
    required this.monto,
    required this.reingresaInventario,
  });

  final String ventaItemId;
  final int cantidad;
  final double monto;

  /// false si la batería regresa dañada y no se puede volver a vender.
  final bool reingresaInventario;

  Map<String, dynamic> toJson() => {
        'venta_item_id': ventaItemId,
        'cantidad': cantidad,
        'monto': monto,
        'reingresa_inventario': reingresaInventario,
      };
}
