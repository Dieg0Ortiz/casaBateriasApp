import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla a pantalla completa del escáner para códigos de barras 1D (UPC-A, EAN-13, etc.)
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _resuelto = false;
  bool _linternaEncendida = false;
  late AnimationController _animController;
  late Animation<double> _laserAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnim = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _resuelto = false;
        _controller?.start();
        break;
      case AppLifecycleState.inactive:
        _controller?.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture captura) {
    if (_resuelto) return;
    final raw = captura.barcodes.isNotEmpty
        ? captura.barcodes.first.rawValue
        : null;
    if (raw == null || raw.trim().isEmpty) return;
    
    _resuelto = true;
    _controller?.stop();
    Navigator.of(context).pop(raw.trim());
  }

  Future<void> _toggleLinterna() async {
    if (_controller == null) return;
    try {
      await _controller!.toggleTorch();
      setState(() {
        _linternaEncendida = !_linternaEncendida;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final boxWidth = math.min(size.width * 0.85, 330.0);
    const boxHeight = 160.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Escanear Código de Barras',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _linternaEncendida ? 'Apagar flash' : 'Encender flash',
            icon: Icon(
              _linternaEncendida ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _linternaEncendida ? const Color(0xFFFBBF24) : Colors.white70,
            ),
            onPressed: _toggleLinterna,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return _MensajeError(
                mensaje: _mensajeDe(error),
                onReintentar: () => _controller?.start(),
              );
            },
          ),

          // Viewfinder Overly con máscara oscura alrededor
          CustomPaint(
            size: Size.infinite,
            painter: _BarcodeScannerOverlayPainter(
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              borderColor: colors.primary,
            ),
          ),

          // Láser animado horizontal
          Center(
            child: SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: AnimatedBuilder(
                animation: _laserAnim,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0, (_laserAnim.value * 2) - 1),
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.withValues(alpha: 0.1),
                            Colors.redAccent,
                            Colors.redAccent.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Instrucciones superiores
          Positioned(
            left: 20,
            right: 20,
            top: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Apunta al código de barras de la batería',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Subtítulo inferior
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Center(
              child: Text(
                'Soporta códigos UPC-A (12 dígitos), EAN-13 y estándar 1D',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mensajeDe(MobileScannerException e) {
    if (e.errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'Sin permiso de cámara. Actívalo en los ajustes del dispositivo.';
    }
    if (e.errorCode == MobileScannerErrorCode.unsupported) {
      return 'La cámara no está disponible en este dispositivo.';
    }
    return 'No se pudo iniciar la cámara.';
  }
}

class _BarcodeScannerOverlayPainter extends CustomPainter {
  _BarcodeScannerOverlayPainter({
    required this.boxWidth,
    required this.boxHeight,
    required this.borderColor,
  });

  final double boxWidth;
  final double boxHeight;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - boxWidth) / 2;
    final top = (size.height - boxHeight) / 2;
    final rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

    // Fondo oscurecido
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(overlayPath, darkPaint);

    // Bordes esquineros del visor
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const radius = 16.0;

    // Esquina Superior Izquierda
    final tlPath = Path()
      ..moveTo(left, top + cornerLength)
      ..lineTo(left, top + radius)
      ..arcToPoint(Offset(left + radius, top), radius: const Radius.circular(radius))
      ..lineTo(left + cornerLength, top);
    canvas.drawPath(tlPath, borderPaint);

    // Esquina Superior Derecha
    final trPath = Path()
      ..moveTo(left + boxWidth - cornerLength, top)
      ..lineTo(left + boxWidth - radius, top)
      ..arcToPoint(Offset(left + boxWidth, top + radius), radius: const Radius.circular(radius))
      ..lineTo(left + boxWidth, top + cornerLength);
    canvas.drawPath(trPath, borderPaint);

    // Esquina Inferior Izquierda
    final blPath = Path()
      ..moveTo(left, top + boxHeight - cornerLength)
      ..lineTo(left, top + boxHeight - radius)
      ..arcToPoint(Offset(left + radius, top + boxHeight), radius: const Radius.circular(radius))
      ..lineTo(left + cornerLength, top + boxHeight);
    canvas.drawPath(blPath, borderPaint);

    // Esquina Inferior Derecha
    final brPath = Path()
      ..moveTo(left + boxWidth - cornerLength, top + boxHeight)
      ..lineTo(left + boxWidth - radius, top + boxHeight)
      ..arcToPoint(Offset(left + boxWidth, top + boxHeight - radius), radius: const Radius.circular(radius))
      ..lineTo(left + boxWidth, top + boxHeight - cornerLength);
    canvas.drawPath(brPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BarcodeScannerOverlayPainter oldDelegate) {
    return oldDelegate.boxWidth != boxWidth ||
        oldDelegate.boxHeight != boxHeight ||
        oldDelegate.borderColor != borderColor;
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48, color: Colors.white70),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
