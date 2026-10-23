/// Modelos de caja: corte (apertura/cierre) y acumulado del turno.
/// Los montos siempre los calcula el servidor (resumen_corte): el corte de
/// efectivo, el de tarjetas y transferencias, y las ventas a crédito aparte.
library;

double _num(dynamic valor) => valor is num ? valor.toDouble() : 0;

int _entero(dynamic valor) => valor is num ? valor.toInt() : 0;

Map<String, dynamic> _mapa(dynamic valor) =>
    valor is Map<String, dynamic> ? valor : const {};

DateTime? _fecha(dynamic valor) =>
    valor is String ? DateTime.tryParse(valor) : null;

/// Corte de caja: apertura con [montoInicial] y, al cerrar, el efectivo
/// esperado ([montoCalculado]), el contado y la [diferencia] entre ambos.
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
    this.totalTarjetas,
    this.totalTransferencias,
    this.resumen,
  });

  final String id;
  final String sucursalId;
  final String usuarioId;
  final double montoInicial;
  final String estado;
  final DateTime abiertoEn;
  final double? montoFinalReportado;

  /// Efectivo que debía haber en el cajón al cerrar.
  final double? montoCalculado;
  final double? diferencia;
  final DateTime? cerradoEn;
  final double? totalTarjetas;
  final double? totalTransferencias;

  /// Resumen guardado al cerrar (lo trae la respuesta del cierre).
  final ResumenCorte? resumen;

  bool get estaAbierta => estado == 'abierto';

  factory CorteCaja.fromJson(Map<String, dynamic> json) {
    final resumen = json['resumen'];
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
      totalTarjetas: _toDouble(json['total_tarjetas']),
      totalTransferencias: _toDouble(json['total_transferencias']),
      resumen: resumen is Map<String, dynamic>
          ? ResumenCorte.fromJson(resumen)
          : null,
    );
  }

  static double? _toDouble(dynamic valor) =>
      valor is num ? valor.toDouble() : null;

  static DateTime? _toDateTime(dynamic valor) {
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }
}

/// Caja abierta de la sucursal con el acumulado del turno. [corte] es null
/// cuando no hay caja abierta.
class CajaActiva {
  const CajaActiva({
    required this.corte,
    required this.totalVentas,
    required this.montoEsperado,
    this.resumen,
  });

  final CorteCaja? corte;

  /// Todo lo cobrado en el turno (efectivo, tarjetas y transferencias).
  final double totalVentas;

  /// Efectivo que debe haber en el cajón.
  final double montoEsperado;

  /// Detalle de los dos cortes; null si el servidor no lo manda.
  final ResumenCorte? resumen;

  bool get tieneCajaAbierta => corte != null && corte!.estaAbierta;

  factory CajaActiva.fromJson(Map<String, dynamic> json) {
    final corte = json['corte'];
    final resumen = json['resumen'];
    return CajaActiva(
      corte: corte == null ? null : CorteCaja.fromJson(corte),
      totalVentas: ((json['total_ventas'] as num?) ?? 0).toDouble(),
      montoEsperado: ((json['monto_esperado'] as num?) ?? 0).toDouble(),
      resumen: resumen is Map<String, dynamic>
          ? ResumenCorte.fromJson(resumen)
          : null,
    );
  }
}

/// Corte de efectivo: lo que debe haber en el cajón.
class CorteEfectivo {
  const CorteEfectivo({
    required this.montoInicial,
    required this.ventas,
    required this.ventasCount,
    required this.intercambios,
    required this.abonosCredito,
    required this.devoluciones,
    required this.esperado,
    this.contado,
    this.diferencia,
  });

  final double montoInicial;
  final double ventas;
  final int ventasCount;
  final double intercambios;
  final double abonosCredito;

  /// Devuelto en efectivo (se resta).
  final double devoluciones;
  final double esperado;
  final double? contado;
  final double? diferencia;

  factory CorteEfectivo.fromJson(Map<String, dynamic> json) {
    return CorteEfectivo(
      montoInicial: _num(json['monto_inicial']),
      ventas: _num(json['ventas']),
      ventasCount: _entero(json['ventas_count']),
      intercambios: _num(json['intercambios']),
      abonosCredito: _num(json['abonos_credito']),
      devoluciones: _num(json['devoluciones']),
      esperado: _num(json['esperado']),
      contado: json['contado'] is num ? _num(json['contado']) : null,
      diferencia: json['diferencia'] is num ? _num(json['diferencia']) : null,
    );
  }
}

/// Una operación con tarjeta o transferencia del turno.
class OperacionElectronica {
  const OperacionElectronica({
    required this.metodo,
    required this.monto,
    this.folio,
    this.detalle,
    this.creadoEn,
  });

  final String? folio;
  final String? detalle;
  final String metodo;
  final double monto;
  final DateTime? creadoEn;

  factory OperacionElectronica.fromJson(Map<String, dynamic> json) {
    return OperacionElectronica(
      folio: json['folio'] as String?,
      detalle: json['detalle'] as String?,
      metodo: json['metodo'] as String? ?? '',
      monto: _num(json['monto']),
      creadoEn: _fecha(json['creado_en']),
    );
  }
}

/// Corte de tarjetas y transferencias.
class CorteElectronico {
  const CorteElectronico({
    required this.tarjetaDebito,
    required this.tarjetaCredito,
    required this.tarjetaSinTipo,
    required this.devolucionesTarjeta,
    required this.totalTarjetas,
    required this.transferencias,
    required this.devolucionesTransferencia,
    required this.totalTransferencias,
    required this.total,
    required this.operaciones,
  });

  final double tarjetaDebito;
  final double tarjetaCredito;
  final double tarjetaSinTipo;
  final double devolucionesTarjeta;
  final double totalTarjetas;
  final double transferencias;
  final double devolucionesTransferencia;
  final double totalTransferencias;
  final double total;
  final List<OperacionElectronica> operaciones;

  factory CorteElectronico.fromJson(Map<String, dynamic> json) {
    return CorteElectronico(
      tarjetaDebito: _num(json['tarjeta_debito']),
      tarjetaCredito: _num(json['tarjeta_credito']),
      tarjetaSinTipo: _num(json['tarjeta_sin_tipo']),
      devolucionesTarjeta: _num(json['devoluciones_tarjeta']),
      totalTarjetas: _num(json['total_tarjetas']),
      transferencias: _num(json['transferencias']),
      devolucionesTransferencia: _num(json['devoluciones_transferencia']),
      totalTransferencias: _num(json['total_transferencias']),
      total: _num(json['total']),
      operaciones: (json['operaciones'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OperacionElectronica.fromJson)
          .toList(),
    );
  }
}

/// Venta a crédito del turno: no entra a ningún corte.
class VentaCreditoTurno {
  const VentaCreditoTurno({
    required this.folio,
    required this.empresa,
    required this.total,
    required this.piezas,
  });

  final String folio;
  final String empresa;
  final double total;
  final int piezas;

  factory VentaCreditoTurno.fromJson(Map<String, dynamic> json) {
    return VentaCreditoTurno(
      folio: json['folio'] as String? ?? '',
      empresa: json['empresa'] as String? ?? '',
      total: _num(json['total']),
      piezas: _entero(json['piezas']),
    );
  }
}

/// Resumen completo de un corte, tal como lo arma el servidor.
class ResumenCorte {
  const ResumenCorte({
    required this.corteId,
    required this.estado,
    required this.sucursal,
    required this.efectivo,
    required this.electronico,
    required this.creditosCount,
    required this.creditosTotal,
    required this.creditosPiezas,
    required this.creditos,
    required this.devolucionesCount,
    required this.devolucionesTotal,
    required this.cancelacionesCount,
    required this.cancelacionesTotal,
    this.abiertoEn,
    this.cerradoEn,
    this.abrio,
    this.cerro,
  });

  final String corteId;
  final String estado;
  final String sucursal;
  final DateTime? abiertoEn;
  final DateTime? cerradoEn;
  final String? abrio;
  final String? cerro;
  final CorteEfectivo efectivo;
  final CorteElectronico electronico;
  final int creditosCount;
  final double creditosTotal;
  final int creditosPiezas;
  final List<VentaCreditoTurno> creditos;
  final int devolucionesCount;
  final double devolucionesTotal;
  final int cancelacionesCount;
  final double cancelacionesTotal;

  bool get cerrado => estado == 'cerrado';

  factory ResumenCorte.fromJson(Map<String, dynamic> json) {
    final creditos = _mapa(json['creditos']);
    final devoluciones = _mapa(json['devoluciones']);
    final cancelaciones = _mapa(json['cancelaciones']);
    return ResumenCorte(
      corteId: json['corte_id'] as String? ?? '',
      estado: json['estado'] as String? ?? 'abierto',
      sucursal: json['sucursal'] as String? ?? '',
      abiertoEn: _fecha(json['abierto_en']),
      cerradoEn: _fecha(json['cerrado_en']),
      abrio: json['abrio'] as String?,
      cerro: json['cerro'] as String?,
      efectivo: CorteEfectivo.fromJson(_mapa(json['efectivo'])),
      electronico: CorteElectronico.fromJson(_mapa(json['electronico'])),
      creditosCount: _entero(creditos['ventas_count']),
      creditosTotal: _num(creditos['total']),
      creditosPiezas: _entero(creditos['piezas']),
      creditos: (creditos['ventas'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VentaCreditoTurno.fromJson)
          .toList(),
      devolucionesCount: _entero(devoluciones['count']),
      devolucionesTotal: _num(devoluciones['total']),
      cancelacionesCount: _entero(cancelaciones['count']),
      cancelacionesTotal: _num(cancelaciones['total']),
    );
  }
}
