import '../../../core/utils/date_formatters.dart';
import '../../printing/print_models.dart';
import '../../printing/ticket_builder.dart';

/// Lo que lleva el papel de una reimpresión autorizada, con clave en la
/// caja o desde el panel: la venta tal como se cobró, más quién autorizó.
class TicketReimpresion {
  TicketReimpresion({
    required this.numero,
    required this.autorizo,
    required this.motivo,
    required this.folio,
    required this.total,
    required this.vendidaEn,
    required this.metodoPago,
    required this.desglose,
    required this.sucursal,
    required this.direccion,
    required this.leyenda,
    required this.empleado,
    required this.lineas,
  });

  final int numero;
  final String autorizo;
  final String motivo;
  final String folio;
  final double total;
  final DateTime? vendidaEn;
  final String metodoPago;
  final List<PagoTicket> desglose;
  final String sucursal;
  final String? direccion;
  final String? leyenda;
  final String? empleado;
  final List<LineaTicket> lineas;

  factory TicketReimpresion.fromJson(Map<String, dynamic> json) {
    final venta = json['venta'] as Map<String, dynamic>? ?? {};
    final items = (venta['items'] as List<dynamic>? ?? []);
    return TicketReimpresion(
      numero: (json['numero'] as num?)?.toInt() ?? 1,
      autorizo: json['autorizo'] as String? ?? '',
      motivo: json['motivo'] as String? ?? '',
      folio: venta['folio'] as String? ?? '',
      total: (venta['total'] as num?)?.toDouble() ?? 0,
      vendidaEn: DateTime.tryParse(venta['created_at'] as String? ?? ''),
      metodoPago: nombreMetodoPago(venta['metodo_pago'] as String? ?? 'efectivo'),
      desglose: (venta['desglose_pago'] is List ? venta['desglose_pago'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (p) => PagoTicket(
              nombreMetodoPago(p['metodo'] as String? ?? ''),
              (p['monto'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
      sucursal: venta['sucursal'] as String? ?? '',
      direccion: venta['direccion'] as String?,
      leyenda: venta['leyenda_ticket'] as String?,
      empleado: venta['empleado'] as String?,
      lineas: items.map((raw) {
        final item = raw as Map<String, dynamic>;
        return LineaTicket(
          marca: item['marca'] as String?,
          modelo: item['modelo'] as String? ?? 'Producto',
          cantidad: (item['cantidad'] as num?)?.toInt() ?? 1,
          precio: (item['precio_unitario'] as num?)?.toDouble() ?? 0,
          conCasco: item['con_casco'] as bool?,
          tipoPrecio: item['tipo_precio'] as String?,
          comisionCasco: (item['comision_casco'] as num?)?.toDouble(),
        );
      }).toList(),
    );
  }

  /// Papel marcado como reimpresión, con la garantía de la sucursal.
  Future<List<int>> construir() {
    return TicketBuilder().ticket(
      DatosTicket(
        encabezado: 'CASA BATERIAS',
        sucursal: sucursal,
        direccionSucursal: direccion,
        propietario: 'Joaquin Gabriel Estrada Marquez',
        rfc: 'EAMJ-760228-E21',
        folio: folio,
        fecha: formatFechaHora(vendidaEn),
        empleado: empleado,
        metodoPago: metodoPago,
        desglosePago: desglose,
        leyenda: leyenda,
        lineas: lineas,
        total: total,
        reimpresionNumero: numero,
        reimpresionAutorizo: autorizo,
        reimpresionMotivo: motivo,
      ),
    );
  }
}
