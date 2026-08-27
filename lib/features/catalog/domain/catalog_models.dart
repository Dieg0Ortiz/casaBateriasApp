/// Modelos de catálogo (productos y marcas). El precio siempre viene del
/// servidor; la app nunca lo captura en una venta (Sección 3.7).
library;

class Sucursal {
  const Sucursal({
    required this.id,
    required this.nombre,
    required this.esMatriz,
    this.direccion,
  });

  final String id;
  final String nombre;
  final bool esMatriz;
  final String? direccion;

  factory Sucursal.fromJson(Map<String, dynamic> json) {
    return Sucursal(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      esMatriz: json['es_matriz'] as bool? ?? false,
      direccion: json['direccion'] as String?,
    );
  }
}

class Marca {
  const Marca({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  final String id;
  final String nombre;
  final String? descripcion;

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
    );
  }
}

class Existencia {
  const Existencia({
    required this.sucursalId,
    required this.cantidad,
    required this.cascosDisponibles,
  });

  final String sucursalId;
  final int cantidad;
  final int cascosDisponibles;

  factory Existencia.fromJson(Map<String, dynamic> json) {
    return Existencia(
      sucursalId: json['sucursal_id'] as String,
      cantidad: (json['cantidad'] as num).toInt(),
      cascosDisponibles: (json['cascos_disponibles'] as num).toInt(),
    );
  }
}

class Producto {
  const Producto({
    required this.id,
    required this.marcaNombre,
    required this.modelo,
    required this.precio,
    required this.requiereCasco,
    required this.codigoBarras,
    required this.codigoBarrasOrigen,
    required this.activo,
    required this.existencias,
    this.precio2,
    this.precio3,
    this.comisionCasco,
    this.descripcion,
  });

  final String id;
  final String marcaNombre;
  final String modelo;
  final String? descripcion;
  final double precio;
  final double? precio2;
  final double? precio3;
  final double? comisionCasco;
  final bool requiereCasco;
  final String codigoBarras;
  final String codigoBarrasOrigen;
  final bool activo;
  final List<Existencia> existencias;

  bool get codigoDeFabrica => codigoBarrasOrigen == 'fabrica';

  int get stockTotal =>
      existencias.fold(0, (suma, e) => suma + e.cantidad);

  factory Producto.fromJson(Map<String, dynamic> json) {
    final marca = json['marcas'] as Map<String, dynamic>?;
    final inv = json['inventario'] as List<dynamic>? ?? const [];
    return Producto(
      id: json['id'] as String,
      marcaNombre: (marca?['nombre'] as String?) ?? '',
      modelo: json['modelo'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precio: (json['precio'] as num).toDouble(),
      precio2: (json['precio_2'] as num?)?.toDouble(),
      precio3: (json['precio_3'] as num?)?.toDouble(),
      comisionCasco: (json['comision_casco'] as num?)?.toDouble(),
      requiereCasco: json['requiere_casco'] as bool? ?? false,
      codigoBarras: json['codigo_barras'] as String? ?? '',
      codigoBarrasOrigen: json['codigo_barras_origen'] as String? ?? '',
      activo: json['activo'] as bool? ?? true,
      existencias: inv
          .map((e) => Existencia.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class NuevoProducto {
  const NuevoProducto({
    required this.marcaId,
    required this.modelo,
    required this.precio,
    required this.requiereCasco,
    this.precio2,
    this.precio3,
    this.comisionCasco,
    this.descripcion,
    this.codigoBarrasFabrica,
    this.sucursalId,
    this.cantidadInicial,
  });

  final String marcaId;
  final String modelo;
  final double precio;
  final double? precio2;
  final double? precio3;
  final double? comisionCasco;
  final bool requiereCasco;
  final String? descripcion;
  final String? codigoBarrasFabrica;
  final String? sucursalId;
  final int? cantidadInicial;

  Map<String, dynamic> toJson() {
    return {
      'marca_id': marcaId,
      'modelo': modelo,
      'precio': precio,
      if (precio2 != null) 'precio_2': precio2,
      if (precio3 != null) 'precio_3': precio3,
      if (comisionCasco != null) 'comision_casco': comisionCasco,
      'requiere_casco': requiereCasco,
      if (descripcion != null && descripcion!.isNotEmpty)
        'descripcion': descripcion,
      if (codigoBarrasFabrica != null && codigoBarrasFabrica!.isNotEmpty)
        'codigo_barras_fabrica': codigoBarrasFabrica,
      if (sucursalId != null) 'sucursal_id': sucursalId,
      if (cantidadInicial != null) 'cantidad_inicial': cantidadInicial,
    };
  }
}
