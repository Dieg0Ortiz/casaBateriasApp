import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/core/network/api_client.dart';
import 'package:casabateriaserp/features/printing/printer_service.dart';

import 'support/plugin_impresora_falso.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final plugin = PluginFalso();
  final impresora = BluetoothDevice('Termica', 'AA:BB:CC:DD:EE:FF');

  setUp(() {
    plugin.instalar();
    plugin.llamadas.clear();
    plugin.escrituras.clear();
    plugin.impresoraResponde = true;
    plugin.caerAlEscribir = false;
    PrinterService.instance.pedirPermisos = () async => true;
    PrinterService.instance.esperaDeEnvio = (_) => Duration.zero;
    FlutterSecureStorage.setMockInitialValues({
      'impresora_tickets':
          '{"name":"Termica","address":"AA:BB:CC:DD:EE:FF","type":1}',
    });
  });

  // Va primero a propósito: el plugin solo abre su canal una vez por
  // ejecución, y este es el caso de la app recién abierta.
  test('con la app recién abierta, el canal se abre antes de conectar', () async {
    final ok = await PrinterService.instance.imprimir(impresora, [1, 2, 3]);

    expect(plugin.cierresDeApp, 0);
    expect(ok, isTrue);
    expect(plugin.llamadas.indexOf('startScan'), lessThan(plugin.llamadas.indexOf('connect')));
    expect(plugin.escrituras.single, [1, 2, 3]);
    expect(plugin.llamadas.last, 'disconnect');
  });

  test('imprimir dos veces no toma por buena la conexión anterior', () async {
    // Cerrar el puerto no avisa: el plugin sigue diciendo "conectado".
    expect(BluetoothPrintPlus.isConnected, isTrue);
    plugin.impresoraResponde = false;

    final ok = await PrinterService.instance.imprimir(
      impresora,
      [1],
      timeout: const Duration(milliseconds: 200),
    );

    expect(ok, isFalse);
    expect(plugin.escrituras, isEmpty);
  });

  test('si la conexión se cae al escribir, se reporta como fallida', () async {
    plugin.caerAlEscribir = true;
    expect(await PrinterService.instance.imprimir(impresora, [1]), isFalse);
  });

  test('sin permiso de Bluetooth no toca el plugin', () async {
    PrinterService.instance.pedirPermisos = () async => false;

    expect(await PrinterService.instance.conectar(impresora), isFalse);
    expect(plugin.llamadas, isEmpty);
  });

  group('la sesión solo termina si el servidor la rechaza', () {
    final peticion = RequestOptions(path: '/api/v1/auth/refresh');

    test('sin señal no se cierra', () {
      final error = DioException(
        requestOptions: peticion,
        type: DioExceptionType.connectionError,
      );
      expect(ApiClient.sesionRechazada(error), isFalse);
    });

    test('un error del servidor no la cierra', () {
      final error = DioException(
        requestOptions: peticion,
        response: Response(requestOptions: peticion, statusCode: 502),
      );
      expect(ApiClient.sesionRechazada(error), isFalse);
    });

    test('un refresh token vencido sí', () {
      final error = DioException(
        requestOptions: peticion,
        response: Response(requestOptions: peticion, statusCode: 401),
      );
      expect(ApiClient.sesionRechazada(error), isTrue);
    });
  });
}
