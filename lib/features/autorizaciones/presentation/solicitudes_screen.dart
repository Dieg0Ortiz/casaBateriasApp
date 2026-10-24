import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_formatters.dart';
import '../data/autorizaciones_remote_data_source.dart';
import '../domain/solicitud_models.dart';
import 'solicitud_screen.dart';

/// Abre la espera de una solicitud recién enviada al panel.
Future<void> abrirSolicitud(BuildContext context, SolicitudAutorizacion s) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SolicitudScreen(solicitud: s)),
  );
}

/// Lo que la sucursal pidió hoy al panel y cómo va cada cosa.
class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  final _ds = AutorizacionesRemoteDataSource();
  List<SolicitudAutorizacion> _lista = const [];
  bool _cargando = true;
  String? _error;
  Timer? _consulta;

  @override
  void initState() {
    super.initState();
    _cargar();
    _consulta = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _cargar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _consulta?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final lista = await _ds.deHoy();
      if (!mounted) return;
      setState(() {
        _lista = lista;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && !silencioso) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && !silencioso) {
        setState(() => _error = 'No se pudieron cargar las solicitudes.');
      }
    } finally {
      if (mounted && !silencioso) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir(SolicitudAutorizacion s) async {
    await abrirSolicitud(context, s);
    if (mounted) await _cargar(silencioso: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Autorizaciones de hoy')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!, style: TextStyle(color: colors.error)),
                    ),
                  if (_lista.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Hoy no se ha pedido ninguna autorización al panel.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  for (final s in _lista)
                    Card(
                      child: ListTile(
                        onTap: () => _abrir(s),
                        leading: Icon(_icono(s.tipo), color: colors.primary),
                        title: Text('${s.tipo.titulo} · ${s.folio}'),
                        subtitle: Text('${formatHora(s.creadaEn)} · ${_detalle(s)}'),
                        trailing: Icon(
                          s.reimpresionPorImprimir
                              ? Icons.print_rounded
                              : Icons.chevron_right_rounded,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  static IconData _icono(TipoSolicitud tipo) => switch (tipo) {
        TipoSolicitud.reimpresion => Icons.receipt_long_rounded,
        TipoSolicitud.cancelacion => Icons.block_rounded,
        TipoSolicitud.devolucionBateria => Icons.battery_alert_rounded,
      };

  static String _detalle(SolicitudAutorizacion s) {
    if (s.reimpresionPorImprimir) return 'Aprobada: falta imprimir';
    if (s.estado == EstadoSolicitud.rechazada && s.notaResolucion != null) {
      return 'Rechazada: ${s.notaResolucion}';
    }
    return s.estado.texto;
  }
}
