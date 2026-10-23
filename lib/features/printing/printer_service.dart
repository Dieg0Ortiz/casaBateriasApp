import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    final ok = await escribir(bytes);
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
