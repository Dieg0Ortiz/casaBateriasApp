/// Resultado de la revisión de integridad del dispositivo.
enum DeviceRisk { ok, comprometido, noVerificado }

/// Verifica que el dispositivo no esté comprometido (root / USB debugging)
/// antes de permitir operaciones sensibles (venta).
///
/// La revisión nativa (Kotlin, MethodChannel) se implementa como parte del
/// plan anti-fraude. Si el canal nativo no existe aún, el estado por defecto
/// es [DeviceRisk.noVerificado] y el flujo de venta debe bloquearse hasta
/// verificar, siguiendo el principio "fail-closed".
class DeviceSecurityService {
  DeviceSecurityService._();
  static final DeviceSecurityService instance = DeviceSecurityService._();

  Future<DeviceRisk> checkRisk() async {
    // TODO: ELIMINAR ESTE BYPASS ANTES DE PASAR A PRODUCCIÓN.
    // Bypass temporal para permitir depuración USB durante el desarrollo.
    return DeviceRisk.ok;
  }

  /// La venta solo puede continuar si el dispositivo fue verificado como seguro.
  bool permiteOperaciones(DeviceRisk risk) => risk == DeviceRisk.ok;
}
