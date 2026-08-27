class IntercambioCascoItem {
  const IntercambioCascoItem({
    required this.id,
    required this.cantidad,
    required this.precioUnitario,
    this.cascoSalienteModelo,
    this.cascoSalienteMarca,
    this.cascoEntranteModelo,
    this.cascoEntranteMarca,
  });

  final String id;
  final int cantidad;
  final double precioUnitario;
  final String? cascoSalienteModelo;
  final String? cascoSalienteMarca;
  final String? cascoEntranteModelo;
  final String? cascoEntranteMarca;

  factory IntercambioCascoItem.fromJson(Map<String, dynamic> json) {
    final saliente = json['casco_saliente'] as Map<String, dynamic>?;
    final salienteMarca = saliente?['marcas'] as Map<String, dynamic>?;
    final entrante = json['casco_entrante'] as Map<String, dynamic>?;
    final entranteMarca = entrante?['marcas'] as Map<String, dynamic>?;

    return IntercambioCascoItem(
      id: json['id'] as String? ?? '',
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 150.0,
      cascoSalienteModelo: saliente?['modelo'] as String?,
      cascoSalienteMarca: salienteMarca?['nombre'] as String?,
      cascoEntranteModelo: entrante?['modelo'] as String?,
      cascoEntranteMarca: entranteMarca?['nombre'] as String?,
    );
  }
}

class IntercambioCasco {
  const IntercambioCasco({
    required this.id,
    required this.folio,
    required this.sucursalId,
    this.sucursalNombre,
    required this.usuarioId,
    this.usuarioNombre,
    required this.montoCobrado,
    required this.metodoPago,
    this.clienteNombre,
    this.clienteTelefono,
    this.notas,
    required this.estado,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String folio;
  final String sucursalId;
  final String? sucursalNombre;
  final String usuarioId;
  final String? usuarioNombre;
  final double montoCobrado;
  final String metodoPago;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? notas;
  final String estado;
  final DateTime createdAt;
  final List<IntercambioCascoItem> items;

  factory IntercambioCasco.fromJson(Map<String, dynamic> json) {
    final sucursal = json['sucursales'] as Map<String, dynamic>?;
    final usuario = json['usuarios'] as Map<String, dynamic>?;
    final itemsRaw = json['intercambio_casco_items'] as List<dynamic>?;

    return IntercambioCasco(
      id: json['id'] as String? ?? '',
      folio: json['folio'] as String? ?? 'S/F',
      sucursalId: json['sucursal_id'] as String? ?? '',
      sucursalNombre: sucursal?['nombre'] as String?,
      usuarioId: json['usuario_id'] as String? ?? '',
      usuarioNombre: usuario?['nombre_completo'] as String?,
      montoCobrado: (json['monto_cobrado'] as num?)?.toDouble() ?? 0.0,
      metodoPago: json['metodo_pago'] as String? ?? 'efectivo',
      clienteNombre: json['cliente_nombre'] as String?,
      clienteTelefono: json['cliente_telefono'] as String?,
      notas: json['notas'] as String?,
      estado: json['estado'] as String? ?? 'completado',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      items: itemsRaw?.map((e) => IntercambioCascoItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class RegistrarIntercambioInput {
  const RegistrarIntercambioInput({
    required this.sucursalId,
    this.metodoPago = 'efectivo',
    this.montoCobrado = 150.0,
    this.clienteNombre,
    this.clienteTelefono,
    this.notas,
    required this.items,
  });

  final String sucursalId;
  final String metodoPago;
  final double montoCobrado;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? notas;
  final List<Map<String, dynamic>> items;

  Map<String, dynamic> toJson() => {
    'sucursal_id': sucursalId,
    'metodo_pago': metodoPago,
    'monto_cobrado': montoCobrado,
    if (clienteNombre != null && clienteNombre!.isNotEmpty) 'cliente_nombre': clienteNombre,
    if (clienteTelefono != null && clienteTelefono!.isNotEmpty) 'cliente_telefono': clienteTelefono,
    if (notas != null && notas!.isNotEmpty) 'notas': notas,
    'items': items,
  };
}
