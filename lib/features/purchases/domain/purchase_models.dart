/// Modelos de compras y proveedores para reabastecimiento de stock.
library;

String? _extraerNombre(dynamic campo, [String subcampo = 'nombre']) {
  if (campo is Map) {
    return (campo[subcampo] as String?) ?? (campo['nombre'] as String?) ?? (campo['nombre_completo'] as String?);
  }
  if (campo is List && campo.isNotEmpty && campo.first is Map) {
    final first = campo.first as Map;
    return (first[subcampo] as String?) ?? (first['nombre'] as String?) ?? (first['nombre_completo'] as String?);
  }
  return null;
}

class Proveedor {
  const Proveedor({
    required this.id,
    required this.nombre,
    this.contacto,
    this.telefono,
    this.email,
  });

  final String id;
  final String nombre;
  final String? contacto;
  final String? telefono;
  final String? email;

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    return Proveedor(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      contacto: json['contacto']?.toString(),
      telefono: json['telefono']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      if (contacto != null && contacto!.isNotEmpty) 'contacto': contacto,
      if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
      if (email != null && email!.isNotEmpty) 'email': email,
    };
  }
}

class CompraItemDetalle {
  const CompraItemDetalle({
    required this.id,
    required this.tipoItem,
    required this.cantidad,
    required this.precioUnitario,
    this.modelo,
    this.descripcion,
  });

  final String id;
  final String tipoItem; // 'bateria' o 'casco'
  final int cantidad;
  final double precioUnitario;
  final String? modelo;
  final String? descripcion;

  double get subtotal => cantidad * precioUnitario;

  factory CompraItemDetalle.fromJson(Map<String, dynamic> json) {
    final prod = json['productos'];
    String? modelo;
    String? descripcion;
    if (prod is Map) {
      modelo = prod['modelo'] as String?;
      descripcion = prod['descripcion'] as String?;
    } else if (prod is List && prod.isNotEmpty && prod.first is Map) {
      final first = prod.first as Map;
      modelo = first['modelo'] as String?;
      descripcion = first['descripcion'] as String?;
    }

    return CompraItemDetalle(
      id: json['id']?.toString() ?? '',
      tipoItem: json['tipo_item']?.toString() ?? 'bateria',
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      modelo: modelo,
      descripcion: descripcion,
    );
  }
}

class Compra {
  const Compra({
    required this.id,
    required this.folio,
    required this.fecha,
    required this.total,
    required this.estado,
    required this.sucursalNombre,
    required this.usuarioNombre,
    this.proveedorNombre,
  });

  final String id;
  final String folio;
  final DateTime fecha;
  final double total;
  final String estado;
  final String sucursalNombre;
  final String usuarioNombre;
  final String? proveedorNombre;

  bool get esCompletada => estado == 'completada';

  factory Compra.fromJson(Map<String, dynamic> json) {
    final fechaStr = json['fecha']?.toString() ?? json['created_at']?.toString();
    final fechaParsed = fechaStr != null ? DateTime.tryParse(fechaStr) ?? DateTime.now() : DateTime.now();

    return Compra(
      id: json['id']?.toString() ?? '',
      folio: json['folio']?.toString() ?? '—',
      fecha: fechaParsed,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado']?.toString() ?? 'completada',
      proveedorNombre: _extraerNombre(json['proveedores']),
      sucursalNombre: _extraerNombre(json['sucursales']) ?? 'Sucursal',
      usuarioNombre: _extraerNombre(json['usuarios'], 'nombre_completo') ?? 'Usuario',
    );
  }
}

class CompraDetalle extends Compra {
  const CompraDetalle({
    required super.id,
    required super.folio,
    required super.fecha,
    required super.total,
    required super.estado,
    required super.sucursalNombre,
    required super.usuarioNombre,
    super.proveedorNombre,
    required this.items,
  });

  final List<CompraItemDetalle> items;

  factory CompraDetalle.fromJson(Map<String, dynamic> json) {
    final base = Compra.fromJson(json);
    final rawItems = json['compra_items'] as List<dynamic>? ?? const [];
    final itemsList = rawItems
        .map((e) => CompraItemDetalle.fromJson(e as Map<String, dynamic>))
        .toList();

    return CompraDetalle(
      id: base.id,
      folio: base.folio,
      fecha: base.fecha,
      total: base.total,
      estado: base.estado,
      sucursalNombre: base.sucursalNombre,
      usuarioNombre: base.usuarioNombre,
      proveedorNombre: base.proveedorNombre,
      items: itemsList,
    );
  }
}

class CompraItemInput {
  const CompraItemInput({
    required this.tipoItem,
    required this.cantidad,
    required this.precioUnitario,
    this.productoId,
    this.descripcionVisual,
    this.marcaVisual,
  });

  final String tipoItem; // 'bateria' | 'casco'
  final String? productoId;
  final int cantidad;
  final double precioUnitario;
  final String? descripcionVisual;
  final String? marcaVisual;

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toJson() {
    return {
      'tipo_item': tipoItem,
      'producto_id': tipoItem == 'bateria' ? productoId : null,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }
}

class RegistrarCompraInput {
  const RegistrarCompraInput({
    required this.sucursalId,
    this.proveedorId,
    required this.items,
  });

  final String sucursalId;
  final String? proveedorId;
  final List<CompraItemInput> items;

  Map<String, dynamic> toJson() {
    return {
      'sucursal_id': sucursalId,
      if (proveedorId != null && proveedorId!.isNotEmpty) 'proveedor_id': proveedorId,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
