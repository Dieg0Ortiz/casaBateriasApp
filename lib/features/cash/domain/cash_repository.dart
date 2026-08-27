import 'cash_models.dart';

/// Contrato de caja. El servidor valida aperturas dobles, calcula el monto
/// esperado con las ventas activas y entrega la diferencia al cerrar
/// (RPCs abrir_caja/cerrar_caja).
abstract class CashRepository {
  /// Caja abierta del usuario con el acumulado de ventas del turno.
  Future<CajaActiva> obtenerActiva();

  /// Historial de cortes del usuario (más reciente primero).
  Future<List<CorteCaja>> historial();

  /// Abre la caja con el efectivo inicial reportado.
  Future<CorteCaja> abrir({required double montoInicial});

  /// Cierra la caja; [corteId] es el corte activo y [montoFinal] el
  /// efectivo reportado por el cajero.
  Future<CorteCaja> cerrar({
    required String corteId,
    required double montoFinal,
  });
}
