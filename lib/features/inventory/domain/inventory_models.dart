/// Modelos de inventario por sucursal (Sección 3.7: cantidad, cascos
/// disponibles y precio vigente siempre del servidor).
library;

class ItemInventario {
  const ItemInventario({
    required this.sucursalId,
    required this.productoId,
    required this.modelo,
    required this.codigoBarras,
    required this.marca,
    required this.precio,
    required this.requiereCasco,
    required this.cantidad,
    required this.cascosDisponibles,
    this.precio2,
    this.precio3,
    this.comisionCasco,
  });

  final String sucursalId;
  final String? productoId;
  final String? modelo;
  final String? codigoBarras;
  final String? marca;
  final double precio;
  final double? precio2;
  final double? precio3;
  final double? comisionCasco;
  final bool requiereCasco;
  final int cantidad;
  final int cascosDisponibles;

  factory ItemInventario.fromJson(Map<String, dynamic> json) {
    return ItemInventario(
      sucursalId: json['sucursal_id'] as String,
      productoId: json['producto_id'] as String?,
      modelo: json['modelo'] as String?,
      codigoBarras: json['codigo_barras'] as String?,
      marca: json['marca'] as String?,
      precio: (json['precio'] as num?)?.toDouble() ?? 0,
      precio2: (json['precio_2'] as num?)?.toDouble(),
      precio3: (json['precio_3'] as num?)?.toDouble(),
      comisionCasco: (json['comision_casco'] as num?)?.toDouble(),
      requiereCasco: json['requiere_casco'] as bool? ?? false,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
      cascosDisponibles: (json['cascos_disponibles'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un traspaso de pilas entre sucursales, como lo devuelve el historial
/// (nombres ya resueltos por el servidor).
class Traspaso {
  const Traspaso({
    required this.id,
    required this.cantidad,
    required this.fecha,
    this.producto,
    this.origen,
    this.destino,
    this.autorizo,
    this.nota,
  });

  final String id;
  final int cantidad;
  final DateTime? fecha;
  final String? producto;
  final String? origen;
  final String? destino;
  final String? autorizo;
  final String? nota;

  factory Traspaso.fromJson(Map<String, dynamic> json) {
    return Traspaso(
      id: json['id'] as String,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
      fecha: DateTime.tryParse(json['created_at'] as String? ?? ''),
      producto: json['producto'] as String?,
      origen: json['sucursal_origen'] as String?,
      destino: json['sucursal_destino'] as String?,
      autorizo: json['autorizado_por'] as String?,
      nota: json['nota'] as String?,
    );
  }
}
