/// Configuración de la app. Los valores se inyectan en build time con
/// `--dart-define` y nunca se compilan datos sensibles.
class AppConfig {
  AppConfig._();

  // La app apunta por defecto al API desplegado en Railway. Para desarrollo
  // local (emulador) se sobreescribe con --dart-define=API_URL=http://10.0.2.2:3000.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://casa-baterias-erp-api-production.up.railway.app',
  );

  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'production',
  );

  /// La app no debe mostrar ni guardar nunca precios o datos sensibles
  /// fuera del servidor.
  static bool get esProduccion => environment == 'production';
}
