import '../domain/intercambio_models.dart';
import '../domain/intercambios_repository.dart';
import 'intercambios_remote_data_source.dart';

class IntercambiosRepositoryImpl implements IntercambiosRepository {
  IntercambiosRepositoryImpl({IntercambiosRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? IntercambiosRemoteDataSource();

  final IntercambiosRemoteDataSource _remoteDataSource;

  @override
  Future<List<IntercambioCasco>> listarIntercambios() => _remoteDataSource.listarIntercambios();

  @override
  Future<IntercambioCasco> obtenerIntercambio(String id) => _remoteDataSource.obtenerIntercambio(id);

  @override
  Future<dynamic> registrarIntercambio(RegistrarIntercambioInput input) =>
      _remoteDataSource.registrarIntercambio(input);
}
