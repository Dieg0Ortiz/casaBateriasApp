/// Autorización a distancia: la caja pide y un administrador aprueba o
/// rechaza desde el panel. Al aprobar, la acción ya quedó hecha en el
/// servidor; la caja solo imprime lo que corresponda.
library;

enum TipoSolicitud {
  reimpresion('reimpresion', 'Reimprimir ticket'),
  cancelacion('cancelacion', 'Cancelar ticket'),
  devolucionBateria('devolucion_bateria', 'Devolver batería');

  const TipoSolicitud(this.api, this.titulo);

  final String api;
  final String titulo;

  static TipoSolicitud desdeApi(String? valor) =>
      values.firstWhere((t) => t.api == valor, orElse: () => reimpresion);
}

enum EstadoSolicitud {
  pendiente('Esperando al administrador'),
  aprobada('Aprobada'),
  rechazada('Rechazada'),
  retirada('Retirada');

  const EstadoSolicitud(this.texto);

  final String texto;

  static EstadoSolicitud desdeApi(String? valor) =>
      values.firstWhere((e) => e.name == valor, orElse: () => pendiente);
}

class SolicitudAutorizacion {
  const SolicitudAutorizacion({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.folio,
    required this.motivo,
    this.creadaEn,
    this.notaResolucion,
    this.autorizador,
    this.impresaEn,
    this.montoDevolucion,
    this.resultado,
    this.ticket,
  });

  final String id;
  final TipoSolicitud tipo;
  final EstadoSolicitud estado;
  final String folio;
  final String motivo;
  final DateTime? creadaEn;
  final String? notaResolucion;
  final String? autorizador;
  final DateTime? impresaEn;

  /// En una devolución de batería, cuánto se entrega al cliente.
  final double? montoDevolucion;

  /// Lo que produjo la aprobación; en la devolución, la devolución completa
  /// (folio DEV) lista para imprimir el comprobante.
  final Map<String, dynamic>? resultado;

  /// Reimpresión aprobada y sin imprimir: los datos del papel.
  final Map<String, dynamic>? ticket;

  bool get pendiente => estado == EstadoSolicitud.pendiente;

  bool get reimpresionPorImprimir =>
      tipo == TipoSolicitud.reimpresion &&
      estado == EstadoSolicitud.aprobada &&
      impresaEn == null &&
      ticket != null;

  factory SolicitudAutorizacion.fromJson(Map<String, dynamic> json) {
    final devolucion = json['devolucion'];
    final resultado = json['resultado'];
    final ticket = json['ticket'];
    return SolicitudAutorizacion(
      id: json['id'] as String? ?? '',
      tipo: TipoSolicitud.desdeApi(json['tipo'] as String?),
      estado: EstadoSolicitud.desdeApi(json['estado'] as String?),
      folio: json['folio'] as String? ?? '',
      motivo: json['motivo'] as String? ?? '',
      creadaEn: DateTime.tryParse(json['created_at'] as String? ?? ''),
      notaResolucion: json['nota_resolucion'] as String?,
      autorizador: json['autorizador'] as String?,
      impresaEn: DateTime.tryParse(json['impresa_en'] as String? ?? ''),
      montoDevolucion: devolucion is Map<String, dynamic>
          ? (devolucion['total'] as num?)?.toDouble()
          : null,
      resultado: resultado is Map<String, dynamic> ? resultado : null,
      ticket: ticket is Map<String, dynamic> ? ticket : null,
    );
  }
}
