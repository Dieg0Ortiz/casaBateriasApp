import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';

/// Servicio de impresión térmica Bluetooth (Fase 9). Encapsula
/// `bluetooth_print_plus` (Bluetooth Classic) para que las pantallas no
/// dependan del plugin directamente.
class PrinterService {
  PrinterService._();

  static final PrinterService instance = PrinterService._();

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

  /// Conecta con [dispositivo] y espera hasta [timeout] a que la conexión
  /// quede establecida. Devuelve false si falla o expira el tiempo.
  Future<bool> conectar(
    BluetoothDevice dispositivo, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (BluetoothPrintPlus.isConnected) {
      await BluetoothPrintPlus.disconnect();
    }
    final conectado = Completer<bool>();
    final sub = BluetoothPrintPlus.connectState.listen((estado) {
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

  Future<void> desconectar() async {
    try {
      await BluetoothPrintPlus.disconnect();
    } catch (_) {
      // No importa si ya estaba desconectado.
    }
  }
}
