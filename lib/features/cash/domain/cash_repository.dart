import 'cash_models.dart';

/// Contrato de caja. El servidor valida aperturas dobles, calcula el corte
/// de efectivo y el de tarjetas y transferencias, y entrega la diferencia al
/// cerrar (RPCs abrir_caja/cerrar_caja/resumen_corte).
abstract class CashRepository {
  /// Caja abierta de la sucursal con el resumen del turno.
  Future<CajaActiva> obtenerActiva();

  /// Historial de cortes de la sucursal (más reciente primero).
  Future<List<CorteCaja>> historial();

  /// Abre la caja con el efectivo inicial reportado.
  Future<CorteCaja> abrir({required double montoInicial});

  /// Cierra la caja; [corteId] es el corte activo y [montoFinal] el
  /// efectivo contado por el cajero.
  Future<CorteCaja> cerrar({
    required String corteId,
    required double montoFinal,
  });

  /// Resumen de un corte (abierto o cerrado), para verlo o reimprimirlo.
  Future<ResumenCorte> resumen(String corteId);
}
