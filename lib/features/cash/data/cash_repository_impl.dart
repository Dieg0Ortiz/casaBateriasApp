import '../domain/cash_models.dart';
import '../domain/cash_repository.dart';
import 'cash_remote_data_source.dart';

class CashRepositoryImpl implements CashRepository {
  CashRepositoryImpl({CashRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? CashRemoteDataSource();

  final CashRemoteDataSource _dataSource;

  @override
  Future<CajaActiva> obtenerActiva() => _dataSource.obtenerActiva();

  @override
  Future<List<CorteCaja>> historial() => _dataSource.historial();

  @override
  Future<CorteCaja> abrir({required double montoInicial}) {
    return _dataSource.abrir(montoInicial: montoInicial);
  }

  @override
  Future<CorteCaja> cerrar({
    required String corteId,
    required double montoFinal,
  }) {
    return _dataSource.cerrar(corteId: corteId, montoFinal: montoFinal);
  }
}
