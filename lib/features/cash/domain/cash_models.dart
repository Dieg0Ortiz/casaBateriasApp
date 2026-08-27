/// Modelos de caja: corte (apertura/cierre) y acumulado del turno.
/// El monto esperado siempre lo calcula el servidor a partir de las
/// ventas activas del corte (Sección 7).
library;

/// Corte de caja: apertura con [montoInicial] y, al cerrar, los montos
/// calculado/reportado y la [diferencia] entre ambos.
class CorteCaja {
  const CorteCaja({
    required this.id,
    required this.sucursalId,
    required this.usuarioId,
    required this.montoInicial,
    required this.estado,
    required this.abiertoEn,
    this.montoFinalReportado,
    this.montoCalculado,
    this.diferencia,
    this.cerradoEn,
  });

  final String id;
  final String sucursalId;
  final String usuarioId;
  final double montoInicial;
  final String estado;
  final DateTime abiertoEn;
  final double? montoFinalReportado;
  final double? montoCalculado;
  final double? diferencia;
  final DateTime? cerradoEn;

  bool get estaAbierta => estado == 'abierto';

  factory CorteCaja.fromJson(Map<String, dynamic> json) {
    return CorteCaja(
      id: json['id'] as String,
      sucursalId: json['sucursal_id'] as String,
      usuarioId: json['usuario_id'] as String,
      montoInicial: (json['monto_inicial'] as num).toDouble(),
      estado: json['estado'] as String,
      abiertoEn:
          DateTime.tryParse(json['abierto_en'] as String? ?? '') ??
              DateTime.now(),
      montoFinalReportado: _toDouble(json['monto_final_reportado']),
      montoCalculado: _toDouble(json['monto_calculado']),
      diferencia: _toDouble(json['diferencia']),
      cerradoEn: _toDateTime(json['cerrado_en']),
    );
  }

  static double? _toDouble(dynamic valor) =>
      valor is num ? valor.toDouble() : null;

  static DateTime? _toDateTime(dynamic valor) {
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }
}

/// Caja abierta del cajero con el acumulado del turno. [corte] es null
/// cuando no hay caja abierta.
class CajaActiva {
  const CajaActiva({
    required this.corte,
    required this.totalVentas,
    required this.montoEsperado,
  });

  final CorteCaja? corte;
  final double totalVentas;
  final double montoEsperado;

  bool get tieneCajaAbierta => corte != null && corte!.estaAbierta;

  factory CajaActiva.fromJson(Map<String, dynamic> json) {
    final corte = json['corte'];
    return CajaActiva(
      corte: corte == null ? null : CorteCaja.fromJson(corte),
      totalVentas: ((json['total_ventas'] as num?) ?? 0).toDouble(),
      montoEsperado: ((json['monto_esperado'] as num?) ?? 0).toDouble(),
    );
  }
}
