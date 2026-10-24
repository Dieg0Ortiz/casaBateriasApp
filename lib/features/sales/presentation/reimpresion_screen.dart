import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../autorizaciones/data/autorizaciones_remote_data_source.dart';
import '../../autorizaciones/domain/solicitud_models.dart';
import '../../autorizaciones/presentation/selector_autorizacion.dart';
import '../../autorizaciones/presentation/solicitudes_screen.dart';
import '../../../core/utils/date_formatters.dart';
import '../../printing/print_models.dart';
import '../../printing/printer_screen.dart';
import '../../printing/ticket_builder.dart';
import '../data/sales_remote_data_source.dart';
import '../domain/sales_models.dart';
import 'ticket_reimpresion.dart';

/// Reimpresión de un ticket ya cobrado. No está en el flujo de cobro:
/// pide la venta (de la lista de hoy o por folio) y el motivo; la autoriza
/// un administrador desde el panel o con su clave aquí. El papel sale
/// marcado como reimpresión.
class ReimpresionScreen extends StatefulWidget {
  const ReimpresionScreen({super.key});

  @override
  State<ReimpresionScreen> createState() => _ReimpresionScreenState();
}

class _ReimpresionScreenState extends State<ReimpresionScreen> {
  final _folio = TextEditingController();
  final _motivo = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _ventas = SalesRemoteDataSource();
  final _autorizaciones = AutorizacionesRemoteDataSource();

  bool _autorizando = false;
  bool _aDistancia = true;
  String? _error;
  TicketReimpresion? _autorizada;

  List<VentaDelDia> _deHoy = const [];
  bool _cargandoHoy = true;
  String? _errorHoy;

  @override
  void initState() {
    super.initState();
    _folio.addListener(() => setState(() {}));
    _cargarHoy();
  }

  @override
  void dispose() {
    _folio.dispose();
    _motivo.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _cargarHoy() async {
    setState(() {
      _cargandoHoy = true;
      _errorHoy = null;
    });
    try {
      final ventas = await _ventas.ventasDeHoy();
      if (!mounted) return;
      setState(() => _deHoy = ventas);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorHoy = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorHoy = 'No se pudieron cargar las ventas de hoy.');
    } finally {
      if (mounted) setState(() => _cargandoHoy = false);
    }
  }

  void _elegir(VentaDelDia venta) {
    _folio.text = venta.folio;
    setState(() {
      _autorizada = null;
      _error = null;
    });
  }

  Future<void> _autorizar() async {
    if (_aDistancia) return _pedirAlPanel();
    setState(() {
      _autorizando = true;
      _error = null;
      _autorizada = null;
    });
    try {
      final json = await _ventas.autorizarReimpresion(
        folio: _folio.text.trim(),
        motivo: _motivo.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _autorizada = TicketReimpresion.fromJson(json));
      _password.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo autorizar la reimpresión.');
    } finally {
      if (mounted) setState(() => _autorizando = false);
    }
  }

  Future<void> _pedirAlPanel() async {
    setState(() {
      _autorizando = true;
      _error = null;
      _autorizada = null;
    });
    try {
      final solicitud = await _autorizaciones.solicitar(
        tipo: TipoSolicitud.reimpresion,
        folio: _folio.text,
        motivo: _motivo.text,
      );
      if (!mounted) return;
      await abrirSolicitud(context, solicitud);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo enviar la solicitud.');
    } finally {
      if (mounted) setState(() => _autorizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lista = _autorizada;

    return Scaffold(
      appBar: AppBar(title: const Text('Reimprimir ticket')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Esto no cobra de nuevo. Elige la venta de hoy o escribe su folio y el motivo; un administrador lo autoriza. El papel sale marcado como reimpresión.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 18),
          _VentasDeHoy(
            ventas: _deHoy,
            cargando: _cargandoHoy,
            error: _errorHoy,
            folioElegido: _folio.text.trim().toUpperCase(),
            onElegir: _elegir,
            onRecargar: _cargarHoy,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _folio,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Folio de la venta',
              hintText: 'NV-MAT-000177',
              helperText: 'Se llena solo al tocar una venta de la lista',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            decoration: const InputDecoration(
              labelText: 'Por qué se reimprime',
              hintText: 'El cliente perdió su ticket',
            ),
          ),
          const SizedBox(height: 12),
          SelectorAutorizacion(
            aDistancia: _aDistancia,
            onCambio: (v) => setState(() => _aDistancia = v),
          ),
          if (!_aDistancia) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo del administrador',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña del administrador',
            ),
          ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _autorizando ? null : _autorizar,
            child: Text(
              _autorizando
                  ? 'Enviando…'
                  : _aDistancia
                      ? 'Enviar al administrador'
                      : 'Pedir autorización',
            ),
          ),
          if (lista != null) ...[
            const SizedBox(height: 22),
            Text(
              'Reimpresión ${lista.numero} autorizada por ${lista.autorizo}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('${lista.folio} · ${lista.sucursal}'),
            Text(lista.metodoPago),
            const SizedBox(height: 8),
            for (final linea in lista.lineas)
              Text(
                '${linea.marca ?? ''} ${linea.modelo}  x${linea.cantidad}'.trim(),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => imprimirDocumento(
                context,
                titulo: 'reimpresión ${lista.folio}',
                construir: lista.construir,
              ),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir ticket marcado'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lista de las ventas de hoy para elegir cuál reimprimir.
class _VentasDeHoy extends StatelessWidget {
  const _VentasDeHoy({
    required this.ventas,
    required this.cargando,
    required this.error,
    required this.folioElegido,
    required this.onElegir,
    required this.onRecargar,
  });

  final List<VentaDelDia> ventas;
  final bool cargando;
  final String? error;
  final String folioElegido;
  final ValueChanged<VentaDelDia> onElegir;
  final VoidCallback onRecargar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final Widget contenido;
    if (cargando) {
      contenido = const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      contenido = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    } else if (ventas.isEmpty) {
      contenido = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Todavía no hay ventas hoy.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    } else {
      contenido = Column(
        children: [
          for (final venta in ventas)
            _RenglonVenta(
              venta: venta,
              elegida: venta.folio.toUpperCase() == folioElegido,
              onTap: venta.cancelada ? null : () => onElegir(venta),
            ),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ventas de hoy',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: cargando ? null : onRecargar,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          contenido,
        ],
      ),
    );
  }
}

class _RenglonVenta extends StatelessWidget {
  const _RenglonVenta({
    required this.venta,
    required this.elegida,
    required this.onTap,
  });

  final VentaDelDia venta;
  final bool elegida;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final detalle = [
      if (venta.articulos.isNotEmpty) venta.articulos.join(', '),
      nombreMetodoPago(venta.metodoPago),
      if (venta.cajero != null) 'Cobró ${venta.cajero}',
      if (venta.sucursal != null) venta.sucursal!,
    ].join(' · ');

    return ListTile(
      selected: elegida,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.35),
      enabled: onTap != null,
      onTap: onTap,
      leading: Icon(
        elegida ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
        color: elegida ? colors.primary : colors.onSurfaceVariant,
      ),
      title: Text(
        '${formatHora(venta.creadaEn)}  ${venta.folio}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        venta.cancelada ? 'Cancelada · $detalle' : detalle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        TicketBuilder.moneda(venta.total),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          decoration: venta.cancelada ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
