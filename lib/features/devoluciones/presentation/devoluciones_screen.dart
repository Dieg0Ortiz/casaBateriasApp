import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_formatters.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../cash/presentation/cash_viewmodel.dart';
import '../data/devoluciones_remote_data_source.dart';
import '../domain/devolucion_models.dart';
import 'devolucion_ticket.dart';

/// Devoluciones de dinero con folio DEV. El dinero sale de la caja abierta
/// de la sucursal y se resta de su corte, por eso la caja debe estar abierta.
class DevolucionesScreen extends StatelessWidget {
  const DevolucionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Devoluciones'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.recycling_rounded), text: 'Depósito de casco'),
              Tab(icon: Icon(Icons.battery_alert_rounded), text: 'Batería devuelta'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_TabDepositos(), _TabBateria()],
        ),
      ),
    );
  }
}

final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

/// Recarga la caja: la devolución cambió su corte de efectivo.
Future<void> _recargarCaja(BuildContext context) async {
  final cashVm = context.read<CashViewModel>();
  if (!cashVm.cargando) await cashVm.cargar();
}

// ---------------------------------------------------------------------
// Depósito de casco
// ---------------------------------------------------------------------

class _TabDepositos extends StatefulWidget {
  const _TabDepositos();

  @override
  State<_TabDepositos> createState() => _TabDepositosState();
}

class _TabDepositosState extends State<_TabDepositos>
    with AutomaticKeepAliveClientMixin {
  final _ds = DevolucionesRemoteDataSource();
  final _folio = TextEditingController();

  List<DepositoPendiente> _depositos = [];
  bool _cargando = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _folio.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _ds.depositosPendientes(folio: _folio.text);
      if (!mounted) return;
      setState(() {
        _depositos = datos;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron consultar los depósitos.';
        _cargando = false;
      });
    }
  }

  Future<void> _devolver(DepositoPendiente deposito) async {
    final devolucion = await showModalBottomSheet<Devolucion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FormularioDeposito(deposito: deposito, ds: _ds),
    );
    if (devolucion == null || !mounted) return;
    await _recargarCaja(context);
    if (!mounted) return;
    await mostrarDevolucionRegistrada(context, devolucion);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final esAdmin = context.watch<AuthViewModel>().usuario?.esAdministrador == true;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'El cliente se llevó la batería sin dejar casco y pagó el depósito. '
            'Si regresa con el casco dentro de los 15 días, se le devuelve el dinero '
            'y el casco entra a la bodega.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.35, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _folio,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por folio de venta',
                    hintText: 'NV-MAT-000124',
                  ),
                  onSubmitted: (_) => _cargar(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(color: colors.error))
          else if (_depositos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No hay depósitos pendientes.')),
            )
          else
            for (final d in _depositos)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: d.vencido && !esAdmin
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Venció el plazo. Solo un administrador puede devolver este depósito.',
                              ),
                            ),
                          )
                      : () => _devolver(d),
                  leading: Icon(
                    Icons.recycling_rounded,
                    color: d.vencido ? colors.error : colors.primary,
                  ),
                  title: Text(
                    '${d.folio ?? '—'} · ${d.producto}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${d.piezas} pza · vence ${formatFechaCorta(d.fechaLimite)}'
                    '${d.clienteNombre != null && d.clienteNombre!.isNotEmpty ? ' · ${d.clienteNombre}' : ''}'
                    '${d.vencido ? ' · VENCIDO' : ''}',
                    style: TextStyle(fontSize: 12, color: d.vencido ? colors.error : null),
                  ),
                  trailing: Text(
                    _moneda.format(d.deposito),
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _FormularioDeposito extends StatefulWidget {
  const _FormularioDeposito({required this.deposito, required this.ds});

  final DepositoPendiente deposito;
  final DevolucionesRemoteDataSource ds;

  @override
  State<_FormularioDeposito> createState() => _FormularioDepositoState();
}

class _FormularioDepositoState extends State<_FormularioDeposito> {
  late final TextEditingController _monto =
      TextEditingController(text: widget.deposito.deposito.toStringAsFixed(2));
  final _notas = TextEditingController();
  String _metodo = 'efectivo';
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', ''));
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Escribe un monto mayor a cero.');
      return;
    }
    if (monto > widget.deposito.deposito + 0.005) {
      setState(() => _error =
          'No se puede devolver más del depósito (${_moneda.format(widget.deposito.deposito)}).');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final devolucion = await widget.ds.devolverDeposito(
        cascoId: widget.deposito.id,
        monto: monto,
        metodoReembolso: _metodo,
        notas: _notas.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(devolucion);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo registrar la devolución.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deposito;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Devolver depósito de casco',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${d.folio ?? ''} · ${d.producto} · ${d.piezas} pza · depósito ${_moneda.format(d.deposito)}',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto a devolver',
              prefixText: r'$ ',
              helperText: 'Menos si el casco que trae vale menos que el depósito',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _metodo,
            decoration: const InputDecoration(labelText: 'Se devuelve en'),
            items: [
              for (final m in metodosReembolso.entries)
                DropdownMenuItem(value: m.key, child: Text(m.value)),
            ],
            onChanged: (v) => setState(() => _metodo = v ?? 'efectivo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notas,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              hintText: 'Trajo casco de otro modelo',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _enviando ? null : _confirmar,
            child: Text(_enviando ? 'Registrando…' : 'Devolver depósito'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Batería devuelta
// ---------------------------------------------------------------------

class _TabBateria extends StatefulWidget {
  const _TabBateria();

  @override
  State<_TabBateria> createState() => _TabBateriaState();
}

/// Lo que se devuelve de un renglón de la venta.
class _Seleccion {
  _Seleccion(this.renglon) : monto = TextEditingController(text: '0.00');

  final RenglonVentaDevolucion renglon;
  final TextEditingController monto;
  int piezas = 0;
  bool reingresa = true;

  /// Mientras el cajero no escriba el monto, se calcula solo.
  bool montoEditado = false;

  void calcularMonto() {
    if (!montoEditado) {
      monto.text = renglon.maximoPara(piezas).toStringAsFixed(2);
    }
  }

  double get montoActual => double.tryParse(monto.text.trim().replaceAll(',', '')) ?? 0;
}

class _TabBateriaState extends State<_TabBateria>
    with AutomaticKeepAliveClientMixin {
  final _ds = DevolucionesRemoteDataSource();
  final _folio = TextEditingController();
  final _motivo = TextEditingController();
  final _cliente = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  VentaDevolucion? _venta;
  List<_Seleccion> _selecciones = [];
  String _metodo = 'efectivo';
  bool _buscando = false;
  bool _enviando = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _folio.dispose();
    _motivo.dispose();
    _cliente.dispose();
    _email.dispose();
    _password.dispose();
    for (final s in _selecciones) {
      s.monto.dispose();
    }
    super.dispose();
  }

  double get _total => _selecciones.fold(0, (s, x) => s + (x.piezas > 0 ? x.montoActual : 0));

  Future<void> _buscar() async {
    if (_folio.text.trim().length < 4) {
      setState(() => _error = 'Escribe el folio del ticket.');
      return;
    }
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final venta = await _ds.ventaPorFolio(_folio.text);
      if (!mounted) return;
      for (final s in _selecciones) {
        s.monto.dispose();
      }
      setState(() {
        _venta = venta;
        _selecciones = venta.items.where((i) => i.porDevolver > 0).map(_Seleccion.new).toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _venta = null;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo buscar la venta.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  String? _validar() {
    final elegidas = _selecciones.where((s) => s.piezas > 0).toList();
    if (elegidas.isEmpty) return 'Elige cuántas piezas se devuelven.';
    for (final s in elegidas) {
      final maximo = s.renglon.maximoPara(s.piezas);
      if (s.montoActual < 0 || s.montoActual > maximo + 0.005) {
        return 'El monto de ${s.renglon.producto} debe ser de \$0 a ${_moneda.format(maximo)}.';
      }
    }
    if (_total <= 0) return 'El monto a devolver debe ser mayor a cero.';
    if (_motivo.text.trim().length < 4) return 'Escribe el motivo de la devolución.';
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      return 'Hace falta la clave de un administrador.';
    }
    return null;
  }

  Future<void> _confirmar() async {
    final venta = _venta;
    if (venta == null) return;
    final problema = _validar();
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final devolucion = await _ds.devolverBateria(
        ventaId: venta.id,
        items: [
          for (final s in _selecciones.where((s) => s.piezas > 0))
            RenglonADevolver(
              ventaItemId: s.renglon.ventaItemId,
              cantidad: s.piezas,
              monto: s.montoActual,
              reingresaInventario: s.reingresa,
            ),
        ],
        motivo: _motivo.text,
        metodoReembolso: _metodo,
        clienteNombre: _cliente.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      _password.clear();
      await _recargarCaja(context);
      if (!mounted) return;
      await mostrarDevolucionRegistrada(context, devolucion);
      if (!mounted) return;
      _motivo.clear();
      _cliente.clear();
      await _buscar();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo registrar la devolución.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final venta = _venta;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'El cliente regresa una batería. Las piezas vuelven al inventario (salvo que '
          'vengan dañadas) y el dinero sale de la caja. Lo autoriza un administrador con su clave.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.35, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _folio,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Folio del ticket',
                  hintText: 'NV-MAT-000124',
                ),
                onSubmitted: (_) => _buscar(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _buscando ? null : _buscar,
              icon: _buscando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search_rounded),
            ),
          ],
        ),
        if (venta != null) ...[
          const SizedBox(height: 16),
          Text(
            '${venta.folio} · ${formatFechaCorta(venta.creadaEn)} · ${_moneda.format(venta.total)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (venta.esCredito)
            Text(
              'Es una venta a crédito: las piezas se corrigen desde el crédito de la empresa en el panel.',
              style: TextStyle(color: colors.error),
            )
          else if (venta.cancelada)
            Text('Esta venta está cancelada.', style: TextStyle(color: colors.error))
          else if (venta.todoDevuelto)
            const Text('Todas las piezas de esta venta ya se devolvieron.')
          else ...[
            for (final s in _selecciones) _RenglonDevolucion(
              seleccion: s,
              onCambio: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _metodo,
              decoration: const InputDecoration(labelText: 'Se devuelve en'),
              items: [
                for (final m in metodosReembolso.entries)
                  DropdownMenuItem(value: m.key, child: Text(m.value)),
              ],
              onChanged: (v) => setState(() => _metodo = v ?? 'efectivo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Se equivocó de modelo / garantía',
              ),
            ),
            TextField(
              controller: _cliente,
              decoration: const InputDecoration(labelText: 'Nombre del cliente (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Correo del administrador'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña del administrador'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total a devolver', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _moneda.format(_total),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _enviando ? null : _confirmar,
              child: Text(_enviando ? 'Verificando…' : 'Registrar devolución'),
            ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: colors.error)),
        ],
      ],
    );
  }
}

class _RenglonDevolucion extends StatelessWidget {
  const _RenglonDevolucion({required this.seleccion, required this.onCambio});

  final _Seleccion seleccion;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final r = seleccion.renglon;
    final colors = Theme.of(context).colorScheme;

    void cambiarPiezas(int piezas) {
      seleccion.piezas = piezas;
      seleccion.calcularMonto();
      onCambio();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.producto, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Vendidas ${r.cantidad}${r.devueltas > 0 ? ' · ya devueltas ${r.devueltas}' : ''} · '
              '${_moneda.format(r.precioUnitario)} c/u'
              '${r.depositoPendiente != null ? ' · depósito ${_moneda.format(r.depositoPendiente!)}' : ''}',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: seleccion.piezas > 0 ? () => cambiarPiezas(seleccion.piezas - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text(
                  '${seleccion.piezas}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: seleccion.piezas < r.porDevolver
                      ? () => cambiarPiezas(seleccion.piezas + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: seleccion.monto,
                    enabled: seleccion.piezas > 0,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$ '),
                    onChanged: (_) {
                      seleccion.montoEditado = true;
                      onCambio();
                    },
                  ),
                ),
              ],
            ),
            if (seleccion.piezas > 0)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: seleccion.reingresa,
                onChanged: (v) {
                  seleccion.reingresa = v;
                  onCambio();
                },
                title: const Text('Regresa al inventario para venderse'),
                subtitle: const Text('Apágalo si la batería viene dañada'),
              ),
          ],
        ),
      ),
    );
  }
}
