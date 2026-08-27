import 'sales_models.dart';

/// Contrato del punto de venta. El servidor valida stock, toma el precio
/// vigente, aplica la regla de casco y genera el folio (RPC registrar_venta).
abstract class SalesRepository {
  Future<VentaResultado> registrarVenta({
    required String sucursalId,
    required List<LineaVenta> items,
    String? corteCajaId,
    String metodoPago = 'efectivo',
    List<PagoParcial>? desglosePago,
    String? empresaCreditoId,
    String? creditoRecibidoPor,
    String? creditoVehiculoPlacas,
    String? creditoFolioVale,
  });
}
