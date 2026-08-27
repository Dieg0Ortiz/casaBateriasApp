import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';
import 'sales_remote_data_source.dart';

class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl({SalesRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? SalesRemoteDataSource();

  final SalesRemoteDataSource _dataSource;

  @override
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
  }) {
    return _dataSource.registrarVenta(
      sucursalId: sucursalId,
      items: items,
      corteCajaId: corteCajaId,
      metodoPago: metodoPago,
      desglosePago: desglosePago,
      empresaCreditoId: empresaCreditoId,
      creditoRecibidoPor: creditoRecibidoPor,
      creditoVehiculoPlacas: creditoVehiculoPlacas,
      creditoFolioVale: creditoFolioVale,
    );
  }
}
