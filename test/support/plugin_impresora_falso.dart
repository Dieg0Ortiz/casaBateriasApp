import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Imita el lado nativo del plugin: al conectar avisa por el canal de estado.
/// Si ese canal no se abrió, el plugin real truena con un nulo y Android
/// cierra la app; aquí queda en [cierresDeApp].
class PluginFalso implements MockStreamHandler {
  MockStreamHandlerEventSink? sink;
  final llamadas = <String>[];
  final escrituras = <Uint8List>[];
  int cierresDeApp = 0;
  bool impresoraResponde = true;
  bool caerAlEscribir = false;

  void instalar() {
    final mensajero =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    mensajero.setMockMethodCallHandler(
      const MethodChannel('bluetooth_print_plus/methods'),
      (llamada) async {
        llamadas.add(llamada.method);
        switch (llamada.method) {
          case 'state':
            return 0;
          case 'connect':
            if (!impresoraResponde) return null;
            if (sink == null) {
              cierresDeApp++;
            } else {
              sink!.success(2);
            }
            return null;
          case 'write':
            final datos = (llamada.arguments as Map)['data'] as Uint8List;
            escrituras.add(datos);
            if (caerAlEscribir) sink?.success(3);
            return true;
          default:
            return null;
        }
      },
    );
    mensajero.setMockStreamHandler(
      const EventChannel('bluetooth_print_plus/state'),
      this,
    );
  }

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    sink = events;
  }

  @override
  void onCancel(Object? arguments) {
    sink = null;
  }
}
