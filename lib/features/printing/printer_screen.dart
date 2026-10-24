import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter/material.dart';

import 'printer_service.dart';

/// Arma los bytes del documento y, si la hay, de su segunda copia.
Future<List<int>> _armarDocumento(
  Future<List<int>> Function() construir,
  Future<List<int>> Function()? construirCopia,
) async {
  try {
    final bytes = await construir();
    if (construirCopia == null || bytes.isEmpty) return bytes;
    return [...bytes, ...await construirCopia()];
  } catch (_) {
    return const <int>[];
  }
}

/// Imprime directo en la impresora guardada, sin escanear ni elegir. Solo
/// abre la pantalla para elegir impresora si no hay una guardada o si la
/// guardada no responde (apagada, sin papel, fuera de alcance). Devuelve
/// true si el papel salió.
Future<bool> imprimirDocumento(
  BuildContext context, {
  required String titulo,
  required Future<List<int>> Function() construir,
  Future<List<int>> Function()? construirCopia,
}) async {
  final servicio = PrinterService.instance;
  final guardada = await servicio.impresoraGuardada();
  if (!context.mounted) return false;

  if (guardada != null) {
    final nombre = guardada.name.isEmpty ? 'la impresora' : guardada.name;
    final navigator = Navigator.of(context, rootNavigator: true);
    final mensajero = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text('Imprimiendo $titulo en $nombre…')),
            ],
          ),
        ),
      ),
    );

    var impreso = false;
    try {
      final bytes = await _armarDocumento(construir, construirCopia);
      impreso = await servicio.imprimir(
        guardada,
        bytes,
        timeout: const Duration(seconds: 12),
      );
    } finally {
      navigator.pop();
    }

    if (impreso) {
      mensajero.showSnackBar(
        SnackBar(content: Text('Listo: se imprimió en $nombre')),
      );
      return true;
    }
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          'No respondió $nombre. Revisa que esté encendida y con papel, o elige otra.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  if (!context.mounted) return false;
  final impreso = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ImpresoraScreen(
        titulo: titulo,
        construir: construir,
        construirCopia: construirCopia,
      ),
    ),
  );
  return impreso == true;
}

/// Pantalla para imprimir en una impresora térmica Bluetooth (Fase 9).
/// La impresora con la que se imprime bien queda guardada para las
/// siguientes impresiones. Implementa el diseño "Ultramarine Industrial".
class ImpresoraScreen extends StatefulWidget {
  const ImpresoraScreen({
    super.key,
    required this.titulo,
    required this.construir,
    this.construirCopia,
  });

  /// Título del documento a imprimir (ej. "Ticket de venta").
  final String titulo;

  /// Genera los bytes ESC/POS del documento a imprimir.
  final Future<List<int>> Function() construir;

  /// Si se informa, se imprime un segundo papel (la copia del comercio) en
  /// la misma conexión, sin volver a elegir impresora.
  final Future<List<int>> Function()? construirCopia;

  @override
  State<ImpresoraScreen> createState() => _ImpresoraScreenState();
}

class _ImpresoraScreenState extends State<ImpresoraScreen> {
  final _servicio = PrinterService.instance;

  bool _escaneando = false;
  bool _conectando = false;
  bool _imprimiendo = false;
  String? _mensaje;
  List<BluetoothDevice> _dispositivos = [];
  BluetoothDevice? _seleccionado;
  BluetoothDevice? _guardada;

  @override
  void initState() {
    super.initState();
    _cargarGuardada();
    _iniciar();
  }

  Future<void> _cargarGuardada() async {
    final guardada = await _servicio.impresoraGuardada();
    if (mounted) setState(() => _guardada = guardada);
  }

  Future<void> _olvidarGuardada() async {
    await _servicio.olvidarImpresora();
    if (mounted) setState(() => _guardada = null);
  }

  Future<void> _iniciar() async {
    if (!_servicio.bluetoothActivo) {
      setState(() {
        _mensaje = 'Activa el Bluetooth del teléfono y vuelve a intentar.';
      });
      return;
    }
    await _escanear();
  }

  Future<void> _escanear() async {
    setState(() {
      _escaneando = true;
      _mensaje = null;
      _dispositivos = [];
      _seleccionado = null;
    });
    try {
      final encontrados = await _servicio.escanear();
      if (!mounted) return;
      setState(() {
        _dispositivos = encontrados;
        _mensaje = encontrados.isEmpty
            ? 'No se encontraron impresoras. '
                'Verifica que estén encendidas y cerca, y vuelve a escanear.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = 'No se pudo escanear. '
            'Asegúrate de aceptar el permiso de Bluetooth.';
      });
    } finally {
      if (mounted) setState(() => _escaneando = false);
    }
  }

  Future<void> _imprimir(BluetoothDevice dispositivo) async {
    setState(() {
      _seleccionado = dispositivo;
      _conectando = true;
      _mensaje = null;
    });

    final conectado = await _servicio.conectar(dispositivo);
    if (!mounted) return;

    if (!conectado) {
      setState(() {
        _conectando = false;
        _mensaje =
            'No se pudo conectar con ${dispositivo.name}. Intenta de nuevo.';
      });
      return;
    }

    setState(() {
      _conectando = false;
      _imprimiendo = true;
    });

    final bytes = await _armarDocumento(widget.construir, widget.construirCopia);

    final ok = bytes.isNotEmpty && await _servicio.escribir(bytes);
    await _servicio.desconectar();
    if (ok) {
      // Los siguientes tickets salen directo a esta impresora.
      await _servicio.guardarImpresora(dispositivo);
    }
    if (!mounted) return;

    setState(() => _imprimiendo = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _mensaje = 'No se pudo imprimir en ${dispositivo.name}. '
            'Verifica que el papel esté cargado y que la impresora esté lista.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Impresora Térmica · ${widget.titulo}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.print_rounded, color: colors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Impresión ESC/POS 58mm',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Selecciona una terminal Bluetooth vinculada',
                          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_guardada != null)
            Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: ListTile(
                leading: Icon(Icons.star_rounded, color: colors.primary),
                title: Text(
                  _guardada!.name.isEmpty ? 'Impresora guardada' : _guardada!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Los tickets salen directo a esta impresora. Si eliges otra, se guarda la nueva.',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: _imprimiendo ? null : _olvidarGuardada,
                  child: const Text('Olvidar'),
                ),
              ),
            ),
          if (!_servicio.bluetoothActivo)
            _Mensaje(
              texto: 'El Bluetooth está apagado. Actívalo y toca «Escanear».',
              onReintentar: _escanear,
              textoBoton: 'Reintentar',
            )
          else if (_mensaje != null)
            _Mensaje(
              texto: _mensaje!,
              onReintentar: _escanear,
              textoBoton: 'Escanear de nuevo',
            ),
          if (_escaneando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Buscando impresoras cercanas…'),
                  ],
                ),
              ),
            ),
          if (!_escaneando && _mensaje == null)
            ..._dispositivos.map(
              (d) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bluetooth_connected_rounded, size: 20),
                  ),
                  title: Text(
                    d.name.isEmpty ? 'Impresora Bluetooth' : d.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    d.address,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  trailing: _imprimiendo && _seleccionado?.address == d.address
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.chevron_right),
                  enabled: !_conectando && !_imprimiendo,
                  onTap: () => _imprimir(d),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              minimumSize: const Size(double.infinity, 54),
            ),
            onPressed: _escaneando || _imprimiendo ? null : _escanear,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Escanear Dispositivos'),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.texto,
    required this.onReintentar,
    required this.textoBoton,
  });

  final String texto;
  final VoidCallback onReintentar;
  final String textoBoton;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: colors.error,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onReintentar,
              child: Text(textoBoton),
            ),
          ],
        ),
      ),
    );
  }
}
