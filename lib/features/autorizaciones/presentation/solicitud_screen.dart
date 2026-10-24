import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_formatters.dart';
import '../../cash/presentation/cash_viewmodel.dart';
import '../../devoluciones/domain/devolucion_models.dart';
import '../../devoluciones/presentation/devolucion_ticket.dart';
import '../../printing/printer_screen.dart';
import '../../printing/ticket_builder.dart';
import '../../sales/presentation/ticket_reimpresion.dart';
import '../data/autorizaciones_remote_data_source.dart';
import '../domain/solicitud_models.dart';

/// Una solicitud enviada al panel: espera la respuesta del administrador
/// y, cuando la aprueba, ofrece imprimir lo que corresponda.
class SolicitudScreen extends StatefulWidget {
  const SolicitudScreen({super.key, required this.solicitud});

  final SolicitudAutorizacion solicitud;

  @override
  State<SolicitudScreen> createState() => _SolicitudScreenState();
}

class _SolicitudScreenState extends State<SolicitudScreen> {
  final _ds = AutorizacionesRemoteDataSource();
  late SolicitudAutorizacion _s = widget.solicitud;
  Timer? _consulta;
  bool _trabajando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_s.pendiente) {
      _consulta = Timer.periodic(const Duration(seconds: 4), (_) => _actualizar());
    } else {
      _actualizar();
    }
  }

  @override
  void dispose() {
    _consulta?.cancel();
    super.dispose();
  }

  Future<void> _actualizar() async {
    try {
      final nueva = await _ds.obtener(_s.id);
      if (!mounted) return;
      final recienResuelta = _s.pendiente && !nueva.pendiente;
      setState(() {
        _s = nueva;
        _error = null;
      });
      if (!nueva.pendiente) _consulta?.cancel();
      if (recienResuelta) await _alResolverse(nueva);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      // Sin señal: se reintenta en la siguiente vuelta.
    }
  }

  /// Una cancelación o devolución aprobada cambia el corte de la caja.
  Future<void> _alResolverse(SolicitudAutorizacion s) async {
    if (s.estado != EstadoSolicitud.aprobada) return;
    if (s.tipo != TipoSolicitud.reimpresion) {
      final cashVm = context.read<CashViewModel>();
      if (!cashVm.cargando) await cashVm.cargar();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${s.tipo.titulo} ${s.folio}: aprobado por ${s.autorizador ?? 'el administrador'}',
        ),
      ),
    );
  }

  Future<void> _retirar() async {
    setState(() => _trabajando = true);
    try {
      final s = await _ds.retirar(_s.id);
      _consulta?.cancel();
      if (mounted) setState(() => _s = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      await _actualizar();
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _imprimirReimpresion() async {
    final ticket = _s.ticket;
    if (ticket == null) return;
    final datos = TicketReimpresion.fromJson(ticket);
    final impreso = await imprimirDocumento(
      context,
      titulo: 'reimpresión ${datos.folio}',
      construir: datos.construir,
    );
    if (!impreso || !mounted) return;
    setState(() => _trabajando = true);
    try {
      final s = await _ds.marcarImpresa(_s.id);
      if (mounted) setState(() => _s = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_s.tipo.titulo)),
      body: RefreshIndicator(
        onRefresh: _actualizar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(_s.folio, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('“${_s.motivo}” · ${formatHora(_s.creadaEn)}'),
                trailing: _Estado(estado: _s.estado),
              ),
            ),
            const SizedBox(height: 20),
            ..._contenido(colors),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido(ColorScheme colors) {
    switch (_s.estado) {
      case EstadoSolicitud.pendiente:
        return [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(
            'Esperando a que un administrador la apruebe en el panel. '
            'Puedes salir de esta pantalla: la encuentras en Inicio → Autorizaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _trabajando ? null : _retirar,
            child: const Text('Ya no hace falta: retirar solicitud'),
          ),
        ];
      case EstadoSolicitud.rechazada:
        return [
          _Mensaje(
            icono: Icons.cancel_rounded,
            color: colors.error,
            titulo: 'Rechazada por ${_s.autorizador ?? 'el administrador'}',
            texto: _s.notaResolucion ?? 'No dejó comentario.',
          ),
        ];
      case EstadoSolicitud.retirada:
        return [
          _Mensaje(
            icono: Icons.undo_rounded,
            color: colors.onSurfaceVariant,
            titulo: 'Solicitud retirada',
            texto: _s.notaResolucion ?? 'Se retiró antes de que la atendieran.',
          ),
        ];
      case EstadoSolicitud.aprobada:
        return _aprobada();
    }
  }

  List<Widget> _aprobada() {
    const verde = Color(0xFF10B981);
    final autorizo = 'Autorizó ${_s.autorizador ?? 'el administrador'}.';
    switch (_s.tipo) {
      case TipoSolicitud.reimpresion:
        return [
          _Mensaje(
            icono: Icons.check_circle_rounded,
            color: verde,
            titulo: 'Reimpresión aprobada',
            texto: _s.impresaEn == null
                ? '$autorizo El papel sale marcado como reimpresión y solo se imprime una vez.'
                : '$autorizo Ya se imprimió a las ${formatHora(_s.impresaEn)}. Para otra copia, pide otra autorización.',
          ),
          if (_s.reimpresionPorImprimir) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _trabajando ? null : _imprimirReimpresion,
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir ticket'),
            ),
          ],
        ];
      case TipoSolicitud.cancelacion:
        return [
          _Mensaje(
            icono: Icons.check_circle_rounded,
            color: verde,
            titulo: 'Ticket cancelado',
            texto: '$autorizo Las pilas regresaron al inventario y el importe salió del corte.',
          ),
        ];
      case TipoSolicitud.devolucionBateria:
        final resultado = _s.resultado;
        final devolucion = resultado == null ? null : Devolucion.fromJson(resultado);
        final monto = devolucion?.monto ?? _s.montoDevolucion ?? 0;
        return [
          _Mensaje(
            icono: Icons.check_circle_rounded,
            color: verde,
            titulo: 'Entrega ${TicketBuilder.moneda(monto)} al cliente',
            texto: '$autorizo Devolución ${devolucion?.folio ?? ''}; ya se restó del corte.',
          ),
          if (devolucion != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => imprimirDevolucion(context, devolucion),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir comprobante'),
            ),
          ],
        ];
    }
  }
}

class _Estado extends StatelessWidget {
  const _Estado({required this.estado});

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (estado) {
      EstadoSolicitud.pendiente => Colors.amber.shade700,
      EstadoSolicitud.aprobada => const Color(0xFF10B981),
      EstadoSolicitud.rechazada => colors.error,
      EstadoSolicitud.retirada => colors.onSurfaceVariant,
    };
    return Text(
      estado == EstadoSolicitud.pendiente ? 'Pendiente' : estado.texto,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: color, size: 48),
        const SizedBox(height: 10),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(texto, textAlign: TextAlign.center, style: const TextStyle(height: 1.35)),
      ],
    );
  }
}
