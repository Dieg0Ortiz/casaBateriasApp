import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/sales_models.dart';

/// Acceso a la red para registrar ventas.
class SalesRemoteDataSource {
  SalesRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

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
  }) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/sales',
        data: {
          'sucursal_id': sucursalId,
          'corte_caja_id': corteCajaId,
          'metodo_pago': metodoPago,
          if (desglosePago != null && desglosePago.isNotEmpty)
            'desglose_pago': desglosePago.map((p) => p.toJson()).toList(),
          if (empresaCreditoId != null && empresaCreditoId.isNotEmpty)
            'empresa_credito_id': empresaCreditoId,
          if (creditoRecibidoPor != null && creditoRecibidoPor.isNotEmpty)
            'credito_recibido_por': creditoRecibidoPor,
          if (creditoVehiculoPlacas != null && creditoVehiculoPlacas.isNotEmpty)
            'credito_vehiculo_placas': creditoVehiculoPlacas,
          if (creditoFolioVale != null && creditoFolioVale.isNotEmpty)
            'credito_folio_vale': creditoFolioVale,
          'items': items.map(_itemAJson).toList(),
        },
      ),
    );
    return VentaResultado.fromJson(res!);
  }

  Future<Map<String, dynamic>> autorizarReimpresion({
    required String folio,
    required String motivo,
    required String email,
    required String password,
  }) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/sales/reimpresiones',
        data: {
          'folio': folio,
          'motivo': motivo,
          'email': email,
          'password': password,
        },
      ),
    );
    return res ?? {};
  }

  /// Cancela un ticket con la clave de un administrador. El servidor
  /// regresa las piezas al inventario y saca la venta del corte; solo se
  /// puede mientras el corte de esa venta siga abierto.
  Future<Map<String, dynamic>> cancelarTicket({
    required String folio,
    required String motivo,
    required String email,
    required String password,
  }) async {
    final res = await _pedir<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/sales/cancelaciones',
        data: {
          'folio': folio,
          'motivo': motivo,
          'email': email,
          'password': password,
        },
      ),
    );
    return res ?? {};
  }

  /// Ventas de hoy de la sucursal del usuario (el administrador ve las de
  /// todas), de la más reciente a la más vieja.
  Future<List<VentaDelDia>> ventasDeHoy() async {
    final res = await _pedir<List<dynamic>>(
      () => _dio.get<List<dynamic>>('/api/v1/sales/hoy'),
    );
    return (res ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VentaDelDia.fromJson)
        .toList();
  }

  Map<String, dynamic> _itemAJson(LineaVenta linea) {
    return {
      'producto_id': linea.productoId,
      'cantidad': linea.cantidad,
      'tipo_precio': linea.tipoPrecio,
      if (linea.tipoPrecio == 'precio_especial') 'precio_unitario': linea.precio,
      if (linea.requiereCasco) 'con_casco': linea.conCasco,
      if (linea.busquedaManual) 'busqueda_manual': true,
      if (linea.nombreCliente != null && linea.nombreCliente!.isNotEmpty)
        'nombre_cliente': linea.nombreCliente,
      if (linea.telefonoCliente != null && linea.telefonoCliente!.isNotEmpty)
        'telefono_cliente': linea.telefonoCliente,
    };
  }

  Future<T?> _pedir<T>(Future<Response<T>> Function() peticion) async {
    try {
      final res = await peticion();
      return res.data;
    } on DioException catch (e) {
      throw desenmascararError(e);
    }
  }
}
