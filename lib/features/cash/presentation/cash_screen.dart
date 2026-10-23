import '../../../../core/utils/date_formatters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/security/device_security_service.dart';
import '../../printing/printer_screen.dart';
import '../domain/cash_models.dart';
import 'cash_viewmodel.dart';
import 'corte_tickets.dart';

/// Pantalla de caja: apertura con efectivo inicial, resumen del turno con
/// dos cortes separados (efectivo, y tarjetas y transferencias), las ventas a
/// crédito aparte, y cierre contando solo el efectivo.
/// Implementa el diseño "Ultramarine Industrial".
class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
  final _montoInicialCtrl = TextEditingController();
  final _montoFinalCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DeviceRisk? _riesgo;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _montoInicialCtrl.dispose();
    _montoFinalCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    final riesgo = await DeviceSecurityService.instance.checkRisk();
    if (!mounted) return;
    setState(() => _riesgo = riesgo);
    if (riesgo != DeviceRisk.ok) return;
    await context.read<CashViewModel>().cargar();
  }

  Future<void> _abrirCaja() async {
    final vm = context.read<CashViewModel>();
    if (!_formKey.currentState!.validate()) return;
    final monto = double.parse(_montoInicialCtrl.text.trim());
    await vm.abrir(monto);
    _montoInicialCtrl.clear();
  }

  Future<void> _cerrarCaja() async {
    final vm = context.read<CashViewModel>();
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoCierre(
        montoEsperado: vm.cajaActiva?.montoEsperado ?? 0,
        moneda: _moneda,
        montoFinalCtrl: _montoFinalCtrl,
      ),
    );
    if (resultado != true || !mounted) return;

    final monto = double.parse(_montoFinalCtrl.text.trim());
    _montoFinalCtrl.clear();
    final exito = await vm.cerrar(monto);
    final cierre = vm.ultimoCierre;
    if (!exito || !mounted || cierre == null) return;
    final resumen = cierre.resumen;
    if (resumen != null) {
      await _mostrarCorte(resumen, recienCerrado: true);
    } else {
      await _mostrarResultadoCierre(cierre);
    }
  }

  void _imprimirCorteEfectivo(ResumenCorte r) {
    imprimirDocumento(
      context,
      titulo: 'el corte de efectivo',
      construir: () => ticketCorteEfectivo(r),
    );
  }

  void _imprimirCorteElectronico(ResumenCorte r) {
    imprimirDocumento(
      context,
      titulo: 'el corte de tarjetas y transferencias',
      construir: () => ticketCorteElectronico(r),
    );
  }

  Future<void> _mostrarCorte(ResumenCorte r, {bool recienCerrado = false}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !recienCerrado,
      builder: (_) => _DialogoCorte(
        resumen: r,
        moneda: _moneda,
        recienCerrado: recienCerrado,
        onImprimirEfectivo: () => _imprimirCorteEfectivo(r),
        onImprimirElectronico: () => _imprimirCorteElectronico(r),
      ),
    );
  }

  Future<void> _verCorte(CorteCaja corte) async {
    final vm = context.read<CashViewModel>();
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final resumen = await vm.resumenDe(corte.id);
      if (!mounted) return;
      await _mostrarCorte(resumen);
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo consultar ese corte.')),
      );
    }
  }

  Future<void> _mostrarResultadoCierre(CorteCaja corte) async {
    final calculado = corte.montoCalculado ?? 0;
    final reportado = corte.montoFinalReportado ?? 0;
    final diferencia = corte.diferencia ?? 0;
    final hayDiferencia = (diferencia - 0).abs() > 0.01;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (hayDiferencia ? Colors.amber.shade700 : const Color(0xFF10B981)).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hayDiferencia ? Icons.info_outline_rounded : Icons.check_circle_rounded,
                      color: hayDiferencia ? Colors.amber.shade700 : const Color(0xFF10B981),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Caja Cerrada',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 18),
                _FilaResultado(
                  etiqueta: 'Efectivo esperado',
                  valor: _moneda.format(calculado),
                ),
                _FilaResultado(
                  etiqueta: 'Efectivo contado',
                  valor: _moneda.format(reportado),
                ),
                const Divider(height: 20),
                _FilaResultado(
                  etiqueta: 'Diferencia de Arqueo',
                  valor: '${diferencia >= 0 ? '+' : ''}${_moneda.format(diferencia)}',
                  destacada: true,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _verHistorial() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HistorialCortes(
        vm: context.read<CashViewModel>(),
        moneda: _moneda,
        onVerCorte: (corte) {
          Navigator.of(ctx).pop();
          _verCorte(corte);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CashViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Caja'),
        actions: [
          IconButton(
            tooltip: 'Historial de cortes',
            icon: const Icon(Icons.history_rounded),
            onPressed: vm.historial.isEmpty ? null : _verHistorial,
          ),
        ],
      ),
      body: _riesgo == null
          ? const Center(child: CircularProgressIndicator())
          : _riesgo != DeviceRisk.ok
              ? _BloqueoDispositivo(
                  onReintentar: _iniciar,
                  comprometido: _riesgo == DeviceRisk.comprometido,
                )
              : _cuerpo(vm),
    );
  }

  Widget _cuerpo(CashViewModel vm) {
    if (vm.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.mensajeError != null && vm.cajaActiva == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(vm.mensajeError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  vm.limpiarError();
                  vm.cargar();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final activa = vm.cajaActiva;
    if (activa == null || !activa.tieneCajaAbierta) {
      return _FormularioApertura(
        formKey: _formKey,
        montoCtrl: _montoInicialCtrl,
        moneda: _moneda,
        procesando: vm.procesando,
        error: vm.mensajeError,
        onAbrir: _abrirCaja,
      );
    }

    final resumen = activa.resumen;
    return RefreshIndicator(
      onRefresh: vm.cargar,
      child: _ResumenTurno(
        activa: activa,
        moneda: _moneda,
        procesando: vm.procesando,
        error: vm.mensajeError,
        onCerrar: _cerrarCaja,
        onImprimirEfectivo:
            resumen == null ? null : () => _imprimirCorteEfectivo(resumen),
        onImprimirElectronico:
            resumen == null ? null : () => _imprimirCorteElectronico(resumen),
      ),
    );
  }
}

class _FormularioApertura extends StatelessWidget {
  const _FormularioApertura({
    required this.formKey,
    required this.montoCtrl,
    required this.moneda,
    required this.procesando,
    required this.error,
    required this.onAbrir,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController montoCtrl;
  final NumberFormat moneda;
  final bool procesando;
  final String? error;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.lock_open_rounded, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apertura de Caja',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                          ),
                          Text(
                            'Registra el fondo inicial para empezar a cobrar',
                            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Form(
                  key: formKey,
                  child: TextFormField(
                    key: const ValueKey('monto-inicial'),
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto inicial en efectivo',
                      prefixText: r'$ ',
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    validator: (v) {
                      final monto = double.tryParse(v?.trim() ?? '');
                      if (monto == null) return 'Ingresa un monto válido';
                      if (monto < 0) return 'El monto no puede ser negativo';
                      return null;
                    },
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(color: colors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('btn-abrir-caja'),
                  onPressed: procesando ? null : onAbrir,
                  icon: procesando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.key_rounded),
                  label: Text(procesando ? 'Abriendo caja…' : 'Abrir Caja del Turno'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumenTurno extends StatelessWidget {
  const _ResumenTurno({
    required this.activa,
    required this.moneda,
    required this.procesando,
    required this.error,
    required this.onCerrar,
    this.onImprimirEfectivo,
    this.onImprimirElectronico,
  });

  final CajaActiva activa;
  final NumberFormat moneda;
  final bool procesando;
  final String? error;
  final VoidCallback onCerrar;
  final VoidCallback? onImprimirEfectivo;
  final VoidCallback? onImprimirElectronico;

  @override
  Widget build(BuildContext context) {
    final abiertaEn = activa.corte?.abiertoEn;
    final colors = Theme.of(context).colorScheme;
    final resumen = activa.resumen;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Caja Abierta',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                    if (abiertaEn != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          formatFechaCorta(abiertaEn),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'CORTE DE EFECTIVO',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                _FilaResumen(
                  etiqueta: 'Fondo Inicial',
                  valor: moneda.format(activa.corte?.montoInicial ?? 0),
                ),
                if (resumen != null) ...[
                  _FilaResumen(
                    etiqueta: 'Ventas en efectivo (${resumen.efectivo.ventasCount})',
                    valor: moneda.format(resumen.efectivo.ventas),
                  ),
                  if (resumen.efectivo.intercambios != 0)
                    _FilaResumen(
                      etiqueta: 'Intercambios de cascos',
                      valor: moneda.format(resumen.efectivo.intercambios),
                    ),
                  if (resumen.efectivo.abonosCredito != 0)
                    _FilaResumen(
                      etiqueta: 'Abonos de crédito',
                      valor: moneda.format(resumen.efectivo.abonosCredito),
                    ),
                  if (resumen.efectivo.devoluciones != 0)
                    _FilaResumen(
                      etiqueta: 'Devoluciones pagadas',
                      valor: '− ${moneda.format(resumen.efectivo.devoluciones)}',
                    ),
                ] else
                  _FilaResumen(
                    etiqueta: 'Ventas del turno',
                    valor: moneda.format(activa.totalVentas),
                  ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EFECTIVO ESPERADO',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.05,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Lo que debe haber en el cajón',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          moneda.format(activa.montoEsperado),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (onImprimirEfectivo != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onImprimirEfectivo,
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Imprimir corte de efectivo'),
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(color: colors.error, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (resumen != null) ...[
          const SizedBox(height: 12),
          _TarjetaElectronico(
            resumen: resumen,
            moneda: moneda,
            onImprimir: onImprimirElectronico,
          ),
          const SizedBox(height: 12),
          _TarjetaCreditos(resumen: resumen, moneda: moneda),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Al cerrar se cuenta solo el efectivo del cajón. Tarjetas y '
                  'transferencias tienen su propio corte y los créditos no '
                  'entran a ninguno.',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant, height: 1.35),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const ValueKey('btn-cerrar-caja'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                  ),
                  onPressed: procesando ? null : onCerrar,
                  icon: procesando
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.error),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Cerrar Caja / Realizar Corte'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(etiqueta, style: const TextStyle(fontSize: 14))),
          const SizedBox(width: 8),
          Text(
            valor,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({
    required this.etiqueta,
    required this.valor,
    this.destacada = false,
  });

  final String etiqueta;
  final String valor;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(fontWeight: destacada ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            valor,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: destacada ? 18 : 15,
              fontWeight: FontWeight.bold,
              color: destacada ? colors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoCierre extends StatelessWidget {
  const _DialogoCierre({
    required this.montoEsperado,
    required this.moneda,
    required this.montoFinalCtrl,
  });

  final double montoEsperado;
  final NumberFormat moneda;
  final TextEditingController montoFinalCtrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cierre de Caja',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Cuenta solo el efectivo del cajón. Los vouchers de tarjeta y las '
              'transferencias van en su propio corte.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Efectivo esperado:',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                  ),
                  Text(
                    moneda.format(montoEsperado),
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('monto-final'),
              controller: montoFinalCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                labelText: 'Efectivo contado',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('btn-confirmar-cierre'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final monto = double.tryParse(montoFinalCtrl.text.trim());
                if (monto == null || monto < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un monto válido')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Confirmar Cierre', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Text('Cancelar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corte de tarjetas y transferencias del turno.
class _TarjetaElectronico extends StatelessWidget {
  const _TarjetaElectronico({
    required this.resumen,
    required this.moneda,
    this.onImprimir,
  });

  final ResumenCorte resumen;
  final NumberFormat moneda;
  final VoidCallback? onImprimir;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final el = resumen.electronico;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CORTE DE TARJETAS Y TRANSFERENCIAS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            _FilaResumen(etiqueta: 'Tarjeta de débito', valor: moneda.format(el.tarjetaDebito)),
            _FilaResumen(etiqueta: 'Tarjeta de crédito', valor: moneda.format(el.tarjetaCredito)),
            if (el.tarjetaSinTipo != 0)
              _FilaResumen(etiqueta: 'Tarjeta (sin tipo)', valor: moneda.format(el.tarjetaSinTipo)),
            _FilaResumen(etiqueta: 'Transferencias', valor: moneda.format(el.transferencias)),
            if (el.devolucionesTarjeta + el.devolucionesTransferencia != 0)
              _FilaResumen(
                etiqueta: 'Devoluciones',
                valor: '− ${moneda.format(el.devolucionesTarjeta + el.devolucionesTransferencia)}',
              ),
            const Divider(height: 20),
            _FilaResultado(
              etiqueta: 'Total del corte (${el.operaciones.length} operaciones)',
              valor: moneda.format(el.total),
              destacada: true,
            ),
            if (onImprimir != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onImprimir,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Imprimir corte de tarjetas'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ventas a crédito del turno: informativo, no suman a ningún corte.
class _TarjetaCreditos extends StatelessWidget {
  const _TarjetaCreditos({required this.resumen, required this.moneda});

  final ResumenCorte resumen;
  final NumberFormat moneda;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const ambar = Color(0xFFB45309);
    return Card(
      color: ambar.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ambar.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CRÉDITOS A EMPRESAS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: ambar,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No se cobraron: no entran a ningún corte.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            _FilaResumen(
              etiqueta: '${resumen.creditosCount} ventas · ${resumen.creditosPiezas} pilas',
              valor: moneda.format(resumen.creditosTotal),
            ),
            for (final c in resumen.creditos)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${c.folio} · ${c.empresa} · ${c.piezas} pilas · ${moneda.format(c.total)}',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Los dos cortes de una caja, con su botón de impresión cada uno.
class _DialogoCorte extends StatelessWidget {
  const _DialogoCorte({
    required this.resumen,
    required this.moneda,
    required this.recienCerrado,
    required this.onImprimirEfectivo,
    required this.onImprimirElectronico,
  });

  final ResumenCorte resumen;
  final NumberFormat moneda;
  final bool recienCerrado;
  final VoidCallback onImprimirEfectivo;
  final VoidCallback onImprimirElectronico;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final e = resumen.efectivo;
    final el = resumen.electronico;
    final diferencia = e.diferencia;
    final hayDiferencia = diferencia != null && diferencia.abs() > 0.01;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              recienCerrado ? 'Caja cerrada' : 'Corte de caja',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${resumen.sucursal} · ${formatFechaCorta(resumen.abiertoEn)}'
              '${resumen.cerradoEn != null ? ' a ${formatHora(resumen.cerradoEn)}' : ' (abierta)'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Text('Corte de efectivo', style: TextStyle(fontWeight: FontWeight.w700)),
            _FilaResultado(etiqueta: 'Efectivo esperado', valor: moneda.format(e.esperado)),
            if (e.contado != null)
              _FilaResultado(etiqueta: 'Efectivo contado', valor: moneda.format(e.contado!)),
            if (diferencia != null)
              _FilaResultado(
                etiqueta: hayDiferencia
                    ? (diferencia > 0 ? 'Sobrante' : 'Faltante')
                    : 'Diferencia',
                valor: '${diferencia >= 0 ? '+' : ''}${moneda.format(diferencia)}',
                destacada: true,
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: onImprimirEfectivo,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Imprimir corte de efectivo'),
            ),
            const Divider(height: 26),
            const Text('Corte de tarjetas y transferencias', style: TextStyle(fontWeight: FontWeight.w700)),
            _FilaResultado(etiqueta: 'Tarjetas', valor: moneda.format(el.totalTarjetas)),
            _FilaResultado(etiqueta: 'Transferencias', valor: moneda.format(el.totalTransferencias)),
            _FilaResultado(etiqueta: 'Total', valor: moneda.format(el.total), destacada: true),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: onImprimirElectronico,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Imprimir corte de tarjetas'),
            ),
            if (resumen.creditosCount > 0) ...[
              const Divider(height: 26),
              Text(
                'Créditos a empresas (aparte): ${resumen.creditosCount} ventas, '
                '${resumen.creditosPiezas} pilas, ${moneda.format(resumen.creditosTotal)}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (resumen.devolucionesCount > 0 || resumen.cancelacionesCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${resumen.devolucionesCount} devoluciones (${moneda.format(resumen.devolucionesTotal)}) · '
                '${resumen.cancelacionesCount} tickets cancelados',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Listo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorialCortes extends StatelessWidget {
  const _HistorialCortes({
    required this.vm,
    required this.moneda,
    required this.onVerCorte,
  });

  final CashViewModel vm;
  final NumberFormat moneda;
  final ValueChanged<CorteCaja> onVerCorte;

  @override
  Widget build(BuildContext context) {
    final cortes = vm.historial;
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Historial de Cortes de Caja',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca un corte para verlo o reimprimirlo.',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: cortes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Sin cortes registrados previamente')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: cortes.length,
                    itemBuilder: (context, i) {
                      final corte = cortes[i];
                      final cerrado = !corte.estaAbierta;
                      final dif = corte.diferencia ?? 0;
                      final esExacto = (dif - 0).abs() < 0.01;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => onVerCorte(corte),
                          leading: Icon(
                            cerrado ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                            color: cerrado ? colors.onSurfaceVariant : colors.primary,
                          ),
                          title: Text(
                            formatFechaCorta(corte.abiertoEn),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Efectivo ${moneda.format(corte.montoCalculado ?? corte.montoInicial)}'
                            '${corte.totalTarjetas != null ? ' · Tarjetas ${moneda.format(corte.totalTarjetas!)}' : ''}'
                            '${corte.totalTransferencias != null ? ' · Transf. ${moneda.format(corte.totalTransferencias!)}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: corte.diferencia != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (esExacto ? colors.primary : Colors.amber.shade700).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${dif >= 0 ? '+' : ''}${moneda.format(dif)}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: esExacto ? colors.primary : Colors.amber.shade700,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _BloqueoDispositivo extends StatelessWidget {
  const _BloqueoDispositivo({
    required this.onReintentar,
    required this.comprometido,
  });

  final VoidCallback onReintentar;
  final bool comprometido;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  comprometido ? Icons.gpp_bad_rounded : Icons.shield_outlined,
                  size: 56,
                  color: colors.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Caja Bloqueada por Seguridad',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  comprometido
                      ? 'Este dispositivo parece estar comprometido (root o depuración USB). '
                          'No se puede operar la caja desde aquí.'
                      : 'No se pudo verificar la seguridad del dispositivo. '
                          'La caja está bloqueada por seguridad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar verificación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
