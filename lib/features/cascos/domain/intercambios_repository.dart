import 'intercambio_models.dart';

abstract class IntercambiosRepository {
  Future<List<IntercambioCasco>> listarIntercambios();
  Future<IntercambioCasco> obtenerIntercambio(String id);
  Future<dynamic> registrarIntercambio(RegistrarIntercambioInput input);
}
