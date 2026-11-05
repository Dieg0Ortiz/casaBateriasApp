import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio de impresión térmica Bluetooth (Fase 9). Encapsula
/// `bluetooth_print_plus` (Bluetooth Classic) para que las pantallas no
/// dependan del plugin directamente.
///
/// Recuerda la última impresora que imprimió bien: los tickets siguientes
/// salen directo a ella, sin volver a buscar ni elegir.
class PrinterService {
  PrinterService._();

  static final PrinterService instance = PrinterService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _claveImpresora = 'impresora_tickets';

  /// Pide los permisos de Bluetooth. Se reemplaza en las pruebas.
  @visibleForTesting
  Future<bool> Function() pedirPermisos = _pedirPermisos;

  /// Tiempo para que la impresora reciba los datos antes de cerrar la
  /// conexión. Se reemplaza en las pruebas.
  @visibleForTesting
  Duration Function(int bytes) esperaDeEnvio = _esperaDeEnvio;

  /// Apertura del canal de estado del plugin, una sola por ejecución.
  Future<bool>? _canalListo;

  bool get bluetoothActivo => BluetoothPrintPlus.isBlueOn;

  bool get conectado => BluetoothPrintPlus.isConnected;

  /// Escanea dispositivos Bluetooth por [duracion] segundos. Devuelve los
  /// encontrados; lanza [TimeoutException] si no se completa.
  Future<List<BluetoothDevice>> escanear({
    Duration duracion = const Duration(seconds: 12),
  }) async {
    final resultados = await BluetoothPrintPlus.startScan(timeout: duracion)
        .timeout(duracion + const Duration(seconds: 30));
    final lista = resultados as List;
    return lista
        .whereType<BluetoothDevice>()
        .toSet()
        .toList(growable: false);
  }

  /// Deja el plugin listo para conectar. Hay que llamarlo antes de cualquier
  /// conexión: el plugin solo abre su canal de estado dentro de `startScan`,
  /// y si conecta sin él, su código nativo avisa a un canal nulo y Android
  /// cierra la app. Un escaneo mínimo basta para abrirlo. Antes se piden los
  /// permisos, porque negarlos dentro del escaneo del plugin también la cierra.
  Future<bool> prepararBluetooth() async {
    if (!await pedirPermisos()) return false;
    return _canalListo ??= _abrirCanal();
  }

  Future<bool> _abrirCanal() async {
    try {
      await BluetoothPrintPlus.startScan(
        timeout: const Duration(milliseconds: 400),
      );
      return true;
    } catch (_) {
      _canalListo = null;
      return false;
    }
  }

  static Future<bool> _pedirPermisos() async {
    if (!Platform.isAndroid) return true;
    final permisos = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    // La ubicación solo hace falta para buscar impresoras en Android 11 o
    // anterior; sin ella se puede imprimir en la impresora guardada.
    return permisos[Permission.bluetoothScan]?.isGranted == true &&
        permisos[Permission.bluetoothConnect]?.isGranted == true;
  }

  /// Conecta con [dispositivo] y espera hasta [timeout] a que la conexión
  /// quede establecida. Devuelve false si falla o expira el tiempo.
  Future<bool> conectar(
    BluetoothDevice dispositivo, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!await prepararBluetooth()) return false;
    // Cerrar el puerto no avisa de la desconexión: el plugin puede seguir
    // diciendo "conectado" por la impresión anterior. Por eso se cierra
    // siempre y se ignora el valor que el stream repite al escucharlo.
    await desconectar();
    final conectado = Completer<bool>();
    final sub = BluetoothPrintPlus.connectState.skip(1).listen((estado) {
      if (estado == ConnectState.connected && !conectado.isCompleted) {
        conectado.complete(true);
      }
    });
    try {
      await BluetoothPrintPlus.connect(dispositivo);
      await conectado.future.timeout(timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      sub.cancel();
    }
  }

  /// Envía [bytes] a la impresora conectada. Devuelve false si falla.
  Future<bool> escribir(List<int> bytes) async {
    try {
      await BluetoothPrintPlus.write(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Envía [bytes] y espera a que la impresora los reciba. Devuelve false si
  /// la conexión se cae en el camino. El plugin no regresa si la escritura
  /// falló, pero sí avisa que se desconectó.
  Future<bool> enviar(List<int> bytes) async {
    var seCayo = false;
    final sub = BluetoothPrintPlus.connectState.skip(1).listen((estado) {
      if (estado == ConnectState.disconnected) seCayo = true;
    });
    try {
      final ok = await escribir(bytes);
      if (ok) await Future<void>.delayed(esperaDeEnvio(bytes.length));
      return ok && !seCayo;
    } finally {
      await sub.cancel();
    }
  }

  // Unos 2 KB por segundo, lo que aguanta una térmica portátil. Cerrar antes
  // tira lo que siga en camino y el ticket no sale o sale cortado.
  static Duration _esperaDeEnvio(int bytes) =>
      Duration(milliseconds: (800 + bytes ~/ 2).clamp(800, 6000));

  Future<void> desconectar() async {
    try {
      await BluetoothPrintPlus.disconnect();
    } catch (_) {
      // No importa si ya estaba desconectado.
    }
  }

  /// Conecta, imprime y desconecta. Se desconecta siempre: la impresora de
  /// la sucursal la comparten varios teléfonos y solo acepta una conexión.
  Future<bool> imprimir(
    BluetoothDevice dispositivo,
    List<int> bytes, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (bytes.isEmpty) return false;
    final conectado = await conectar(dispositivo, timeout: timeout);
    if (!conectado) return false;
    final ok = await enviar(bytes);
    await desconectar();
    return ok;
  }

  /// Impresora que se usa sin preguntar, o null si no hay una guardada.
  Future<BluetoothDevice?> impresoraGuardada() async {
    try {
      final raw = await _storage.read(key: _claveImpresora);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final address = json['address'] as String?;
      if (address == null || address.isEmpty) return null;
      return BluetoothDevice(json['name'] as String? ?? '', address)
        ..type = (json['type'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarImpresora(BluetoothDevice dispositivo) async {
    try {
      await _storage.write(
        key: _claveImpresora,
        value: jsonEncode(dispositivo.toJson()),
      );
    } catch (_) {
      // Si no se puede guardar, la próxima vez se vuelve a elegir.
    }
  }

  Future<void> olvidarImpresora() async {
    try {
      await _storage.delete(key: _claveImpresora);
    } catch (_) {
      // Nada que olvidar.
    }
  }
}
