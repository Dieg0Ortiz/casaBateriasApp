import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../cash/presentation/cash_viewmodel.dart';
import '../data/sales_remote_data_source.dart';

/// Cancelación de un ticket cobrado por error. Pide folio, motivo y la
/// clave de un administrador. Las piezas regresan al inventario y la venta
/// sale del corte. Solo se puede mientras la caja de esa venta siga abierta;
/// si el cliente regresa otro día, es una devolución.
class CancelacionScreen extends StatefulWidget {
  const CancelacionScreen({super.key});

  @override
  State<CancelacionScreen> createState() => _CancelacionScreenState();
}

class _CancelacionScreenState extends State<CancelacionScreen> {
  final _folio = TextEditingController();
  final _motivo = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _ventas = SalesRemoteDataSource();
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

  bool _enviando = false;
  String? _error;
  Map<String, dynamic>? _cancelada;

  @override
  void dispose() {
    _folio.dispose();
    _motivo.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_folio.text.trim().length < 4) {
      setState(() => _error = 'Escribe el folio del ticket.');
      return;
    }
    if (_motivo.text.trim().length < 4) {
      setState(() => _error = 'Escribe por qué se cancela.');
      return;
    }
    final seguro = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar este ticket?'),
        content: Text(
          'El ticket ${_folio.text.trim().toUpperCase()} quedará cancelado, las piezas regresan al inventario y el importe sale del corte. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;

    setState(() {
      _enviando = true;
      _error = null;
      _cancelada = null;
    });
    try {
      final json = await _ventas.cancelarTicket(
        folio: _folio.text.trim(),
        motivo: _motivo.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _cancelada = json);
      _password.clear();
      // El corte del turno cambió: se recarga para que Caja lo muestre.
      final cashVm = context.read<CashViewModel>();
      if (!cashVm.cargando) await cashVm.cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cancelar el ticket.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cancelada = _cancelada;

    return Scaffold(
      appBar: AppBar(title: const Text('Cancelar ticket')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Para un ticket cobrado por error mientras la caja sigue abierta. Las piezas regresan al inventario y el importe sale del corte. Si el cliente regresa otro día, registra una devolución.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _folio,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Folio del ticket',
              hintText: 'NV-MAT-000124',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Por qué se cancela',
              hintText: 'Se cobró dos veces',
            ),
          ),
          const SizedBox(height: 4),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: _enviando ? null : _confirmar,
            child: Text(_enviando ? 'Verificando…' : 'Cancelar ticket'),
          ),
          if (cancelada != null) ...[
            const SizedBox(height: 22),
            Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_rounded, color: colors.primary),
                title: Text(
                  'Ticket ${cancelada['folio'] ?? ''} cancelado',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_moneda.format((cancelada['total'] as num?)?.toDouble() ?? 0)} · autorizó ${cancelada['autorizo'] ?? ''}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
