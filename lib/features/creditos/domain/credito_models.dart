/// Pilas de un modelo que una empresa tiene en ventas a crédito abiertas.
class PiezasDeModelo {
  const PiezasDeModelo({required this.cantidad, this.marca, this.modelo});

  final String? marca;
  final String? modelo;
  final int cantidad;

  String get producto => [marca, modelo]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(' ');

  factory PiezasDeModelo.fromJson(Map<String, dynamic> json) {
    return PiezasDeModelo(
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
    );
  }
}

class EmpresaCredito {
  const EmpresaCredito({
    required this.id,
    required this.nombre,
    this.rfc,
    this.contactoNombre,
    this.telefono,
    this.email,
    this.direccion,
    this.limiteCredito = 0.0,
    this.diasCredito = 30,
    this.activo = true,
    this.saldoDeudor = 0.0,
    this.totalBateriasDebidas = 0,
    this.bateriasPorModelo = const [],
    this.tieneVencidas = false,
    this.ventasPendientesCount = 0,
  });

  final String id;
  final String nombre;
  final String? rfc;
  final String? contactoNombre;
  final String? telefono;
  final String? email;
  final String? direccion;
  final double limiteCredito;
  final int diasCredito;
  final bool activo;
  final double saldoDeudor;
  final int totalBateriasDebidas;

  /// Las pilas a crédito sumadas por modelo, de la que más piezas tiene.
  final List<PiezasDeModelo> bateriasPorModelo;
  final bool tieneVencidas;
  final int ventasPendientesCount;

  factory EmpresaCredito.fromJson(Map<String, dynamic> json) {
    return EmpresaCredito(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      rfc: json['rfc'] as String?,
      contactoNombre: json['contacto_nombre'] as String?,
      telefono: json['telefono'] as String?,
      email: json['email'] as String?,
      direccion: json['direccion'] as String?,
      limiteCredito: (json['limite_credito'] as num?)?.toDouble() ?? 0.0,
      diasCredito: (json['dias_credito'] as num?)?.toInt() ?? 30,
      activo: json['activo'] as bool? ?? true,
      saldoDeudor: (json['saldo_deudor'] as num?)?.toDouble() ?? 0.0,
      totalBateriasDebidas: (json['total_baterias_debidas'] as num?)?.toInt() ?? 0,
      bateriasPorModelo: (json['baterias_por_modelo'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PiezasDeModelo.fromJson)
          .toList(),
      tieneVencidas: json['tiene_vencidas'] as bool? ?? false,
      ventasPendientesCount: (json['ventas_pendientes_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreditoVentaItem {
  const CreditoVentaItem({
    required this.id,
    required this.cantidad,
    required this.precioUnitario,
    required this.conCasco,
    this.productoModelo,
    this.productoMarca,
  });

  final String id;
  final int cantidad;
  final double precioUnitario;
  final bool conCasco;
  final String? productoModelo;
  final String? productoMarca;

  factory CreditoVentaItem.fromJson(Map<String, dynamic> json) {
    final prod = json['producto'] as Map<String, dynamic>?;
    final marcaObj = prod?['marcas'] as Map<String, dynamic>?;
    final marcaStr = (prod?['marca'] ?? marcaObj?['nombre']) as String?;
    return CreditoVentaItem(
      id: json['id'] as String,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      conCasco: json['con_casco'] as bool? ?? true,
      productoModelo: prod?['modelo'] as String?,
      productoMarca: marcaStr,
    );
  }
}

class CreditoVenta {
  const CreditoVenta({
    required this.id,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.fechaVencimiento,
    this.recibidoPor,
    this.vehiculoPlacas,
    this.folioVale,
    required this.estado,
    required this.createdAt,
    this.esVencida = false,
    this.empresaNombre,
    this.empresaId,
    this.sucursalNombre,
    this.ventaFolio,
    this.items = const [],
  });

  final String id;
  final double montoTotal;
  final double saldoPendiente;
  final String fechaVencimiento;
  final String? recibidoPor;
  final String? vehiculoPlacas;
  final String? folioVale;
  final String estado;
  final String createdAt;
  final bool esVencida;
  final String? empresaNombre;
  final String? empresaId;
  final String? sucursalNombre;
  final String? ventaFolio;
  final List<CreditoVentaItem> items;

  factory CreditoVenta.fromJson(Map<String, dynamic> json) {
    final emp = json['empresa'] as Map<String, dynamic>?;
    final suc = json['sucursal'] as Map<String, dynamic>?;
    final ven = json['venta'] as Map<String, dynamic>?;
    final rawItems = ven?['venta_items'] as List<dynamic>? ?? [];

    return CreditoVenta(
      id: json['id'] as String,
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0.0,
      saldoPendiente: (json['saldo_pendiente'] as num?)?.toDouble() ?? 0.0,
      fechaVencimiento: json['fecha_vencimiento'] as String? ?? '',
      recibidoPor: json['recibido_por'] as String?,
      vehiculoPlacas: json['vehiculo_placas'] as String?,
      folioVale: json['folio_vale'] as String?,
      estado: json['estado'] as String? ?? 'pendiente',
      createdAt: json['created_at'] as String? ?? '',
      esVencida: json['es_vencida'] as bool? ?? false,
      empresaNombre: emp?['nombre'] as String?,
      empresaId: emp?['id'] as String?,
      sucursalNombre: suc?['nombre'] as String?,
      ventaFolio: ven?['folio'] as String?,
      items: rawItems.map((e) => CreditoVentaItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class CreditoAbono {
  const CreditoAbono({
    required this.id,
    required this.monto,
    required this.metodoPago,
    this.referencia,
    this.notas,
    required this.createdAt,
    this.usuarioNombre,
    this.sucursalNombre,
  });

  final String id;
  final double monto;
  final String metodoPago;
  final String? referencia;
  final String? notas;
  final String createdAt;
  final String? usuarioNombre;
  final String? sucursalNombre;

  factory CreditoAbono.fromJson(Map<String, dynamic> json) {
    final usu = json['usuario'] as Map<String, dynamic>?;
    final suc = json['sucursal'] as Map<String, dynamic>?;

    return CreditoAbono(
      id: json['id'] as String,
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      metodoPago: json['metodo_pago'] as String? ?? 'efectivo',
      referencia: json['referencia'] as String?,
      notas: json['notas'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      usuarioNombre: (usu?['nombre_completo'] ?? usu?['nombre']) as String?,
      sucursalNombre: suc?['nombre'] as String?,
    );
  }
}

class EstadoCuentaEmpresa {
  const EstadoCuentaEmpresa({
    required this.empresa,
    required this.saldoDeudor,
    required this.ventas,
    required this.abonos,
  });

  final EmpresaCredito empresa;
  final double saldoDeudor;
  final List<CreditoVenta> ventas;
  final List<CreditoAbono> abonos;

  factory EstadoCuentaEmpresa.fromJson(Map<String, dynamic> json) {
    final empJson = json['empresa'] as Map<String, dynamic>;
    final rawVentas = json['ventas'] as List<dynamic>? ?? [];
    final rawAbonos = json['abonos'] as List<dynamic>? ?? [];

    return EstadoCuentaEmpresa(
      empresa: EmpresaCredito.fromJson(empJson),
      saldoDeudor: (json['saldo_deudor'] as num?)?.toDouble() ?? 0.0,
      ventas: rawVentas.map((e) => CreditoVenta.fromJson(e as Map<String, dynamic>)).toList(),
      abonos: rawAbonos.map((e) => CreditoAbono.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
