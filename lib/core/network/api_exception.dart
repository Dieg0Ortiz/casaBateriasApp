/// Excepciones tipadas del API. El ViewModel solo conoce mensajes simples
/// para mostrar al usuario final.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.tipo = 'error'});

  final String message;
  final int? statusCode;
  final String tipo;

  bool get esNoAutorizado => statusCode == 401;

  bool get esProhibido => statusCode == 403;

  bool get esSinRed => statusCode == null;

  @override
  String toString() => message;
}
